package org.bigredbutton.firststudy

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.os.SystemClock
import android.util.Log
import java.util.UUID
import kotlin.math.roundToLong

data class PolarStatusSnapshot(
    val state: String = "idle",
    val detected: Boolean = false,
    val connected: Boolean = false,
    val streaming: Boolean = false,
    val pmdReady: Boolean = false,
    val ecgStreaming: Boolean = false,
    val deviceName: String = "",
    val deviceAddress: String = "",
    val heartRateBpm: Int = 0,
    val rrIntervalCount: Int = 0,
    val ecgSampleCount: Int = 0,
    val pmdFrameCount: Int = 0,
    val lastEventElapsedMs: Long = 0L,
    val lastEcgEventElapsedMs: Long = 0L,
    val requestedMtu: Int = 0,
    val negotiatedMtu: Int = 0,
    val connectionPriorityHighRequested: Boolean = false,
    val ecgSampleRateHz: Int = 0,
    val ecgResolutionBits: Int = 0,
    val missingPermissions: String = "",
    val error: String = "",
)

data class PolarRrMeasurement(
    val heartRateBpm: Int,
    val rrIntervalsMs: List<Double>,
    val deviceName: String,
    val deviceAddress: String,
    val elapsedRealtimeMs: Long,
    val unixTimeMs: Long,
)

data class PolarEcgSample(
    val sampleIndexInFrame: Int,
    val sensorTimestampNs: Long,
    val estimatedElapsedRealtimeMs: Long,
    val estimatedElapsedRealtimeNs: Long,
    val estimatedUnixTimeMs: Long,
    val microVolts: Int,
    val frameType: Int,
    val sampleRateHz: Int,
    val requestedMtu: Int,
    val negotiatedMtu: Int,
    val packageSizeBytes: Int,
)

data class PolarEcgMeasurement(
    val frameIndex: Int,
    val frameTimestampNs: Long,
    val previousFrameTimestampNs: Long,
    val receivedElapsedRealtimeMs: Long,
    val receivedUnixTimeMs: Long,
    val frameType: Int,
    val sampleRateHz: Int,
    val requestedMtu: Int,
    val negotiatedMtu: Int,
    val packageSizeBytes: Int,
    val deviceName: String,
    val deviceAddress: String,
    val samples: List<PolarEcgSample>,
)

class PolarH10HeartRateClient(
    context: Context,
    private val listener: Listener,
) {
  interface Listener {
    fun onPolarStatus(status: PolarStatusSnapshot)
    fun onPolarRrMeasurement(measurement: PolarRrMeasurement)
    fun onPolarEcgMeasurement(measurement: PolarEcgMeasurement)
  }

  private val appContext = context.applicationContext
  private val mainHandler = Handler(Looper.getMainLooper())
  private var gatt: BluetoothGatt? = null
  private var scanning = false
  private var deviceName = ""
  private var deviceAddress = ""
  private var rrIntervalCount = 0
  private var ecgSampleCount = 0
  private var pmdFrameCount = 0
  private var heartRateBpm = 0
  private var streamingHr = false
  private var pmdReady = false
  private var ecgStreaming = false
  private var pmdControlPoint: BluetoothGattCharacteristic? = null
  private var pmdData: BluetoothGattCharacteristic? = null
  private var pmdCpNotificationsEnabled = false
  private var pmdDataNotificationsEnabled = false
  private var requestedMtu = POLAR_LOW_LATENCY_MTU
  private var negotiatedMtu = 0
  private var mtuRetryIndex = 0
  private var connectionPriorityHighRequested = false
  private var ecgSampleRateHz = POLAR_ECG_SAMPLE_RATE_HZ
  private var ecgResolutionBits = POLAR_ECG_RESOLUTION_BITS
  private var previousEcgFrameTimestampNs = 0L
  private val descriptorQueue = mutableListOf<DescriptorWriteRequest>()
  private var descriptorWriteInFlight = false

  private val scanTimeoutRunnable = Runnable {
    if (scanning) {
      stopScanOnly()
      publishStatus(state = "not_detected", error = "No Polar H10-compatible Heart Rate Service advertisement detected.")
    }
  }

  private val scanCallback =
      object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
          handleScanResult(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
          results.forEach { handleScanResult(it) }
        }

        override fun onScanFailed(errorCode: Int) {
          scanning = false
          publishStatus(state = "scan_failed", error = "BLE scan failed with code $errorCode.")
        }
      }

  @SuppressLint("MissingPermission")
  fun start() {
    val missing = missingPermissions()
    if (missing.isNotBlank()) {
      publishStatus(state = "missing_permissions", missingPermissions = missing)
      return
    }
    val adapter = bluetoothAdapter()
    if (adapter == null || !adapter.isEnabled) {
      publishStatus(state = "bluetooth_unavailable", error = "Bluetooth adapter unavailable or disabled.")
      return
    }
    stop()
    val scanner = adapter.bluetoothLeScanner
    if (scanner == null) {
      publishStatus(state = "scanner_unavailable", error = "Bluetooth LE scanner unavailable.")
      return
    }
    scanning = true
    rrIntervalCount = 0
    ecgSampleCount = 0
    pmdFrameCount = 0
    negotiatedMtu = 0
    mtuRetryIndex = 0
    previousEcgFrameTimestampNs = 0L
    publishStatus(state = "scanning")
    val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
    scanner.startScan(null, settings, scanCallback)
    mainHandler.removeCallbacks(scanTimeoutRunnable)
    mainHandler.postDelayed(scanTimeoutRunnable, SCAN_TIMEOUT_MS)
  }

  @SuppressLint("MissingPermission")
  fun stop() {
    stopScanOnly()
    stopEcgStreamBestEffort()
    gatt?.disconnect()
    gatt?.close()
    gatt = null
    pmdControlPoint = null
    pmdData = null
    descriptorQueue.clear()
    descriptorWriteInFlight = false
    streamingHr = false
    pmdReady = false
    ecgStreaming = false
    publishStatus(state = "stopped")
  }

  @SuppressLint("MissingPermission")
  private fun stopScanOnly() {
    if (!scanning) {
      return
    }
    val adapter = bluetoothAdapter()
    adapter?.bluetoothLeScanner?.stopScan(scanCallback)
    mainHandler.removeCallbacks(scanTimeoutRunnable)
    scanning = false
  }

  @SuppressLint("MissingPermission")
  private fun handleScanResult(result: ScanResult) {
    if (!scanning || missingPermissions().isNotBlank()) {
      return
    }
    val scanName = result.scanRecord?.deviceName ?: result.device.name ?: ""
    val advertisedServices = result.scanRecord?.serviceUuids ?: emptyList<ParcelUuid>()
    val hasHeartRateService = advertisedServices.any { it.uuid == HEART_RATE_SERVICE }
    val hasPmdService = advertisedServices.any { it.uuid == PMD_SERVICE }
    val looksPolar = scanName.contains("polar", ignoreCase = true) || scanName.contains("h10", ignoreCase = true)
    if (!looksPolar && !hasHeartRateService && !hasPmdService) {
      return
    }
    stopScanOnly()
    deviceName = scanName.ifBlank { "Polar-compatible heart-rate sensor" }
    deviceAddress = result.device.address ?: ""
    publishStatus(state = "detected", detected = true, deviceName = deviceName, deviceAddress = deviceAddress)
    gatt = result.device.connectGatt(appContext, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    publishStatus(state = "connecting", detected = true, deviceName = deviceName, deviceAddress = deviceAddress)
  }

  private val gattCallback =
      object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
          if (status != BluetoothGatt.GATT_SUCCESS) {
            publishStatus(state = "connection_failed", error = "GATT status $status.")
            closeGatt(gatt)
            return
          }
          if (newState == BluetoothProfile.STATE_CONNECTED) {
            connectionPriorityHighRequested =
                gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
            requestedMtu = POLAR_LOW_LATENCY_MTU
            val mtuIssued = gatt.requestMtu(requestedMtu)
            Log.i(
                "BigRedButtonStudy",
                "BRB_POLAR_H10_LOW_LATENCY_CONFIG connectionPriorityHighRequested=$connectionPriorityHighRequested requestedMtu=$requestedMtu mtuIssued=$mtuIssued strategy=minimum_mtu_low_latency_ecg",
            )
            publishStatus(state = "connected", detected = true, connected = true)
            mainHandler.postDelayed({ gatt.discoverServices() }, SERVICE_DISCOVERY_DELAY_MS)
          } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
            streamingHr = false
            pmdReady = false
            ecgStreaming = false
            publishStatus(state = "disconnected", detected = true)
            closeGatt(gatt)
          }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
          if (status == BluetoothGatt.GATT_SUCCESS) {
            negotiatedMtu = mtu
            publishStatus(state = "mtu_negotiated", detected = true, connected = true)
          } else {
            publishStatus(state = "mtu_failed", detected = true, connected = true, error = "MTU request status $status.")
          }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
          if (status != BluetoothGatt.GATT_SUCCESS) {
            publishStatus(state = "service_discovery_failed", error = "GATT status $status.")
            return
          }
          configureHeartRateNotifications(gatt)
          configurePmdNotifications(gatt)
          if (!descriptorWriteInFlight) {
            writeNextDescriptor(gatt)
          }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
          val label = descriptorQueue.firstOrNull()?.label ?: descriptor.characteristic?.uuid?.toString().orEmpty()
          if (descriptorQueue.isNotEmpty()) {
            descriptorQueue.removeAt(0)
          }
          descriptorWriteInFlight = false
          if (status == BluetoothGatt.GATT_SUCCESS) {
            when (descriptor.characteristic?.uuid) {
              HEART_RATE_MEASUREMENT -> {
                streamingHr = true
                publishStatus(state = "streaming", detected = true, connected = true, streaming = true)
              }
              PMD_CP -> {
                pmdCpNotificationsEnabled = true
                publishStatus(state = "pmd_cp_enabled", detected = true, connected = true)
              }
              PMD_DATA -> {
                pmdDataNotificationsEnabled = true
                pmdReady = pmdCpNotificationsEnabled
                publishStatus(state = if (pmdReady) "pmd_ready" else "pmd_data_enabled", detected = true, connected = true)
                if (pmdReady) {
                  requestPmdEcgSettings()
                }
              }
            }
          } else {
            publishStatus(state = "subscribe_failed", error = "$label descriptor write status $status.")
          }
          writeNextDescriptor(gatt)
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
          Log.i(
              "BigRedButtonStudy",
              "BRB_POLAR_H10_PMD_COMMAND_WRITE characteristic=${characteristic.uuid} status=$status",
          )
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
          handleCharacteristicBytes(characteristic.uuid, characteristic.value)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
          handleCharacteristicBytes(characteristic.uuid, value)
        }
      }

  @SuppressLint("MissingPermission")
  private fun configureHeartRateNotifications(gatt: BluetoothGatt) {
    val service = gatt.getService(HEART_RATE_SERVICE)
    val measurement = service?.getCharacteristic(HEART_RATE_MEASUREMENT) ?: return
    enqueueNotification(gatt, measurement, "heart_rate_measurement")
  }

  @SuppressLint("MissingPermission")
  private fun configurePmdNotifications(gatt: BluetoothGatt) {
    val pmdService = gatt.getService(PMD_SERVICE)
    if (pmdService == null) {
      publishStatus(state = "pmd_service_missing", detected = true, connected = true)
      return
    }
    pmdControlPoint = pmdService.getCharacteristic(PMD_CP)
    pmdData = pmdService.getCharacteristic(PMD_DATA)
    if (pmdControlPoint == null || pmdData == null) {
      publishStatus(state = "pmd_characteristics_missing", detected = true, connected = true)
      return
    }
    enqueueNotification(gatt, pmdControlPoint!!, "pmd_control_point")
    enqueueNotification(gatt, pmdData!!, "pmd_data")
  }

  @SuppressLint("MissingPermission")
  private fun enqueueNotification(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, label: String) {
    val cccd = characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG)
    if (cccd == null) {
      publishStatus(state = "cccd_missing", error = "$label CCCD missing.")
      return
    }
    gatt.setCharacteristicNotification(characteristic, true)
    cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
    descriptorQueue.add(DescriptorWriteRequest(cccd, label))
  }

  @SuppressLint("MissingPermission")
  private fun writeNextDescriptor(gatt: BluetoothGatt) {
    if (descriptorWriteInFlight || descriptorQueue.isEmpty()) {
      return
    }
    descriptorWriteInFlight = true
    val next = descriptorQueue.first()
    if (!gatt.writeDescriptor(next.descriptor)) {
      descriptorWriteInFlight = false
      publishStatus(state = "descriptor_write_failed", error = "${next.label} descriptor write could not be issued.")
      descriptorQueue.removeAt(0)
      writeNextDescriptor(gatt)
    }
  }

  private fun handleCharacteristicBytes(uuid: UUID, value: ByteArray?) {
    when (uuid) {
      HEART_RATE_MEASUREMENT -> handleHeartRateBytes(value)
      PMD_CP -> handlePmdControlPoint(value)
      PMD_DATA -> handlePmdDataBytes(value)
    }
  }

  private fun handleHeartRateBytes(bytes: ByteArray?) {
    val measurement = decodeHeartRate(bytes)
    if (measurement == null) {
      publishStatus(state = "malformed_measurement", error = "Malformed Heart Rate Measurement payload.")
      return
    }
    heartRateBpm = measurement.heartRateBpm
    rrIntervalCount += measurement.rrIntervalsMs.size
    val elapsedMs = SystemClock.elapsedRealtime()
    publishStatus(
        state = "streaming",
        detected = true,
        connected = true,
        streaming = true,
        heartRateBpm = measurement.heartRateBpm,
        rrIntervalCount = rrIntervalCount,
        lastEventElapsedMs = elapsedMs,
    )
    if (measurement.rrIntervalsMs.isNotEmpty()) {
      listener.onPolarRrMeasurement(
          PolarRrMeasurement(
              heartRateBpm = measurement.heartRateBpm,
              rrIntervalsMs = measurement.rrIntervalsMs,
              deviceName = deviceName,
              deviceAddress = deviceAddress,
              elapsedRealtimeMs = elapsedMs,
              unixTimeMs = System.currentTimeMillis(),
          )
      )
    }
  }

  private fun handlePmdControlPoint(bytes: ByteArray?) {
    if (bytes == null || bytes.size < 4) {
      publishStatus(state = "pmd_control_malformed", error = "Malformed PMD control payload.")
      return
    }
    val responseCode = bytes[0].toInt() and 0xff
    val command = bytes[1].toInt() and 0xff
    val measurementType = bytes[2].toInt() and 0xff
    val error = bytes[3].toInt() and 0xff
    Log.i(
        "BigRedButtonStudy",
        "BRB_POLAR_H10_PMD_CONTROL response=$responseCode command=$command measurementType=$measurementType error=$error bytes=${bytes.toHex()}",
    )
    if (error == PMD_ERROR_INVALID_MTU) {
      retryLowLatencyMtu()
      return
    }
    if (error != 0) {
      publishStatus(state = "pmd_control_error", error = "PMD command $command measurement $measurementType error $error.")
      return
    }
    if (command == PMD_COMMAND_GET_MEASUREMENT_SETTINGS && measurementType == PMD_MEASUREMENT_ECG) {
      parsePmdSettings(bytes)?.let { settings ->
        ecgSampleRateHz = settings.sampleRates.maxOrNull() ?: POLAR_ECG_SAMPLE_RATE_HZ
        if (ecgSampleRateHz <= 0) {
          ecgSampleRateHz = POLAR_ECG_SAMPLE_RATE_HZ
        }
        ecgResolutionBits = settings.resolutions.maxOrNull() ?: POLAR_ECG_RESOLUTION_BITS
        if (ecgResolutionBits <= 0) {
          ecgResolutionBits = POLAR_ECG_RESOLUTION_BITS
        }
        Log.i(
            "BigRedButtonStudy",
            "BRB_POLAR_H10_ECG_SETTINGS supportedSampleRates=${settings.sampleRates.joinToString("|")} supportedResolutions=${settings.resolutions.joinToString("|")} selectedSampleRateHz=$ecgSampleRateHz selectedResolutionBits=$ecgResolutionBits strategy=highest_available_pmd_ecg_settings",
        )
      }
      startPmdEcgStream()
    } else if (command == PMD_COMMAND_START_MEASUREMENT && measurementType == PMD_MEASUREMENT_ECG) {
      ecgStreaming = true
      publishStatus(state = "ecg_streaming", detected = true, connected = true, pmdReady = true, ecgStreaming = true)
    } else if (command == PMD_COMMAND_STOP_MEASUREMENT && measurementType == PMD_MEASUREMENT_ECG) {
      ecgStreaming = false
      publishStatus(state = "ecg_stopped", detected = true, connected = true, pmdReady = pmdReady)
    }
  }

  private fun handlePmdDataBytes(bytes: ByteArray?) {
    if (bytes == null || bytes.size < PMD_HEADER_BYTES) {
      return
    }
    val measurementType = bytes[0].toInt() and 0xff
    val frameType = bytes[9].toInt() and 0x7f
    val compressed = (bytes[9].toInt() and 0x80) != 0
    if (measurementType != PMD_MEASUREMENT_ECG || compressed || frameType != PMD_FRAME_TYPE_RAW_0) {
      return
    }
    val sampleCount = (bytes.size - PMD_HEADER_BYTES) / PMD_ECG_SAMPLE_BYTES
    if (sampleCount <= 0 || (bytes.size - PMD_HEADER_BYTES) % PMD_ECG_SAMPLE_BYTES != 0) {
      publishStatus(state = "pmd_ecg_malformed", error = "Bad ECG PMD frame length ${bytes.size}.")
      return
    }
    val frameTimestampNs = readUInt64LittleEndian(bytes, 1)
    val previousFrameTimestamp = previousEcgFrameTimestampNs
    previousEcgFrameTimestampNs = frameTimestampNs
    val receivedElapsedNs = SystemClock.elapsedRealtimeNanos()
    val receivedElapsedMs = receivedElapsedNs / 1_000_000L
    val receivedUnixMs = System.currentTimeMillis()
    pmdFrameCount += 1
    val sampleTimestampsNs =
        ecgSampleTimestamps(previousFrameTimestamp, frameTimestampNs, sampleCount, ecgSampleRateHz)
    val samples = mutableListOf<PolarEcgSample>()
    var offset = PMD_HEADER_BYTES
    for (index in 0 until sampleCount) {
      val sensorTimestampNs = sampleTimestampsNs[index]
      val estimatedDeltaFromFrameNs = sensorTimestampNs - frameTimestampNs
      val estimatedDeltaFromFrameMs = (estimatedDeltaFromFrameNs.toDouble() / 1_000_000.0).roundToLong()
      val estimatedElapsedRealtimeNs = receivedElapsedNs + estimatedDeltaFromFrameNs
      samples.add(
          PolarEcgSample(
              sampleIndexInFrame = index,
              sensorTimestampNs = sensorTimestampNs,
              estimatedElapsedRealtimeMs = estimatedElapsedRealtimeNs / 1_000_000L,
              estimatedElapsedRealtimeNs = estimatedElapsedRealtimeNs,
              estimatedUnixTimeMs = receivedUnixMs + estimatedDeltaFromFrameMs,
              microVolts = readSigned24LittleEndian(bytes, offset),
              frameType = frameType,
              sampleRateHz = ecgSampleRateHz,
              requestedMtu = requestedMtu,
              negotiatedMtu = negotiatedMtu,
              packageSizeBytes = bytes.size,
          )
      )
      offset += PMD_ECG_SAMPLE_BYTES
    }
    ecgSampleCount += samples.size
    publishStatus(
        state = "ecg_streaming",
        detected = true,
        connected = true,
        streaming = streamingHr,
        pmdReady = true,
        ecgStreaming = true,
        heartRateBpm = heartRateBpm,
        rrIntervalCount = rrIntervalCount,
        ecgSampleCount = ecgSampleCount,
        pmdFrameCount = pmdFrameCount,
        lastEcgEventElapsedMs = receivedElapsedMs,
    )
    listener.onPolarEcgMeasurement(
        PolarEcgMeasurement(
            frameIndex = pmdFrameCount,
            frameTimestampNs = frameTimestampNs,
            previousFrameTimestampNs = previousFrameTimestamp,
            receivedElapsedRealtimeMs = receivedElapsedMs,
            receivedUnixTimeMs = receivedUnixMs,
            frameType = frameType,
            sampleRateHz = ecgSampleRateHz,
            requestedMtu = requestedMtu,
            negotiatedMtu = negotiatedMtu,
            packageSizeBytes = bytes.size,
            deviceName = deviceName,
            deviceAddress = deviceAddress,
            samples = samples,
        )
    )
  }

  @SuppressLint("MissingPermission")
  private fun requestPmdEcgSettings() {
    writePmdCommand(byteArrayOf(PMD_COMMAND_GET_MEASUREMENT_SETTINGS.toByte(), PMD_MEASUREMENT_ECG.toByte()), "get_ecg_settings")
  }

  @SuppressLint("MissingPermission")
  private fun startPmdEcgStream() {
    val selectedSampleRateHz =
        if (ecgSampleRateHz > 0) {
          ecgSampleRateHz
        } else {
          POLAR_ECG_SAMPLE_RATE_HZ
        }
    val selectedResolutionBits =
        if (ecgResolutionBits > 0) {
          ecgResolutionBits
        } else {
          POLAR_ECG_RESOLUTION_BITS
        }
    val command =
        buildPmdStartRequest(
            measurementType = PMD_MEASUREMENT_ECG,
            sampleRateHz = selectedSampleRateHz,
            resolutionBits = selectedResolutionBits,
        )
    ecgSampleRateHz = selectedSampleRateHz
    ecgResolutionBits = selectedResolutionBits
    writePmdCommand(command, "start_ecg_stream")
  }

  @SuppressLint("MissingPermission")
  private fun stopEcgStreamBestEffort() {
    if (!ecgStreaming) {
      return
    }
    writePmdCommand(byteArrayOf(PMD_COMMAND_STOP_MEASUREMENT.toByte(), PMD_MEASUREMENT_ECG.toByte()), "stop_ecg_stream")
  }

  @SuppressLint("MissingPermission")
  private fun retryLowLatencyMtu() {
    val next = PMD_MTU_FALLBACKS.getOrNull(mtuRetryIndex++) ?: return
    requestedMtu = next
    val issued = gatt?.requestMtu(next) == true
    Log.i("BigRedButtonStudy", "BRB_POLAR_H10_MTU_RETRY requestedMtu=$next issued=$issued")
    mainHandler.postDelayed({ startPmdEcgStream() }, PMD_MTU_RETRY_DELAY_MS)
  }

  @SuppressLint("MissingPermission")
  private fun writePmdCommand(bytes: ByteArray, label: String) {
    val characteristic = pmdControlPoint ?: return
    characteristic.value = bytes
    val issued = gatt?.writeCharacteristic(characteristic) == true
    Log.i(
        "BigRedButtonStudy",
        "BRB_POLAR_H10_PMD_COMMAND label=$label issued=$issued bytes=${bytes.toHex()}",
    )
    if (!issued) {
      publishStatus(state = "pmd_command_failed", error = "Could not issue PMD command $label.")
    }
  }

  @SuppressLint("MissingPermission")
  private fun closeGatt(gattToClose: BluetoothGatt) {
    if (gatt === gattToClose) {
      gatt = null
    }
    gattToClose.close()
  }

  private fun publishStatus(
      state: String,
      detected: Boolean = this.deviceName.isNotBlank(),
      connected: Boolean = false,
      streaming: Boolean = this.streamingHr,
      pmdReady: Boolean = this.pmdReady,
      ecgStreaming: Boolean = this.ecgStreaming,
      deviceName: String = this.deviceName,
      deviceAddress: String = this.deviceAddress,
      heartRateBpm: Int = this.heartRateBpm,
      rrIntervalCount: Int = this.rrIntervalCount,
      ecgSampleCount: Int = this.ecgSampleCount,
      pmdFrameCount: Int = this.pmdFrameCount,
      lastEventElapsedMs: Long = 0L,
      lastEcgEventElapsedMs: Long = 0L,
      requestedMtu: Int = this.requestedMtu,
      negotiatedMtu: Int = this.negotiatedMtu,
      connectionPriorityHighRequested: Boolean = this.connectionPriorityHighRequested,
      ecgSampleRateHz: Int = this.ecgSampleRateHz,
      ecgResolutionBits: Int = this.ecgResolutionBits,
      missingPermissions: String = "",
      error: String = "",
  ) {
    val snapshot =
        PolarStatusSnapshot(
            state = state,
            detected = detected,
            connected = connected,
            streaming = streaming,
            pmdReady = pmdReady,
            ecgStreaming = ecgStreaming,
            deviceName = deviceName,
            deviceAddress = deviceAddress,
            heartRateBpm = heartRateBpm,
            rrIntervalCount = rrIntervalCount,
            ecgSampleCount = ecgSampleCount,
            pmdFrameCount = pmdFrameCount,
            lastEventElapsedMs = lastEventElapsedMs,
            lastEcgEventElapsedMs = lastEcgEventElapsedMs,
            requestedMtu = requestedMtu,
            negotiatedMtu = negotiatedMtu,
            connectionPriorityHighRequested = connectionPriorityHighRequested,
            ecgSampleRateHz = ecgSampleRateHz,
            ecgResolutionBits = ecgResolutionBits,
            missingPermissions = missingPermissions,
            error = error,
        )
    Log.i(
        "BigRedButtonStudy",
        "BRB_POLAR_H10_STATUS state=${snapshot.state} detected=${snapshot.detected} connected=${snapshot.connected} streaming=${snapshot.streaming} pmdReady=${snapshot.pmdReady} ecgStreaming=${snapshot.ecgStreaming} hr=${snapshot.heartRateBpm} rrCount=${snapshot.rrIntervalCount} ecgSamples=${snapshot.ecgSampleCount} pmdFrames=${snapshot.pmdFrameCount} requestedMtu=${snapshot.requestedMtu} negotiatedMtu=${snapshot.negotiatedMtu} ecgHz=${snapshot.ecgSampleRateHz} missing=${snapshot.missingPermissions} error=${snapshot.error}",
    )
    mainHandler.post { listener.onPolarStatus(snapshot) }
  }

  private fun bluetoothAdapter(): BluetoothAdapter? {
    val manager = appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    return manager?.adapter
  }

  private fun missingPermissions(): String {
    val missing = mutableListOf<String>()
    if (appContext.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
      missing.add(Manifest.permission.BLUETOOTH_SCAN)
    }
    if (appContext.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
      missing.add(Manifest.permission.BLUETOOTH_CONNECT)
    }
    if (appContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
      missing.add(Manifest.permission.ACCESS_FINE_LOCATION)
    }
    return missing.joinToString("|")
  }

  private data class DescriptorWriteRequest(
      val descriptor: BluetoothGattDescriptor,
      val label: String,
  )

  private data class DecodedHeartRate(
      val heartRateBpm: Int,
      val rrIntervalsMs: List<Double>,
  )

  private data class PmdSettings(
      val sampleRates: List<Int>,
      val resolutions: List<Int>,
  )

  companion object {
    private val HEART_RATE_SERVICE = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
    private val HEART_RATE_MEASUREMENT = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
    private val CLIENT_CHARACTERISTIC_CONFIG = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    private val PMD_SERVICE = UUID.fromString("fb005c80-02e7-f387-1cad-8acd2d8df0c8")
    private val PMD_CP = UUID.fromString("fb005c81-02e7-f387-1cad-8acd2d8df0c8")
    private val PMD_DATA = UUID.fromString("fb005c82-02e7-f387-1cad-8acd2d8df0c8")
    private const val SCAN_TIMEOUT_MS = 30_000L
    private const val SERVICE_DISCOVERY_DELAY_MS = 250L
    private const val POLAR_LOW_LATENCY_MTU = 70
    private val PMD_MTU_FALLBACKS = listOf(128, 158, 185, 232, 247)
    private const val PMD_MTU_RETRY_DELAY_MS = 500L
    private const val POLAR_ECG_SAMPLE_RATE_HZ = 130
    private const val POLAR_ECG_RESOLUTION_BITS = 14
    private const val PMD_HEADER_BYTES = 10
    private const val PMD_ECG_SAMPLE_BYTES = 3
    private const val PMD_COMMAND_GET_MEASUREMENT_SETTINGS = 0x01
    private const val PMD_COMMAND_START_MEASUREMENT = 0x02
    private const val PMD_COMMAND_STOP_MEASUREMENT = 0x03
    private const val PMD_MEASUREMENT_ECG = 0x00
    private const val PMD_FRAME_TYPE_RAW_0 = 0x00
    private const val PMD_ERROR_INVALID_MTU = 0x0A

    private fun decodeHeartRate(bytes: ByteArray?): DecodedHeartRate? {
      if (bytes == null || bytes.size < 2) {
        return null
      }
      val flags = bytes[0].toInt() and 0xff
      var index = 1
      val heartRate: Int
      if ((flags and 0x01) != 0) {
        if (bytes.size < 3) {
          return null
        }
        heartRate = (bytes[index].toInt() and 0xff) or ((bytes[index + 1].toInt() and 0xff) shl 8)
        index += 2
      } else {
        heartRate = bytes[index].toInt() and 0xff
        index += 1
      }
      if ((flags and 0x08) != 0) {
        index += 2
      }
      val rr = mutableListOf<Double>()
      if ((flags and 0x10) != 0) {
        while (index + 1 < bytes.size) {
          val raw = (bytes[index].toInt() and 0xff) or ((bytes[index + 1].toInt() and 0xff) shl 8)
          rr.add(raw * 1000.0 / 1024.0)
          index += 2
        }
      }
      return DecodedHeartRate(heartRate, rr)
    }

    private fun buildPmdStartRequest(measurementType: Int, sampleRateHz: Int, resolutionBits: Int): ByteArray {
      return byteArrayOf(
          PMD_COMMAND_START_MEASUREMENT.toByte(),
          measurementType.toByte(),
          0x00,
          0x01,
          (sampleRateHz and 0xff).toByte(),
          ((sampleRateHz shr 8) and 0xff).toByte(),
          0x01,
          0x01,
          (resolutionBits and 0xff).toByte(),
          ((resolutionBits shr 8) and 0xff).toByte(),
      )
    }

    private fun parsePmdSettings(bytes: ByteArray): PmdSettings? {
      return parsePmdSettingsPayload(bytes, 4) ?: parsePmdSettingsPayload(bytes, 5)
    }

    private fun parsePmdSettingsPayload(bytes: ByteArray, offset: Int): PmdSettings? {
      if (bytes.size <= offset) {
        return null
      }
      val sampleRates = mutableListOf<Int>()
      val resolutions = mutableListOf<Int>()
      var index = offset
      while (index + 1 < bytes.size) {
        val type = bytes[index++].toInt() and 0xff
        val count = bytes[index++].toInt() and 0xff
        if (index + count * 2 > bytes.size) {
          break
        }
        repeat(count) {
          val value = (bytes[index].toInt() and 0xff) or ((bytes[index + 1].toInt() and 0xff) shl 8)
          index += 2
          when (type) {
            0x00 -> sampleRates.add(value)
            0x01 -> resolutions.add(value)
          }
        }
      }
      return if (sampleRates.isNotEmpty() || resolutions.isNotEmpty()) {
        PmdSettings(sampleRates, resolutions)
      } else {
        null
      }
    }

    private fun ecgSampleTimestamps(
        previousFrameTimestampNs: Long,
        frameTimestampNs: Long,
        sampleCount: Int,
        sampleRateHz: Int,
    ): List<Long> {
      if (sampleCount <= 0) {
        return emptyList()
      }
      val deltaNs =
          if (previousFrameTimestampNs > 0L && frameTimestampNs > previousFrameTimestampNs) {
            (frameTimestampNs - previousFrameTimestampNs).toDouble() / sampleCount.toDouble()
          } else {
            1_000_000_000.0 / sampleRateHz.coerceAtLeast(1).toDouble()
          }
      val startNs =
          if (previousFrameTimestampNs > 0L) {
            previousFrameTimestampNs.toDouble() + deltaNs
          } else {
            frameTimestampNs.toDouble() - deltaNs * (sampleCount - 1)
          }
      return List(sampleCount - 1) { index -> (startNs + deltaNs * index).roundToLong() } + frameTimestampNs
    }

    private fun readUInt64LittleEndian(bytes: ByteArray, offset: Int): Long {
      var value = 0L
      for (i in 0 until 8) {
        value = value or ((bytes[offset + i].toLong() and 0xffL) shl (8 * i))
      }
      return value
    }

    private fun readSigned24LittleEndian(bytes: ByteArray, offset: Int): Int {
      var raw =
          (bytes[offset].toInt() and 0xff) or
              ((bytes[offset + 1].toInt() and 0xff) shl 8) or
              ((bytes[offset + 2].toInt() and 0xff) shl 16)
      if ((raw and 0x0080_0000) != 0) {
        raw = raw or -0x0100_0000
      }
      return raw
    }

    private fun ByteArray.toHex(): String = joinToString("-") { "%02X".format(it.toInt() and 0xff) }
  }
}
