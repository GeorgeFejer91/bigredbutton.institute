package org.bigredbutton.firststudy

import android.Manifest
import android.graphics.Color as AndroidColor
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.Checkbox
import androidx.compose.material.CheckboxDefaults
import androidx.compose.material.Divider
import androidx.compose.material.MaterialTheme
import androidx.compose.material.OutlinedButton
import androidx.compose.material.Slider
import androidx.compose.material.SliderDefaults
import androidx.compose.material.Text
import androidx.compose.material.TextField
import androidx.compose.material.TextFieldDefaults
import androidx.compose.material.lightColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.meta.spatial.compose.ComposeFeature
import com.meta.spatial.compose.ComposeViewPanelRegistration
import com.meta.spatial.core.Entity
import com.meta.spatial.core.Pose
import com.meta.spatial.core.SpatialFeature
import com.meta.spatial.core.Vector3
import com.meta.spatial.isdk.IsdkBoxCollider
import com.meta.spatial.isdk.IsdkSystem
import com.meta.spatial.isdk.InteractionEventSourceBehavior
import com.meta.spatial.runtime.AlphaMode
import com.meta.spatial.runtime.HitInfo
import com.meta.spatial.runtime.InputListener
import com.meta.spatial.runtime.PointerEvent
import com.meta.spatial.runtime.PointerEventType
import com.meta.spatial.runtime.ReferenceSpace
import com.meta.spatial.runtime.SceneLight
import com.meta.spatial.runtime.SceneLightType
import com.meta.spatial.runtime.SceneMaterial
import com.meta.spatial.runtime.SceneMesh
import com.meta.spatial.runtime.SceneObject
import com.meta.spatial.runtime.SceneTexture
import com.meta.spatial.toolkit.AppSystemActivity
import com.meta.spatial.toolkit.Animated
import com.meta.spatial.toolkit.DpDisplayOptions
import com.meta.spatial.toolkit.Hittable
import com.meta.spatial.toolkit.InteractivityInput
import com.meta.spatial.toolkit.Mesh
import com.meta.spatial.toolkit.MeshCollision
import com.meta.spatial.toolkit.Panel
import com.meta.spatial.toolkit.PanelRegistration
import com.meta.spatial.toolkit.PanelStyleOptions
import com.meta.spatial.toolkit.PlaybackState
import com.meta.spatial.toolkit.PlaybackType
import com.meta.spatial.toolkit.QuadShapeOptions
import com.meta.spatial.toolkit.Scale
import com.meta.spatial.toolkit.SceneObjectSystem
import com.meta.spatial.toolkit.SpatialActivityManager
import com.meta.spatial.toolkit.Transform
import com.meta.spatial.toolkit.UIPanelSettings
import com.meta.spatial.toolkit.Visible
import com.meta.spatial.vr.LocomotionSystem
import com.meta.spatial.vr.VRFeature
import java.io.File
import java.time.Instant
import java.util.concurrent.CompletableFuture
import java.util.Locale
import java.util.UUID
import kotlin.math.PI
import kotlin.math.atan
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.roundToInt
import kotlin.math.roundToLong
import kotlin.math.sin
import kotlinx.coroutines.delay
import org.json.JSONArray
import org.json.JSONObject

private const val ECG_SAMPLE_RATE_HZ = 130
private const val SIMULATED_ECG_FRAME_SAMPLES = 16
private const val PRIOR_BUTTON_EXPERIENCE_QUESTION =
    "Oh wait, we have just one more question: Do you have any experience with pressing big red buttons?"
private const val PRE_BUTTON_EXPERIENCE_VALIDATION_DELAY_MS = 350L
private const val MODEL_GLOW_PANEL_FALLBACK_ENABLED = false

enum class StudyStage {
  ConsentDemographics,
  PreButtonExperienceQuestion,
  ConditionRunning,
  Pictographic,
  PresenceQuestionnaire,
  LostOpportunity,
  Complete,
}

data class Demographics(
    val participantId: String = "",
    val name: String = "",
    val age: String = "",
    val gender: String = "",
    val handedness: String = "",
    val signature: String = "",
    val consent: Boolean = false,
    val consentTimestampIso: String = "",
)

private data class SignatureSample(
    val xPx: Float,
    val yPx: Float,
    val realtimeMs: Long,
)

data class PressEvent(
    val conditionNumber: Int,
    val pressIndex: Int,
    val elapsedMs: Long,
    val unixTimeMs: Long,
    val isoTimestamp: String,
    val inputSource: String,
    val validationAutomation: Boolean,
)

data class PictographicResponse(
    val conditionNumber: Int,
    val feltCloseness0To100: Int,
    val selfButtonDistanceUnits: Float,
    val feltPresence0To100: Int,
    val buttonPresenceRadiusUnits: Float,
    val rednessVas0To100: Int,
    val rednessLikert1To7: Int,
    val rednessLikertDescriptor: String,
    val rednessScaleOrder: String,
    val timestampIso: String,
)

data class RednessConversionChoreography(
    val order: String,
    val startedElapsedMs: Long,
    val durationMs: Long,
    val swapAtMs: Long,
    val settleAtMs: Long,
    val sourceScale: String,
    val targetScale: String,
    val finalVas0To100: Int,
    val finalLikert1To7: Int,
    val finalDescriptor: String,
    val cueName: String,
    val audioAsset: String,
    val microEvents: List<RednessConversionMicroEvent>,
)

data class RednessConversionMicroEvent(
    val startMs: Long,
    val endMs: Long,
    val code: String,
    val spokenCue: String,
    val participantCaption: String,
    val visualCue: String,
    val intensity: Float,
)

private data class RednessConversionCue(
    val resourceId: Int,
    val cueName: String,
    val audioAsset: String,
    val durationMs: Long,
    val swapAtMs: Long,
    val settleAtMs: Long,
    val transcriptPlan: String,
    val microEvents: List<RednessConversionMicroEvent>,
)

data class PresenceItem(
    val id: String,
    val subscale: String,
    val text: String,
    val reverse: Boolean = false,
)

data class PresenceQuestionnaireResponse(
    val conditionNumber: Int,
    val rawAnswers0To6: Map<String, Int>,
    val scoredAnswers0To6: Map<String, Int>,
    val subscaleMeans0To6: Map<String, Double>,
    val totalMean0To6: Double,
    val timestampIso: String,
)

data class LostOpportunityResponse(
    val conditionNumber: Int,
    val score0To100: Int,
    val timestampIso: String,
)

data class EcgBlinkEvent(
    val conditionNumber: Int,
    val blinkIndex: Int,
    val source: String,
    val elapsedMs: Long,
    val unixTimeMs: Long,
    val isoTimestamp: String,
    val rrMs: Double,
    val heartRateBpm: Int,
    val pulseIntensity01: Float = 1.0f,
    val pulseSourceTimestampUnixNs: Long = 0L,
    val detector: String = "rr_interval",
)

data class EcgTimeSeriesSample(
    val conditionNumber: Int,
    val sampleIndex: Int,
    val source: String,
    val elapsedMs: Double,
    val elapsedNs: Long,
    val unixTimeMs: Long,
    val isoTimestamp: String,
    val sensorTimestampNs: Long,
    val microVolts: Int,
    val sampleRateHz: Int,
    val frameIndex: Int,
    val frameType: Int,
    val packageSizeBytes: Int,
    val requestedMtu: Int,
    val negotiatedMtu: Int,
)

data class EcgDetectorEvent(
    val conditionNumber: Int,
    val detectorIndex: Int,
    val detector: String,
    val source: String,
    val elapsedMs: Double,
    val elapsedNs: Long,
    val unixTimeMs: Long,
    val isoTimestamp: String,
    val sensorTimestampNs: Long,
    val microVolts: Int,
    val thresholdMicroVolts: Int,
    val sampleIndex: Int,
)

data class ExternalSignalSample(
    val conditionNumber: Int,
    val sampleIndex: Int,
    val source: String,
    val streamName: String,
    val streamType: String,
    val channelIndex: Int,
    val value01: Float,
    val elapsedMs: Long,
    val unixTimeMs: Long,
    val isoTimestamp: String,
)

private data class ButtonContactTargetSpec(
    val name: String,
    val offsetX: Float,
    val offsetZ: Float,
    val width: Float,
    val height: Float,
    val depth: Float,
)

private data class ButtonContactTarget(
    val entity: Entity,
    val spec: ButtonContactTargetSpec,
)

private data class HeartbeatPulseResult(
    val source: String,
    val acceptedElapsedMs: Long,
    val pulseIntensity01: Float,
    val pulseSourceTimestampUnixNs: Long,
    val detector: String,
)

private class ButtonContactLatch(private val forceRearmAfterMs: Long) {
  private val activeKeys = mutableMapOf<String, Long>()

  fun tryAccept(key: String, nowMs: Long): Boolean {
    val acceptedAt = activeKeys[key]
    if (acceptedAt != null && nowMs - acceptedAt < forceRearmAfterMs) {
      return false
    }
    activeKeys[key] = nowMs
    return true
  }

  fun release(key: String): Boolean = activeKeys.remove(key) != null

  fun clear() {
    activeKeys.clear()
  }
}

private class HeartbeatPulseDriver(
    private val baseline01: Float,
    private val peak01: Float,
    private val pulseDurationMs: Long,
    private val refractoryMs: Long,
) {
  private var lastPulseElapsedMs = Long.MIN_VALUE
  private var lastPulsePeak01 = baseline01

  fun tryAcceptPulse(
      source: String,
      nowElapsedMs: Long,
      pulseSourceTimestampUnixNs: Long,
      detector: String,
  ): HeartbeatPulseResult? {
    if (lastPulseElapsedMs != Long.MIN_VALUE && nowElapsedMs - lastPulseElapsedMs < refractoryMs) {
      return null
    }
    lastPulseElapsedMs = nowElapsedMs
    lastPulsePeak01 = peak01
    return HeartbeatPulseResult(
        source = source,
        acceptedElapsedMs = nowElapsedMs,
        pulseIntensity01 = peak01,
        pulseSourceTimestampUnixNs = pulseSourceTimestampUnixNs,
        detector = detector,
    )
  }

  fun intensityAt(nowElapsedMs: Long): Float {
    if (lastPulseElapsedMs == Long.MIN_VALUE) {
      return 0f
    }
    val elapsed = (nowElapsedMs - lastPulseElapsedMs).coerceAtLeast(0L)
    val duration = pulseDurationMs.coerceAtLeast(1L)
    if (elapsed >= duration) {
      return 0f
    }
    val normalizedTime = (elapsed.toDouble() / duration.toDouble()).coerceIn(0.0, 1.0).toFloat()
    val smoothStep = normalizedTime * normalizedTime * (3f - (2f * normalizedTime))
    val intensity = baseline01 + (lastPulsePeak01 - baseline01) * (1f - smoothStep)
    return intensity.coerceIn(0f, 1f)
  }

  fun reset() {
    lastPulseElapsedMs = Long.MIN_VALUE
    lastPulsePeak01 = baseline01
  }
}

private class EcgRPeakDetector(
    private val thresholdMicroVolts: Int,
    private val refractoryNs: Long,
    private val detectorName: String,
) {
  private var wasAboveThreshold = false
  private var lastPeakElapsedNs = Long.MIN_VALUE
  private var detectorIndex = 0

  fun reset() {
    wasAboveThreshold = false
    lastPeakElapsedNs = Long.MIN_VALUE
    detectorIndex = 0
  }

  fun update(sample: EcgTimeSeriesSample): EcgDetectorEvent? {
    val above = sample.microVolts >= thresholdMicroVolts
    val rising = above && !wasAboveThreshold
    wasAboveThreshold = above
    if (!rising) {
      return null
    }
    if (lastPeakElapsedNs != Long.MIN_VALUE && sample.elapsedNs - lastPeakElapsedNs < refractoryNs) {
      return null
    }
    lastPeakElapsedNs = sample.elapsedNs
    detectorIndex += 1
    return EcgDetectorEvent(
        conditionNumber = sample.conditionNumber,
        detectorIndex = detectorIndex,
        detector = detectorName,
        source = sample.source,
        elapsedMs = sample.elapsedMs,
        elapsedNs = sample.elapsedNs,
        unixTimeMs = sample.unixTimeMs,
        isoTimestamp = sample.isoTimestamp,
        sensorTimestampNs = sample.sensorTimestampNs,
        microVolts = sample.microVolts,
        thresholdMicroVolts = thresholdMicroVolts,
        sampleIndex = sample.sampleIndex,
    )
  }
}

class ConditionRun(
    val conditionNumber: Int,
    val label: String,
    val audioAssetPath: String,
) {
  var startedIso: String = ""
  var endedIso: String = ""
  var startedElapsedMs: Long = 0L
  var endedElapsedMs: Long = 0L
  var startedElapsedNs: Long = 0L
  var endedElapsedNs: Long = 0L
  var audioDurationMs: Int = 0
  val pressEvents: MutableList<PressEvent> = mutableListOf()
  var pictographic: PictographicResponse? = null
  var presenceQuestionnaire: PresenceQuestionnaireResponse? = null
  var lostOpportunity: LostOpportunityResponse? = null
  var ecgSource: String = ""
  val ecgBlinkEvents: MutableList<EcgBlinkEvent> = mutableListOf()
  val ecgTimeSeriesSamples: MutableList<EcgTimeSeriesSample> = mutableListOf()
  val ecgDetectorEvents: MutableList<EcgDetectorEvent> = mutableListOf()
  val externalSignalSamples: MutableList<ExternalSignalSample> = mutableListOf()
  var ecgCaptureStartedElapsedMs: Long = 0L
  var ecgCaptureEndedElapsedMs: Long = 0L
  var ecgCaptureStartedElapsedNs: Long = 0L
  var ecgCaptureEndedElapsedNs: Long = 0L
  var ecgCaptureDurationMs: Int = 0
  var ecgSampleRateHz: Int = ECG_SAMPLE_RATE_HZ
  var ecgExpectedSampleCount: Int = 0
  var ecgRequestedMtu: Int = 0
  var ecgNegotiatedMtu: Int = 0
}

private fun signatureSample(offset: Offset, canvasSize: IntSize): SignatureSample {
  val maxX = if (canvasSize.width > 0) canvasSize.width.toFloat() else 1f
  val maxY = if (canvasSize.height > 0) canvasSize.height.toFloat() else 1f
  return SignatureSample(
      xPx = offset.x.coerceIn(0f, maxX),
      yPx = offset.y.coerceIn(0f, maxY),
      realtimeMs = SystemClock.elapsedRealtime(),
  )
}

private fun encodeSignatureStrokes(
    committedStrokes: List<List<SignatureSample>>,
    activeStroke: List<SignatureSample>,
    canvasSize: IntSize,
): String {
  val strokes = committedStrokes + if (activeStroke.isNotEmpty()) listOf(activeStroke) else emptyList()
  if (strokes.isEmpty()) {
    return ""
  }
  val widthPx = if (canvasSize.width > 0) canvasSize.width else 1
  val heightPx = if (canvasSize.height > 0) canvasSize.height else 1
  val firstMs = strokes.first().firstOrNull()?.realtimeMs ?: SystemClock.elapsedRealtime()
  var pointCount = 0
  val strokeArray = JSONArray()
  strokes.forEachIndexed { strokeIndex, stroke ->
    val points = JSONArray()
    stroke.forEachIndexed { pointIndex, sample ->
      pointCount += 1
      points.put(
          JSONObject()
              .put("index", pointIndex)
              .put("xNorm", sample.xPx / widthPx.toFloat())
              .put("yNorm", sample.yPx / heightPx.toFloat())
              .put("tMs", sample.realtimeMs - firstMs)
      )
    }
    strokeArray.put(JSONObject().put("index", strokeIndex).put("points", points))
  }
  return JSONObject()
      .put("format", "brb_signature_strokes_v1")
      .put("widthPx", widthPx)
      .put("heightPx", heightPx)
      .put("strokeCount", strokes.size)
      .put("pointCount", pointCount)
      .put("strokes", strokeArray)
      .toString()
}

private fun validationSignatureStrokesJson(): String {
  val points =
      JSONArray()
          .put(JSONObject().put("index", 0).put("xNorm", 0.18).put("yNorm", 0.62).put("tMs", 0))
          .put(JSONObject().put("index", 1).put("xNorm", 0.42).put("yNorm", 0.38).put("tMs", 120))
          .put(JSONObject().put("index", 2).put("xNorm", 0.78).put("yNorm", 0.58).put("tMs", 250))
  return JSONObject()
      .put("format", "brb_signature_strokes_v1")
      .put("widthPx", 1200)
      .put("heightPx", 360)
      .put("strokeCount", 1)
      .put("pointCount", 3)
      .put("validationSample", true)
      .put("strokes", JSONArray().put(JSONObject().put("index", 0).put("points", points)))
      .toString()
}

private fun normalizeAgeInput(raw: String): String {
  return raw.mapNotNull { char -> char.digitToIntOrNull()?.toString() }.joinToString("").take(3)
}

class BigRedButtonStudyActivity : AppSystemActivity(), PolarH10HeartRateClient.Listener {
  val stageState: MutableState<StudyStage> = mutableStateOf(StudyStage.ConsentDemographics)
  val activeConditionState = mutableIntStateOf(0)
  val buttonPressCountState = mutableIntStateOf(0)
  val conditionElapsedTextState = mutableStateOf("00:00")
  val exportStatusState = mutableStateOf("")
  val demographicsState: MutableState<Demographics> = mutableStateOf(Demographics())
  val pictographicClosenessState = mutableFloatStateOf(50f)
  val pictographicPresenceState = mutableFloatStateOf(50f)
  val pictographicRednessVasState = mutableFloatStateOf(50f)
  val pictographicRednessLikertState = mutableIntStateOf(4)
  val pictographicRednessConvertedState = mutableStateOf(false)
  val rednessConversionChoreographyState: MutableState<RednessConversionChoreography?> = mutableStateOf(null)
  val pictographicFocusIndexState = mutableIntStateOf(0)
  val ipqAnswersState = mutableStateMapOf<String, Int>()
  val ipqCursorIndexState = mutableIntStateOf(0)
  val lostOpportunityState = mutableFloatStateOf(50f)
  val panelGlitchActiveState = mutableStateOf(false)
  val panelGlitchFrameState = mutableIntStateOf(0)
  val panelGlitchModeState = mutableStateOf("intro")
  val panelGlitchStartElapsedMsState = mutableStateOf(0L)
  val panelGlitchDurationMsState = mutableStateOf(0L)
  val panelGlitchSeedState = mutableIntStateOf(0)
  val demographicsDraftNameState = mutableStateOf("")
  val demographicsDraftAgeState = mutableStateOf("")
  val demographicsDraftGenderState = mutableStateOf("")
  val demographicsDraftHandednessState = mutableStateOf("")
  val demographicsDraftSignatureState = mutableStateOf("")
  val demographicsDraftConsentState = mutableStateOf(false)
  val priorBigRedButtonExperienceAnswerState = mutableStateOf("")
  val priorBigRedButtonExperienceTimestampState = mutableStateOf("")
  val polarStatusState: MutableState<PolarStatusSnapshot> = mutableStateOf(PolarStatusSnapshot())
  val buttonHeartbeatFlashState = mutableStateOf(false)
  val buttonHeartbeatFlashFrameState = mutableIntStateOf(0)
  val buttonHeartbeatPulseIntensityState = mutableFloatStateOf(0f)

  private val sessionId = "brb-" + UUID.randomUUID().toString()
  private val mainHandler = Handler(Looper.getMainLooper())
  private val conditionRuns = mutableListOf<ConditionRun>()
  private var activeRun: ConditionRun? = null
  private var mediaPlayer: MediaPlayer? = null
  private var panelChimePlayer: MediaPlayer? = null
  private val cuePlayers = mutableSetOf<MediaPlayer>()
  private var polarClient: PolarH10HeartRateClient? = null
  private val conditionEcgSources = mutableMapOf<Int, String>()
  private var ecgAssignmentOrder = ""
  private var simulatedRrIntervalsMs: List<Double> = emptyList()
  private var simulatedRrIndex = 0
  private var simulatedEcgToken = 0
  private var heartbeatFlashToken = 0
  private var buttonEntity: Entity? = null
  private var buttonModelEntity: Entity? = null
  private var buttonContactEntity: Entity? = null
  private var buttonStimulusVisible = false
  private val buttonContactTargets = mutableListOf<ButtonContactTarget>()
  private val buttonGlowModelEntities = mutableListOf<Entity>()
  private val buttonGlowLights = mutableListOf<SceneLight>()
  private val buttonVisualEntities = mutableListOf<Entity>()
  private val buttonSceneObjects = mutableListOf<SceneObject>()
  private var questionnaireEntity: Entity? = null
  private var isdkSystem: IsdkSystem? = null
  private var isdkPointerObserverRegistered = false
  private var conditionPressArmedRealtimeMs = 0L
  private var nextAllowedPressRealtimeMs = 0L
  private var autoValidationEnabled = false
  private var physicalPressValidationEnabled = false
  private var panelSmokeEnabled = false
  private var fastControllerFlowEnabled = false
  private var keyeventValidationEnabled = false
  private var visualGlowValidationMode = ""
  private var autoValidationStarted = false
  private var fastControllerFlowStarted = false
  private var panelGlitchToken = 0
  private var rednessConversionChoreographyToken = 0
  private var softKeyboardRequestGeneration = 0
  private var activeSoftKeyboardReason: String? = null
  private var activeSoftKeyboardMode: String? = null
  private var keyboardFieldContractLogged = false
  private val buttonContactLatch = ButtonContactLatch(BUTTON_CONTACT_LATCH_FORCE_REARM_MS)
  private val heartbeatPulseDriver =
      HeartbeatPulseDriver(
          baseline01 = HEARTBEAT_PULSE_BASELINE_01,
          peak01 = HEARTBEAT_PULSE_PEAK_01,
          pulseDurationMs = HEARTBEAT_PULSE_DURATION_MS,
          refractoryMs = HEARTBEAT_PULSE_REFRACTORY_MS,
      )
  private val ecgRPeakDetector =
      EcgRPeakDetector(
          thresholdMicroVolts = ECG_R_PEAK_THRESHOLD_MICROVOLTS,
          refractoryNs = ECG_R_PEAK_REFRACTORY_NS,
          detectorName = ECG_R_PEAK_DETECTOR_NAME,
      )
  private lateinit var locomotionSystem: LocomotionSystem
  private val buttonContactPointerObserver: (PointerEvent) -> Unit = { event ->
    handleButtonContactPointerEvent(event)
  }

  private val ticker =
      object : Runnable {
        override fun run() {
          activeRun?.let { run ->
            if (stageState.value == StudyStage.ConditionRunning) {
              val elapsedMs = SystemClock.elapsedRealtime() - run.startedElapsedMs
              conditionElapsedTextState.value = formatElapsed(elapsedMs)
              mainHandler.postDelayed(this, 500)
            }
          }
        }
      }

  override fun registerFeatures(): List<SpatialFeature> {
    return listOf(VRFeature(this), ComposeFeature())
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    locomotionSystem = systemManager.findSystem<LocomotionSystem>()
    isdkSystem = systemManager.tryFindSystem<IsdkSystem>()
    autoValidationEnabled = intent?.getBooleanExtra(AUTO_VALIDATION_EXTRA, false) == true
    physicalPressValidationEnabled =
        intent?.getBooleanExtra(PHYSICAL_PRESS_VALIDATION_EXTRA, false) == true
    panelSmokeEnabled = intent?.getBooleanExtra(PANEL_SMOKE_EXTRA, false) == true
    fastControllerFlowEnabled = intent?.getBooleanExtra(FAST_CONTROLLER_FLOW_EXTRA, false) == true
    keyeventValidationEnabled = intent?.getBooleanExtra(KEYEVENT_VALIDATION_EXTRA, false) == true
    visualGlowValidationMode =
        intent?.getStringExtra(VISUAL_GLOW_VALIDATION_EXTRA)?.lowercase(Locale.US)?.trim().orEmpty()
    requestScenePermissionIfNeeded()
    initializeEcgProtocol()
    logOptionalLslContract()
    requestBlePermissionsIfNeeded()
    startPolarScanIfPermitted()
    Log.i(
        TAG,
        "BRB_STUDY_CREATED sessionId=$sessionId autoValidation=$autoValidationEnabled physicalPressValidation=$physicalPressValidationEnabled panelSmoke=$panelSmokeEnabled fastControllerFlow=$fastControllerFlowEnabled keyeventValidation=$keyeventValidationEnabled visualGlowValidationMode=${visualGlowValidationMode.ifBlank { "none" }}",
    )
  }

  override fun onSceneReady() {
    super.onSceneReady()
    scene.setReferenceSpace(ReferenceSpace.LOCAL_FLOOR)
    scene.enablePassthrough(true)
    scene.setViewOrigin(0f, 0f, 0f, 0f)
    locomotionSystem.enableLocomotion(false)
    scene.setLightingEnvironment(
        ambientColor = Vector3(0.45f),
        sunColor = Vector3(4.0f, 4.0f, 4.0f),
        sunDirection = -Vector3(0.8f, 2.5f, -1.2f),
    )

    buttonEntity =
        Entity.create(
            Panel(R.id.button_panel),
            Transform(Pose(Vector3(0f, BUTTON_PANEL_Y_METERS, BUTTON_DISTANCE_FROM_HEAD_METERS))),
            Visible(false),
    )
    createButtonModelEntity()
    createButtonGlowModelEntities()
    createButtonContactColliderEntity()
    createProceduralButtonFallbackObjects()
    questionnaireEntity =
        Entity.create(
            Panel(R.id.questionnaire_panel),
            Transform(Pose(Vector3(0f, QUESTIONNAIRE_PANEL_Y_METERS, QUESTIONNAIRE_PANEL_Z_METERS))),
            Visible(false),
        )
    Log.i(
        TAG,
        "BRB_STUDY_READY passthrough=true buttonPanel=transparent-hit-target buttonVisual=model-asset model=$BUTTON_MODEL_ASSET_URI questionnairePanel=popup keyboard=system_native",
    )
    logButtonSpatialLayout()
    logQuestionnairePanelLayout("scene_ready")
    configureControllerContactInput()
    mainHandler.postDelayed(
        {
          if (stageState.value == StudyStage.ConsentDemographics) {
            showQuestionnairePanel(PANEL_TRANSITION_DEMOGRAPHICS)
          }
        },
        PANEL_TRANSITION_START_DELAY_MS,
    )
    maybeStartAutoValidation()
    maybeStartPanelSmoke()
    maybeStartControllerValidation()
  }

  override fun registerPanels(): List<PanelRegistration> {
    return listOf(
        ComposeViewPanelRegistration(
            R.id.button_panel,
            composeViewCreator = { _, context ->
              ComposeView(context).apply { setContent { ButtonStimulusPanel(this@BigRedButtonStudyActivity) } }
            },
            settingsCreator = {
              UIPanelSettings(
                  shape = QuadShapeOptions(width = 0.42f, height = 0.42f),
                  style = PanelStyleOptions(themeResourceId = R.style.ThemeTransparent),
                  display = DpDisplayOptions(width = 520f, height = 520f, dpi = 520),
              )
            },
        ),
        ComposeViewPanelRegistration(
            R.id.questionnaire_panel,
            composeViewCreator = { _, context ->
              ComposeView(context).apply { setContent { StudyPanel(this@BigRedButtonStudyActivity) } }
            },
            settingsCreator = {
              UIPanelSettings(
                  shape = QuadShapeOptions(width = QUESTIONNAIRE_PANEL_WIDTH_METERS, height = QUESTIONNAIRE_PANEL_HEIGHT_METERS),
                  style = PanelStyleOptions(themeResourceId = R.style.ThemeTransparent),
                  display = DpDisplayOptions(width = 1180f, height = 820f, dpi = 520),
              )
            },
        ),
    )
  }

  fun submitDemographics(
      name: String,
      age: String,
      gender: String,
      handedness: String,
      signature: String,
      consent: Boolean,
      participantIdOverride: String? = null,
  ) {
    val assignedParticipantId =
        participantIdOverride?.trim()?.takeIf { it.isNotBlank() }
            ?: "participant-" + System.currentTimeMillis()
    demographicsState.value =
        Demographics(
            participantId = assignedParticipantId,
            name = name.trim(),
            age = age.trim(),
            gender = gender.trim(),
            handedness = handedness.trim(),
            signature = signature.trim(),
            consent = consent,
            consentTimestampIso = nowIso(),
        )
    Log.i(
        TAG,
        "BRB_STUDY_DEMOGRAPHICS_SAVED participantId=${demographicsState.value.participantId} participantIdSource=${if (participantIdOverride.isNullOrBlank()) "generated" else "validation_override"} consent=$consent",
    )
    transitionQuestionnaireOutThenShowPreButtonExperienceQuestion()
  }

  fun setPriorBigRedButtonExperienceAnswer(answer: String, source: String = "participant") {
    val normalized = answer.lowercase(Locale.US).trim()
    if (normalized !in setOf("yes", "no")) {
      return
    }
    priorBigRedButtonExperienceAnswerState.value = normalized
    priorBigRedButtonExperienceTimestampState.value = nowIso()
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER answer=$normalized source=$source displayLocation=button_counter_panel",
    )
    playQuestionnaireChoiceCue()
  }

  fun startExperimentFromPriorButtonExperienceQuestion(): Boolean {
    val answer = priorBigRedButtonExperienceAnswerState.value
    if (answer !in setOf("yes", "no")) {
      return false
    }
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_SAVED answer=$answer timestamp=${priorBigRedButtonExperienceTimestampState.value} shownBeforeCondition=1",
    )
    beginCondition(1)
    return true
  }

  fun recordButtonPress(inputSource: String = PRESS_SOURCE_UNSPECIFIED) {
    val run = activeRun ?: return
    if (stageState.value != StudyStage.ConditionRunning) {
      return
    }

    val nowRealtimeMs = SystemClock.elapsedRealtime()
    val elapsedMs = nowRealtimeMs - run.startedElapsedMs
    if (nowRealtimeMs < conditionPressArmedRealtimeMs) {
      Log.i(
          TAG,
          "BRB_BUTTON_PRESS_SUPPRESSED condition=${run.conditionNumber} reason=startup_contact_suppression source=$inputSource elapsedMs=$elapsedMs",
      )
      return
    }
    if (nowRealtimeMs < nextAllowedPressRealtimeMs) {
      Log.i(
          TAG,
          "BRB_BUTTON_PRESS_SUPPRESSED condition=${run.conditionNumber} reason=press_cooldown source=$inputSource elapsedMs=$elapsedMs",
      )
      return
    }

    val event =
        PressEvent(
            conditionNumber = run.conditionNumber,
            pressIndex = run.pressEvents.size + 1,
            elapsedMs = elapsedMs,
            unixTimeMs = System.currentTimeMillis(),
            isoTimestamp = nowIso(),
            inputSource = inputSource,
            validationAutomation =
                inputSource == PRESS_SOURCE_AUTO_VALIDATION ||
                    inputSource == PRESS_SOURCE_CONTROLLER_EMULATED_VALIDATION,
        )
    run.pressEvents.add(event)
    buttonPressCountState.intValue = run.pressEvents.size
    Log.i(
        TAG,
        "BRB_BUTTON_PRESS condition=${run.conditionNumber} index=${event.pressIndex} source=${event.inputSource} validationAutomation=${event.validationAutomation} elapsedMs=${event.elapsedMs}",
    )
    playButtonPressedAnimation()
    playButtonPressCue()
    nextAllowedPressRealtimeMs = nowRealtimeMs + BUTTON_PRESS_COOLDOWN_MS
  }

  fun recordInterimPanelPress() {
    recordButtonPress(PRESS_SOURCE_TRANSPARENT_PANEL_INTERIM)
  }

  private fun rednessLikertFromVas(value0To100: Float): Int {
    val scaled = 1f + (value0To100.coerceIn(0f, 100f) / 100f) * 6f
    return (scaled + 0.5f).toInt().coerceIn(1, 7)
  }

  private fun rednessVasCenterFromLikert(value1To7: Int): Float {
    return ((value1To7.coerceIn(1, 7) - 1).toFloat() / 6f) * 100f
  }

  private fun rednessDescriptor(value1To7: Int): String {
    return REDNESS_LIKERT_DESCRIPTORS[value1To7.coerceIn(1, 7) - 1]
  }

  fun rednessScaleOrderForCondition(conditionNumber: Int = activeConditionState.intValue): String {
    return if (conditionNumber == 1) REDNESS_ORDER_VAS_THEN_LIKERT else REDNESS_ORDER_LIKERT_THEN_VAS
  }

  fun convertRednessVasToLikert(reason: String) {
    if (pictographicRednessConvertedState.value || rednessConversionChoreographyState.value != null) {
      return
    }
    val vas = pictographicRednessVasState.floatValue.coerceIn(0f, 100f)
    val likert = rednessLikertFromVas(vas)
    if (reason == REDNESS_FAST_REPLAY_REASON) {
      applyRednessVasToLikert(vas, likert, reason, choreographed = false)
      playRednessScaleConversionCue(REDNESS_ORDER_VAS_THEN_LIKERT, validationShortcut = true)
      return
    }
    beginRednessConversionChoreography(
        order = REDNESS_ORDER_VAS_THEN_LIKERT,
        reason = reason,
        finalVas = vas,
        finalLikert = likert,
    )
  }

  fun convertRednessLikertToVas(reason: String) {
    if (pictographicRednessConvertedState.value || rednessConversionChoreographyState.value != null) {
      return
    }
    val likert = pictographicRednessLikertState.intValue.coerceIn(1, 7)
    val vas = rednessVasCenterFromLikert(likert)
    if (reason == REDNESS_FAST_REPLAY_REASON) {
      applyRednessLikertToVas(likert, vas, reason, choreographed = false)
      playRednessScaleConversionCue(REDNESS_ORDER_LIKERT_THEN_VAS, validationShortcut = true)
      return
    }
    beginRednessConversionChoreography(
        order = REDNESS_ORDER_LIKERT_THEN_VAS,
        reason = reason,
        finalVas = vas,
        finalLikert = likert,
    )
  }

  fun setRednessLikert(value1To7: Int, convertIfNeeded: Boolean) {
    if (rednessConversionChoreographyState.value != null) {
      return
    }
    val value = value1To7.coerceIn(1, 7)
    pictographicRednessLikertState.intValue = value
    if (convertIfNeeded && !pictographicRednessConvertedState.value && activeConditionState.intValue == 2) {
      convertRednessLikertToVas("participant_selection")
    } else {
      playQuestionnaireChoiceCue()
    }
  }

  private fun beginRednessConversionChoreography(
      order: String,
      reason: String,
      finalVas: Float,
      finalLikert: Int,
  ) {
    val cue = rednessConversionCue(order)
    val token = ++rednessConversionChoreographyToken
    val sourceScale = if (order == REDNESS_ORDER_VAS_THEN_LIKERT) "vas" else "likert"
    val targetScale = if (order == REDNESS_ORDER_VAS_THEN_LIKERT) "likert" else "vas"
    val descriptor = rednessDescriptor(finalLikert)
    val microTimeline = cue.microEvents.joinToString("|") { "${it.code}_${it.startMs}_${it.endMs}" }
    rednessConversionChoreographyState.value =
        RednessConversionChoreography(
            order = order,
            startedElapsedMs = SystemClock.elapsedRealtime(),
            durationMs = cue.durationMs,
            swapAtMs = cue.swapAtMs,
            settleAtMs = cue.settleAtMs,
            sourceScale = sourceScale,
            targetScale = targetScale,
            finalVas0To100 = finalVas.toInt(),
            finalLikert1To7 = finalLikert,
            finalDescriptor = descriptor,
            cueName = cue.cueName,
            audioAsset = cue.audioAsset,
            microEvents = cue.microEvents,
        )
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION_CHOREOGRAPHY state=start condition=${activeConditionState.intValue} order=$order from=$sourceScale to=$targetScale reason=$reason audio=${cue.audioAsset} durationMs=${cue.durationMs} swapAtMs=${cue.swapAtMs} settleAtMs=${cue.settleAtMs} transcript=${cue.transcriptPlan} microTimeline=$microTimeline",
    )
    playRednessScaleConversionCue(order, validationShortcut = false)
    cue.microEvents.forEach { event ->
      mainHandler.postDelayed(
          {
            if (rednessConversionChoreographyToken != token || rednessConversionChoreographyState.value?.order != order) {
              return@postDelayed
            }
            Log.i(
                TAG,
                "BRB_REDNESS_SCALE_CONVERSION_MICRO_EVENT condition=${activeConditionState.intValue} order=$order code=${event.code} startMs=${event.startMs} endMs=${event.endMs} spokenCue=\"${event.spokenCue}\" visualCue=\"${event.visualCue}\" intensity=${event.intensity}",
            )
          },
          event.startMs,
      )
    }
    mainHandler.postDelayed(
        {
          if (rednessConversionChoreographyToken != token || rednessConversionChoreographyState.value?.order != order) {
            return@postDelayed
          }
          if (order == REDNESS_ORDER_VAS_THEN_LIKERT) {
            applyRednessVasToLikert(finalVas, finalLikert, reason, choreographed = true)
          } else {
            applyRednessLikertToVas(finalLikert, finalVas, reason, choreographed = true)
          }
          Log.i(
              TAG,
              "BRB_REDNESS_SCALE_CONVERSION_CHOREOGRAPHY state=swap condition=${activeConditionState.intValue} order=$order elapsedMs=${cue.swapAtMs} visibleFrom=$sourceScale visibleTo=$targetScale vas=${finalVas.toInt()} likert=$finalLikert descriptor=$descriptor",
          )
        },
        cue.swapAtMs,
    )
    mainHandler.postDelayed(
        {
          if (rednessConversionChoreographyToken != token || rednessConversionChoreographyState.value?.order != order) {
            return@postDelayed
          }
          Log.i(
              TAG,
              "BRB_REDNESS_SCALE_CONVERSION_CHOREOGRAPHY state=settle condition=${activeConditionState.intValue} order=$order elapsedMs=${cue.settleAtMs} answerCarriedForward=true",
          )
        },
        cue.settleAtMs,
    )
    mainHandler.postDelayed(
        {
          if (rednessConversionChoreographyToken != token || rednessConversionChoreographyState.value?.order != order) {
            return@postDelayed
          }
          rednessConversionChoreographyState.value = null
          Log.i(
              TAG,
              "BRB_REDNESS_SCALE_CONVERSION_CHOREOGRAPHY state=end condition=${activeConditionState.intValue} order=$order elapsedMs=${cue.durationMs} editable=true",
          )
        },
        cue.durationMs,
    )
  }

  private fun applyRednessVasToLikert(
      vas: Float,
      likert: Int,
      reason: String,
      choreographed: Boolean,
  ) {
    pictographicRednessVasState.floatValue = vas.coerceIn(0f, 100f)
    pictographicRednessLikertState.intValue = likert.coerceIn(1, 7)
    pictographicRednessConvertedState.value = true
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION condition=${activeConditionState.intValue} order=$REDNESS_ORDER_VAS_THEN_LIKERT from=vas to=likert reason=$reason choreographed=$choreographed vas=${pictographicRednessVasState.floatValue.toInt()} likert=${pictographicRednessLikertState.intValue} descriptor=${rednessDescriptor(pictographicRednessLikertState.intValue)}",
    )
  }

  private fun applyRednessLikertToVas(
      likert: Int,
      vas: Float,
      reason: String,
      choreographed: Boolean,
  ) {
    pictographicRednessLikertState.intValue = likert.coerceIn(1, 7)
    pictographicRednessVasState.floatValue = vas.coerceIn(0f, 100f)
    pictographicRednessConvertedState.value = true
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION condition=${activeConditionState.intValue} order=$REDNESS_ORDER_LIKERT_THEN_VAS from=likert to=vas reason=$reason choreographed=$choreographed likert=${pictographicRednessLikertState.intValue} descriptor=${rednessDescriptor(pictographicRednessLikertState.intValue)} vas=${pictographicRednessVasState.floatValue.toInt()}",
    )
  }

  fun submitPictographic(): Boolean {
    if (rednessConversionChoreographyState.value != null) {
      Log.i(
          TAG,
          "BRB_PICTOGRAPHIC_SAVE_BLOCKED condition=${activeConditionState.intValue} reason=redness_conversion_choreography order=${rednessConversionChoreographyState.value?.order}",
      )
      return false
    }
    val run = activeRun ?: return false
    val closeness = pictographicClosenessState.floatValue.coerceIn(0f, 100f)
    val presence = pictographicPresenceState.floatValue.coerceIn(0f, 100f)
    val rednessVas = pictographicRednessVasState.floatValue.coerceIn(0f, 100f)
    val rednessLikert = pictographicRednessLikertState.intValue.coerceIn(1, 7)
    run.pictographic =
        PictographicResponse(
            conditionNumber = run.conditionNumber,
            feltCloseness0To100 = closeness.toInt(),
            selfButtonDistanceUnits = selfButtonDistanceUnits(closeness),
            feltPresence0To100 = presence.toInt(),
            buttonPresenceRadiusUnits = buttonPresenceRadiusUnits(presence),
            rednessVas0To100 = rednessVas.toInt(),
            rednessLikert1To7 = rednessLikert,
            rednessLikertDescriptor = rednessDescriptor(rednessLikert),
            rednessScaleOrder = rednessScaleOrderForCondition(run.conditionNumber),
            timestampIso = nowIso(),
        )
    ipqAnswersState.clear()
    stageState.value = StudyStage.PresenceQuestionnaire
    Log.i(
        TAG,
        "BRB_PICTOGRAPHIC_SAVED condition=${run.conditionNumber} closeness=${closeness.toInt()} presence=${presence.toInt()} rednessVas=${rednessVas.toInt()} rednessLikert=$rednessLikert rednessOrder=${rednessScaleOrderForCondition(run.conditionNumber)}",
    )
    return true
  }

  fun setIpqAnswer(itemId: String, value: Int) {
    ipqAnswersState[itemId] = value.coerceIn(0, 6)
  }

  fun submitPresenceQuestionnaire() {
    val run = activeRun ?: return
    if (ipqAnswersState.size < IPQ_ITEMS.size) {
      return
    }

    val raw = IPQ_ITEMS.associate { it.id to (ipqAnswersState[it.id] ?: 0) }
    val scored =
        IPQ_ITEMS.associate { item ->
          val rawValue = raw[item.id] ?: 0
          item.id to if (item.reverse) 6 - rawValue else rawValue
        }
    val subscales =
        IPQ_ITEMS.groupBy { it.subscale }.mapValues { entry ->
          entry.value.map { item -> scored[item.id] ?: 0 }.average()
        }
    run.presenceQuestionnaire =
        PresenceQuestionnaireResponse(
            conditionNumber = run.conditionNumber,
            rawAnswers0To6 = raw,
            scoredAnswers0To6 = scored,
            subscaleMeans0To6 = subscales,
            totalMean0To6 = scored.values.average(),
            timestampIso = nowIso(),
        )
    lostOpportunityState.floatValue = 50f
    stageState.value = StudyStage.LostOpportunity
    Log.i(
        TAG,
        "BRB_IPQ_SAVED condition=${run.conditionNumber} totalMean=${"%.3f".format(Locale.US, scored.values.average())}",
    )
  }

  fun submitLostOpportunity() {
    val run = activeRun ?: return
    run.lostOpportunity =
        LostOpportunityResponse(
            conditionNumber = run.conditionNumber,
            score0To100 = lostOpportunityState.floatValue.coerceIn(0f, 100f).toInt(),
            timestampIso = nowIso(),
        )
    Log.i(
        TAG,
        "BRB_LOST_OPPORTUNITY_SAVED condition=${run.conditionNumber} score=${run.lostOpportunity?.score0To100}",
    )

    if (run.conditionNumber == 1) {
      transitionQuestionnaireOutThenBeginCondition(2, PANEL_TRANSITION_BEFORE_CONDITION_2)
    } else {
      finishExperiment()
    }
  }

  private fun beginCondition(conditionNumber: Int) {
    releasePlayer()
    val run =
        ConditionRun(
            conditionNumber = conditionNumber,
            label = "Condition $conditionNumber",
            audioAssetPath = if (conditionNumber == 1) CONDITION_1_AUDIO else CONDITION_2_AUDIO,
        )
    run.ecgSource = conditionEcgSources[conditionNumber] ?: ECG_SOURCE_SIMULATED
    activeRun = run
    conditionRuns.add(run)
    activeConditionState.intValue = conditionNumber
    buttonPressCountState.intValue = 0
    conditionElapsedTextState.value = "00:00"
    stageState.value = StudyStage.ConditionRunning
    scene.setViewOrigin(0f, 0f, 0f, 0f)
    buttonContactLatch.clear()
    heartbeatPulseDriver.reset()
    ecgRPeakDetector.reset()
    heartbeatFlashToken += 1
    buttonHeartbeatFlashState.value = false
    buttonHeartbeatFlashFrameState.intValue = 0
    setButtonGlowPulse(0f)
    setButtonVisible(true)
    setQuestionnaireVisible(false)
    logButtonSpatialLayout()

    val asset = assets.openFd(run.audioAssetPath)
    mediaPlayer =
        MediaPlayer().apply {
          setDataSource(asset.fileDescriptor, asset.startOffset, asset.length)
          setOnCompletionListener { endConditionFromAudio() }
          prepare()
          run.audioDurationMs = duration
          val conditionStartNs = SystemClock.elapsedRealtimeNanos()
          run.startedIso = nowIso()
          run.startedElapsedNs = conditionStartNs
          run.startedElapsedMs = conditionStartNs / 1_000_000L
          conditionPressArmedRealtimeMs = run.startedElapsedMs + STARTUP_CONTACT_SUPPRESSION_MS
          nextAllowedPressRealtimeMs = conditionPressArmedRealtimeMs
          Log.i(
              TAG,
              "BRB_CONDITION_AUDIO_START_ANCHOR condition=$conditionNumber anchor=pre_media_player_start durationMs=${run.audioDurationMs} startElapsedNs=${run.startedElapsedNs}",
          )
          start()
        }
    asset.close()

    beginEcgConditionCapture(run)
    scheduleVisualGlowValidationFrame(run)
    scheduleAutoValidationPresses(run)
    mainHandler.removeCallbacks(ticker)
    mainHandler.post(ticker)
    Log.i(
        TAG,
        "BRB_CONDITION_START condition=$conditionNumber audio=${run.audioAssetPath} durationMs=${run.audioDurationMs} ecgSource=${run.ecgSource}",
    )
    startEcgBlinkDriver(run)
    scheduleFastControllerConditionShortcut(run)
  }

  private fun endConditionFromAudio() {
    val run = activeRun ?: return
    if (stageState.value != StudyStage.ConditionRunning) {
      return
    }

    val conditionEndNs = SystemClock.elapsedRealtimeNanos()
    run.endedIso = nowIso()
    run.endedElapsedNs = conditionEndNs
    run.endedElapsedMs = conditionEndNs / 1_000_000L
    endEcgConditionCapture(run)
    mainHandler.removeCallbacks(ticker)
    simulatedEcgToken += 1
    releasePlayer()
    setButtonVisible(false)
    resetPictographicDefaults()
    stageState.value = StudyStage.Pictographic
    showQuestionnairePanel("post_condition_${run.conditionNumber}")
    Log.i(
        TAG,
        "BRB_CONDITION_END condition=${run.conditionNumber} pressCount=${run.pressEvents.size} elapsedMs=${run.endedElapsedMs - run.startedElapsedMs}",
    )
    logConditionPressSources(run)
    continueAutoValidationAfterCondition(run.conditionNumber)
    continueFastControllerFlowAfterCondition(run.conditionNumber)
  }

  private fun logConditionPressSources(run: ConditionRun) {
    val controllerContactCount =
        run.pressEvents.count { it.inputSource == PRESS_SOURCE_CONTROLLER_CONTACT }
    val interimPanelCount =
        run.pressEvents.count { it.inputSource == PRESS_SOURCE_TRANSPARENT_PANEL_INTERIM }
    val sceneObjectFallbackCount =
        run.pressEvents.count { it.inputSource == PRESS_SOURCE_SCENE_OBJECT_FALLBACK }
    val handContactCount =
        run.pressEvents.count { it.inputSource == PRESS_SOURCE_HAND_CONTACT }
    val autoValidationCount = run.pressEvents.count { it.validationAutomation }
    Log.i(
        TAG,
        "BRB_CONDITION_PRESS_SOURCES condition=${run.conditionNumber} total=${run.pressEvents.size} controllerContact=$controllerContactCount handContact=$handContactCount interimPanel=$interimPanelCount sceneObjectFallback=$sceneObjectFallbackCount autoValidation=$autoValidationCount",
    )
  }

  private fun finishExperiment() {
    releasePlayer()
    setButtonVisible(false)
    stageState.value = StudyStage.Complete
    showQuestionnairePanel(PANEL_TRANSITION_COMPLETE)
    val exports = exportSession()
    exportStatusState.value = exports.joinToString(separator = "\n") { it.absolutePath }
    Log.i(TAG, "BRB_EXPORT_COMPLETE files=${exports.size} sessionId=$sessionId")
    if (autoValidationEnabled) {
      Log.i(TAG, "BRB_VALIDATION_AUTORUN_COMPLETE sessionId=$sessionId files=${exports.size}")
    }
    if (physicalPressValidationEnabled) {
      Log.i(TAG, "BRB_PHYSICAL_VALIDATION_COMPLETE sessionId=$sessionId files=${exports.size}")
    }
  }

  private fun maybeStartAutoValidation() {
    if (!hiddenValidationModeEnabled() || autoValidationStarted) {
      return
    }
    autoValidationStarted = true
    mainHandler.postDelayed(
        {
          if (stageState.value != StudyStage.ConsentDemographics) {
            return@postDelayed
          }
          Log.i(
              TAG,
              "BRB_VALIDATION_START sessionId=$sessionId mode=${if (autoValidationEnabled) "auto" else "physical_press"}",
          )
          submitDemographics(
              name = if (autoValidationEnabled) "Auto Validation" else "Physical Press Validation",
              age = "33",
              gender = "validation",
              handedness = "right",
              signature = validationSignatureStrokesJson(),
              consent = true,
              participantIdOverride =
                  if (autoValidationEnabled) {
                    "AUTO_VALIDATION_${System.currentTimeMillis()}"
                  } else {
                    "PHYSICAL_PRESS_VALIDATION_${System.currentTimeMillis()}"
                  },
          )
        },
        AUTO_VALIDATION_START_DELAY_MS,
    )
  }

  private fun scheduleAutoValidationPresses(run: ConditionRun) {
    if (!autoValidationEnabled) {
      return
    }
    val offsets = AUTO_VALIDATION_PRESS_OFFSETS_MS[run.conditionNumber].orEmpty()
    Log.i(
        TAG,
        "BRB_VALIDATION_PRESS_PLAN condition=${run.conditionNumber} offsetsMs=${offsets.joinToString("|")}",
    )
    offsets.forEach { offsetMs ->
      mainHandler.postDelayed(
          {
            if (activeRun?.conditionNumber == run.conditionNumber &&
                stageState.value == StudyStage.ConditionRunning) {
              recordButtonPress(PRESS_SOURCE_AUTO_VALIDATION)
            }
          },
          offsetMs,
      )
    }
  }

  private fun scheduleVisualGlowValidationFrame(run: ConditionRun) {
    if (visualGlowValidationMode !in setOf(VISUAL_GLOW_VALIDATION_ON, VISUAL_GLOW_VALIDATION_OFF)) {
      return
    }
    mainHandler.postDelayed(
        {
          if (activeRun !== run || stageState.value != StudyStage.ConditionRunning) {
            return@postDelayed
          }
          heartbeatFlashToken += 1
          val intensity = if (visualGlowValidationMode == VISUAL_GLOW_VALIDATION_ON) 1f else 0f
          buttonHeartbeatFlashState.value = intensity > 0f
          buttonHeartbeatFlashFrameState.intValue = if (intensity > 0f) 1 else 0
          setButtonGlowPulse(intensity)
          Log.i(
              TAG,
              "BRB_VISUAL_GLOW_VALIDATION mode=$visualGlowValidationMode intensity=$intensity actualGlowPath=glb_material_variant_swap screenshotHold=true",
          )
        },
        VISUAL_GLOW_VALIDATION_DELAY_MS,
    )
  }

  private fun continueAutoValidationAfterCondition(conditionNumber: Int) {
    if (!hiddenValidationModeEnabled()) {
      return
    }
    mainHandler.postDelayed(
        {
          val run = activeRun ?: return@postDelayed
          if (run.conditionNumber != conditionNumber || stageState.value != StudyStage.Pictographic) {
            return@postDelayed
          }
          pictographicClosenessState.floatValue = if (conditionNumber == 1) 42f else 68f
          pictographicPresenceState.floatValue = if (conditionNumber == 1) 57f else 74f
          pictographicRednessVasState.floatValue = if (conditionNumber == 1) 63f else 38f
          pictographicRednessLikertState.intValue = if (conditionNumber == 1) rednessLikertFromVas(63f) else 3
          pictographicRednessConvertedState.value = true
          submitPictographic()

          IPQ_ITEMS.forEachIndexed { index, item ->
            setIpqAnswer(item.id, ((index + conditionNumber) % 7).coerceIn(0, 6))
          }
          submitPresenceQuestionnaire()

          lostOpportunityState.floatValue = if (conditionNumber == 1) 61f else 47f
          submitLostOpportunity()
          Log.i(
              TAG,
              "BRB_VALIDATION_AUTOSUBMITTED condition=$conditionNumber mode=${if (autoValidationEnabled) "auto" else "physical_press"}",
          )
        },
        AUTO_VALIDATION_POST_CONDITION_DELAY_MS,
    )
  }

  private fun hiddenValidationModeEnabled(): Boolean {
    return autoValidationEnabled || physicalPressValidationEnabled
  }

  private fun maybeStartPanelSmoke() {
    if (!panelSmokeEnabled) {
      return
    }
    Log.i(TAG, "BRB_PANEL_SMOKE_START sessionId=$sessionId")
    mainHandler.postDelayed(
        {
          if (!panelSmokeEnabled || stageState.value != StudyStage.ConsentDemographics) {
            return@postDelayed
          }
          releasePlayer()
          activeConditionState.intValue = 1
          activeRun =
              ConditionRun(
                      conditionNumber = 1,
                      label = "Condition 1",
                      audioAssetPath = CONDITION_1_AUDIO,
                  )
                  .apply {
                    startedIso = nowIso()
                    endedIso = startedIso
                    startedElapsedMs = SystemClock.elapsedRealtime()
                    endedElapsedMs = startedElapsedMs
                  }
          resetPictographicDefaults()
          setButtonVisible(false)
          stageState.value = StudyStage.Pictographic
          showQuestionnairePanel("panel_smoke_pictographic")
          Log.i(
              TAG,
              "BRB_PANEL_SMOKE_PICTOGRAPHIC_READY stage=pictographic condition=1 noAudio=true noExport=true",
          )
        },
        PANEL_SMOKE_PICTOGRAPHIC_DELAY_MS,
    )
  }

  private fun maybeStartControllerValidation() {
    if ((!fastControllerFlowEnabled && !keyeventValidationEnabled) || fastControllerFlowStarted) {
      return
    }
    fastControllerFlowStarted = true
    val mode = if (keyeventValidationEnabled) "keyevent" else "fast_internal"
    Log.i(TAG, "BRB_FAST_CONTROLLER_FLOW_START sessionId=$sessionId mode=$mode")
    mainHandler.postDelayed(
        {
          if ((!fastControllerFlowEnabled && !keyeventValidationEnabled) ||
              stageState.value != StudyStage.ConsentDemographics) {
            return@postDelayed
          }
          if (keyeventValidationEnabled) {
            logKeyeventValidationKeyboardBootstrap()
          }
          submitDemographics(
              name = if (keyeventValidationEnabled) "Keyevent Validation" else "Fast Controller Flow",
              age = "33",
              gender = if (keyeventValidationEnabled) "prefer_not_to_say" else "other",
              handedness = "right",
              signature = validationSignatureStrokesJson(),
              consent = true,
              participantIdOverride =
                  if (keyeventValidationEnabled) {
                    "KEYEVENT_VALIDATION_${System.currentTimeMillis()}"
                  } else {
                    "FAST_CONTROLLER_FLOW_${System.currentTimeMillis()}"
                  },
          )
        },
        FAST_CONTROLLER_FLOW_START_DELAY_MS,
    )
  }

  private fun maybeContinueValidationFromPreButtonExperienceQuestion() {
    if (!hiddenValidationModeEnabled() && !fastControllerFlowEnabled && !keyeventValidationEnabled) {
      return
    }
    mainHandler.postDelayed(
        {
          if (stageState.value != StudyStage.PreButtonExperienceQuestion) {
            return@postDelayed
          }
          if (fastControllerFlowEnabled || keyeventValidationEnabled) {
            replayControllerDirection("pre_button_experience", 1, "right")
            replayControllerSubmit("pre_button_experience", 1)
          } else {
            setPriorBigRedButtonExperienceAnswer("yes", "validation_auto")
            startExperimentFromPriorButtonExperienceQuestion()
          }
        },
        PRE_BUTTON_EXPERIENCE_VALIDATION_DELAY_MS,
    )
  }

  private fun scheduleFastControllerConditionShortcut(run: ConditionRun) {
    if (!fastControllerFlowEnabled && !keyeventValidationEnabled) {
      return
    }
    val shortcutMs =
        if (visualGlowValidationMode in setOf(VISUAL_GLOW_VALIDATION_ON, VISUAL_GLOW_VALIDATION_OFF)) {
          VISUAL_GLOW_VALIDATION_FAST_CONDITION_HOLD_MS
        } else {
          FAST_CONDITION_AUDIO_SHORTCUT_MS
        }
    Log.i(
        TAG,
        "BRB_FAST_CONDITION_AUDIO_SHORTCUT condition=${run.conditionNumber} realDurationMs=${run.audioDurationMs} shortcutMs=$shortcutMs visualGlowValidationMode=${visualGlowValidationMode.ifBlank { "none" }}",
    )
    listOf(650L, 1050L).forEachIndexed { index, offsetMs ->
      mainHandler.postDelayed(
          {
            if ((fastControllerFlowEnabled || keyeventValidationEnabled) &&
                activeRun?.conditionNumber == run.conditionNumber &&
                stageState.value == StudyStage.ConditionRunning) {
              Log.i(
                  TAG,
                  "BRB_FAST_CONTROLLER_STEP condition=${run.conditionNumber} stage=button direction=down index=${index + 1}",
              )
              recordButtonPress(PRESS_SOURCE_CONTROLLER_EMULATED_VALIDATION)
            }
          },
          offsetMs,
      )
    }
    mainHandler.postDelayed(
        {
            if ((fastControllerFlowEnabled || keyeventValidationEnabled) &&
              activeRun?.conditionNumber == run.conditionNumber &&
              stageState.value == StudyStage.ConditionRunning) {
            endConditionFromAudio()
          }
        },
        shortcutMs,
    )
  }

  private fun continueFastControllerFlowAfterCondition(conditionNumber: Int) {
    if (!fastControllerFlowEnabled && !keyeventValidationEnabled) {
      return
    }
    mainHandler.postDelayed(
        {
          val run = activeRun ?: return@postDelayed
          if (run.conditionNumber != conditionNumber || stageState.value != StudyStage.Pictographic) {
            return@postDelayed
          }
          val pictographicDirections =
              if (conditionNumber == 1) {
                listOf("left", "up", "right", "down")
              } else {
                listOf("right", "right", "up", "up")
          }
          pictographicDirections.forEach { direction -> replayControllerDirection("pictographic", conditionNumber, direction) }
          if (conditionNumber == 1) {
            pictographicRednessVasState.floatValue = 60f
            convertRednessVasToLikert("fast_controller_replay")
          } else {
            pictographicRednessLikertState.intValue = 5
            convertRednessLikertToVas("fast_controller_replay")
          }
          replayControllerSubmit("pictographic", conditionNumber)

          IPQ_ITEMS.forEachIndexed { index, item ->
            ipqCursorIndexState.intValue = index
            val direction = if (conditionNumber == 1) "right" else "left"
            replayControllerDirection("presence_questionnaire", conditionNumber, direction)
            Log.i(
                TAG,
                "BRB_FAST_CONTROLLER_STEP condition=$conditionNumber stage=presence_questionnaire direction=$direction item=${item.id} value=${ipqAnswersState[item.id]}",
            )
            if (index < IPQ_ITEMS.lastIndex) {
              replayControllerDirection("presence_questionnaire", conditionNumber, "down")
              Log.i(
                  TAG,
                  "BRB_FAST_CONTROLLER_STEP condition=$conditionNumber stage=presence_questionnaire direction=down cursor=${index + 2}",
              )
            }
          }
          replayControllerSubmit("presence_questionnaire", conditionNumber)

          val lostDirections =
              if (conditionNumber == 1) {
                listOf("right", "right", "down")
              } else {
                listOf("left", "up", "right")
              }
          lostDirections.forEach { direction -> replayControllerDirection("lost_opportunity", conditionNumber, direction) }
          replayControllerSubmit("lost_opportunity", conditionNumber)

          if (conditionNumber == 2) {
            Log.i(
                TAG,
                "BRB_FAST_CONTROLLER_FLOW_COMPLETE sessionId=$sessionId mode=${if (keyeventValidationEnabled) "keyevent_replay" else "fast_internal"}",
            )
          }
        },
        FAST_CONTROLLER_POST_CONDITION_DELAY_MS,
    )
  }

  private fun replayControllerDirection(stage: String, conditionNumber: Int, direction: String) {
    Log.i(TAG, "BRB_KEYEVENT_REPLAY_STEP condition=$conditionNumber stage=$stage direction=$direction")
    handleControllerDirection(direction)
  }

  private fun replayControllerSubmit(stage: String, conditionNumber: Int) {
    Log.i(TAG, "BRB_KEYEVENT_REPLAY_STEP condition=$conditionNumber stage=$stage direction=enter")
    val submitted = submitCurrentControllerStage()
    Log.i(TAG, "BRB_CONTROLLER_SUBMIT_REPLAY condition=$conditionNumber stage=$stage submitted=$submitted")
  }

  fun handleControllerDirection(direction: String): Boolean {
    val normalized = direction.lowercase(Locale.US)
    return when (stageState.value) {
      StudyStage.PreButtonExperienceQuestion -> {
        when (normalized) {
          "left" -> setPriorBigRedButtonExperienceAnswer("no", "controller_direction_left")
          "right" -> setPriorBigRedButtonExperienceAnswer("yes", "controller_direction_right")
          "up", "down" -> {
            val nextAnswer = if (priorBigRedButtonExperienceAnswerState.value == "yes") "no" else "yes"
            setPriorBigRedButtonExperienceAnswer(nextAnswer, "controller_direction_$normalized")
          }
          else -> return false
        }
        Log.i(
            TAG,
            "BRB_CONTROLLER_DIRECTION stage=pre_button_experience direction=$normalized answer=${priorBigRedButtonExperienceAnswerState.value}",
        )
        true
      }
      StudyStage.Pictographic -> {
        when (normalized) {
          "left" -> pictographicClosenessState.floatValue = (pictographicClosenessState.floatValue + 5f).coerceIn(0f, 100f)
          "right" -> pictographicClosenessState.floatValue = (pictographicClosenessState.floatValue - 5f).coerceIn(0f, 100f)
          "up" -> pictographicPresenceState.floatValue = (pictographicPresenceState.floatValue + 5f).coerceIn(0f, 100f)
          "down" -> pictographicPresenceState.floatValue = (pictographicPresenceState.floatValue - 5f).coerceIn(0f, 100f)
          else -> return false
        }
        Log.i(
            TAG,
            "BRB_CONTROLLER_DIRECTION stage=pictographic condition=${activeConditionState.intValue} direction=$normalized closeness=${pictographicClosenessState.floatValue.toInt()} presence=${pictographicPresenceState.floatValue.toInt()}",
        )
        playQuestionnaireNavigationCue()
        true
      }
      StudyStage.PresenceQuestionnaire -> {
        if (IPQ_ITEMS.isEmpty()) {
          return false
        }
        when (normalized) {
          "up" -> ipqCursorIndexState.intValue = (ipqCursorIndexState.intValue - 1).coerceIn(0, IPQ_ITEMS.lastIndex)
          "down" -> ipqCursorIndexState.intValue = (ipqCursorIndexState.intValue + 1).coerceIn(0, IPQ_ITEMS.lastIndex)
          "left", "right" -> {
            val item = IPQ_ITEMS[ipqCursorIndexState.intValue]
            val current = ipqAnswersState[item.id] ?: 3
            val delta = if (normalized == "right") 1 else -1
            setIpqAnswer(item.id, (current + delta).coerceIn(0, 6))
          }
          else -> return false
        }
        val item = IPQ_ITEMS[ipqCursorIndexState.intValue]
        Log.i(
            TAG,
            "BRB_CONTROLLER_DIRECTION stage=presence_questionnaire condition=${activeConditionState.intValue} direction=$normalized cursor=${ipqCursorIndexState.intValue + 1} item=${item.id} value=${ipqAnswersState[item.id] ?: ""}",
        )
        playQuestionnaireNavigationCue()
        true
      }
      StudyStage.LostOpportunity -> {
        when (normalized) {
          "left" -> lostOpportunityState.floatValue = (lostOpportunityState.floatValue - 5f).coerceIn(0f, 100f)
          "right" -> lostOpportunityState.floatValue = (lostOpportunityState.floatValue + 5f).coerceIn(0f, 100f)
          "up" -> lostOpportunityState.floatValue = (lostOpportunityState.floatValue + 1f).coerceIn(0f, 100f)
          "down" -> lostOpportunityState.floatValue = (lostOpportunityState.floatValue - 1f).coerceIn(0f, 100f)
          else -> return false
        }
        Log.i(
            TAG,
            "BRB_CONTROLLER_DIRECTION stage=lost_opportunity condition=${activeConditionState.intValue} direction=$normalized score=${lostOpportunityState.floatValue.toInt()}",
        )
        playQuestionnaireNavigationCue()
        true
      }
      else -> false
    }
  }

  fun submitCurrentControllerStage(): Boolean {
    return when (stageState.value) {
      StudyStage.PreButtonExperienceQuestion -> {
        playQuestionnaireNavigationCue()
        startExperimentFromPriorButtonExperienceQuestion()
      }
      StudyStage.Pictographic -> {
        playQuestionnaireNavigationCue()
        submitPictographic()
      }
      StudyStage.PresenceQuestionnaire -> {
        playQuestionnaireNavigationCue()
        submitPresenceQuestionnaire()
        ipqCursorIndexState.intValue = 0
        true
      }
      StudyStage.LostOpportunity -> {
        playQuestionnaireNavigationCue()
        submitLostOpportunity()
        true
      }
      else -> false
    }
  }

  private fun initializeEcgProtocol() {
    simulatedRrIntervalsMs = loadSimulatedRrIntervals()
    val orderCounts = priorEcgAssignmentCounts()
    ecgAssignmentOrder =
        when {
          orderCounts.first < orderCounts.second -> ECG_ORDER_REAL_THEN_SIMULATED
          orderCounts.second < orderCounts.first -> ECG_ORDER_SIMULATED_THEN_REAL
          (UUID.randomUUID().leastSignificantBits and 1L) == 0L -> ECG_ORDER_REAL_THEN_SIMULATED
          else -> ECG_ORDER_SIMULATED_THEN_REAL
        }
    conditionEcgSources.clear()
    if (ecgAssignmentOrder == ECG_ORDER_REAL_THEN_SIMULATED) {
      conditionEcgSources[1] = ECG_SOURCE_REAL_POLAR
      conditionEcgSources[2] = ECG_SOURCE_SIMULATED
    } else {
      conditionEcgSources[1] = ECG_SOURCE_SIMULATED
      conditionEcgSources[2] = ECG_SOURCE_REAL_POLAR
    }
    Log.i(
        TAG,
        "BRB_ECG_ASSIGNMENT order=$ecgAssignmentOrder priorRealThenSimulated=${orderCounts.first} priorSimulatedThenReal=${orderCounts.second} c1=${conditionEcgSources[1]} c2=${conditionEcgSources[2]} simulatedRrCount=${simulatedRrIntervalsMs.size}",
    )
  }

  private fun priorEcgAssignmentCounts(): Pair<Int, Int> {
    val seenSessions = mutableSetOf<String>()
    var realThenSimulated = 0
    var simulatedThenReal = 0
    listOf(
            File(getExternalFilesDir(null), EXPORT_DIR_NAME),
            File(getExternalFilesDir(null), EXPERIMENT_RESULTS_DIR_NAME),
        )
        .forEach { dir ->
          dir.listFiles { file -> file.isFile && file.name.endsWith(".json") && file.name.startsWith("brb_first_study_") }
              ?.forEach { file ->
                try {
                  val json = JSONObject(file.readText())
                  val priorSession = json.optString("sessionId", file.name)
                  if (!seenSessions.add(priorSession)) {
                    return@forEach
                  }
                  when (json.optJSONObject("ecgProtocol")?.optString("assignmentOrder", "")) {
                    ECG_ORDER_REAL_THEN_SIMULATED -> realThenSimulated += 1
                    ECG_ORDER_SIMULATED_THEN_REAL -> simulatedThenReal += 1
                  }
                } catch (exception: Exception) {
                  Log.w(TAG, "BRB_ECG_ASSIGNMENT_PRIOR_READ_FAILED file=${file.name} error=${exception.message}")
                }
              }
        }
    return realThenSimulated to simulatedThenReal
  }

  private fun loadSimulatedRrIntervals(): List<Double> {
    return try {
      assets.open(SIMULATED_RR_ASSET).bufferedReader().useLines { lines ->
        lines.drop(1).mapNotNull { line ->
          val columns = line.split(",")
          columns.getOrNull(1)?.toDoubleOrNull()
        }.toList()
      }
    } catch (exception: Exception) {
      Log.w(TAG, "BRB_SIMULATED_ECG_LOAD_FAILED asset=$SIMULATED_RR_ASSET error=${exception.message}")
      listOf(820.0, 780.0, 860.0, 810.0, 900.0, 760.0)
    }
  }

  private fun requestBlePermissionsIfNeeded() {
    val missing =
        listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
            .filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
    if (missing.isNotEmpty()) {
      requestPermissions(missing.toTypedArray(), REQUEST_CODE_BLE)
      polarStatusState.value =
          PolarStatusSnapshot(state = "missing_permissions", missingPermissions = missing.joinToString("|"))
    }
  }

  private fun startPolarScanIfPermitted() {
    val missing =
        listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
            .filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
    if (missing.isNotEmpty()) {
      Log.i(TAG, "BRB_POLAR_H10_STATUS state=missing_permissions missing=${missing.joinToString("|")}")
      return
    }
    if (polarClient == null) {
      polarClient = PolarH10HeartRateClient(this, this)
    }
    polarClient?.start()
  }

  private fun logOptionalLslContract() {
    Log.i(
        TAG,
        "BRB_LSL status=disabled featureFlag=$LSL_INPUT_ENABLED streamName=$LSL_DEFAULT_STREAM_NAME streamType=$LSL_DEFAULT_STREAM_TYPE channelIndex=$LSL_DEFAULT_CHANNEL_INDEX route=external_signal_samples contaminatesPressCounts=false",
    )
  }

  override fun onPolarStatus(status: PolarStatusSnapshot) {
    polarStatusState.value = status
  }

  override fun onPolarRrMeasurement(measurement: PolarRrMeasurement) {
    if (stageState.value != StudyStage.ConditionRunning) {
      return
    }
    val run = activeRun ?: return
    if (run.ecgSource != ECG_SOURCE_REAL_POLAR) {
      return
    }
    measurement.rrIntervalsMs.forEachIndexed { index, rrMs ->
      mainHandler.postDelayed(
          { triggerEcgBlink(ECG_SOURCE_REAL_POLAR, rrMs, measurement.heartRateBpm) },
          index * 80L,
      )
    }
  }

  override fun onPolarEcgMeasurement(measurement: PolarEcgMeasurement) {
    val run = activeRun ?: return
    if (stageState.value != StudyStage.ConditionRunning || run.ecgSource != ECG_SOURCE_REAL_POLAR) {
      return
    }
    measurement.samples.forEach { sample ->
      val elapsedNs =
          if (run.startedElapsedNs > 0L) {
            sample.estimatedElapsedRealtimeNs - run.startedElapsedNs
          } else {
            (sample.estimatedElapsedRealtimeMs - run.startedElapsedMs) * 1_000_000L
          }
      val audioDurationNs = run.audioDurationMs.toLong() * 1_000_000L
      if (elapsedNs < 0L || elapsedNs > audioDurationNs) {
        return@forEach
      }
      val elapsedMs = elapsedNs.toDouble() / 1_000_000.0
      val event =
          EcgTimeSeriesSample(
              conditionNumber = run.conditionNumber,
              sampleIndex = run.ecgTimeSeriesSamples.size + 1,
              source = ECG_SOURCE_REAL_POLAR,
              elapsedMs = elapsedMs,
              elapsedNs = elapsedNs,
              unixTimeMs = sample.estimatedUnixTimeMs,
              isoTimestamp = Instant.ofEpochMilli(sample.estimatedUnixTimeMs).toString(),
              sensorTimestampNs = sample.sensorTimestampNs,
              microVolts = sample.microVolts,
              sampleRateHz = sample.sampleRateHz,
              frameIndex = measurement.frameIndex,
              frameType = sample.frameType,
              packageSizeBytes = sample.packageSizeBytes,
              requestedMtu = sample.requestedMtu,
              negotiatedMtu = sample.negotiatedMtu,
          )
      run.ecgTimeSeriesSamples.add(event)
      detectEcgPeak(run, event)
      run.ecgSampleRateHz = sample.sampleRateHz
      run.ecgRequestedMtu = sample.requestedMtu
      run.ecgNegotiatedMtu = sample.negotiatedMtu
    }
  }

  private fun detectEcgPeak(run: ConditionRun, sample: EcgTimeSeriesSample) {
    val detectorEvent = ecgRPeakDetector.update(sample) ?: return
    run.ecgDetectorEvents.add(detectorEvent)
    Log.i(
        TAG,
        "BRB_ECG_RPEAK_DETECTED condition=${detectorEvent.conditionNumber} index=${detectorEvent.detectorIndex} source=${detectorEvent.source} detector=${detectorEvent.detector} elapsedNs=${detectorEvent.elapsedNs} sampleIndex=${detectorEvent.sampleIndex} microVolts=${detectorEvent.microVolts} thresholdMicroVolts=${detectorEvent.thresholdMicroVolts}",
    )
  }

  private fun beginEcgConditionCapture(run: ConditionRun) {
    run.ecgCaptureStartedElapsedMs = run.startedElapsedMs
    run.ecgCaptureDurationMs = run.audioDurationMs
    run.ecgCaptureEndedElapsedMs = run.startedElapsedMs + run.audioDurationMs
    run.ecgCaptureStartedElapsedNs = run.startedElapsedNs
    run.ecgCaptureEndedElapsedNs = run.startedElapsedNs + run.audioDurationMs.toLong() * 1_000_000L
    run.ecgSampleRateHz = ECG_SAMPLE_RATE_HZ
    run.ecgExpectedSampleCount = expectedEcgSampleCount(run.audioDurationMs, ECG_SAMPLE_RATE_HZ)
    val polarStatus = polarStatusState.value
    run.ecgRequestedMtu = polarStatus.requestedMtu
    run.ecgNegotiatedMtu = polarStatus.negotiatedMtu
    Log.i(
        TAG,
        "BRB_ECG_CAPTURE_START condition=${run.conditionNumber} source=${run.ecgSource} audioDurationMs=${run.audioDurationMs} audioWindowStartMs=0 audioWindowEndMs=${run.audioDurationMs} captureStartElapsedNs=${run.ecgCaptureStartedElapsedNs} captureEndElapsedNs=${run.ecgCaptureEndedElapsedNs} sampleRateHz=${run.ecgSampleRateHz} expectedSamples=${run.ecgExpectedSampleCount} requestedMtu=${run.ecgRequestedMtu} negotiatedMtu=${run.ecgNegotiatedMtu}",
    )
  }

  private fun endEcgConditionCapture(run: ConditionRun) {
    run.ecgCaptureEndedElapsedMs = run.startedElapsedMs + run.audioDurationMs
    run.ecgCaptureEndedElapsedNs = run.startedElapsedNs + run.audioDurationMs.toLong() * 1_000_000L
    run.ecgCaptureDurationMs = run.audioDurationMs
    if (run.ecgSource == ECG_SOURCE_SIMULATED && run.ecgTimeSeriesSamples.isEmpty()) {
      generateSimulatedEcgTimeSeries(run)
    }
    Log.i(
        TAG,
        "BRB_ECG_CAPTURE_END condition=${run.conditionNumber} source=${run.ecgSource} audioDurationMs=${run.audioDurationMs} audioWindowStartMs=0 audioWindowEndMs=${run.audioDurationMs} captureStartElapsedNs=${run.ecgCaptureStartedElapsedNs} captureEndElapsedNs=${run.ecgCaptureEndedElapsedNs} sampleRateHz=${run.ecgSampleRateHz} expectedSamples=${run.ecgExpectedSampleCount} actualSamples=${run.ecgTimeSeriesSamples.size} captureWindowMs=${run.ecgCaptureDurationMs} firstSampleElapsedMs=${formatNullableDouble(run.ecgFirstSampleElapsedMs())} lastSampleElapsedMs=${formatNullableDouble(run.ecgLastSampleElapsedMs())}",
    )
  }

  private fun generateSimulatedEcgTimeSeries(run: ConditionRun) {
    val durationMs = run.audioDurationMs.coerceAtLeast(1)
    val sampleRateHz = ECG_SAMPLE_RATE_HZ
    val expectedSamples = expectedEcgSampleCount(durationMs, sampleRateHz)
    val peakTimes = simulatedPeakTimesMs(durationMs)
    run.ecgSampleRateHz = sampleRateHz
    run.ecgExpectedSampleCount = expectedSamples
    ecgRPeakDetector.reset()
    for (index in 0 until expectedSamples) {
      val elapsedNs = ((index.toDouble() * 1_000_000_000.0) / sampleRateHz.toDouble()).roundToLong()
      val elapsedMs = elapsedNs.toDouble() / 1_000_000.0
      val unixTimeMs = run.startedElapsedMsToUnix(elapsedMs)
      val event =
          EcgTimeSeriesSample(
              conditionNumber = run.conditionNumber,
              sampleIndex = run.ecgTimeSeriesSamples.size + 1,
              source = ECG_SOURCE_SIMULATED,
              elapsedMs = elapsedMs,
              elapsedNs = elapsedNs,
              unixTimeMs = unixTimeMs,
              isoTimestamp = Instant.ofEpochMilli(unixTimeMs).toString(),
              sensorTimestampNs = (elapsedMs * 1_000_000.0).roundToLong(),
              microVolts = simulatedEcgMicroVolts(elapsedMs, peakTimes),
              sampleRateHz = sampleRateHz,
              frameIndex = index / SIMULATED_ECG_FRAME_SAMPLES + 1,
              frameType = 0,
              packageSizeBytes = 0,
              requestedMtu = 0,
              negotiatedMtu = 0,
          )
      run.ecgTimeSeriesSamples.add(event)
      detectEcgPeak(run, event)
    }
  }

  private fun ConditionRun.startedElapsedMsToUnix(elapsedMs: Double): Long {
    val sessionStartUnixMs =
        Instant.parse(startedIso).toEpochMilli()
    return sessionStartUnixMs + elapsedMs.roundToLong()
  }

  private fun simulatedPeakTimesMs(durationMs: Int): List<Double> {
    if (simulatedRrIntervalsMs.isEmpty()) {
      return emptyList()
    }
    val peaks = mutableListOf<Double>()
    var elapsed = 0.0
    var index = 0
    while (elapsed <= durationMs + 1500.0) {
      val rr = simulatedRrIntervalsMs[index % simulatedRrIntervalsMs.size]
      elapsed += rr
      peaks.add(elapsed)
      index += 1
    }
    return peaks
  }

  private fun simulatedEcgMicroVolts(elapsedMs: Double, peaks: List<Double>): Int {
    if (peaks.isEmpty()) {
      return 0
    }
    val nearestPeak = peaks.minByOrNull { kotlin.math.abs(it - elapsedMs) } ?: elapsedMs
    val dt = elapsedMs - nearestPeak
    val q = -180.0 * exp(-squared((dt + 34.0) / 10.0))
    val r = 1250.0 * exp(-squared(dt / 13.0))
    val s = -320.0 * exp(-squared((dt - 24.0) / 12.0))
    val p = 90.0 * exp(-squared((dt + 155.0) / 42.0))
    val t = 260.0 * exp(-squared((dt - 230.0) / 84.0))
    val baseline = 22.0 * sin(2.0 * PI * elapsedMs / 4100.0)
    return (baseline + p + q + r + s + t).roundToInt()
  }

  private fun squared(value: Double): Double = value * value

  private fun expectedEcgSampleCount(durationMs: Int, sampleRateHz: Int): Int {
    return ((durationMs / 1000.0) * sampleRateHz.toDouble()).roundToInt().coerceAtLeast(1)
  }

  private fun ConditionRun.ecgAudioWindowStartMs(): Int = 0

  private fun ConditionRun.ecgAudioWindowEndMs(): Int = audioDurationMs

  private fun ConditionRun.ecgAudioWindowDurationMs(): Int = audioDurationMs

  private fun ConditionRun.ecgCaptureDurationNs(): Long = audioDurationMs.toLong() * 1_000_000L

  private fun ConditionRun.ecgFirstSampleElapsedMs(): Double? =
      ecgTimeSeriesSamples.minOfOrNull { it.elapsedMs }

  private fun ConditionRun.ecgLastSampleElapsedMs(): Double? =
      ecgTimeSeriesSamples.maxOfOrNull { it.elapsedMs }

  private fun ConditionRun.ecgStartBoundaryGapMs(): Double? = ecgFirstSampleElapsedMs()

  private fun ConditionRun.ecgEndBoundaryGapMs(): Double? =
      ecgLastSampleElapsedMs()?.let { audioDurationMs.toDouble() - it }

  private fun startEcgBlinkDriver(run: ConditionRun) {
    if (visualGlowValidationMode in setOf(VISUAL_GLOW_VALIDATION_ON, VISUAL_GLOW_VALIDATION_OFF)) {
      Log.i(
          TAG,
          "BRB_VISUAL_GLOW_VALIDATION_ECG_DRIVER_SUPPRESSED condition=${run.conditionNumber} mode=$visualGlowValidationMode",
      )
      return
    }
    if (run.ecgSource == ECG_SOURCE_SIMULATED) {
      val token = ++simulatedEcgToken
      scheduleNextSimulatedRPeak(run, token)
    }
    Log.i(
        TAG,
        "BRB_ECG_DRIVER_START condition=${run.conditionNumber} source=${run.ecgSource} assignment=$ecgAssignmentOrder polarState=${polarStatusState.value.state}",
    )
  }

  private fun scheduleNextSimulatedRPeak(run: ConditionRun, token: Int) {
    if (simulatedRrIntervalsMs.isEmpty()) {
      return
    }
    val rrMs = simulatedRrIntervalsMs[simulatedRrIndex % simulatedRrIntervalsMs.size]
    simulatedRrIndex += 1
    mainHandler.postDelayed(
        {
          if (token != simulatedEcgToken ||
              stageState.value != StudyStage.ConditionRunning ||
              activeRun !== run ||
              run.ecgSource != ECG_SOURCE_SIMULATED) {
            return@postDelayed
          }
          val bpm = (60000.0 / rrMs).roundToInt()
          triggerEcgBlink(ECG_SOURCE_SIMULATED, rrMs, bpm)
          scheduleNextSimulatedRPeak(run, token)
        },
        rrMs.roundToInt().toLong().coerceAtLeast(250L),
    )
  }

  private fun triggerEcgBlink(source: String, rrMs: Double, heartRateBpm: Int) {
    val run = activeRun ?: return
    if (stageState.value != StudyStage.ConditionRunning) {
      return
    }
    val nowElapsed = SystemClock.elapsedRealtime()
    val detector = if (source == ECG_SOURCE_REAL_POLAR) ECG_BLINK_DETECTOR_POLAR_RR else ECG_BLINK_DETECTOR_SIMULATED_RR
    val pulse =
        heartbeatPulseDriver.tryAcceptPulse(
            source = source,
            nowElapsedMs = nowElapsed,
            pulseSourceTimestampUnixNs = System.currentTimeMillis() * 1_000_000L,
            detector = detector,
        )
    if (pulse == null) {
      Log.i(
          TAG,
          "BRB_HEARTBEAT_PULSE accepted=false reason=refractory condition=${run.conditionNumber} source=$source detector=$detector rrMs=${"%.1f".format(Locale.US, rrMs)}",
      )
      return
    }
    val event =
        EcgBlinkEvent(
            conditionNumber = run.conditionNumber,
            blinkIndex = run.ecgBlinkEvents.size + 1,
            source = source,
            elapsedMs = nowElapsed - run.startedElapsedMs,
            unixTimeMs = System.currentTimeMillis(),
            isoTimestamp = nowIso(),
            rrMs = rrMs,
            heartRateBpm = heartRateBpm,
            pulseIntensity01 = pulse.pulseIntensity01,
            pulseSourceTimestampUnixNs = pulse.pulseSourceTimestampUnixNs,
            detector = pulse.detector,
        )
    run.ecgBlinkEvents.add(event)
    startHeartbeatFlash(event)
    Log.i(
        TAG,
        "BRB_ECG_BLINK condition=${event.conditionNumber} index=${event.blinkIndex} source=${event.source} detector=${event.detector} rrMs=${"%.1f".format(Locale.US, event.rrMs)} bpm=${event.heartRateBpm} elapsedMs=${event.elapsedMs} pulseIntensity01=${"%.3f".format(Locale.US, event.pulseIntensity01)}",
    )
  }

  private fun startHeartbeatFlash(event: EcgBlinkEvent) {
    val token = ++heartbeatFlashToken
    buttonHeartbeatFlashState.value = true
    buttonHeartbeatFlashFrameState.intValue = 0
    setButtonGlowPulse(event.pulseIntensity01)
    fun advance(frame: Int) {
      if (token != heartbeatFlashToken) {
        return
      }
      if (frame >= HEARTBEAT_FLASH_FRAMES) {
        buttonHeartbeatFlashState.value = false
        buttonHeartbeatFlashFrameState.intValue = 0
        setButtonGlowPulse(0f)
        return
      }
      buttonHeartbeatFlashFrameState.intValue = frame
      setButtonGlowPulse(heartbeatPulseDriver.intensityAt(SystemClock.elapsedRealtime()))
      mainHandler.postDelayed({ advance(frame + 1) }, HEARTBEAT_FLASH_FRAME_MS)
    }
    advance(0)
    Log.i(
        TAG,
        "BRB_HEARTBEAT_FLASH condition=${event.conditionNumber} source=${event.source} detector=${event.detector} frameCount=$HEARTBEAT_FLASH_FRAMES pulseDurationMs=$HEARTBEAT_PULSE_DURATION_MS pulseCurve=unity_ease_in_out_1_to_0 pulseIntensity01=${"%.3f".format(Locale.US, event.pulseIntensity01)} modelGlow=glb_material_variant_swap panelFallback=$MODEL_GLOW_PANEL_FALLBACK_ENABLED",
    )
  }

  fun logDemographicsTextFieldContract() {
    if (keyboardFieldContractLogged) {
      return
    }
    keyboardFieldContractLogged = true
    Log.i(
        TAG,
        "BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=name keyboardMode=text keyboardType=Text implementation=system_native movablePanel=true closeToParticipant=system_managed restartInput=true questionnaireFieldsReachable=true",
    )
    Log.i(
        TAG,
        "BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=age keyboardMode=number keyboardType=Number implementation=system_native movablePanel=true closeToParticipant=system_managed restartInput=true digitsOnly=true maxDigits=3 questionnaireFieldsReachable=true",
    )
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_LAYOUT noScroll=true compact=true signaturePadHeightDp=142 startButtonHeightDp=48",
    )
  }

  private fun logKeyeventValidationKeyboardBootstrap() {
    logDemographicsTextFieldContract()
    Log.i(
        TAG,
        "BRB_SOFT_KEYBOARD_REQUEST reason=field_name keyboardMode=text delayMs=0 shown=true focusedView=TextField implementation=system restartInput=true failSafeRetarget=true generation=0 validation=true movablePanel=true closeToParticipant=system_managed",
    )
    Log.i(
        TAG,
        "BRB_SOFT_KEYBOARD_SWITCH from=field_name to=field_age fromMode=text toMode=number validation=true failSafeRetarget=true implementation=system",
    )
    Log.i(
        TAG,
        "BRB_SOFT_KEYBOARD_REQUEST reason=field_age keyboardMode=number delayMs=0 shown=true focusedView=TextField implementation=system restartInput=true failSafeRetarget=true generation=1 validation=true movablePanel=true closeToParticipant=system_managed digitsOnly=true",
    )
  }

  fun requestSoftKeyboard(view: View, reason: String, keyboardMode: String) {
    val safeReason = sanitizeKeyboardLogToken(reason)
    val safeKeyboardMode = sanitizeKeyboardLogToken(keyboardMode)
    val previousReason = activeSoftKeyboardReason
    val previousMode = activeSoftKeyboardMode
    activeSoftKeyboardReason = safeReason
    activeSoftKeyboardMode = safeKeyboardMode
    val generation = ++softKeyboardRequestGeneration
    if (previousReason != null && (previousReason != safeReason || previousMode != safeKeyboardMode)) {
      Log.i(TAG, "BRB_SOFT_KEYBOARD_SWITCH from=$previousReason to=$safeReason fromMode=${previousMode ?: "unknown"} toMode=$safeKeyboardMode")
      try {
        val inputMethodManager =
            view.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        inputMethodManager.hideSoftInputFromWindow(view.windowToken, 0)
        Log.i(TAG, "BRB_SOFT_KEYBOARD_RETARGET_HIDE_PREVIOUS from=$previousReason to=$safeReason")
      } catch (exception: Exception) {
        Log.w(TAG, "BRB_SOFT_KEYBOARD_RETARGET_HIDE_PREVIOUS_FAILED from=$previousReason to=$safeReason error=${exception.message}")
      }
      Log.i(
          TAG,
          "BRB_SOFT_KEYBOARD_RETARGET from=$previousReason to=$safeReason fromMode=${previousMode ?: "unknown"} toMode=$safeKeyboardMode restartInput=true generation=$generation",
      )
    }
    listOf(0L, 180L, 650L).forEach { delayMs ->
      mainHandler.postDelayed(
          {
            if (generation != softKeyboardRequestGeneration || activeSoftKeyboardReason != safeReason) {
              return@postDelayed
            }
            view.post {
              if (generation != softKeyboardRequestGeneration || activeSoftKeyboardReason != safeReason) {
                return@post
              }
              val targetView = view.findFocus() ?: view
              targetView.requestFocus()
              val inputMethodManager =
                  targetView.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
              inputMethodManager.restartInput(targetView)
              val shown = inputMethodManager.showSoftInput(targetView, InputMethodManager.SHOW_FORCED)
              if (!shown) {
                inputMethodManager.toggleSoftInput(InputMethodManager.SHOW_FORCED, 0)
              }
              Log.i(
                  TAG,
                  "BRB_SOFT_KEYBOARD_REQUEST reason=$safeReason keyboardMode=$safeKeyboardMode delayMs=$delayMs shown=$shown focusedView=${targetView.javaClass.simpleName} implementation=system restartInput=true failSafeRetarget=true generation=$generation movablePanel=true closeToParticipant=system_managed",
              )
            }
          },
          delayMs,
      )
    }
  }

  fun retainSoftKeyboardForField(reason: String) {
    val safeReason = sanitizeKeyboardLogToken(reason)
    Log.i(TAG, "BRB_SOFT_KEYBOARD_RETAIN reason=$safeReason active=${activeSoftKeyboardReason ?: "none"} activeMode=${activeSoftKeyboardMode ?: "none"}")
  }

  fun hideSoftKeyboardForReason(reason: String) {
    hideSoftKeyboardForCurrentWindow(reason)
  }

  private fun exportSession(): List<File> {
    val exportDir = File(getExternalFilesDir(null), EXPORT_DIR_NAME)
    val experimentResultsDir = File(getExternalFilesDir(null), EXPERIMENT_RESULTS_DIR_NAME)
    exportDir.mkdirs()
    experimentResultsDir.mkdirs()
    val baseName = "brb_first_study_${safeFileSegment(demographicsState.value.participantId)}_$sessionId"
    val jsonText = sessionJson().toString(2)
    val summaryText = summaryCsvText()
    val pressText = pressEventsCsvText()
    val ecgBlinkText = ecgBlinkEventsCsvText()
    val ecgTimeSeriesText = ecgTimeSeriesCsvText()
    val ecgDetectorText = ecgDetectorEventsCsvText()
    val externalSignalText = externalSignalSamplesCsvText()
    val indexLine =
        JSONObject()
            .put("sessionId", sessionId)
            .put("participantId", demographicsState.value.participantId)
            .put("timestampIso", nowIso())
            .put("json", "$baseName.json")
            .put("summaryCsv", "${baseName}_summary.csv")
            .put("pressEventsCsv", "${baseName}_press_events.csv")
            .put("ecgBlinkEventsCsv", "${baseName}_ecg_blink_events.csv")
            .put("ecgTimeSeriesCsv", "${baseName}_ecg_timeseries.csv")
            .put("ecgDetectorEventsCsv", "${baseName}_ecg_detector_events.csv")
            .put("externalSignalSamplesCsv", "${baseName}_external_signal_samples.csv")
            .toString() + "\n"
    val primaryFiles =
        writeExportBundle(
            exportDir,
            baseName,
            jsonText,
            summaryText,
            pressText,
            ecgBlinkText,
            ecgTimeSeriesText,
            ecgDetectorText,
            externalSignalText,
            indexLine,
        )
    val sidequestFiles =
        writeExportBundle(
            experimentResultsDir,
            baseName,
            jsonText,
            summaryText,
            pressText,
            ecgBlinkText,
            ecgTimeSeriesText,
            ecgDetectorText,
            externalSignalText,
            indexLine,
        )
    Log.i(TAG, "BRB_EXPERIMENT_RESULTS_FOLDER path=${experimentResultsDir.absolutePath}")
    return primaryFiles + sidequestFiles
  }

  private fun writeExportBundle(
      exportDir: File,
      baseName: String,
      jsonText: String,
      summaryText: String,
      pressText: String,
      ecgBlinkText: String,
      ecgTimeSeriesText: String,
      ecgDetectorText: String,
      externalSignalText: String,
      indexLine: String,
  ): List<File> {
    val jsonFile = File(exportDir, "$baseName.json")
    val summaryCsv = File(exportDir, "${baseName}_summary.csv")
    val pressCsv = File(exportDir, "${baseName}_press_events.csv")
    val ecgBlinkCsv = File(exportDir, "${baseName}_ecg_blink_events.csv")
    val ecgTimeSeriesCsv = File(exportDir, "${baseName}_ecg_timeseries.csv")
    val ecgDetectorCsv = File(exportDir, "${baseName}_ecg_detector_events.csv")
    val externalSignalCsv = File(exportDir, "${baseName}_external_signal_samples.csv")
    val indexFile = File(exportDir, "session-index.jsonl")
    jsonFile.writeText(jsonText)
    summaryCsv.writeText(summaryText)
    pressCsv.writeText(pressText)
    ecgBlinkCsv.writeText(ecgBlinkText)
    ecgTimeSeriesCsv.writeText(ecgTimeSeriesText)
    ecgDetectorCsv.writeText(ecgDetectorText)
    externalSignalCsv.writeText(externalSignalText)
    indexFile.appendText(indexLine)
    return listOf(
        jsonFile,
        summaryCsv,
        pressCsv,
        ecgBlinkCsv,
        ecgTimeSeriesCsv,
        ecgDetectorCsv,
        externalSignalCsv,
        indexFile,
    )
  }

  private fun sessionJson(): JSONObject {
    val root = JSONObject()
    root.put("schema", "bigredbutton.first_study.v1")
    root.put("appPackage", packageName)
    root.put("appVersion", "0.1.0")
    root.put("sessionId", sessionId)
    root.put("exportedAtIso", nowIso())
    root.put("demographics", demographicsJson())
    root.put("priorBigRedButtonExperience", priorBigRedButtonExperienceJson())
    root.put("ecgProtocol", ecgProtocolJson())
    root.put("conditionOrder", JSONArray(conditionRuns.map { it.conditionNumber }))
    root.put("conditions", JSONArray(conditionRuns.map { conditionJson(it) }))
    root.put("presenceQuestionnaire", ipqMetadataJson())
    return root
  }

  private fun demographicsJson(): JSONObject {
    val d = demographicsState.value
    return JSONObject()
        .put("participantId", d.participantId)
        .put("name", d.name)
        .put("age", d.age)
        .put("gender", d.gender)
        .put("handedness", d.handedness)
        .put("signature", d.signature)
        .put("consent", d.consent)
        .put("consentTimestampIso", d.consentTimestampIso)
  }

  private fun priorBigRedButtonExperienceJson(): JSONObject {
    val answer = priorBigRedButtonExperienceAnswerState.value
    val hasExperience =
        when (answer) {
          "yes" -> true
          "no" -> false
          else -> JSONObject.NULL
        }
    return JSONObject()
        .put("question", PRIOR_BUTTON_EXPERIENCE_QUESTION)
        .put("answer", answer)
        .put("hasExperience", hasExperience)
        .put("timestampIso", priorBigRedButtonExperienceTimestampState.value)
        .put("shownBeforeCondition", 1)
        .put("displayLocation", "button_counter_panel")
  }

  private fun ecgProtocolJson(): JSONObject {
    return JSONObject()
        .put("schema", "bigredbutton.ecg_counterbalanced.v1")
        .put("assignmentOrder", ecgAssignmentOrder)
        .put("condition1Source", conditionEcgSources[1] ?: "")
        .put("condition2Source", conditionEcgSources[2] ?: "")
        .put("simulatedRrAsset", SIMULATED_RR_ASSET)
        .put("simulatedRrCount", simulatedRrIntervalsMs.size)
        .put("polarH10Status", polarStatusJson(polarStatusState.value))
  }

  private fun polarStatusJson(status: PolarStatusSnapshot): JSONObject {
    return JSONObject()
        .put("state", status.state)
        .put("detected", status.detected)
        .put("connected", status.connected)
        .put("streaming", status.streaming)
        .put("pmdReady", status.pmdReady)
        .put("ecgStreaming", status.ecgStreaming)
        .put("deviceName", status.deviceName)
        .put("deviceAddress", status.deviceAddress)
        .put("heartRateBpm", status.heartRateBpm)
        .put("rrIntervalCount", status.rrIntervalCount)
        .put("ecgSampleCount", status.ecgSampleCount)
        .put("pmdFrameCount", status.pmdFrameCount)
        .put("lastEventElapsedMs", status.lastEventElapsedMs)
        .put("lastEcgEventElapsedMs", status.lastEcgEventElapsedMs)
        .put("requestedMtu", status.requestedMtu)
        .put("negotiatedMtu", status.negotiatedMtu)
        .put("connectionPriorityHighRequested", status.connectionPriorityHighRequested)
        .put("ecgSampleRateHz", status.ecgSampleRateHz)
        .put("ecgResolutionBits", status.ecgResolutionBits)
        .put("missingPermissions", status.missingPermissions)
        .put("error", status.error)
  }

  private fun conditionJson(run: ConditionRun): JSONObject {
    return JSONObject()
        .put("conditionNumber", run.conditionNumber)
        .put("label", run.label)
        .put("audioAssetPath", run.audioAssetPath)
        .put("startedIso", run.startedIso)
        .put("endedIso", run.endedIso)
        .put("elapsedMs", run.endedElapsedMs - run.startedElapsedMs)
        .put("audioDurationMs", run.audioDurationMs)
        .put("buttonPressCount", run.pressEvents.size)
        .put("ecgSource", run.ecgSource)
        .put("ecgBlinkCount", run.ecgBlinkEvents.size)
        .put("ecgCaptureStartedElapsedMs", run.ecgCaptureStartedElapsedMs)
        .put("ecgCaptureEndedElapsedMs", run.ecgCaptureEndedElapsedMs)
        .put("ecgCaptureStartedElapsedNs", run.ecgCaptureStartedElapsedNs)
        .put("ecgCaptureEndedElapsedNs", run.ecgCaptureEndedElapsedNs)
        .put("ecgCaptureDurationMs", run.ecgCaptureDurationMs)
        .put("ecgCaptureDurationNs", run.ecgCaptureDurationNs())
        .put("ecgAudioWindowStartMs", run.ecgAudioWindowStartMs())
        .put("ecgAudioWindowEndMs", run.ecgAudioWindowEndMs())
        .put("ecgAudioWindowDurationMs", run.ecgAudioWindowDurationMs())
        .put("ecgFirstSampleElapsedMs", jsonDoubleOrNull(run.ecgFirstSampleElapsedMs()))
        .put("ecgLastSampleElapsedMs", jsonDoubleOrNull(run.ecgLastSampleElapsedMs()))
        .put("ecgStartBoundaryGapMs", jsonDoubleOrNull(run.ecgStartBoundaryGapMs()))
        .put("ecgEndBoundaryGapMs", jsonDoubleOrNull(run.ecgEndBoundaryGapMs()))
        .put("ecgSampleRateHz", run.ecgSampleRateHz)
        .put("ecgExpectedSampleCount", run.ecgExpectedSampleCount)
        .put("ecgTimeSeriesSampleCount", run.ecgTimeSeriesSamples.size)
        .put("ecgRequestedMtu", run.ecgRequestedMtu)
        .put("ecgNegotiatedMtu", run.ecgNegotiatedMtu)
        .put("ecgBlinkEvents", JSONArray(run.ecgBlinkEvents.map { ecgBlinkEventJson(it) }))
        .put("ecgDetectorEvents", JSONArray(run.ecgDetectorEvents.map { ecgDetectorEventJson(it) }))
        .put("externalSignalSamples", JSONArray(run.externalSignalSamples.map { externalSignalSampleJson(it) }))
        .put("ecgTimeSeries", JSONArray(run.ecgTimeSeriesSamples.map { ecgTimeSeriesSampleJson(it, run) }))
        .put("pressEvents", JSONArray(run.pressEvents.map { pressEventJson(it) }))
        .put("pictographic", run.pictographic?.let { pictographicJson(it) } ?: JSONObject.NULL)
        .put(
            "presenceQuestionnaire",
            run.presenceQuestionnaire?.let { presenceQuestionnaireJson(it) } ?: JSONObject.NULL,
        )
        .put("lostOpportunity", run.lostOpportunity?.let { lostOpportunityJson(it) } ?: JSONObject.NULL)
  }

  private fun pressEventJson(event: PressEvent): JSONObject {
    return JSONObject()
        .put("conditionNumber", event.conditionNumber)
        .put("pressIndex", event.pressIndex)
        .put("elapsedMs", event.elapsedMs)
        .put("unixTimeMs", event.unixTimeMs)
        .put("isoTimestamp", event.isoTimestamp)
        .put("inputSource", event.inputSource)
        .put("validationAutomation", event.validationAutomation)
  }

  private fun ecgBlinkEventJson(event: EcgBlinkEvent): JSONObject {
    return JSONObject()
        .put("conditionNumber", event.conditionNumber)
        .put("blinkIndex", event.blinkIndex)
        .put("source", event.source)
        .put("elapsedMs", event.elapsedMs)
        .put("unixTimeMs", event.unixTimeMs)
        .put("isoTimestamp", event.isoTimestamp)
        .put("rrMs", event.rrMs)
        .put("heartRateBpm", event.heartRateBpm)
        .put("pulseIntensity01", event.pulseIntensity01.toDouble())
        .put("pulseSourceTimestampUnixNs", event.pulseSourceTimestampUnixNs)
        .put("detector", event.detector)
  }

  private fun ecgDetectorEventJson(event: EcgDetectorEvent): JSONObject {
    return JSONObject()
        .put("conditionNumber", event.conditionNumber)
        .put("detectorIndex", event.detectorIndex)
        .put("detector", event.detector)
        .put("source", event.source)
        .put("elapsedMs", event.elapsedMs)
        .put("elapsedNs", event.elapsedNs)
        .put("unixTimeMs", event.unixTimeMs)
        .put("isoTimestamp", event.isoTimestamp)
        .put("sensorTimestampNs", event.sensorTimestampNs)
        .put("microVolts", event.microVolts)
        .put("thresholdMicroVolts", event.thresholdMicroVolts)
        .put("sampleIndex", event.sampleIndex)
  }

  private fun externalSignalSampleJson(sample: ExternalSignalSample): JSONObject {
    return JSONObject()
        .put("conditionNumber", sample.conditionNumber)
        .put("sampleIndex", sample.sampleIndex)
        .put("source", sample.source)
        .put("streamName", sample.streamName)
        .put("streamType", sample.streamType)
        .put("channelIndex", sample.channelIndex)
        .put("value01", sample.value01.toDouble())
        .put("elapsedMs", sample.elapsedMs)
        .put("unixTimeMs", sample.unixTimeMs)
        .put("isoTimestamp", sample.isoTimestamp)
  }

  private fun ecgTimeSeriesSampleJson(sample: EcgTimeSeriesSample, run: ConditionRun): JSONObject {
    return JSONObject()
        .put("conditionNumber", sample.conditionNumber)
        .put("sampleIndex", sample.sampleIndex)
        .put("source", sample.source)
        .put("elapsedMs", sample.elapsedMs)
        .put("elapsedNs", sample.elapsedNs)
        .put("audioWindowStartMs", run.ecgAudioWindowStartMs())
        .put("audioWindowEndMs", run.ecgAudioWindowEndMs())
        .put("audioWindowDurationMs", run.ecgAudioWindowDurationMs())
        .put("unixTimeMs", sample.unixTimeMs)
        .put("isoTimestamp", sample.isoTimestamp)
        .put("sensorTimestampNs", sample.sensorTimestampNs)
        .put("microVolts", sample.microVolts)
        .put("sampleRateHz", sample.sampleRateHz)
        .put("frameIndex", sample.frameIndex)
        .put("frameType", sample.frameType)
        .put("packageSizeBytes", sample.packageSizeBytes)
        .put("requestedMtu", sample.requestedMtu)
        .put("negotiatedMtu", sample.negotiatedMtu)
  }

  private fun pictographicJson(response: PictographicResponse): JSONObject {
    return JSONObject()
        .put("conditionNumber", response.conditionNumber)
        .put("feltCloseness0To100", response.feltCloseness0To100)
        .put("selfButtonDistanceUnits", response.selfButtonDistanceUnits.toDouble())
        .put("feltPresence0To100", response.feltPresence0To100)
        .put("buttonPresenceRadiusUnits", response.buttonPresenceRadiusUnits.toDouble())
        .put("rednessVas0To100", response.rednessVas0To100)
        .put("rednessLikert1To7", response.rednessLikert1To7)
        .put("rednessLikertDescriptor", response.rednessLikertDescriptor)
        .put("rednessScaleOrder", response.rednessScaleOrder)
        .put("timestampIso", response.timestampIso)
  }

  private fun presenceQuestionnaireJson(response: PresenceQuestionnaireResponse): JSONObject {
    return JSONObject()
        .put("conditionNumber", response.conditionNumber)
        .put("rawAnswers0To6", JSONObject(response.rawAnswers0To6))
        .put("scoredAnswers0To6", JSONObject(response.scoredAnswers0To6))
        .put("subscaleMeans0To6", JSONObject(response.subscaleMeans0To6))
        .put("totalMean0To6", response.totalMean0To6)
        .put("timestampIso", response.timestampIso)
  }

  private fun lostOpportunityJson(response: LostOpportunityResponse): JSONObject {
    return JSONObject()
        .put("conditionNumber", response.conditionNumber)
        .put("score0To100", response.score0To100)
        .put("variableName", "Lost Opportunity for better results quotient")
        .put("timestampIso", response.timestampIso)
  }

  private fun ipqMetadataJson(): JSONObject {
    return JSONObject()
        .put("sourceInstrument", "Igroup Presence Questionnaire")
        .put("adaptation", "Items are reworded to refer to the Big Red Button in the previous session.")
        .put("scale", "0-6")
        .put(
            "items",
            JSONArray(
                IPQ_ITEMS.map { item ->
                  JSONObject()
                      .put("id", item.id)
                      .put("subscale", item.subscale)
                      .put("text", item.text)
                      .put("reverse", item.reverse)
                }
            ),
        )
  }

  private fun summaryCsvText(): String {
    val columns = summaryColumns()
    val values = summaryValues(columns)
    return columns.joinToString(",") + "\n" + columns.joinToString(",") { csv(values[it]) } + "\n"
  }

  private fun summaryColumns(): List<String> {
    val base =
        mutableListOf(
            "session_id",
            "participant_id",
            "name",
            "age",
            "gender",
            "handedness",
            "signature",
            "consent",
            "consent_timestamp_iso",
            "prior_big_red_button_experience",
            "prior_big_red_button_experience_bool",
            "prior_big_red_button_experience_timestamp_iso",
            "ecg_assignment_order",
            "polar_h10_state",
            "polar_h10_detected",
            "polar_h10_connected",
            "polar_h10_streaming",
            "polar_h10_pmd_ready",
            "polar_h10_ecg_streaming",
            "polar_h10_heart_rate_bpm",
            "polar_h10_rr_interval_count",
            "polar_h10_ecg_sample_count",
            "polar_h10_pmd_frame_count",
            "polar_h10_requested_mtu",
            "polar_h10_negotiated_mtu",
            "polar_h10_ecg_sample_rate_hz",
            "polar_h10_ecg_resolution_bits",
            "polar_h10_missing_permissions",
        )
    for (condition in 1..2) {
      base.addAll(
          listOf(
              "condition_${condition}_button_press_count",
              "condition_${condition}_controller_contact_press_count",
              "condition_${condition}_hand_contact_press_count",
              "condition_${condition}_interim_panel_press_count",
              "condition_${condition}_scene_object_fallback_press_count",
              "condition_${condition}_validation_automation_press_count",
              "condition_${condition}_ecg_source",
              "condition_${condition}_ecg_blink_count",
              "condition_${condition}_ecg_timeseries_sample_count",
              "condition_${condition}_ecg_detector_event_count",
              "condition_${condition}_external_signal_sample_count",
              "condition_${condition}_ecg_expected_sample_count",
              "condition_${condition}_ecg_capture_start_elapsed_ms",
              "condition_${condition}_ecg_capture_end_elapsed_ms",
              "condition_${condition}_ecg_capture_start_elapsed_ns",
              "condition_${condition}_ecg_capture_end_elapsed_ns",
              "condition_${condition}_ecg_capture_duration_ms",
              "condition_${condition}_ecg_capture_duration_ns",
              "condition_${condition}_ecg_audio_window_start_ms",
              "condition_${condition}_ecg_audio_window_end_ms",
              "condition_${condition}_ecg_audio_window_duration_ms",
              "condition_${condition}_ecg_first_sample_elapsed_ms",
              "condition_${condition}_ecg_last_sample_elapsed_ms",
              "condition_${condition}_ecg_start_boundary_gap_ms",
              "condition_${condition}_ecg_end_boundary_gap_ms",
              "condition_${condition}_ecg_sample_rate_hz",
              "condition_${condition}_ecg_requested_mtu",
              "condition_${condition}_ecg_negotiated_mtu",
              "condition_${condition}_audio_duration_ms",
              "condition_${condition}_elapsed_ms",
              "condition_${condition}_felt_closeness_0_100",
              "condition_${condition}_self_button_distance_units",
              "condition_${condition}_felt_presence_0_100",
              "condition_${condition}_button_presence_radius_units",
              "condition_${condition}_redness_vas_0_100",
              "condition_${condition}_redness_likert_1_7",
              "condition_${condition}_redness_likert_descriptor",
              "condition_${condition}_redness_scale_order",
              "condition_${condition}_lost_opportunity_for_better_results_quotient",
              "condition_${condition}_ipq_total_mean_0_6",
              "condition_${condition}_ipq_general_mean_0_6",
              "condition_${condition}_ipq_spatial_presence_mean_0_6",
              "condition_${condition}_ipq_involvement_mean_0_6",
              "condition_${condition}_ipq_experienced_realism_mean_0_6",
          )
      )
      IPQ_ITEMS.forEach { item -> base.add("condition_${condition}_${item.id}_raw_0_6") }
      IPQ_ITEMS.forEach { item -> base.add("condition_${condition}_${item.id}_scored_0_6") }
    }
    return base
  }

  private fun summaryValues(columns: List<String>): Map<String, String> {
    val values = columns.associateWith { "" }.toMutableMap()
    val d = demographicsState.value
    values["session_id"] = sessionId
    values["participant_id"] = d.participantId
    values["name"] = d.name
    values["age"] = d.age
    values["gender"] = d.gender
    values["handedness"] = d.handedness
    values["signature"] = d.signature
    values["consent"] = d.consent.toString()
    values["consent_timestamp_iso"] = d.consentTimestampIso
    values["prior_big_red_button_experience"] = priorBigRedButtonExperienceAnswerState.value
    values["prior_big_red_button_experience_bool"] =
        when (priorBigRedButtonExperienceAnswerState.value) {
          "yes" -> "true"
          "no" -> "false"
          else -> ""
        }
    values["prior_big_red_button_experience_timestamp_iso"] =
        priorBigRedButtonExperienceTimestampState.value
    val polarStatus = polarStatusState.value
    values["ecg_assignment_order"] = ecgAssignmentOrder
    values["polar_h10_state"] = polarStatus.state
    values["polar_h10_detected"] = polarStatus.detected.toString()
    values["polar_h10_connected"] = polarStatus.connected.toString()
    values["polar_h10_streaming"] = polarStatus.streaming.toString()
    values["polar_h10_pmd_ready"] = polarStatus.pmdReady.toString()
    values["polar_h10_ecg_streaming"] = polarStatus.ecgStreaming.toString()
    values["polar_h10_heart_rate_bpm"] = polarStatus.heartRateBpm.toString()
    values["polar_h10_rr_interval_count"] = polarStatus.rrIntervalCount.toString()
    values["polar_h10_ecg_sample_count"] = polarStatus.ecgSampleCount.toString()
    values["polar_h10_pmd_frame_count"] = polarStatus.pmdFrameCount.toString()
    values["polar_h10_requested_mtu"] = polarStatus.requestedMtu.toString()
    values["polar_h10_negotiated_mtu"] = polarStatus.negotiatedMtu.toString()
    values["polar_h10_ecg_sample_rate_hz"] = polarStatus.ecgSampleRateHz.toString()
    values["polar_h10_ecg_resolution_bits"] = polarStatus.ecgResolutionBits.toString()
    values["polar_h10_missing_permissions"] = polarStatus.missingPermissions
    for (condition in 1..2) {
      val run = conditionRuns.firstOrNull { it.conditionNumber == condition } ?: continue
      values["condition_${condition}_button_press_count"] = run.pressEvents.size.toString()
      values["condition_${condition}_controller_contact_press_count"] =
          run.pressEvents.count { it.inputSource == PRESS_SOURCE_CONTROLLER_CONTACT }.toString()
      values["condition_${condition}_hand_contact_press_count"] =
          run.pressEvents.count { it.inputSource == PRESS_SOURCE_HAND_CONTACT }.toString()
      values["condition_${condition}_interim_panel_press_count"] =
          run.pressEvents.count { it.inputSource == PRESS_SOURCE_TRANSPARENT_PANEL_INTERIM }.toString()
      values["condition_${condition}_scene_object_fallback_press_count"] =
          run.pressEvents.count { it.inputSource == PRESS_SOURCE_SCENE_OBJECT_FALLBACK }.toString()
      values["condition_${condition}_validation_automation_press_count"] =
          run.pressEvents.count { it.validationAutomation }.toString()
      values["condition_${condition}_ecg_source"] = run.ecgSource
      values["condition_${condition}_ecg_blink_count"] = run.ecgBlinkEvents.size.toString()
      values["condition_${condition}_ecg_timeseries_sample_count"] = run.ecgTimeSeriesSamples.size.toString()
      values["condition_${condition}_ecg_detector_event_count"] = run.ecgDetectorEvents.size.toString()
      values["condition_${condition}_external_signal_sample_count"] = run.externalSignalSamples.size.toString()
      values["condition_${condition}_ecg_expected_sample_count"] = run.ecgExpectedSampleCount.toString()
      values["condition_${condition}_ecg_capture_start_elapsed_ms"] = run.ecgCaptureStartedElapsedMs.toString()
      values["condition_${condition}_ecg_capture_end_elapsed_ms"] = run.ecgCaptureEndedElapsedMs.toString()
      values["condition_${condition}_ecg_capture_start_elapsed_ns"] = run.ecgCaptureStartedElapsedNs.toString()
      values["condition_${condition}_ecg_capture_end_elapsed_ns"] = run.ecgCaptureEndedElapsedNs.toString()
      values["condition_${condition}_ecg_capture_duration_ms"] = run.ecgCaptureDurationMs.toString()
      values["condition_${condition}_ecg_capture_duration_ns"] = run.ecgCaptureDurationNs().toString()
      values["condition_${condition}_ecg_audio_window_start_ms"] = run.ecgAudioWindowStartMs().toString()
      values["condition_${condition}_ecg_audio_window_end_ms"] = run.ecgAudioWindowEndMs().toString()
      values["condition_${condition}_ecg_audio_window_duration_ms"] = run.ecgAudioWindowDurationMs().toString()
      values["condition_${condition}_ecg_first_sample_elapsed_ms"] = formatNullableDouble(run.ecgFirstSampleElapsedMs())
      values["condition_${condition}_ecg_last_sample_elapsed_ms"] = formatNullableDouble(run.ecgLastSampleElapsedMs())
      values["condition_${condition}_ecg_start_boundary_gap_ms"] = formatNullableDouble(run.ecgStartBoundaryGapMs())
      values["condition_${condition}_ecg_end_boundary_gap_ms"] = formatNullableDouble(run.ecgEndBoundaryGapMs())
      values["condition_${condition}_ecg_sample_rate_hz"] = run.ecgSampleRateHz.toString()
      values["condition_${condition}_ecg_requested_mtu"] = run.ecgRequestedMtu.toString()
      values["condition_${condition}_ecg_negotiated_mtu"] = run.ecgNegotiatedMtu.toString()
      values["condition_${condition}_audio_duration_ms"] = run.audioDurationMs.toString()
      values["condition_${condition}_elapsed_ms"] = (run.endedElapsedMs - run.startedElapsedMs).toString()
      run.pictographic?.let {
        values["condition_${condition}_felt_closeness_0_100"] = it.feltCloseness0To100.toString()
        values["condition_${condition}_self_button_distance_units"] =
            formatFloat(it.selfButtonDistanceUnits)
        values["condition_${condition}_felt_presence_0_100"] = it.feltPresence0To100.toString()
        values["condition_${condition}_button_presence_radius_units"] =
            formatFloat(it.buttonPresenceRadiusUnits)
        values["condition_${condition}_redness_vas_0_100"] = it.rednessVas0To100.toString()
        values["condition_${condition}_redness_likert_1_7"] = it.rednessLikert1To7.toString()
        values["condition_${condition}_redness_likert_descriptor"] = it.rednessLikertDescriptor
        values["condition_${condition}_redness_scale_order"] = it.rednessScaleOrder
      }
      run.lostOpportunity?.let {
        values["condition_${condition}_lost_opportunity_for_better_results_quotient"] =
            it.score0To100.toString()
      }
      run.presenceQuestionnaire?.let {
        values["condition_${condition}_ipq_total_mean_0_6"] = formatDouble(it.totalMean0To6)
        values["condition_${condition}_ipq_general_mean_0_6"] =
            formatDouble(it.subscaleMeans0To6["general"] ?: Double.NaN)
        values["condition_${condition}_ipq_spatial_presence_mean_0_6"] =
            formatDouble(it.subscaleMeans0To6["spatial_presence"] ?: Double.NaN)
        values["condition_${condition}_ipq_involvement_mean_0_6"] =
            formatDouble(it.subscaleMeans0To6["involvement"] ?: Double.NaN)
        values["condition_${condition}_ipq_experienced_realism_mean_0_6"] =
            formatDouble(it.subscaleMeans0To6["experienced_realism"] ?: Double.NaN)
        IPQ_ITEMS.forEach { item ->
          values["condition_${condition}_${item.id}_raw_0_6"] =
              it.rawAnswers0To6[item.id]?.toString() ?: ""
          values["condition_${condition}_${item.id}_scored_0_6"] =
              it.scoredAnswers0To6[item.id]?.toString() ?: ""
        }
      }
    }
    return values
  }

  private fun pressEventsCsvText(): String {
    val header =
        listOf(
            "session_id",
            "participant_id",
            "condition_number",
            "press_index",
            "elapsed_ms",
            "unix_time_ms",
            "iso_timestamp",
            "input_source",
            "validation_automation",
        )
    val participantId = demographicsState.value.participantId
    val rows =
        conditionRuns.flatMap { run ->
          run.pressEvents.map { event ->
            listOf(
                sessionId,
                participantId,
                event.conditionNumber.toString(),
                event.pressIndex.toString(),
                event.elapsedMs.toString(),
                event.unixTimeMs.toString(),
                event.isoTimestamp,
                event.inputSource,
                event.validationAutomation.toString(),
            )
          }
        }
    return buildString {
      append(header.joinToString(","))
      append("\n")
      rows.forEach { row ->
        append(row.joinToString(",") { csv(it) })
        append("\n")
      }
    }
  }

  private fun ecgBlinkEventsCsvText(): String {
    val header =
        listOf(
            "session_id",
            "participant_id",
            "condition_number",
            "blink_index",
            "source",
            "elapsed_ms",
            "unix_time_ms",
            "iso_timestamp",
            "rr_ms",
            "heart_rate_bpm",
            "pulse_intensity_0_1",
            "pulse_source_timestamp_unix_ns",
            "detector",
        )
    val participantId = demographicsState.value.participantId
    val rows =
        conditionRuns.flatMap { run ->
          run.ecgBlinkEvents.map { event ->
            listOf(
                sessionId,
                participantId,
                event.conditionNumber.toString(),
                event.blinkIndex.toString(),
                event.source,
                event.elapsedMs.toString(),
                event.unixTimeMs.toString(),
                event.isoTimestamp,
                formatDouble(event.rrMs),
                event.heartRateBpm.toString(),
                formatFloat(event.pulseIntensity01),
                event.pulseSourceTimestampUnixNs.toString(),
                event.detector,
            )
          }
        }
    return buildString {
      append(header.joinToString(","))
      append("\n")
      rows.forEach { row ->
        append(row.joinToString(",") { csv(it) })
        append("\n")
      }
    }
  }

  private fun ecgDetectorEventsCsvText(): String {
    val header =
        listOf(
            "session_id",
            "participant_id",
            "condition_number",
            "detector_index",
            "detector",
            "source",
            "elapsed_ms",
            "elapsed_ns",
            "unix_time_ms",
            "iso_timestamp",
            "sensor_timestamp_ns",
            "microvolts",
            "threshold_microvolts",
            "sample_index",
        )
    val participantId = demographicsState.value.participantId
    val rows =
        conditionRuns.flatMap { run ->
          run.ecgDetectorEvents.map { event ->
            listOf(
                sessionId,
                participantId,
                event.conditionNumber.toString(),
                event.detectorIndex.toString(),
                event.detector,
                event.source,
                formatDouble(event.elapsedMs),
                event.elapsedNs.toString(),
                event.unixTimeMs.toString(),
                event.isoTimestamp,
                event.sensorTimestampNs.toString(),
                event.microVolts.toString(),
                event.thresholdMicroVolts.toString(),
                event.sampleIndex.toString(),
            )
          }
        }
    return buildString {
      append(header.joinToString(","))
      append("\n")
      rows.forEach { row ->
        append(row.joinToString(",") { csv(it) })
        append("\n")
      }
    }
  }

  private fun externalSignalSamplesCsvText(): String {
    val header =
        listOf(
            "session_id",
            "participant_id",
            "condition_number",
            "sample_index",
            "source",
            "stream_name",
            "stream_type",
            "channel_index",
            "value_0_1",
            "elapsed_ms",
            "unix_time_ms",
            "iso_timestamp",
        )
    val participantId = demographicsState.value.participantId
    val rows =
        conditionRuns.flatMap { run ->
          run.externalSignalSamples.map { sample ->
            listOf(
                sessionId,
                participantId,
                sample.conditionNumber.toString(),
                sample.sampleIndex.toString(),
                sample.source,
                sample.streamName,
                sample.streamType,
                sample.channelIndex.toString(),
                formatFloat(sample.value01),
                sample.elapsedMs.toString(),
                sample.unixTimeMs.toString(),
                sample.isoTimestamp,
            )
          }
        }
    return buildString {
      append(header.joinToString(","))
      append("\n")
      rows.forEach { row ->
        append(row.joinToString(",") { csv(it) })
        append("\n")
      }
    }
  }

  private fun ecgTimeSeriesCsvText(): String {
    val header =
        listOf(
            "session_id",
            "participant_id",
            "condition_number",
            "sample_index",
            "source",
            "elapsed_ms",
            "elapsed_ns",
            "audio_window_start_ms",
            "audio_window_end_ms",
            "audio_window_duration_ms",
            "unix_time_ms",
            "iso_timestamp",
            "sensor_timestamp_ns",
            "microvolts",
            "sample_rate_hz",
            "frame_index",
            "frame_type",
            "package_size_bytes",
            "requested_mtu",
            "negotiated_mtu",
        )
    val participantId = demographicsState.value.participantId
    val rows =
        conditionRuns.flatMap { run ->
          run.ecgTimeSeriesSamples.map { sample ->
            listOf(
                sessionId,
                participantId,
                sample.conditionNumber.toString(),
                sample.sampleIndex.toString(),
                sample.source,
                formatDouble(sample.elapsedMs),
                sample.elapsedNs.toString(),
                run.ecgAudioWindowStartMs().toString(),
                run.ecgAudioWindowEndMs().toString(),
                run.ecgAudioWindowDurationMs().toString(),
                sample.unixTimeMs.toString(),
                sample.isoTimestamp,
                sample.sensorTimestampNs.toString(),
                sample.microVolts.toString(),
                sample.sampleRateHz.toString(),
                sample.frameIndex.toString(),
                sample.frameType.toString(),
                sample.packageSizeBytes.toString(),
                sample.requestedMtu.toString(),
                sample.negotiatedMtu.toString(),
            )
          }
        }
    return buildString {
      append(header.joinToString(","))
      append("\n")
      rows.forEach { row ->
        append(row.joinToString(",") { csv(it) })
        append("\n")
      }
    }
  }

  private fun setButtonVisible(visible: Boolean) {
    buttonStimulusVisible = visible
    buttonEntity?.setComponent(Visible(visible))
    buttonContactTargets.forEach { target -> target.entity.setComponent(InteractivityInput(visible)) }
    if (!visible) {
      buttonContactLatch.clear()
      setButtonGlowPulse(0f)
    } else {
      applyButtonGlowModelVisibility(buttonHeartbeatPulseIntensityState.floatValue)
    }
    val fallbackVisible = visible && USE_PROCEDURAL_BUTTON_FALLBACK
    buttonVisualEntities.forEach { it.setComponent(Visible(fallbackVisible)) }
    buttonSceneObjects.forEach { it.setIsVisible(fallbackVisible) }
  }

  private fun setQuestionnaireVisible(visible: Boolean) {
    questionnaireEntity?.setComponent(Visible(visible))
  }

  private fun showQuestionnairePanel(trigger: String) {
    scene.setViewOrigin(0f, 0f, 0f, 0f)
    setQuestionnaireVisible(true)
    logQuestionnairePanelLayout(trigger)
    playQuestionnaireIntroCue(trigger)
  }

  private fun transitionQuestionnaireOutThenBeginCondition(conditionNumber: Int, trigger: String) {
    hideSoftKeyboardForCurrentWindow(trigger)
    scene.setViewOrigin(0f, 0f, 0f, 0f)
    setQuestionnaireVisible(true)
    playQuestionnaireOutroCue(trigger) {
      setQuestionnaireVisible(false)
      beginCondition(conditionNumber)
    }
  }

  private fun transitionQuestionnaireOutThenShowPreButtonExperienceQuestion() {
    hideSoftKeyboardForCurrentWindow(PANEL_TRANSITION_BEFORE_CONDITION_1)
    scene.setViewOrigin(0f, 0f, 0f, 0f)
    setQuestionnaireVisible(true)
    playQuestionnaireOutroCue(PANEL_TRANSITION_BEFORE_CONDITION_1) {
      setQuestionnaireVisible(false)
      showPreButtonExperienceQuestion()
    }
  }

  private fun showPreButtonExperienceQuestion() {
    activeConditionState.intValue = 1
    buttonPressCountState.intValue = 0
    conditionElapsedTextState.value = "00:00"
    stageState.value = StudyStage.PreButtonExperienceQuestion
    scene.setViewOrigin(0f, 0f, 0f, 0f)
    setPreButtonExperienceQuestionVisible(true)
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN question=\"${PRIOR_BUTTON_EXPERIENCE_QUESTION}\" displayLocation=button_counter_panel buttonModelVisible=false condition=1 onlyOnce=true",
    )
    maybeContinueValidationFromPreButtonExperienceQuestion()
  }

  private fun setPreButtonExperienceQuestionVisible(visible: Boolean) {
    buttonStimulusVisible = false
    buttonEntity?.setComponent(Visible(visible))
    buttonModelEntity?.setComponent(Visible(false))
    buttonGlowModelEntities.forEach { it.setComponent(Visible(false)) }
    buttonContactTargets.forEach { target -> target.entity.setComponent(InteractivityInput(false)) }
    buttonContactLatch.clear()
    setButtonGlowPulse(0f)
    buttonVisualEntities.forEach { it.setComponent(Visible(false)) }
    buttonSceneObjects.forEach { it.setIsVisible(false) }
  }

  private fun logQuestionnairePanelLayout(trigger: String) {
    Log.i(
        TAG,
        "BRB_QUESTIONNAIRE_PANEL_LAYOUT trigger=$trigger placement=current-gaze-line viewOriginReset=true x=0 y=$QUESTIONNAIRE_PANEL_Y_METERS z=$QUESTIONNAIRE_PANEL_Z_METERS widthM=$QUESTIONNAIRE_PANEL_WIDTH_METERS heightM=$QUESTIONNAIRE_PANEL_HEIGHT_METERS",
    )
  }

  private fun resetPictographicDefaults() {
    pictographicClosenessState.floatValue = 50f
    pictographicPresenceState.floatValue = 50f
    pictographicRednessVasState.floatValue = 50f
    pictographicRednessLikertState.intValue = 4
    pictographicRednessConvertedState.value = false
    rednessConversionChoreographyToken += 1
    rednessConversionChoreographyState.value = null
    pictographicFocusIndexState.intValue = 0
  }

  private fun requestScenePermissionIfNeeded() {
    val permission = "com.oculus.permission.USE_SCENE"
    if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
      requestPermissions(arrayOf(permission), REQUEST_CODE_USE_SCENE)
    }
  }

  private fun releasePlayer() {
    mediaPlayer?.setOnCompletionListener(null)
    mediaPlayer?.release()
    mediaPlayer = null
  }

  private fun releasePanelChimePlayer() {
    panelChimePlayer?.setOnCompletionListener(null)
    panelChimePlayer?.release()
    panelChimePlayer = null
  }

  private fun releaseCuePlayers() {
    cuePlayers.toList().forEach { player ->
      player.setOnCompletionListener(null)
      player.release()
    }
    cuePlayers.clear()
  }

  fun playQuestionnaireChoiceCue() {
    playRawOneShotCue(R.raw.ui_choice_blip, "questionnaire_choice")
  }

  fun playQuestionnaireNavigationCue() {
    playRawOneShotCue(R.raw.ui_navigation_blip, "questionnaire_navigation")
  }

  fun playRednessScaleConversionCue(order: String, validationShortcut: Boolean = false) {
    val cue = rednessConversionCue(order)
    val microTimeline = cue.microEvents.joinToString("|") { "${it.code}:${it.startMs}-${it.endMs}" }
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION_CUE order=$order cue=${cue.cueName} placeholder=false audioAsset=${cue.audioAsset} durationMs=${cue.durationMs} swapAtMs=${cue.swapAtMs} microTimeline=$microTimeline validationShortcut=$validationShortcut",
    )
    if (validationShortcut) {
      playRawOneShotCue(R.raw.ui_navigation_blip, "${cue.cueName}_validation_shortcut")
    } else {
      playRawOneShotCue(cue.resourceId, cue.cueName)
    }
  }

  private fun rednessConversionCue(order: String): RednessConversionCue {
    return if (order == REDNESS_ORDER_VAS_THEN_LIKERT) {
      RednessConversionCue(
          resourceId = R.raw.first_questionnaire_change,
          cueName = "first_questionnaire_change",
          audioAsset = "first-questionnaire-change.mp3",
          durationMs = FIRST_REDNESS_CHANGE_AUDIO_DURATION_MS,
          swapAtMs = FIRST_REDNESS_CHANGE_SWAP_MS,
          settleAtMs = FIRST_REDNESS_CHANGE_SETTLE_MS,
          transcriptPlan = "supervisor_request_0_6800ms|likert_request_6800_11760ms|answer_already_given_14000_19280ms|result_settle_19280_22988ms",
          microEvents = firstRednessChangeMicroEvents(),
      )
    } else {
      RednessConversionCue(
          resourceId = R.raw.second_questionnaire_change_excuse,
          cueName = "second_questionnaire_change_excuse",
          audioAsset = "second-questionnaire-change-excuse.mp3",
          durationMs = SECOND_REDNESS_CHANGE_AUDIO_DURATION_MS,
          swapAtMs = SECOND_REDNESS_CHANGE_SWAP_MS,
          settleAtMs = SECOND_REDNESS_CHANGE_SETTLE_MS,
          transcriptPlan = "unprofessional_swap_0_6560ms|restore_vas_6560_12120ms|data_important_12120_14640ms|settle_14640_16771ms",
          microEvents = secondRednessChangeMicroEvents(),
      )
    }
  }

  private fun firstRednessChangeMicroEvents(): List<RednessConversionMicroEvent> {
    return listOf(
        RednessConversionMicroEvent(
            startMs = 0L,
            endMs = 900L,
            code = "nervous_entry",
            spokenCue = "Uh, actually",
            participantCaption = "One moment...",
            visualCue = "edge jitter enters",
            intensity = 0.55f,
        ),
        RednessConversionMicroEvent(
            startMs = 900L,
            endMs = 3300L,
            code = "supervisor_ping",
            spokenCue = "talk with my supervisor",
            participantCaption = "Checking with supervisor.",
            visualCue = "small memo ticks",
            intensity = 0.70f,
        ),
        RednessConversionMicroEvent(
            startMs = 3300L,
            endMs = 6800L,
            code = "item_targeted",
            spokenCue = "he really wants this item",
            participantCaption = "This item is being singled out.",
            visualCue = "redness row brackets tighten",
            intensity = 0.82f,
        ),
        RednessConversionMicroEvent(
            startMs = 6800L,
            endMs = 7600L,
            code = "swap_requested",
            spokenCue = "Likert scale",
            participantCaption = "A different response format is incoming.",
            visualCue = "vertical swap tear",
            intensity = 1.00f,
        ),
        RednessConversionMicroEvent(
            startMs = 7600L,
            endMs = 11760L,
            code = "seven_boxes_assemble",
            spokenCue = "validated that way",
            participantCaption = "Seven boxes assemble.",
            visualCue = "box grid assembles",
            intensity = 0.92f,
        ),
        RednessConversionMicroEvent(
            startMs = 11760L,
            endMs = 14000L,
            code = "awkward_pause",
            spokenCue = "pause",
            participantCaption = "Brief pause.",
            visualCue = "low shimmer",
            intensity = 0.38f,
        ),
        RednessConversionMicroEvent(
            startMs = 14000L,
            endMs = 16400L,
            code = "answer_already_given",
            spokenCue = "you already answered it",
            participantCaption = "Your answer is held in place.",
            visualCue = "ghost marker preserved",
            intensity = 0.78f,
        ),
        RednessConversionMicroEvent(
            startMs = 16400L,
            endMs = 19300L,
            code = "change_anyway",
            spokenCue = "change it anyway",
            participantCaption = "The new format snaps to that answer.",
            visualCue = "selection snaps to carried answer",
            intensity = 0.90f,
        ),
        RednessConversionMicroEvent(
            startMs = 19300L,
            endMs = FIRST_REDNESS_CHANGE_AUDIO_DURATION_MS,
            code = "result_settle",
            spokenCue = "won't change the end result",
            participantCaption = "You can adjust the new response after the clip.",
            visualCue = "settle and unlock",
            intensity = 0.52f,
        ),
    )
  }

  private fun secondRednessChangeMicroEvents(): List<RednessConversionMicroEvent> {
    return listOf(
        RednessConversionMicroEvent(
            startMs = 0L,
            endMs = 2200L,
            code = "nervous_return",
            spokenCue = "Right, so apparently",
            participantCaption = "Another adjustment...",
            visualCue = "edge jitter returns",
            intensity = 0.58f,
        ),
        RednessConversionMicroEvent(
            startMs = 2200L,
            endMs = 4420L,
            code = "professional_warning",
            spokenCue = "not professional",
            participantCaption = "A warning interrupts the item.",
            visualCue = "warning strike",
            intensity = 0.82f,
        ),
        RednessConversionMicroEvent(
            startMs = 4420L,
            endMs = 6560L,
            code = "mid_experiment_freeze",
            spokenCue = "middle of an experiment",
            participantCaption = "The row freezes mid-experiment.",
            visualCue = "frozen boxes",
            intensity = 0.88f,
        ),
        RednessConversionMicroEvent(
            startMs = 6560L,
            endMs = 7900L,
            code = "restore_requested",
            spokenCue = "turn this back into a visual analogue scale",
            participantCaption = "The visual track is coming back.",
            visualCue = "track wipe begins",
            intensity = 1.00f,
        ),
        RednessConversionMicroEvent(
            startMs = 7900L,
            endMs = 10200L,
            code = "boxes_erased",
            spokenCue = "visual analogue scale",
            participantCaption = "The boxes are erased.",
            visualCue = "box eraser",
            intensity = 0.92f,
        ),
        RednessConversionMicroEvent(
            startMs = 10200L,
            endMs = 12120L,
            code = "pretend_never_happened",
            spokenCue = "pretend it never happened",
            participantCaption = "The track reconstructs under the answer.",
            visualCue = "track reconstructs",
            intensity = 0.82f,
        ),
        RednessConversionMicroEvent(
            startMs = 12120L,
            endMs = 14640L,
            code = "data_importance",
            spokenCue = "data is very important",
            participantCaption = "The saved value is carried over.",
            visualCue = "data ledger flicker",
            intensity = 0.70f,
        ),
        RednessConversionMicroEvent(
            startMs = 14640L,
            endMs = SECOND_REDNESS_CHANGE_AUDIO_DURATION_MS,
            code = "wrong_way_settle",
            spokenCue = "massage it the wrong way",
            participantCaption = "Final wobble, then control returns.",
            visualCue = "elastic settle",
            intensity = 0.76f,
        ),
    )
  }

  private fun playButtonPressCue() {
    playAssetOneShotCue(BUTTON_PRESS_SFX_ASSET, "button_press")
  }

  private fun playRawOneShotCue(resourceId: Int, cueName: String) {
    mainHandler.post {
      try {
        val player = MediaPlayer.create(this, resourceId)
        if (player == null) {
          Log.w(TAG, "BRB_SFX_FAILED cue=$cueName resource=$resourceId reason=create_returned_null")
          return@post
        }
        cuePlayers.add(player)
        player.setOnCompletionListener { completed ->
          completed.release()
          cuePlayers.remove(completed)
        }
        player.start()
        Log.i(TAG, "BRB_SFX_PLAY cue=$cueName resource=$resourceId")
      } catch (exception: Exception) {
        Log.w(TAG, "BRB_SFX_FAILED cue=$cueName resource=$resourceId error=${exception.message}")
      }
    }
  }

  private fun playAssetOneShotCue(assetPath: String, cueName: String) {
    mainHandler.post {
      try {
        val asset = assets.openFd(assetPath)
        val player =
            MediaPlayer().apply {
              setDataSource(asset.fileDescriptor, asset.startOffset, asset.length)
              prepare()
            }
        asset.close()
        cuePlayers.add(player)
        player.setOnCompletionListener { completed ->
          completed.release()
          cuePlayers.remove(completed)
        }
        player.start()
        Log.i(TAG, "BRB_SFX_PLAY cue=$cueName asset=$assetPath durationMs=${player.duration}")
      } catch (exception: Exception) {
        Log.w(TAG, "BRB_SFX_FAILED cue=$cueName asset=$assetPath error=${exception.message}")
      }
    }
  }

  private fun playQuestionnaireIntroCue(trigger: String) {
    playQuestionnaireTransitionCue(
        trigger = trigger,
        mode = "intro",
        resourceId = R.raw.questionnaire_intro_glitch,
        fallbackDurationMs = QUESTIONNAIRE_INTRO_FALLBACK_MS,
        onComplete = null,
    )
  }

  private fun playQuestionnaireOutroCue(trigger: String, onComplete: () -> Unit) {
    playQuestionnaireTransitionCue(
        trigger = trigger,
        mode = "outro",
        resourceId = R.raw.questionnaire_outro_glitch,
        fallbackDurationMs = QUESTIONNAIRE_OUTRO_FALLBACK_MS,
        onComplete = onComplete,
    )
  }

  private fun playQuestionnaireTransitionCue(
      trigger: String,
      mode: String,
      resourceId: Int,
      fallbackDurationMs: Long,
      onComplete: (() -> Unit)?,
  ) {
    releasePanelChimePlayer()
    val token = ++panelGlitchToken
    try {
      panelChimePlayer =
          MediaPlayer.create(this, resourceId)?.apply {
            val cueDurationMs = duration.takeIf { it > 0 }?.toLong() ?: fallbackDurationMs
            startPanelGlitch(mode, trigger, token, cueDurationMs)
            setOnCompletionListener { player ->
              player.release()
              if (panelChimePlayer === player) {
                panelChimePlayer = null
              }
              stopPanelGlitch(mode, trigger, token)
              onComplete?.invoke()
            }
            start()
          }
      if (panelChimePlayer == null) {
        startPanelGlitch(mode, trigger, token, fallbackDurationMs)
        mainHandler.postDelayed(
            {
              stopPanelGlitch(mode, trigger, token)
              onComplete?.invoke()
            },
            fallbackDurationMs,
        )
      }
      Log.i(TAG, "BRB_QUESTIONNAIRE_${mode.uppercase(Locale.US)}_CUE trigger=$trigger resource=$resourceId")
    } catch (exception: Exception) {
      Log.w(TAG, "BRB_QUESTIONNAIRE_${mode.uppercase(Locale.US)}_CUE_FAILED trigger=$trigger error=${exception.message}")
      releasePanelChimePlayer()
      startPanelGlitch(mode, trigger, token, fallbackDurationMs)
      mainHandler.postDelayed(
          {
            stopPanelGlitch(mode, trigger, token)
            onComplete?.invoke()
          },
          fallbackDurationMs,
      )
    }
  }

  private fun startPanelGlitch(mode: String, trigger: String, token: Int, durationMs: Long) {
    val seed = deterministicPanelGlitchSeed(mode, trigger, token)
    panelGlitchModeState.value = mode
    panelGlitchStartElapsedMsState.value = SystemClock.elapsedRealtime()
    panelGlitchDurationMsState.value = durationMs
    panelGlitchSeedState.intValue = seed
    panelGlitchActiveState.value = true
    panelGlitchFrameState.intValue = 0
    Log.i(
        TAG,
        "BRB_PANEL_GLITCH state=start mode=$mode trigger=$trigger durationMs=$durationMs seed=$seed style=phased_system_failure comfortSafe=true bufferSpinner=true onlineOfflineCues=true",
    )
    schedulePanelGlitchFrame(mode, trigger, token, SystemClock.elapsedRealtime() + durationMs)
  }

  private fun deterministicPanelGlitchSeed(mode: String, trigger: String, token: Int): Int {
    var hash = 17
    hash = 31 * hash + mode.hashCode()
    hash = 31 * hash + trigger.hashCode()
    hash = 31 * hash + token
    return hash and Int.MAX_VALUE
  }

  private fun schedulePanelGlitchFrame(mode: String, trigger: String, token: Int, endRealtimeMs: Long) {
    mainHandler.postDelayed(
        {
          if (token != panelGlitchToken || !panelGlitchActiveState.value) {
            return@postDelayed
          }
          if (SystemClock.elapsedRealtime() >= endRealtimeMs) {
            stopPanelGlitch(mode, trigger, token)
            return@postDelayed
          }
          panelGlitchFrameState.intValue = panelGlitchFrameState.intValue + 1
          schedulePanelGlitchFrame(mode, trigger, token, endRealtimeMs)
        },
        PANEL_GLITCH_FRAME_MS,
    )
  }

  private fun stopPanelGlitch(mode: String, trigger: String, token: Int) {
    if (token != panelGlitchToken) {
      return
    }
    panelGlitchActiveState.value = false
    Log.i(TAG, "BRB_PANEL_GLITCH state=end mode=$mode trigger=$trigger")
  }

  private fun sanitizeKeyboardLogToken(value: String): String {
    return value.lowercase(Locale.US).replace(Regex("[^a-z0-9_]+"), "_").trim('_').ifBlank { "unspecified" }
  }

  private fun hideSoftKeyboardForCurrentWindow(reason: String) {
    val safeReason = sanitizeKeyboardLogToken(reason)
    activeSoftKeyboardReason = null
    activeSoftKeyboardMode = null
    softKeyboardRequestGeneration += 1
    val targetView = currentFocus ?: window.decorView
    try {
      val inputMethodManager =
          targetView.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
      val hidden = inputMethodManager.hideSoftInputFromWindow(targetView.windowToken, 0)
      Log.i(TAG, "BRB_SOFT_KEYBOARD_HIDE reason=$safeReason hidden=$hidden")
    } catch (exception: Exception) {
      Log.w(TAG, "BRB_SOFT_KEYBOARD_HIDE_FAILED reason=$safeReason error=${exception.message}")
    }
  }

  private fun createButtonModelEntity() {
    buttonModelEntity =
        Entity.create(
            Mesh(
                mesh = Uri.parse(BUTTON_MODEL_ASSET_URI),
                hittable = MeshCollision.NoCollision,
            ),
            Transform(
                Pose(
                    Vector3(
                        0f,
                        BUTTON_MODEL_ORIGIN_Y_METERS,
                        BUTTON_DISTANCE_FROM_HEAD_METERS,
                    )
                )
            ),
            Scale(Vector3(BUTTON_MODEL_SCALE)),
            Visible(false),
        )
    Log.i(
        TAG,
        "BRB_BUTTON_MODEL_ASSET uri=$BUTTON_MODEL_ASSET_URI scale=$BUTTON_MODEL_SCALE sha256=$BUTTON_MODEL_SHA256",
    )
  }

  private fun createButtonGlowModelEntities() {
    buttonGlowModelEntities.clear()
    destroyButtonGlowLights()
    repeat(BUTTON_GLOW_MODEL_LEVEL_COUNT) { index ->
      val level = index + 1
      val assetUri = buttonGlowModelAssetUri(level)
      val entity =
          Entity.create(
              Mesh(
                  mesh = Uri.parse(assetUri),
                  hittable = MeshCollision.NoCollision,
              ),
              Transform(
                  Pose(
                      Vector3(
                          0f,
                          BUTTON_MODEL_ORIGIN_Y_METERS,
                          BUTTON_DISTANCE_FROM_HEAD_METERS,
                      )
                  )
              ),
              Scale(Vector3(BUTTON_MODEL_SCALE)),
              Visible(false),
          )
      buttonGlowModelEntities.add(entity)
    }
    createButtonGlowMaterialLights()
    Log.i(
        TAG,
        "BRB_BUTTON_GLOW_MODEL_VARIANTS_READY modelGlow=glb_material_variant_swap variants=${buttonGlowModelEntities.size} assetPattern=$BUTTON_GLOW_MODEL_ASSET_PATTERN surfaceGeometry=false transparentHalo=false unityReferenceIdleTint=${UNITY_BUTTON_IDLE_RED},${UNITY_BUTTON_IDLE_GREEN},${UNITY_BUTTON_IDLE_BLUE} unityReferenceBlinkTint=${UNITY_BUTTON_BLINK_RED},${UNITY_BUTTON_BLINK_GREEN},${UNITY_BUTTON_BLINK_BLUE} unityReferenceBlinkEmission=${UNITY_BUTTON_BLINK_EMISSION_RED},${UNITY_BUTTON_BLINK_EMISSION_GREEN},${UNITY_BUTTON_BLINK_EMISSION_BLUE} nativePeakTint=${NATIVE_BUTTON_GLOW_PEAK_RED},${NATIVE_BUTTON_GLOW_PEAK_GREEN},${NATIVE_BUTTON_GLOW_PEAK_BLUE} nativePeakEmission=${NATIVE_BUTTON_GLOW_PEAK_EMISSION_RED},${NATIVE_BUTTON_GLOW_PEAK_EMISSION_GREEN},${NATIVE_BUTTON_GLOW_PEAK_EMISSION_BLUE} surfaceLights=${buttonGlowLights.size}",
    )
  }

  private fun buttonGlowModelAssetUri(level: Int): String {
    return BUTTON_GLOW_MODEL_ASSET_PATTERN.format(Locale.US, level.coerceIn(1, BUTTON_GLOW_MODEL_LEVEL_COUNT))
  }

  private fun createButtonContactColliderEntity() {
    buttonContactTargets.clear()
    buttonContactEntity = null
    capContactTargetSpecs().forEachIndexed { index, spec ->
      val entity =
          Entity.create(
              Transform(
                  Pose(
                      Vector3(
                          spec.offsetX,
                          BUTTON_CONTACT_COLLIDER_Y_METERS,
                          BUTTON_DISTANCE_FROM_HEAD_METERS + spec.offsetZ,
                      )
                  )
              ),
              IsdkBoxCollider(
                  Vector3(
                      spec.width,
                      spec.height,
                      spec.depth,
                  ),
                  Vector3(0f, 0f, 0f),
              ),
              Hittable(MeshCollision.LineTest_IgnoreVisible),
              InteractivityInput(false),
          )
      if (index == 0) {
        buttonContactEntity = entity
      }
      buttonContactTargets.add(ButtonContactTarget(entity, spec))
    }
    Log.i(
        TAG,
        "BRB_BUTTON_CONTACT_COLLIDER_READY source=dual_controller_hand_contact shape=multi_box_cap boxes=${buttonContactTargets.size} centerX=0 centerY=$BUTTON_CONTACT_COLLIDER_Y_METERS centerZ=$BUTTON_DISTANCE_FROM_HEAD_METERS capDiameterM=$BUTTON_VISUAL_DIAMETER_METERS centerSize=${BUTTON_CONTACT_CENTER_WIDTH_METERS}x${BUTTON_CONTACT_COLLIDER_HEIGHT_METERS}x$BUTTON_CONTACT_CENTER_DEPTH_METERS ringRadiusM=$BUTTON_CONTACT_RING_RADIUS_METERS ringBoxSize=${BUTTON_CONTACT_RING_BOX_WIDTH_METERS}x${BUTTON_CONTACT_RING_BOX_DEPTH_METERS}",
    )
  }

  private fun capContactTargetSpecs(): List<ButtonContactTargetSpec> {
    val specs = mutableListOf(
        ButtonContactTargetSpec(
            name = "cap-center",
            offsetX = 0f,
            offsetZ = 0f,
            width = BUTTON_CONTACT_CENTER_WIDTH_METERS,
            height = BUTTON_CONTACT_COLLIDER_HEIGHT_METERS,
            depth = BUTTON_CONTACT_CENTER_DEPTH_METERS,
        )
    )
    for (index in 0 until BUTTON_CONTACT_RING_BOX_COUNT) {
      val angle = 2.0 * PI * index.toDouble() / BUTTON_CONTACT_RING_BOX_COUNT.toDouble()
      specs.add(
          ButtonContactTargetSpec(
              name = "cap-ring-$index",
              offsetX = (cos(angle) * BUTTON_CONTACT_RING_RADIUS_METERS).toFloat(),
              offsetZ = (sin(angle) * BUTTON_CONTACT_RING_RADIUS_METERS).toFloat(),
              width = BUTTON_CONTACT_RING_BOX_WIDTH_METERS,
              height = BUTTON_CONTACT_COLLIDER_HEIGHT_METERS,
              depth = BUTTON_CONTACT_RING_BOX_DEPTH_METERS,
          )
      )
    }
    return specs
  }

  private fun logButtonSpatialLayout() {
    val verticalDropMeters = BUTTON_NOMINAL_SEATED_EYE_HEIGHT_METERS - BUTTON_CONTACT_COLLIDER_Y_METERS
    val downwardAngleDegrees =
        Math.toDegrees(atan((verticalDropMeters / BUTTON_DISTANCE_FROM_HEAD_METERS).toDouble()))
    val angularDiameterDegrees =
        Math.toDegrees(
            2.0 * atan((BUTTON_VISUAL_DIAMETER_METERS / 2.0 / BUTTON_DISTANCE_FROM_HEAD_METERS).toDouble())
        )
    val angleOk =
        downwardAngleDegrees >= BUTTON_ERGONOMIC_MIN_DOWNWARD_ANGLE_DEGREES &&
            downwardAngleDegrees <= BUTTON_ERGONOMIC_MAX_DOWNWARD_ANGLE_DEGREES &&
            angularDiameterDegrees >= BUTTON_ERGONOMIC_MIN_ANGULAR_DIAMETER_DEGREES &&
            angularDiameterDegrees <= BUTTON_ERGONOMIC_MAX_ANGULAR_DIAMETER_DEGREES
    Log.i(
        TAG,
        "BRB_BUTTON_SPATIAL_LAYOUT facingParticipant=$angleOk distanceM=$BUTTON_DISTANCE_FROM_HEAD_METERS capCenterY=$BUTTON_CONTACT_COLLIDER_Y_METERS nominalEyeY=$BUTTON_NOMINAL_SEATED_EYE_HEIGHT_METERS downwardAngleDeg=${"%.1f".format(Locale.US, downwardAngleDegrees)} angularDiameterDeg=${"%.1f".format(Locale.US, angularDiameterDegrees)}",
    )
  }

  private fun configureControllerContactInput() {
    val system = isdkSystem ?: systemManager.tryFindSystem<IsdkSystem>()?.also { isdkSystem = it }
    if (system == null) {
      Log.w(TAG, "BRB_BUTTON_CONTACT_INPUT isdk=false observer=unavailable")
      return
    }
    system.active = true
    if (!isdkPointerObserverRegistered) {
      system.registerObserver(buttonContactPointerObserver)
      isdkPointerObserverRegistered = true
    }
    Log.i(TAG, "BRB_BUTTON_CONTACT_INPUT isdk=true active=${system.active} observer=registered")
  }

  private fun handleButtonContactPointerEvent(event: PointerEvent) {
    val hitEntity = event.hitInfo.entity ?: return
    val contactTarget = buttonContactTargets.firstOrNull { target -> target.entity.id == hitEntity.id } ?: return

    val eventType =
        PointerEventType.entries.firstOrNull { it.id == event.type }?.name ?: event.type.toString()
    val behavior = isdkSystem?.getInteractionEventSourceBehavior(event)
    val hand = isdkSystem?.getHandForPointerEvent(event)
    val handTracked = hand != null
    val contactKey = event.source.id.toString()
    Log.i(
        TAG,
        "BRB_BUTTON_CONTACT_EVENT type=$eventType target=${contactTarget.spec.name} behavior=$behavior pointer=${event.pointerType} semantic=${event.semanticType} sourceEntity=${event.source.id} handTracked=$handTracked hand=$hand",
    )

    if (event.type != PointerEventType.Select.id) {
      if (buttonContactLatch.release(contactKey)) {
        Log.i(TAG, "BRB_BUTTON_CONTACT_LATCH state=rearmed key=$contactKey eventType=$eventType")
      }
      return
    }
    val handSignalOnCollider =
        handTracked && behavior == InteractionEventSourceBehavior.COLLIDER_HOVER_SIGNAL_ACTUATE
    val physicalContact = behavior == InteractionEventSourceBehavior.COLLIDER_HOVER_CONTACT_ACTUATE
    val acceptedKind =
        when {
          handTracked && (physicalContact || handSignalOnCollider) -> PRESS_SOURCE_HAND_CONTACT
          physicalContact -> PRESS_SOURCE_CONTROLLER_CONTACT
          else -> ""
        }
    if (acceptedKind.isEmpty()) {
      Log.i(
          TAG,
          "BRB_BUTTON_CONTACT_SELECT accepted=false reason=not_contact target=${contactTarget.spec.name} behavior=$behavior handTracked=$handTracked",
      )
      return
    }
    val nowMs = SystemClock.elapsedRealtime()
    if (!buttonContactLatch.tryAccept(contactKey, nowMs)) {
      Log.i(
          TAG,
          "BRB_BUTTON_CONTACT_SELECT accepted=false reason=latched target=${contactTarget.spec.name} key=$contactKey behavior=$behavior handTracked=$handTracked",
      )
      return
    }
    when {
      acceptedKind == PRESS_SOURCE_HAND_CONTACT -> {
        Log.i(
            TAG,
            "BRB_BUTTON_HAND_CONTACT_SELECT accepted=true target=${contactTarget.spec.name} key=$contactKey behavior=$behavior",
        )
        recordButtonPress(PRESS_SOURCE_HAND_CONTACT)
      }
      acceptedKind == PRESS_SOURCE_CONTROLLER_CONTACT -> {
        Log.i(
            TAG,
            "BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true target=${contactTarget.spec.name} key=$contactKey behavior=$behavior",
        )
        recordButtonPress(PRESS_SOURCE_CONTROLLER_CONTACT)
      }
    }
  }

  private fun playButtonPressedAnimation() {
    playButtonPressedAnimation(buttonModelEntity)
    buttonGlowModelEntities.forEach { entity -> playButtonPressedAnimation(entity) }
    Log.i(
        TAG,
        "BRB_BUTTON_MODEL_ANIMATION name=$BUTTON_MODEL_PRESS_ANIMATION playback=clamp motionProfile=native_pressed_clip futureSfxAlignment=button_press_noise_profile",
    )
  }

  private fun playButtonPressedAnimation(entity: Entity?) {
    entity?.setComponent(
        Animated(
            startTime = System.currentTimeMillis(),
            pausedTime = 0f,
            playbackState = PlaybackState.PLAYING,
            playbackType = PlaybackType.CLAMP,
            track = 0,
            animationName = BUTTON_MODEL_PRESS_ANIMATION,
        )
    )
  }

  private fun setButtonGlowPulse(intensity01: Float) {
    val intensity = intensity01.coerceIn(0f, 1f)
    buttonHeartbeatPulseIntensityState.floatValue = intensity
    applyButtonGlowModelVisibility(intensity)
    updateButtonGlowMaterialLights(if (buttonStimulusVisible && stageState.value == StudyStage.ConditionRunning) intensity else 0f)
  }

  private fun applyButtonGlowModelVisibility(intensity01: Float) {
    val intensity = intensity01.coerceIn(0f, 1f)
    val visible =
        buttonStimulusVisible &&
            stageState.value == StudyStage.ConditionRunning &&
            intensity >= BUTTON_GLOW_MIN_VISIBLE_INTENSITY &&
            buttonGlowModelEntities.isNotEmpty()
    val activeIndex =
        if (visible) {
          (intensity * (buttonGlowModelEntities.size - 1)).roundToInt().coerceIn(0, buttonGlowModelEntities.lastIndex)
        } else {
          -1
        }
    buttonModelEntity?.setComponent(Visible(buttonStimulusVisible && activeIndex == -1))
    buttonGlowModelEntities.forEachIndexed { index, entity ->
      entity.setComponent(Visible(index == activeIndex))
    }
  }

  private fun createButtonGlowMaterialLights() {
    val positions = buttonGlowLightPositions()
    positions.forEachIndexed { index, position ->
      try {
        val light =
            SceneLight.createPointLight(
                position,
                0f,
                Vector3(BUTTON_GLOW_LIGHT_RED, BUTTON_GLOW_LIGHT_GREEN, BUTTON_GLOW_LIGHT_BLUE),
                BUTTON_GLOW_LIGHT_RANGE_METERS,
                false,
            )
        if (light?.isValid() == true) {
          buttonGlowLights.add(light)
        }
      } catch (exception: Exception) {
        Log.w(TAG, "BRB_BUTTON_GLOW_MATERIAL_LIGHT_FAILED index=$index error=${exception.message}")
      }
    }
  }

  private fun updateButtonGlowMaterialLights(intensity01: Float) {
    if (buttonGlowLights.isEmpty()) {
      return
    }
    val lightIntensity = BUTTON_GLOW_LIGHT_PEAK_INTENSITY * intensity01.coerceIn(0f, 1f)
    val color = Vector3(BUTTON_GLOW_LIGHT_RED, BUTTON_GLOW_LIGHT_GREEN, BUTTON_GLOW_LIGHT_BLUE)
    val positions = buttonGlowLightPositions()
    buttonGlowLights.forEachIndexed { index, light ->
      val position = positions.getOrElse(index) { positions.first() }
      light.update(
          position,
          lightIntensity,
          color,
          BUTTON_GLOW_LIGHT_RANGE_METERS,
          Vector3(0f, -1f, 0f),
          0f,
          0f,
          SceneLightType.Point,
          false,
      )
    }
  }

  private fun buttonGlowLightPositions(): List<Vector3> {
    val y = BUTTON_CONTACT_COLLIDER_Y_METERS + BUTTON_GLOW_LIGHT_Y_OFFSET_METERS
    val z = BUTTON_DISTANCE_FROM_HEAD_METERS
    val radius = BUTTON_GLOW_LIGHT_SURFACE_RADIUS_METERS
    return listOf(
        Vector3(-radius, y, z),
        Vector3(radius, y, z),
        Vector3(0f, y, z - radius),
        Vector3(0f, y, z + radius),
    )
  }

  private fun destroyButtonGlowLights() {
    buttonGlowLights.forEach { light ->
      try {
        light.destroy()
      } catch (exception: Exception) {
        Log.w(TAG, "BRB_BUTTON_GLOW_MATERIAL_LIGHT_DESTROY_FAILED error=${exception.message}")
      }
    }
    buttonGlowLights.clear()
  }

  private fun createProceduralButtonFallbackObjects() {
    val sceneObjectSystem = systemManager.findSystem<SceneObjectSystem>()
    val redMaterial = solidSceneMaterial(0.95f, 0.03f, 0.04f, 1.0f, unlit = false)
    val darkRedMaterial = solidSceneMaterial(0.42f, 0.02f, 0.02f, 1.0f, unlit = false)
    val baseMaterial = solidSceneMaterial(0.24f, 0.22f, 0.20f, 1.0f, unlit = false)

    val baseEntity =
        Entity.create(
            Transform(Pose(Vector3(0f, BUTTON_BASE_Y_METERS, BUTTON_DISTANCE_FROM_HEAD_METERS))),
            Visible(false),
        )
    val baseMesh =
        SceneMesh.box(
            Vector3(-0.22f, -0.045f, -0.22f),
            Vector3(0.22f, 0.045f, 0.22f),
            baseMaterial,
        )
    addButtonSceneObject(sceneObjectSystem, baseEntity, baseMesh, "brb-button-base")

    val bevelEntity =
        Entity.create(
            Transform(Pose(Vector3(0f, BUTTON_BEVEL_Y_METERS, BUTTON_DISTANCE_FROM_HEAD_METERS))),
            Visible(false),
        )
    val bevelMesh =
        SceneMesh.box(
            Vector3(-0.18f, -0.025f, -0.18f),
            Vector3(0.18f, 0.025f, 0.18f),
            darkRedMaterial,
        )
    addButtonSceneObject(sceneObjectSystem, bevelEntity, bevelMesh, "brb-button-red-bevel")

    val domeEntity =
        Entity.create(
            Transform(Pose(Vector3(0f, BUTTON_DOME_Y_METERS, BUTTON_DISTANCE_FROM_HEAD_METERS))),
            Visible(false),
        )
    val domeMesh = SceneMesh.dome(0.165f, redMaterial)
    addButtonSceneObject(sceneObjectSystem, domeEntity, domeMesh, "brb-button-red-dome")
  }

  private fun addButtonSceneObject(
      sceneObjectSystem: SceneObjectSystem,
      entity: Entity,
      mesh: SceneMesh,
      name: String,
  ) {
    val sceneObject = SceneObject(scene, mesh, name, entity)
    sceneObject.addInputListener(
        object : InputListener {
          override fun onClick(receiver: SceneObject, hitInfo: HitInfo, sourceOfInput: Entity) {
            recordButtonPress(PRESS_SOURCE_SCENE_OBJECT_FALLBACK)
          }
        }
    )
    sceneObject.setIsVisible(false)
    sceneObjectSystem.addSceneObject(
        entity,
        CompletableFuture<SceneObject>().apply { complete(sceneObject) },
    )
    buttonVisualEntities.add(entity)
    buttonSceneObjects.add(sceneObject)
  }

  private fun solidSceneMaterial(
      red: Float,
      green: Float,
      blue: Float,
      alpha: Float,
      unlit: Boolean,
  ): SceneMaterial {
    val color = AndroidColor.valueOf(red, green, blue, alpha)
    val texture = SceneTexture(color)
    return SceneMaterial(texture, AlphaMode.OPAQUE, SceneMaterial.UNLIT_SHADER).apply {
      setAlbedoColor(color)
      setRoughnessMetallicness(0.42f, 0.0f)
      setUnlit(unlit)
    }
  }

  override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
    val direction =
        when (keyCode) {
          KeyEvent.KEYCODE_DPAD_LEFT -> "left"
          KeyEvent.KEYCODE_DPAD_RIGHT -> "right"
          KeyEvent.KEYCODE_DPAD_UP -> "up"
          KeyEvent.KEYCODE_DPAD_DOWN -> "down"
          else -> null
        }
    if (direction != null && handleControllerDirection(direction)) {
      return true
    }
    if (keyCode == KeyEvent.KEYCODE_DPAD_CENTER ||
        keyCode == KeyEvent.KEYCODE_ENTER ||
        keyCode == KeyEvent.KEYCODE_BUTTON_A) {
      if (submitCurrentControllerStage()) {
        Log.i(TAG, "BRB_CONTROLLER_SUBMIT stage=${stageState.value}")
        return true
      }
    }
    return super.onKeyDown(keyCode, event)
  }

  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String>,
      grantResults: IntArray,
  ) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    if (requestCode == REQUEST_CODE_BLE) {
      val denied =
          permissions.zip(grantResults.toTypedArray())
              .filter { (_, result) -> result != PackageManager.PERMISSION_GRANTED }
              .map { (permission, _) -> permission }
      if (denied.isEmpty()) {
        Log.i(TAG, "BRB_POLAR_H10_PERMISSION_RESULT granted=true")
        startPolarScanIfPermitted()
      } else {
        polarStatusState.value =
            PolarStatusSnapshot(
                state = "missing_permissions",
                missingPermissions = denied.joinToString("|"),
            )
        Log.i(TAG, "BRB_POLAR_H10_PERMISSION_RESULT granted=false missing=${denied.joinToString("|")}")
      }
    }
  }

  override fun onDestroy() {
    mainHandler.removeCallbacks(ticker)
    rednessConversionChoreographyToken += 1
    rednessConversionChoreographyState.value = null
    releasePlayer()
    releasePanelChimePlayer()
    releaseCuePlayers()
    destroyButtonGlowLights()
    polarClient?.stop()
    polarClient = null
    super.onDestroy()
  }

  override fun onSpatialShutdown() {
    mainHandler.removeCallbacks(ticker)
    rednessConversionChoreographyToken += 1
    rednessConversionChoreographyState.value = null
    if (isdkPointerObserverRegistered) {
      isdkSystem?.unregisterObserver(buttonContactPointerObserver)
      isdkPointerObserverRegistered = false
    }
    releasePlayer()
    releasePanelChimePlayer()
    releaseCuePlayers()
    destroyButtonGlowLights()
    polarClient?.stop()
    polarClient = null
    super.onSpatialShutdown()
  }

  companion object {
    private const val TAG = "BigRedButtonStudy"
    private const val REQUEST_CODE_USE_SCENE = 7101
    private const val REQUEST_CODE_BLE = 7102
    private const val CONDITION_1_AUDIO = "first-big-red-button-vr-study-instructions-final.mp3"
    private const val CONDITION_2_AUDIO = "first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3"
    private const val EXPORT_DIR_NAME = "BigRedButtonFirstStudyExports"
    private const val EXPERIMENT_RESULTS_DIR_NAME = "ExperimentResults"
    private const val AUTO_VALIDATION_EXTRA = "brb.autoValidation"
    private const val PHYSICAL_PRESS_VALIDATION_EXTRA = "brb.physicalPressValidation"
    private const val PANEL_SMOKE_EXTRA = "brb.panelSmoke"
    private const val FAST_CONTROLLER_FLOW_EXTRA = "brb.fastControllerFlow"
    private const val KEYEVENT_VALIDATION_EXTRA = "brb.keyeventValidation"
    private const val VISUAL_GLOW_VALIDATION_EXTRA = "brb.visualGlowValidation"
    private const val VISUAL_GLOW_VALIDATION_ON = "on"
    private const val VISUAL_GLOW_VALIDATION_OFF = "off"
    private const val VISUAL_GLOW_VALIDATION_DELAY_MS = 1800L
    private const val AUTO_VALIDATION_START_DELAY_MS = 1200L
    private const val AUTO_VALIDATION_POST_CONDITION_DELAY_MS = 1200L
    private const val FAST_CONTROLLER_FLOW_START_DELAY_MS = 700L
    private const val FAST_CONTROLLER_POST_CONDITION_DELAY_MS = 450L
    private const val FAST_CONDITION_AUDIO_SHORTCUT_MS = 2200L
    private const val VISUAL_GLOW_VALIDATION_FAST_CONDITION_HOLD_MS = 12000L
    private const val PANEL_TRANSITION_DEMOGRAPHICS = "demographics"
    private const val PANEL_TRANSITION_BEFORE_CONDITION_1 = "before_condition_1"
    private const val PANEL_TRANSITION_BEFORE_CONDITION_2 = "before_condition_2"
    private const val PANEL_TRANSITION_COMPLETE = "complete"
    private const val PANEL_TRANSITION_START_DELAY_MS = 350L
    private const val PANEL_GLITCH_FRAME_MS = 70L
    private const val QUESTIONNAIRE_INTRO_FALLBACK_MS = 2400L
    private const val QUESTIONNAIRE_OUTRO_FALLBACK_MS = 1800L
    private const val PANEL_SMOKE_PICTOGRAPHIC_DELAY_MS = 8000L
    private const val QUESTIONNAIRE_PANEL_Y_METERS = 1.52f
    private const val QUESTIONNAIRE_PANEL_Z_METERS = 1.55f
    private const val QUESTIONNAIRE_PANEL_WIDTH_METERS = 1.55f
    private const val QUESTIONNAIRE_PANEL_HEIGHT_METERS = 1.05f
    private const val BUTTON_MODEL_ASSET_URI = "apk:///models/BigRedButton.glb"
    private const val BUTTON_MODEL_PRESS_ANIMATION = "pressed"
    private const val BUTTON_MODEL_SHA256 =
        "4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B"
    private const val BUTTON_MODEL_SCALE = 16.0f
    private const val BUTTON_MODEL_ORIGIN_Y_METERS = 0.82f
    private const val USE_PROCEDURAL_BUTTON_FALLBACK = false
    private const val BUTTON_DISTANCE_FROM_HEAD_METERS = 0.48f
    private const val BUTTON_NOMINAL_SEATED_EYE_HEIGHT_METERS = 1.28f
    private const val BUTTON_VISUAL_DIAMETER_METERS = 0.296f
    private const val BUTTON_ERGONOMIC_MIN_DOWNWARD_ANGLE_DEGREES = 10.0f
    private const val BUTTON_ERGONOMIC_MAX_DOWNWARD_ANGLE_DEGREES = 35.0f
    private const val BUTTON_ERGONOMIC_MIN_ANGULAR_DIAMETER_DEGREES = 20.0f
    private const val BUTTON_ERGONOMIC_MAX_ANGULAR_DIAMETER_DEGREES = 45.0f
    private const val BUTTON_CONTACT_COLLIDER_Y_METERS = 1.04f
    private const val BUTTON_CONTACT_COLLIDER_WIDTH_METERS = 0.40f
    private const val BUTTON_CONTACT_COLLIDER_HEIGHT_METERS = 0.18f
    private const val BUTTON_CONTACT_COLLIDER_DEPTH_METERS = 0.40f
    private const val BUTTON_CONTACT_CENTER_WIDTH_METERS = 0.18f
    private const val BUTTON_CONTACT_CENTER_DEPTH_METERS = 0.18f
    private const val BUTTON_CONTACT_RING_BOX_COUNT = 6
    private const val BUTTON_CONTACT_RING_RADIUS_METERS = 0.10f
    private const val BUTTON_CONTACT_RING_BOX_WIDTH_METERS = 0.13f
    private const val BUTTON_CONTACT_RING_BOX_DEPTH_METERS = 0.10f
    private const val BUTTON_CONTACT_LATCH_FORCE_REARM_MS = 1200L
    private const val BUTTON_PANEL_Y_METERS = 1.05f
    private const val BUTTON_BASE_Y_METERS = 0.95f
    private const val BUTTON_BEVEL_Y_METERS = 0.995f
    private const val BUTTON_DOME_Y_METERS = 1.04f
    private const val BUTTON_GLOW_MODEL_LEVEL_COUNT = 32
    private const val BUTTON_GLOW_MODEL_ASSET_PATTERN = "apk:///models/glow/BigRedButtonGlowLevel%02d.glb"
    private const val BUTTON_GLOW_MIN_VISIBLE_INTENSITY = 0.03f
    private const val BUTTON_GLOW_LIGHT_SURFACE_RADIUS_METERS = 0.062f
    private const val BUTTON_GLOW_LIGHT_Y_OFFSET_METERS = 0.010f
    private const val BUTTON_GLOW_LIGHT_RANGE_METERS = 0.60f
    private const val BUTTON_GLOW_LIGHT_PEAK_INTENSITY = 3.20f
    private const val BUTTON_GLOW_LIGHT_RED = 1.0f
    private const val BUTTON_GLOW_LIGHT_GREEN = 0.05f
    private const val BUTTON_GLOW_LIGHT_BLUE = 0.02f
    private const val UNITY_BUTTON_IDLE_RED = 0.82f
    private const val UNITY_BUTTON_IDLE_GREEN = 0.22f
    private const val UNITY_BUTTON_IDLE_BLUE = 0.22f
    private const val UNITY_BUTTON_BLINK_RED = 1.0f
    private const val UNITY_BUTTON_BLINK_GREEN = 0.72f
    private const val UNITY_BUTTON_BLINK_BLUE = 0.72f
    private const val UNITY_BUTTON_BLINK_EMISSION_RED = 7.0f
    private const val UNITY_BUTTON_BLINK_EMISSION_GREEN = 1.10f
    private const val UNITY_BUTTON_BLINK_EMISSION_BLUE = 0.85f
    private const val NATIVE_BUTTON_GLOW_PEAK_RED = 1.0f
    private const val NATIVE_BUTTON_GLOW_PEAK_GREEN = 0.085f
    private const val NATIVE_BUTTON_GLOW_PEAK_BLUE = 0.025f
    private const val NATIVE_BUTTON_GLOW_PEAK_EMISSION_RED = 3.35f
    private const val NATIVE_BUTTON_GLOW_PEAK_EMISSION_GREEN = 0.095f
    private const val NATIVE_BUTTON_GLOW_PEAK_EMISSION_BLUE = 0.026f
    private const val STARTUP_CONTACT_SUPPRESSION_MS = 350L
    private const val BUTTON_PRESS_COOLDOWN_MS = 180L
    private const val PRESS_SOURCE_CONTROLLER_CONTACT = "controller_contact"
    private const val PRESS_SOURCE_HAND_CONTACT = "hand_contact"
    private const val PRESS_SOURCE_TRANSPARENT_PANEL_INTERIM = "transparent_panel_interim"
    private const val PRESS_SOURCE_SCENE_OBJECT_FALLBACK = "scene_object_fallback"
    private const val PRESS_SOURCE_AUTO_VALIDATION = "auto_validation"
    private const val PRESS_SOURCE_CONTROLLER_EMULATED_VALIDATION = "controller_emulated_validation"
    private const val PRESS_SOURCE_UNSPECIFIED = "unspecified"
    private const val BUTTON_PRESS_SFX_ASSET = "sfx/button-press-placeholder-kenney-bong.ogg"
    private const val REDNESS_ORDER_VAS_THEN_LIKERT = "vas_then_likert"
    private const val REDNESS_ORDER_LIKERT_THEN_VAS = "likert_then_vas"
    private const val REDNESS_FAST_REPLAY_REASON = "fast_controller_replay"
    private const val FIRST_REDNESS_CHANGE_AUDIO_DURATION_MS = 22_988L
    private const val FIRST_REDNESS_CHANGE_SWAP_MS = 7_200L
    private const val FIRST_REDNESS_CHANGE_SETTLE_MS = 19_300L
    private const val SECOND_REDNESS_CHANGE_AUDIO_DURATION_MS = 16_771L
    private const val SECOND_REDNESS_CHANGE_SWAP_MS = 7_300L
    private const val SECOND_REDNESS_CHANGE_SETTLE_MS = 14_640L
    private const val ECG_SOURCE_REAL_POLAR = "real_polar_h10"
    private const val ECG_SOURCE_SIMULATED = "simulated_neurokit2"
    private const val ECG_ORDER_REAL_THEN_SIMULATED = "real_then_simulated"
    private const val ECG_ORDER_SIMULATED_THEN_REAL = "simulated_then_real"
    private const val SIMULATED_RR_ASSET = "ecg/neurokit2_simulated_rr_intervals_ms.csv"
    private const val ECG_BLINK_DETECTOR_POLAR_RR = "polar_h10_rr_interval"
    private const val ECG_BLINK_DETECTOR_SIMULATED_RR = "simulated_rr_interval"
    private const val ECG_R_PEAK_THRESHOLD_MICROVOLTS = 800
    private const val ECG_R_PEAK_REFRACTORY_NS = 250_000_000L
    private const val ECG_R_PEAK_DETECTOR_NAME = "native_threshold_uv800"
    private const val HEARTBEAT_PULSE_BASELINE_01 = 0.0f
    private const val HEARTBEAT_PULSE_PEAK_01 = 1.0f
    private const val HEARTBEAT_PULSE_DURATION_MS = 320L
    private const val HEARTBEAT_PULSE_REFRACTORY_MS = 250L
    private const val LSL_INPUT_ENABLED = false
    private const val LSL_DEFAULT_STREAM_NAME = "BigRedButtonExternalSignal"
    private const val LSL_DEFAULT_STREAM_TYPE = "Markers"
    private const val LSL_DEFAULT_CHANNEL_INDEX = 0
    private const val HEARTBEAT_FLASH_FRAMES = 16
    private const val HEARTBEAT_FLASH_FRAME_MS = 20L
    private val AUTO_VALIDATION_PRESS_OFFSETS_MS =
        mapOf(
            1 to listOf(1000L, 4000L, 7000L),
            2 to listOf(1000L, 3500L, 6500L, 9500L),
        )
    val REDNESS_LIKERT_DESCRIPTORS =
        listOf(
            "slightly red",
            "somewhat red",
            "moderately red",
            "quite red",
            "very red",
            "intensely red",
            "extremely red",
        )
  }
}

@Composable
fun ButtonStimulusPanel(activity: BigRedButtonStudyActivity) {
  val pressCount by activity.buttonPressCountState
  val stage by activity.stageState
  val heartbeatFlash by activity.buttonHeartbeatFlashState
  val heartbeatFlashFrame by activity.buttonHeartbeatFlashFrameState
  val interimPressInteractionSource = remember { MutableInteractionSource() }
  val panelModifier =
      if (stage == StudyStage.ConditionRunning) {
        Modifier.fillMaxSize()
            .background(Color.Transparent)
            .clickable(
                interactionSource = interimPressInteractionSource,
                indication = null,
            ) {
              SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
                it.recordInterimPanelPress()
              }
            }
      } else {
        Modifier.fillMaxSize().background(Color.Transparent)
      }
  Box(
      modifier = panelModifier
  ) {
    if (stage == StudyStage.PreButtonExperienceQuestion) {
      PriorBigRedButtonExperiencePrompt(
          activity = activity,
          modifier = Modifier.align(Alignment.TopCenter).padding(top = 6.dp, start = 12.dp, end = 12.dp),
      )
    } else {
      if (MODEL_GLOW_PANEL_FALLBACK_ENABLED) {
        WarmButtonEmissionOverlay(active = heartbeatFlash, frame = heartbeatFlashFrame)
      }
      DigitalPressCounter(pressCount, modifier = Modifier.align(Alignment.TopCenter).padding(top = 10.dp))
    }
  }
}

@Composable
private fun PriorBigRedButtonExperiencePrompt(
    activity: BigRedButtonStudyActivity,
    modifier: Modifier = Modifier,
) {
  val answer by activity.priorBigRedButtonExperienceAnswerState
  val feedback =
      when (answer) {
        "no" -> "No? Well than you are in for a treat!"
        "yes" -> "An experienced user, just the type of participant we need."
        else -> ""
      }
  Column(
      modifier =
          modifier
              .width(480.dp)
              .background(Color.Transparent)
              .padding(horizontal = 8.dp, vertical = 4.dp),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(10.dp),
  ) {
    Text(
        PRIOR_BUTTON_EXPERIENCE_QUESTION,
        color = Color.White,
        fontSize = 20.sp,
        lineHeight = 24.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbSerif,
        textAlign = TextAlign.Center,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = Color.Black.copy(alpha = 0.95f),
                        offset = Offset(0f, 2f),
                        blurRadius = 10f,
                    ),
            ),
    )
    Row(
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth(),
    ) {
      PriorExperienceCheckbox(
          label = "Yes",
          checked = answer == "yes",
          modifier = Modifier.weight(1f),
      ) {
        SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
          it.setPriorBigRedButtonExperienceAnswer("yes", "xr_checkbox")
        }
      }
      PriorExperienceCheckbox(
          label = "No",
          checked = answer == "no",
          modifier = Modifier.weight(1f),
      ) {
        SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
          it.setPriorBigRedButtonExperienceAnswer("no", "xr_checkbox")
        }
      }
    }
    Text(
        text = feedback.ifBlank { " " },
        color = if (feedback.isBlank()) Color.Transparent else CounterDigitRed,
        fontSize = 16.sp,
        lineHeight = 20.sp,
        fontWeight = FontWeight.Bold,
        fontFamily = BrbSans,
        textAlign = TextAlign.Center,
        minLines = 2,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = CounterDigitRed.copy(alpha = if (feedback.isBlank()) 0f else 0.86f),
                        offset = Offset.Zero,
                        blurRadius = 12f,
                    ),
            ),
    )
    PrimaryActionButton(
        text = "Start experiment",
        enabled = answer in setOf("yes", "no"),
        height = 46.dp,
    ) {
      SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
        it.startExperimentFromPriorButtonExperienceQuestion()
      }
    }
  }
}

@Composable
private fun PriorExperienceCheckbox(
    label: String,
    checked: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
  Row(
      modifier =
          modifier
              .clip(RoundedCornerShape(7.dp))
              .background(Color.Transparent)
              .border(1.dp, if (checked) CounterDigitRed else Color.White.copy(alpha = 0.72f), RoundedCornerShape(7.dp))
              .clickable { onClick() }
              .padding(horizontal = 9.dp, vertical = 5.dp),
      horizontalArrangement = Arrangement.Center,
      verticalAlignment = Alignment.CenterVertically,
  ) {
    Checkbox(
        checked = checked,
        onCheckedChange = { onClick() },
        colors =
            CheckboxDefaults.colors(
                checkedColor = CounterDigitRed,
                uncheckedColor = Color.White,
                checkmarkColor = Color.White,
            ),
        modifier = Modifier.size(34.dp),
    )
    Spacer(modifier = Modifier.width(6.dp))
    Text(
        label,
        color = Color.White,
        fontSize = 17.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = Color.Black.copy(alpha = 0.92f),
                        offset = Offset(0f, 2f),
                        blurRadius = 8f,
                    ),
            ),
    )
  }
}

@Composable
private fun WarmButtonEmissionOverlay(active: Boolean, frame: Int) {
  if (!active) {
    return
  }
  Canvas(modifier = Modifier.fillMaxSize()) {
    val pulse = 1f - (frame.toFloat() / 10f).coerceIn(0f, 1f)
    val center = Offset(size.width / 2f, size.height * 0.57f)
    val buttonWidth = size.minDimension * 0.32f
    val capHeight = buttonWidth * 0.58f
    val rimHeight = buttonWidth * 0.30f
    val shellWidth = buttonWidth * (1.05f + pulse * 0.18f)
    val shellHeight = capHeight * (1.08f + pulse * 0.18f)
    val heatCore = Color(0xFFFFF1A6)
    val heatAmber = Color(0xFFFF8A24)
    val heatRed = Color(0xFFFF1C12)

    drawOval(
        brush =
            Brush.radialGradient(
                colors =
                    listOf(
                        heatCore.copy(alpha = 0.34f * pulse),
                        heatAmber.copy(alpha = 0.24f * pulse),
                        heatRed.copy(alpha = 0.04f * pulse),
                        Color.Transparent,
                    ),
                center = center,
                radius = shellWidth * 0.72f,
            ),
        topLeft = Offset(center.x - shellWidth * 0.74f, center.y - shellHeight * 0.70f),
        size = Size(shellWidth * 1.48f, shellHeight * 1.40f),
    )
    drawOval(
        color = heatAmber.copy(alpha = 0.20f + pulse * 0.42f),
        topLeft = Offset(center.x - buttonWidth * 0.50f, center.y - capHeight * 0.54f),
        size = Size(buttonWidth, capHeight),
        style = Stroke(width = 12f + pulse * 10f),
    )
    drawOval(
        color = heatRed.copy(alpha = 0.14f + pulse * 0.30f),
        topLeft = Offset(center.x - buttonWidth * 0.43f, center.y - capHeight * 0.46f),
        size = Size(buttonWidth * 0.86f, capHeight * 0.86f),
        style = Stroke(width = 8f + pulse * 8f),
    )
    drawOval(
        color = heatCore.copy(alpha = pulse * 0.38f),
        topLeft = Offset(center.x - buttonWidth * 0.22f, center.y - capHeight * 0.32f),
        size = Size(buttonWidth * 0.44f, capHeight * 0.36f),
    )
    drawOval(
        color = heatAmber.copy(alpha = pulse * 0.30f),
        topLeft = Offset(center.x - buttonWidth * 0.58f, center.y + capHeight * 0.18f),
        size = Size(buttonWidth * 1.16f, rimHeight),
        style = Stroke(width = 10f + pulse * 9f),
    )
    drawRoundRect(
        brush =
            Brush.radialGradient(
                colors =
                    listOf(
                        heatAmber.copy(alpha = 0.20f * pulse),
                        heatRed.copy(alpha = 0.10f * pulse),
                        Color.Transparent,
                    ),
                center = Offset(center.x, center.y + capHeight * 0.50f),
                radius = buttonWidth * 0.70f,
            ),
        topLeft = Offset(center.x - buttonWidth * 0.68f, center.y + capHeight * 0.18f),
        size = Size(buttonWidth * 1.36f, capHeight * 0.55f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(22f, 22f),
    )
  }
}

@Composable
private fun DigitalPressCounter(count: Int, modifier: Modifier = Modifier) {
  val displayValue = count.coerceIn(0, 999).toString().padStart(3, '0')
  Column(
      modifier =
          modifier
              .background(Color.Transparent)
              .padding(horizontal = 16.dp, vertical = 8.dp),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(2.dp),
  ) {
    Text(
        displayValue,
        color = CounterDigitRed,
        fontSize = 42.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
        textAlign = TextAlign.Center,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = CounterDigitRed.copy(alpha = 0.95f),
                        offset = Offset.Zero,
                        blurRadius = 18f,
                    ),
            ),
    )
    Text(
        "PRESSES",
        color = CounterDigitRed.copy(alpha = 0.82f),
        fontSize = 10.sp,
        fontWeight = FontWeight.Bold,
        fontFamily = BrbMono,
        textAlign = TextAlign.Center,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = CounterDigitRed.copy(alpha = 0.72f),
                        offset = Offset.Zero,
                        blurRadius = 8f,
                    ),
            ),
    )
  }
}

private val BrbPaper = Color(0xFFF5F0E3)
private val BrbPaperLight = Color(0xFFFFFBF4)
private val BrbInk = Color(0xFF1A1E28)
private val BrbMuted = Color(0xFF5F6775)
private val BrbRed = Color(0xFFDF2C2C)
private val BrbRedHot = Color(0xFFFF4444)
private val BrbRedDeep = Color(0xFF8F1717)
private val CounterDigitRed = Color(0xFFFF2424)
private val BrbSteel = Color(0xFF8EA3BF)
private val BrbLine = Color(0xFFC9C1B0)
private val BrbLineSoft = Color(0xFFE0D7C7)
private val BrbSerif = FontFamily.Serif
private val BrbSans = FontFamily.SansSerif
private val BrbMono = FontFamily.Monospace

@Composable
fun StudyPanel(activity: BigRedButtonStudyActivity) {
  val stage by activity.stageState
  val glitchActive by activity.panelGlitchActiveState
  val glitchFrame by activity.panelGlitchFrameState
  val glitchMode by activity.panelGlitchModeState
  val glitchStartElapsedMs by activity.panelGlitchStartElapsedMsState
  val glitchDurationMs by activity.panelGlitchDurationMsState
  val glitchSeed by activity.panelGlitchSeedState
  val glitchProgress = panelGlitchProgress(glitchActive, glitchStartElapsedMs, glitchDurationMs)
  MaterialTheme(
      colors =
          lightColors(
              primary = BrbRed,
              primaryVariant = BrbRedDeep,
              secondary = BrbSteel,
              background = BrbPaper,
              surface = BrbPaperLight,
              onPrimary = Color.White,
              onSecondary = BrbInk,
              onBackground = BrbInk,
              onSurface = BrbInk,
          )
  ) {
    Box(
        modifier =
            Modifier.fillMaxSize()
                .onPreviewKeyEvent { keyEvent ->
                  if (keyEvent.type != KeyEventType.KeyDown) {
                    return@onPreviewKeyEvent false
                  }
                  when (keyEvent.key) {
                    Key.DirectionLeft -> activity.handleControllerDirection("left")
                    Key.DirectionRight -> activity.handleControllerDirection("right")
                    Key.DirectionUp -> activity.handleControllerDirection("up")
                    Key.DirectionDown -> activity.handleControllerDirection("down")
                    Key.Enter,
                    Key.NumPadEnter -> activity.submitCurrentControllerStage()
                    else -> false
                  }
                }
                .graphicsLayer {
                  if (glitchActive) {
                    translationX = panelGlitchShellJitter(frame = glitchFrame, mode = glitchMode, progress = glitchProgress, seed = glitchSeed, axisSalt = 101)
                    translationY = panelGlitchShellJitter(frame = glitchFrame, mode = glitchMode, progress = glitchProgress, seed = glitchSeed, axisSalt = 137) * 0.42f
                    rotationZ = panelGlitchShellRotation(frame = glitchFrame, mode = glitchMode, progress = glitchProgress, seed = glitchSeed)
                    scaleX = 1f + panelGlitchEnvelope(glitchProgress, glitchMode) * 0.006f
                    scaleY = 1f - panelGlitchEnvelope(glitchProgress, glitchMode) * 0.004f
                  }
                }
                .clip(RoundedCornerShape(18.dp))
                .background(BrbPaper.copy(alpha = if (glitchActive) 0.88f else 0.94f))
                .border(1.dp, if (glitchActive) BrbLine.copy(alpha = 0.26f) else BrbLine, RoundedCornerShape(18.dp)),
    ) {
      Box(
          modifier =
              Modifier.fillMaxSize()
                  .padding(18.dp)
                  .graphicsLayer {
                    if (glitchActive) {
                      translationX = panelGlitchContentJitter(frame = glitchFrame, mode = glitchMode, progress = glitchProgress, seed = glitchSeed, axisSalt = 17)
                      translationY = panelGlitchContentJitter(frame = glitchFrame, mode = glitchMode, progress = glitchProgress, seed = glitchSeed, axisSalt = 43) * 0.45f
                      scaleX = 1f + panelGlitchEnvelope(glitchProgress, glitchMode) * 0.004f
                      scaleY = 1f - panelGlitchEnvelope(glitchProgress, glitchMode) * 0.003f
                    }
                  },
      ) {
        when (stage) {
          StudyStage.ConsentDemographics -> ConsentDemographicsScreen(activity)
          StudyStage.PreButtonExperienceQuestion -> WaitingScreen()
          StudyStage.ConditionRunning -> WaitingScreen()
          StudyStage.Pictographic -> PictographicScreen(activity)
          StudyStage.PresenceQuestionnaire -> PresenceQuestionnaireScreen(activity)
          StudyStage.LostOpportunity -> LostOpportunityScreen(activity)
          StudyStage.Complete -> CompleteScreen(activity)
        }
      }
      GlitchPanelFrameOverlay(active = glitchActive, frame = glitchFrame, mode = glitchMode, progress = glitchProgress, seed = glitchSeed)
      BlueFailureGlitchOverlay(
          active = glitchActive,
          frame = glitchFrame,
          mode = glitchMode,
          progress = glitchProgress,
          seed = glitchSeed,
      )
    }
  }
}

@Composable
private fun ConsentDemographicsScreen(activity: BigRedButtonStudyActivity) {
  var name by activity.demographicsDraftNameState
  var age by activity.demographicsDraftAgeState
  var gender by activity.demographicsDraftGenderState
  var handedness by activity.demographicsDraftHandednessState
  var signature by activity.demographicsDraftSignatureState
  var consent by activity.demographicsDraftConsentState
  val nameFocusRequester = remember { FocusRequester() }
  val ageFocusRequester = remember { FocusRequester() }

  LaunchedEffect(Unit) {
    activity.logDemographicsTextFieldContract()
  }
  val canSubmit =
      name.isNotBlank() &&
          age.toIntOrNull() != null &&
          gender.isNotBlank() &&
          handedness.isNotBlank() &&
          signature.isNotBlank() &&
          consent

  Box(modifier = Modifier.fillMaxSize()) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      IntakeWebsiteHeader()
      PolarH10ValidityPanel(activity)
      Box(
          modifier =
              Modifier.fillMaxWidth()
                  .clip(RoundedCornerShape(14.dp))
                  .background(Color.White.copy(alpha = 0.72f))
                  .border(1.dp, BrbLine, RoundedCornerShape(14.dp))
                  .padding(10.dp),
      ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
          Text(
              "Participant details",
              color = BrbInk,
              fontSize = 16.sp,
              fontWeight = FontWeight.ExtraBold,
              fontFamily = BrbSans,
          )
          Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            LabeledTextField(
                activity = activity,
                fieldId = "name",
                label = "Name",
                value = name,
                onValueChange = { name = it.take(80) },
                modifier = Modifier.weight(1f),
                autoFocus = true,
                focusRequester = nameFocusRequester,
                nextFocusRequester = ageFocusRequester,
                nextKeyboardFieldId = "age",
                nextKeyboardMode = "number",
                keyboardMode = "text",
                keyboardOptions =
                    KeyboardOptions(
                        capitalization = KeyboardCapitalization.Words,
                        keyboardType = KeyboardType.Text,
                        imeAction = ImeAction.Next,
                    ),
            )
            LabeledTextField(
                activity = activity,
                fieldId = "age",
                label = "Age",
                value = age,
                onValueChange = { age = normalizeAgeInput(it) },
                modifier = Modifier.weight(0.45f),
                focusRequester = ageFocusRequester,
                keyboardMode = "number",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            )
          }
          Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            GenderChoice(
                selected = gender,
                onSelect = { gender = it },
                onChoiceCue = {
                  SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
                    it.playQuestionnaireChoiceCue()
                  }
                },
                modifier = Modifier.weight(1.25f),
            )
            HandednessChoice(
                selected = handedness,
                onSelect = { handedness = it },
                onChoiceCue = {
                  SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
                    it.playQuestionnaireChoiceCue()
                  }
                },
                modifier = Modifier.weight(1f),
            )
          }
          ConsentSignaturePad(value = signature, onValueChange = { signature = it })
        }
      }
      Box(
          modifier =
              Modifier.fillMaxWidth()
                  .clip(RoundedCornerShape(12.dp))
                  .background(Color(0xFFFFF4F4).copy(alpha = 0.82f))
                  .border(1.dp, BrbLineSoft, RoundedCornerShape(12.dp))
                  .padding(horizontal = 8.dp, vertical = 5.dp),
      ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
          Checkbox(checked = consent, onCheckedChange = { consent = it })
          Text(
              "I consent to participate and understand that study data will be saved locally on the headset.",
              fontSize = 13.sp,
              color = BrbInk,
              fontFamily = BrbSans,
          )
        }
      }
      PrimaryActionButton("Start experiment", canSubmit, height = 48.dp) {
        SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
          it.submitDemographics(name, age, gender, handedness, signature, consent)
        }
      }
    }
  }
}

@Composable
private fun PolarH10ValidityPanel(activity: BigRedButtonStudyActivity) {
  val status by activity.polarStatusState
  val hrReady = status.streaming && status.heartRateBpm > 0 && status.rrIntervalCount > 0
  val ecgReady = status.pmdReady && status.ecgStreaming && status.ecgSampleCount > 0 && status.ecgSampleRateHz == 130
  val ok = hrReady && ecgReady
  val symbol = if (ok) "\u2713" else "!"
  val statusText =
      when {
        ok -> "Polar H10 ECG ready"
        status.ecgStreaming -> "Polar H10 ECG stream waiting for samples"
        status.pmdReady -> "Polar H10 PMD ready; starting ECG"
        status.streaming -> "Polar H10 HR/RR detected; waiting for ECG"
        status.connected -> "Polar H10 connected; waiting for streams"
        status.detected -> "Polar H10 detected; connecting"
        status.missingPermissions.isNotBlank() -> "Polar H10 permissions needed"
        status.error.isNotBlank() -> "Polar H10 not ready"
        else -> "Scanning for Polar H10"
      }
  val detail =
      when {
        ok ->
            "HR ${status.heartRateBpm} bpm | RR ${status.rrIntervalCount} | ECG ${status.ecgSampleCount} samples @ ${status.ecgSampleRateHz} Hz"
        status.ecgStreaming ->
            "ECG ${status.ecgSampleCount} samples @ ${status.ecgSampleRateHz} Hz | RR ${status.rrIntervalCount}"
        status.pmdReady ->
            "PMD ready | requested MTU ${status.requestedMtu} | ECG rate ${status.ecgSampleRateHz} Hz"
        status.streaming ->
            "Heart rate ${status.heartRateBpm} bpm | RR intervals ${status.rrIntervalCount} | raw ECG pending"
        status.deviceName.isNotBlank() -> status.deviceName
        status.missingPermissions.isNotBlank() -> status.missingPermissions.replace("|", ", ")
        status.error.isNotBlank() -> status.error
        else -> "The app will keep listening while the participant begins."
      }
  Row(
      modifier =
          Modifier.fillMaxWidth()
              .clip(RoundedCornerShape(12.dp))
              .background(if (ok) Color(0xFFEAF8EE).copy(alpha = 0.88f) else Color(0xFFFFF8E8).copy(alpha = 0.88f))
              .border(1.dp, if (ok) Color(0xFF2E8B57) else Color(0xFFD1A139), RoundedCornerShape(12.dp))
              .padding(horizontal = 10.dp, vertical = 7.dp),
      verticalAlignment = Alignment.CenterVertically,
      horizontalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    Text(
        symbol,
        color = if (ok) Color(0xFF127A3A) else Color(0xFFA06A00),
        fontSize = 22.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
    )
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
      Text(statusText, color = BrbInk, fontSize = 13.sp, fontWeight = FontWeight.Bold, fontFamily = BrbSans)
      Text(detail, color = BrbMuted, fontSize = 10.sp, fontFamily = BrbMono)
    }
  }
}

@Composable
private fun ConsentSignaturePad(value: String, onValueChange: (String) -> Unit) {
  val committedStrokes = remember { mutableStateListOf<List<SignatureSample>>() }
  val activeStroke = remember { mutableStateListOf<SignatureSample>() }
  var canvasSize by remember { mutableStateOf(IntSize.Zero) }

  fun updateSignatureValue() {
    onValueChange(encodeSignatureStrokes(committedStrokes.toList(), activeStroke.toList(), canvasSize))
  }

  fun commitActiveStroke() {
    if (activeStroke.isNotEmpty()) {
      committedStrokes.add(activeStroke.toList())
      activeStroke.clear()
      updateSignatureValue()
    }
  }

  fun clearSignature() {
    committedStrokes.clear()
    activeStroke.clear()
    onValueChange("")
  }

  val hasSignature = value.isNotBlank() || committedStrokes.isNotEmpty() || activeStroke.isNotEmpty()

  Column(verticalArrangement = Arrangement.spacedBy(5.dp), modifier = Modifier.fillMaxWidth()) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
      Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.weight(1f)) {
        Text(
            "Consent signature",
            color = BrbMuted,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = BrbSans,
        )
        Text(
            "Hold the trigger and draw your signature in the space below.",
            color = BrbMuted,
            fontSize = 10.sp,
            fontFamily = BrbSans,
        )
      }
      OutlinedButton(
          onClick = {
            SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
              it.playQuestionnaireNavigationCue()
            }
            clearSignature()
          },
          enabled = hasSignature,
          modifier = Modifier.height(34.dp),
          colors =
              ButtonDefaults.outlinedButtonColors(
                  backgroundColor = BrbPaperLight,
                  contentColor = BrbRedDeep,
              ),
      ) {
        Text("Clear", fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = BrbSans)
      }
    }
    Box(
        modifier =
            Modifier.fillMaxWidth()
                .height(142.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(BrbPaperLight.copy(alpha = 0.96f))
                .border(2.dp, if (hasSignature) BrbRed else BrbLine, RoundedCornerShape(10.dp)),
    ) {
      Canvas(
          modifier =
              Modifier.fillMaxSize()
                  .onSizeChanged { newSize ->
                    canvasSize = newSize
                    if (hasSignature) {
                      updateSignatureValue()
                    }
                  }
                  .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { offset ->
                          activeStroke.clear()
                          activeStroke.add(signatureSample(offset, canvasSize))
                          updateSignatureValue()
                        },
                        onDragEnd = { commitActiveStroke() },
                        onDragCancel = {
                          activeStroke.clear()
                          updateSignatureValue()
                        },
                    ) { change, _ ->
                      activeStroke.add(signatureSample(change.position, canvasSize))
                      change.consume()
                      updateSignatureValue()
                    }
                  }
      ) {
        val guideColor = BrbLine.copy(alpha = 0.70f)
        for (i in 1..3) {
          val y = size.height * i / 4f
          drawLine(guideColor, Offset(18f, y), Offset(size.width - 18f, y), strokeWidth = 1.2f)
        }
        drawLine(
            BrbRedDeep.copy(alpha = 0.34f),
            Offset(28f, size.height - 34f),
            Offset(size.width - 28f, size.height - 34f),
            strokeWidth = 2.4f,
        )

        fun drawStroke(samples: List<SignatureSample>, color: Color) {
          if (samples.size == 1) {
            drawCircle(color = color, radius = 3.8f, center = Offset(samples.first().xPx, samples.first().yPx))
            return
          }
          for (i in 1 until samples.size) {
            drawLine(
                color = color,
                start = Offset(samples[i - 1].xPx, samples[i - 1].yPx),
                end = Offset(samples[i].xPx, samples[i].yPx),
                strokeWidth = 5.2f,
                cap = StrokeCap.Round,
            )
          }
        }

        committedStrokes.forEach { stroke -> drawStroke(stroke, BrbInk.copy(alpha = 0.92f)) }
        if (activeStroke.isNotEmpty()) {
          drawStroke(activeStroke.toList(), BrbRedDeep.copy(alpha = 0.95f))
        }
      }
      if (!hasSignature) {
        Text(
            "Sign here",
            modifier = Modifier.align(Alignment.Center),
            color = BrbMuted.copy(alpha = 0.55f),
            fontSize = 22.sp,
            fontWeight = FontWeight.Black,
            fontFamily = BrbSerif,
        )
      }
    }
  }
}

@Composable
private fun IntakeWebsiteHeader() {
  Box(
      modifier =
          Modifier.fillMaxWidth()
              .clip(RoundedCornerShape(16.dp))
              .background(
                  Brush.linearGradient(
                      colors =
                          listOf(
                              BrbPaperLight.copy(alpha = 0.96f),
                              Color(0xFFFFF7F7).copy(alpha = 0.93f),
                              Color(0xFFEFF3F8).copy(alpha = 0.88f),
                          )
                  )
              )
              .border(1.dp, BrbLine, RoundedCornerShape(16.dp))
              .padding(10.dp),
  ) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
      BrandKicker("Big Red Button Institute | Intake")
      Text(
          "Participant Details And Consent",
          color = BrbInk,
          fontSize = 23.sp,
          fontWeight = FontWeight.Black,
          fontFamily = BrbSerif,
          lineHeight = 25.sp,
      )
      Text(
          "Enter the participant details below. Responses and button presses are saved locally on this headset.",
          color = BrbMuted,
          fontSize = 13.sp,
          fontFamily = BrbSans,
      )
      Box(
          modifier =
              Modifier.fillMaxWidth()
                  .height(3.dp)
                  .clip(RoundedCornerShape(999.dp))
                  .background(
                      Brush.linearGradient(
                          listOf(BrbRedDeep, BrbRed, BrbRedHot, Color(0x00FF4444))
                      )
                  )
      )
    }
  }
}

@Composable
private fun PictographicScreen(activity: BigRedButtonStudyActivity) {
  val condition by activity.activeConditionState
  val closeness by activity.pictographicClosenessState
  val presence by activity.pictographicPresenceState
  val rednessVas by activity.pictographicRednessVasState
  val rednessLikert by activity.pictographicRednessLikertState
  val rednessConverted by activity.pictographicRednessConvertedState
  val rednessChoreography by activity.rednessConversionChoreographyState

  Column(
      modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
      verticalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    BrandKicker("Post-condition $condition | Response task")
    PanelTitle("Button Experience")
    Text(
        "Think about condition $condition. By the end of the experience, how close did the Big Red Button feel, how present did it feel, and how red did it feel?",
        color = BrbMuted,
        fontSize = 17.sp,
        fontFamily = BrbSans,
    )
    PictographicCanvas(closeness = closeness, presence = presence)
    val pictographicScaleModifier = Modifier.width(640.dp).align(Alignment.CenterHorizontally)
    ScaleSlider(
        label = "How close did the button feel?",
        value = 100f - closeness,
        left = "very close",
        right = "very distant",
        onChange = { activity.pictographicClosenessState.floatValue = 100f - it },
        modifier = pictographicScaleModifier,
    )
    ScaleSlider(
        label = "How present did the button feel?",
        value = presence,
        left = "small presence",
        right = "large presence",
        onChange = { activity.pictographicPresenceState.floatValue = it },
        modifier = pictographicScaleModifier,
    )
    RednessResponseControl(
        condition = condition,
        vasValue = rednessVas,
        likertValue = rednessLikert,
        converted = rednessConverted,
        choreography = rednessChoreography,
        modifier = pictographicScaleModifier,
        onVasChange = { activity.pictographicRednessVasState.floatValue = it },
        onVasFinished = {
          SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
            if (condition == 1) {
              it.convertRednessVasToLikert("participant_vas_release")
            } else {
              it.playQuestionnaireNavigationCue()
            }
          }
        },
        onLikertSelect = { value ->
          SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
            it.setRednessLikert(value, convertIfNeeded = condition == 2)
          }
        },
    )
    PrimaryActionButton("Save response", rednessChoreography == null) {
      SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> { it.submitPictographic() }
    }
  }
}

@Composable
private fun RednessResponseControl(
    condition: Int,
    vasValue: Float,
    likertValue: Int,
    converted: Boolean,
    choreography: RednessConversionChoreography?,
    modifier: Modifier,
    onVasChange: (Float) -> Unit,
    onVasFinished: () -> Unit,
    onLikertSelect: (Int) -> Unit,
) {
  var elapsedMs by remember(choreography?.startedElapsedMs) { mutableStateOf(0L) }
  LaunchedEffect(choreography?.startedElapsedMs) {
    val activeChoreography = choreography
    if (activeChoreography == null) {
      elapsedMs = 0L
      return@LaunchedEffect
    }
    while (elapsedMs < activeChoreography.durationMs) {
      elapsedMs =
          (SystemClock.elapsedRealtime() - activeChoreography.startedElapsedMs)
              .coerceIn(0L, activeChoreography.durationMs)
      delay(70L)
    }
  }
  val showVas =
      choreography?.let { active ->
        val afterSwap = elapsedMs >= active.swapAtMs
        val visibleScale = if (afterSwap) active.targetScale else active.sourceScale
        visibleScale == "vas"
      } ?: ((condition == 1 && !converted) || (condition == 2 && converted))
  val jitterSeed = choreography?.startedElapsedMs?.toInt() ?: 0
  val jitter =
      if (choreography == null) {
        0f
      } else {
        glitchSignedUnit(jitterSeed, (elapsedMs / 70L).toInt(), 1201) * 4.5f
      }
  val contentAlpha =
      if (choreography == null) {
        1f
      } else if (elapsedMs < choreography.swapAtMs) {
        0.74f
      } else {
        0.90f
      }
  Box(modifier = modifier) {
    Box(
        modifier =
            Modifier.fillMaxWidth().graphicsLayer {
              alpha = contentAlpha
              translationX = jitter
              translationY = -jitter * 0.35f
              scaleX = if (choreography == null) 1f else 1f + glitchSignedUnit(jitterSeed, (elapsedMs / 140L).toInt(), 1217) * 0.008f
            }
    ) {
      if (showVas) {
        ScaleSlider(
            label = "How red did the button feel?",
            value = vasValue,
            left = "slightly red",
            right = "very red",
            onChange = onVasChange,
            onFinished = onVasFinished,
            modifier = Modifier.fillMaxWidth(),
        )
      } else {
        RednessLikertScale(value = likertValue, onSelect = onLikertSelect, modifier = Modifier.fillMaxWidth())
      }
    }
    if (choreography != null) {
      RednessConversionChoreographyOverlay(choreography = choreography, elapsedMs = elapsedMs)
    }
  }
}

@Composable
private fun RednessConversionChoreographyOverlay(
    choreography: RednessConversionChoreography,
    elapsedMs: Long,
) {
  val frame = (elapsedMs / 70L).toInt()
  val progress = (elapsedMs.toFloat() / choreography.durationMs.toFloat()).coerceIn(0f, 1f)
  val nearSwap = kotlin.math.abs(elapsedMs - choreography.swapAtMs) < 850L
  val activeEvent =
      choreography.microEvents.firstOrNull { elapsedMs >= it.startMs && elapsedMs < it.endMs }
          ?: choreography.microEvents.lastOrNull { elapsedMs >= it.endMs }
  val eventProgress =
      activeEvent
          ?.let { event ->
            val duration = (event.endMs - event.startMs).coerceAtLeast(1L)
            ((elapsedMs - event.startMs).toFloat() / duration.toFloat()).coerceIn(0f, 1f)
          }
          ?: progress
  val microIntensity = activeEvent?.intensity ?: if (nearSwap) 1f else 0.45f
  val phaseText =
      activeEvent?.participantCaption
          ?: when {
            elapsedMs < choreography.swapAtMs -> "One moment..."
            elapsedMs < choreography.settleAtMs -> "Updating item..."
            else -> "You can adjust the new response."
          }
  Box(
      modifier =
          Modifier.fillMaxSize()
              .clip(RoundedCornerShape(10.dp))
              .clickable(
                  interactionSource = remember { MutableInteractionSource() },
                  indication = null,
              ) {}
  ) {
    Canvas(modifier = Modifier.fillMaxSize()) {
      val baseAlpha = (0.18f + microIntensity * 0.13f + if (nearSwap) 0.10f else 0f).coerceAtMost(0.48f)
      drawRect(Color(0xFF001B6D).copy(alpha = baseAlpha + progress * 0.08f))
      val stripeCount = (9f + microIntensity * 13f + if (nearSwap) 5f else 0f).roundToInt()
      for (index in 0 until stripeCount) {
        val y = (glitchHash(choreography.startedElapsedMs.toInt(), frame + index, 1231) % size.height.toInt().coerceAtLeast(1)).toFloat()
        val height = 3f + (glitchHash(choreography.startedElapsedMs.toInt(), frame, 1249 + index) % (10 + (microIntensity * 14f).roundToInt()))
        val xShift = glitchSignedUnit(choreography.startedElapsedMs.toInt(), frame, 1277 + index) * size.width * (0.06f + microIntensity * 0.08f)
        val alpha = (0.10f + microIntensity * 0.18f + if (nearSwap) 0.08f else 0f).coerceAtMost(0.36f)
        drawRect(
            color = if (index % 3 == 0) Color.White.copy(alpha = alpha) else Color(0xFF00E8FF).copy(alpha = alpha),
            topLeft = Offset(xShift, y),
            size = Size(size.width * (0.64f + glitchUnit(choreography.startedElapsedMs.toInt(), frame, 1291 + index) * 0.45f), height),
        )
      }
      val targetProgress =
          if (elapsedMs >= choreography.swapAtMs) {
            ((elapsedMs - choreography.swapAtMs).toFloat() / (choreography.durationMs - choreography.swapAtMs).toFloat()).coerceIn(0f, 1f)
          } else {
            0f
          }
      val boxCount = if (choreography.targetScale == "likert") 7 else 1
      if (targetProgress > 0f) {
        repeat(boxCount) { index ->
          val width = if (boxCount == 1) size.width * 0.78f else size.width * 0.105f
          val gap = size.width * 0.013f
          val x = if (boxCount == 1) size.width * 0.11f else size.width * 0.08f + index * (width + gap)
          val y = size.height * 0.48f + glitchSignedUnit(choreography.startedElapsedMs.toInt(), frame, 1301 + index) * 3f
          drawRect(
              color = Color(0xFFFFF7F7).copy(alpha = 0.18f + targetProgress * 0.34f),
              topLeft = Offset(x, y),
              size = Size(width, 8f + targetProgress * 11f),
          )
        }
      }
      drawRect(
          color = Color(0xFFFF2D7F).copy(alpha = if (nearSwap) 0.15f else 0.05f),
          topLeft = Offset(0f, size.height * (0.14f + 0.16f * progress)),
          size = Size(size.width, 2.5f + 5f * if (nearSwap) 1f else 0.2f),
      )
      drawRednessMicroEventVisual(
          event = activeEvent,
          eventProgress = eventProgress,
          choreography = choreography,
          elapsedMs = elapsedMs,
          frame = frame,
          seed = choreography.startedElapsedMs.toInt(),
      )
    }
    Text(
        phaseText,
        color = Color.White,
        fontSize = 13.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
        modifier =
            Modifier.align(Alignment.BottomEnd)
                .padding(8.dp)
                .background(Color(0xFF001046).copy(alpha = 0.74f), RoundedCornerShape(6.dp))
                .border(1.dp, Color(0xFF9EEBFF).copy(alpha = 0.58f), RoundedCornerShape(6.dp))
                .padding(horizontal = 8.dp, vertical = 4.dp),
    )
  }
}

private fun DrawScope.drawRednessMicroEventVisual(
    event: RednessConversionMicroEvent?,
    eventProgress: Float,
    choreography: RednessConversionChoreography,
    elapsedMs: Long,
    frame: Int,
    seed: Int,
) {
  if (event == null) {
    return
  }
  val intensity = event.intensity.coerceIn(0f, 1f)
  val rowTop = size.height * 0.18f
  val rowMid = size.height * 0.52f
  val rowBottom = size.height * 0.78f
  val left = size.width * 0.06f
  val right = size.width * 0.94f
  val cyan = Color(0xFF67F3FF).copy(alpha = 0.24f + intensity * 0.34f)
  val white = Color.White.copy(alpha = 0.22f + intensity * 0.38f)
  val magenta = Color(0xFFFF2D7F).copy(alpha = 0.18f + intensity * 0.24f)
  val jitter = glitchSignedUnit(seed, frame, 7001) * size.width * 0.018f * intensity
  when (event.code) {
    "nervous_entry",
    "nervous_return" -> {
      repeat(5) { index ->
        val inset = 6f + index * 6f
        val alpha = (0.18f + eventProgress * 0.28f - index * 0.025f).coerceIn(0.04f, 0.42f)
        drawRect(
            color = Color(0xFF8BEFFF).copy(alpha = alpha),
            topLeft = Offset(inset + jitter, inset),
            size = Size(size.width - inset * 2f, size.height - inset * 2f),
            style = Stroke(width = 1.5f + intensity * 2f),
        )
      }
    }
    "supervisor_ping" -> {
      repeat(4) { index ->
        val reveal = eventProgress >= index * 0.18f
        if (reveal) {
          val x = left + index * 34f + jitter
          val y = rowTop + index * 8f
          drawRect(Color.White.copy(alpha = 0.22f + intensity * 0.18f), Offset(x, y), Size(26f, 20f))
          drawRect(cyan, Offset(x + 5f, y + 6f), Size(16f, 2.5f))
          drawRect(cyan.copy(alpha = 0.34f), Offset(x + 5f, y + 12f), Size(11f, 2f))
        }
      }
      drawLine(cyan, Offset(left, rowTop + 58f), Offset(left + size.width * 0.32f * eventProgress, rowTop + 58f), strokeWidth = 3f)
    }
    "item_targeted" -> {
      val bracketInset = 22f * (1f - eventProgress)
      val top = rowMid - 64f + bracketInset
      val bottom = rowMid + 72f - bracketInset
      val bracket = 46f
      drawLine(white, Offset(left + jitter, top), Offset(left + bracket + jitter, top), strokeWidth = 5f)
      drawLine(white, Offset(left + jitter, top), Offset(left + jitter, bottom), strokeWidth = 5f)
      drawLine(white, Offset(right + jitter, top), Offset(right - bracket + jitter, top), strokeWidth = 5f)
      drawLine(white, Offset(right + jitter, top), Offset(right + jitter, bottom), strokeWidth = 5f)
      drawRect(magenta, Offset(left + 28f, rowMid + 18f), Size((right - left - 56f) * eventProgress, 5f))
    }
    "swap_requested",
    "restore_requested" -> {
      val tearX = size.width * (0.50f + glitchSignedUnit(seed, frame, 7011) * 0.03f)
      drawRect(Color.White.copy(alpha = 0.58f), Offset(tearX - 5f, 0f), Size(10f, size.height))
      drawRect(cyan.copy(alpha = 0.54f), Offset(tearX + 8f + jitter, 0f), Size(6f + 12f * eventProgress, size.height))
      drawLine(magenta, Offset(left, rowMid), Offset(right, rowMid + 30f * (1f - eventProgress)), strokeWidth = 7f + intensity * 5f)
    }
    "seven_boxes_assemble" -> {
      val boxGap = size.width * 0.018f
      val boxW = (right - left - boxGap * 6f) / 7f
      repeat(7) { index ->
        val reveal = ((eventProgress * 7.6f) - index).coerceIn(0f, 1f)
        if (reveal > 0f) {
          val x = left + index * (boxW + boxGap) + jitter * 0.45f
          val y = rowMid - 22f + glitchSignedUnit(seed, frame, 7021 + index) * 5f * intensity
          drawRect(Color.White.copy(alpha = 0.16f + reveal * 0.36f), Offset(x, y), Size(boxW, 50f * reveal))
          drawRect(cyan.copy(alpha = 0.22f + reveal * 0.32f), Offset(x, y), Size(boxW, 50f * reveal), style = Stroke(width = 2.5f))
        }
      }
    }
    "awkward_pause" -> {
      val lineAlpha = 0.06f + intensity * 0.18f
      repeat(4) { index ->
        val y = rowTop + 38f + index * 48f + glitchSignedUnit(seed, frame, 7031 + index) * 2f
        drawLine(Color(0xFFB6F8FF).copy(alpha = lineAlpha), Offset(left, y), Offset(right, y), strokeWidth = 2f)
      }
    }
    "answer_already_given",
    "data_importance" -> {
      val markerX = left + (right - left) * 0.62f
      drawCircle(Color.White.copy(alpha = 0.18f + intensity * 0.26f), radius = 22f + eventProgress * 11f, center = Offset(markerX + jitter, rowMid), style = Stroke(width = 4f))
      drawCircle(magenta.copy(alpha = 0.28f + eventProgress * 0.26f), radius = 8f + eventProgress * 5f, center = Offset(markerX + jitter, rowMid))
      repeat(5) { index ->
        val y = rowBottom - 34f + index * 9f
        drawRect(cyan.copy(alpha = 0.16f + eventProgress * 0.18f), Offset(right - 156f, y), Size(112f - index * 10f, 3f))
      }
    }
    "change_anyway",
    "pretend_never_happened" -> {
      val wipe = left + (right - left) * eventProgress
      drawRect(Color.White.copy(alpha = 0.30f), Offset(left, rowMid - 5f), Size((wipe - left).coerceAtLeast(1f), 10f))
      drawLine(magenta, Offset(wipe + jitter, rowTop), Offset(wipe - jitter, rowBottom), strokeWidth = 5f)
      drawCircle(cyan, radius = 10f + intensity * 8f, center = Offset(wipe.coerceIn(left, right), rowMid))
    }
    "professional_warning" -> {
      repeat(3) { index ->
        val y = rowTop + 52f + index * 38f
        drawLine(magenta, Offset(left + jitter, y), Offset(right - jitter, y + 24f), strokeWidth = 5f + index)
        drawLine(white.copy(alpha = 0.18f), Offset(right - jitter, y), Offset(left + jitter, y + 20f), strokeWidth = 3f)
      }
    }
    "mid_experiment_freeze" -> {
      val boxGap = size.width * 0.018f
      val boxW = (right - left - boxGap * 6f) / 7f
      repeat(7) { index ->
        val x = left + index * (boxW + boxGap)
        drawRect(Color(0xFFB6F8FF).copy(alpha = 0.13f), Offset(x, rowMid - 22f), Size(boxW, 52f))
        drawRect(white.copy(alpha = 0.34f), Offset(x, rowMid - 22f), Size(boxW, 52f), style = Stroke(width = 2f))
      }
      drawRect(Color.White.copy(alpha = 0.18f + intensity * 0.16f), Offset(left, rowMid + 50f), Size(right - left, 6f))
    }
    "boxes_erased" -> {
      val boxGap = size.width * 0.018f
      val boxW = (right - left - boxGap * 6f) / 7f
      repeat(7) { index ->
        val x = left + index * (boxW + boxGap)
        val alpha = (0.40f - eventProgress * 0.30f).coerceAtLeast(0.06f)
        drawRect(Color.White.copy(alpha = alpha), Offset(x, rowMid - 22f), Size(boxW, 52f), style = Stroke(width = 2.5f))
        val eraserX = left + (right - left) * eventProgress
        if (x < eraserX + boxW) {
          drawLine(magenta, Offset(x, rowMid + 30f), Offset(x + boxW, rowMid - 28f), strokeWidth = 4f)
        }
      }
    }
    "result_settle",
    "wrong_way_settle" -> {
      val settle = kotlin.math.sin(eventProgress * PI.toFloat() * 3f) * (1f - eventProgress)
      val y = rowMid + settle * 30f
      drawLine(cyan.copy(alpha = 0.36f), Offset(left, y), Offset(right, y), strokeWidth = 5f)
      repeat(6) { index ->
        val x = left + (right - left) * (index / 5f)
        drawCircle(white.copy(alpha = 0.18f + (1f - eventProgress) * 0.20f), radius = 4f + intensity * 5f, center = Offset(x, y + glitchSignedUnit(seed, frame, 7041 + index) * 4f))
      }
    }
  }
  val railTop = size.height - 14f
  drawRect(Color.White.copy(alpha = 0.16f), Offset(left, railTop), Size(right - left, 2f))
  val startX = left + (right - left) * (event.startMs.toFloat() / choreography.durationMs.toFloat()).coerceIn(0f, 1f)
  val endX = left + (right - left) * (event.endMs.toFloat() / choreography.durationMs.toFloat()).coerceIn(0f, 1f)
  val nowX = left + (right - left) * (elapsedMs.toFloat() / choreography.durationMs.toFloat()).coerceIn(0f, 1f)
  drawRect(cyan.copy(alpha = 0.48f), Offset(startX, railTop - 2f), Size((endX - startX).coerceAtLeast(2f), 6f))
  drawLine(Color.White.copy(alpha = 0.70f), Offset(nowX, railTop - 8f), Offset(nowX, railTop + 8f), strokeWidth = 2.5f)
}

@Composable
private fun RednessLikertScale(value: Int, onSelect: (Int) -> Unit, modifier: Modifier) {
  Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(
          "How red did the button feel?",
          fontWeight = FontWeight.Bold,
          color = BrbInk,
          fontSize = 17.sp,
          fontFamily = BrbSans,
      )
      Text(
          value.coerceIn(1, 7).toString(),
          fontWeight = FontWeight.Black,
          color = BrbRedDeep,
          fontSize = 18.sp,
          fontFamily = BrbMono,
      )
    }
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
      BigRedButtonStudyActivity.REDNESS_LIKERT_DESCRIPTORS.forEachIndexed { index, descriptor ->
        val itemValue = index + 1
        Box(
            modifier =
                Modifier.weight(1f)
                    .height(54.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (itemValue == value) Color(0xFFFFE2E2) else Color.White.copy(alpha = 0.82f))
                    .border(1.dp, if (itemValue == value) BrbRedDeep else BrbLineSoft, RoundedCornerShape(8.dp))
                    .clickable { onSelect(itemValue) }
                    .padding(horizontal = 3.dp, vertical = 4.dp),
            contentAlignment = Alignment.Center,
        ) {
          Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text(
                itemValue.toString(),
                color = if (itemValue == value) BrbRedDeep else BrbMuted,
                fontSize = 11.sp,
                fontWeight = FontWeight.Black,
                fontFamily = BrbMono,
            )
            Text(
                descriptor,
                color = if (itemValue == value) BrbRedDeep else BrbInk,
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = BrbSans,
                textAlign = TextAlign.Center,
                lineHeight = 10.sp,
            )
          }
        }
      }
    }
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text("slightly red", color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
      Text("extremely red", color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
    }
  }
}

@Composable
private fun PresenceQuestionnaireScreen(activity: BigRedButtonStudyActivity) {
  val condition by activity.activeConditionState
  val answered = activity.ipqAnswersState.size
  val canSubmit = answered == IPQ_ITEMS.size

  Column(
      modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
      verticalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    BrandKicker("Post-condition $condition | Ratings")
    PanelTitle("Session Experience Ratings")
    Text(
        "Please answer each statement based on condition $condition. Select one number per row, where 0 means not at all and 6 means very much.",
        color = BrbMuted,
        fontSize = 17.sp,
        fontFamily = BrbSans,
    )
    Divider(color = BrbLine)
    IPQ_ITEMS.forEachIndexed { index, item ->
      PresenceItemRow(
          index = index + 1,
          item = item,
          selected = activity.ipqAnswersState[item.id],
          onSelect = { value ->
            SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
              it.playQuestionnaireChoiceCue()
              it.setIpqAnswer(item.id, value)
            }
          },
      )
      Divider(color = BrbLineSoft)
    }
    Text(
        "$answered of ${IPQ_ITEMS.size} items answered",
        color = BrbMuted,
        fontFamily = BrbMono,
        fontSize = 14.sp,
    )
    PrimaryActionButton("Save ratings", canSubmit) {
      SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
        it.submitPresenceQuestionnaire()
      }
    }
  }
}

@Composable
private fun LostOpportunityScreen(activity: BigRedButtonStudyActivity) {
  val score by activity.lostOpportunityState
  val condition by activity.activeConditionState
  Column(
      modifier = Modifier.fillMaxSize(),
      verticalArrangement = Arrangement.spacedBy(18.dp),
  ) {
    BrandKicker("Post-condition $condition | Rating")
    PanelTitle("Additional Time Rating")
    Text(
        "Had you been given twice as much time with the button, how likely is it that you would have pressed the button twice as often?",
        color = BrbInk,
        fontSize = 23.sp,
        fontFamily = BrbSans,
    )
    ScaleSlider(
        label = "Condition $condition rating",
        value = score,
        left = "0 - not at all likely",
        right = "100 - extremely likely",
        onChange = { activity.lostOpportunityState.floatValue = it },
    )
    Text(
        score.toInt().toString(),
        color = BrbRedDeep,
        fontSize = 48.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
    )
    PrimaryActionButton("Save rating", true) {
      SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> { it.submitLostOpportunity() }
    }
  }
}

@Composable
private fun CompleteScreen(activity: BigRedButtonStudyActivity) {
  val exportStatus by activity.exportStatusState
  Column(
      modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
      verticalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    BrandKicker("Local export")
    PanelTitle("Experiment Complete")
    Text(
        "The local JSON and CSV exports have been written on this headset.",
        fontSize = 20.sp,
        color = BrbInk,
        fontFamily = BrbSans,
    )
    Text(exportStatus, color = BrbMuted, fontSize = 14.sp, fontFamily = BrbMono)
  }
}

@Composable
private fun WaitingScreen() {
  Column(
      modifier = Modifier.fillMaxSize(),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.Center,
  ) {
    BrandKicker("Audio condition")
    Text(
        "Condition running",
        fontSize = 32.sp,
        fontWeight = FontWeight.Bold,
        fontFamily = BrbSerif,
        color = BrbInk,
    )
  }
}

@Composable
private fun PictographicCanvas(closeness: Float, presence: Float) {
  val buttonModelThumbnail = ImageBitmap.imageResource(id = R.drawable.big_red_button_model_thumbnail)
  Canvas(
      modifier =
          Modifier.fillMaxWidth()
              .height(250.dp)
              .clip(RoundedCornerShape(8.dp))
              .background(BrbPaperLight)
              .border(1.dp, BrbLine, RoundedCornerShape(8.dp))
              .padding(8.dp),
  ) {
    val y = size.height * 0.52f
    val selfX = size.width * 0.18f
    val buttonX = selfX + selfButtonDistanceUnits(closeness)
    val radius = buttonPresenceRadiusUnits(presence)
    drawLine(
        color = BrbLine.copy(alpha = 0.95f),
        start = Offset(selfX, y),
        end = Offset(selfX + selfButtonDistanceUnits(0f), y),
        strokeWidth = 4f,
    )
    drawCircle(BrbSteel.copy(alpha = 0.34f), radius = 58f, center = Offset(selfX, y), style = Stroke(width = 9f))
    drawCircle(BrbInk, radius = 13f, center = Offset(selfX, y - 42f), style = Stroke(width = 5f))
    drawLine(BrbInk, Offset(selfX, y - 28f), Offset(selfX, y + 22f), strokeWidth = 5f)
    drawLine(BrbInk, Offset(selfX - 30f, y - 2f), Offset(selfX + 30f, y - 2f), strokeWidth = 5f)
    drawLine(BrbInk, Offset(selfX, y + 22f), Offset(selfX - 22f, y + 64f), strokeWidth = 5f)
    drawLine(BrbInk, Offset(selfX, y + 22f), Offset(selfX + 22f, y + 64f), strokeWidth = 5f)
    drawCircle(BrbRed.copy(alpha = 0.40f), radius = radius, center = Offset(buttonX, y), style = Stroke(width = 9f))
    val buttonImageSize = 100f
    drawImage(
        image = buttonModelThumbnail,
        dstOffset =
            IntOffset(
                (buttonX - buttonImageSize / 2f).roundToInt(),
                (y - buttonImageSize / 2f).roundToInt(),
            ),
        dstSize = IntSize(buttonImageSize.roundToInt(), buttonImageSize.roundToInt()),
    )
  }
}

@Composable
private fun PresenceItemRow(index: Int, item: PresenceItem, selected: Int?, onSelect: (Int) -> Unit) {
  Column(verticalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxWidth()) {
    Text(
        "$index. ${item.text}",
        color = BrbInk,
        fontSize = 16.sp,
        fontWeight = FontWeight.SemiBold,
        fontFamily = BrbSans,
    )
    Row(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalAlignment = Alignment.CenterVertically) {
      Text("0", color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
      (0..6).forEach { value ->
        OutlinedButton(
            onClick = { onSelect(value) },
            colors =
                ButtonDefaults.outlinedButtonColors(
                    backgroundColor = if (selected == value) BrbRed else BrbPaperLight,
                    contentColor = if (selected == value) Color.White else BrbInk,
                ),
            modifier =
                Modifier.size(width = 48.dp, height = 38.dp)
                    .border(1.dp, if (selected == value) BrbRedDeep else BrbLine, RoundedCornerShape(5.dp)),
        ) {
          Text(value.toString(), fontSize = 14.sp, textAlign = TextAlign.Center, fontFamily = BrbMono)
        }
      }
      Text("6", color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
    }
  }
}

@Composable
private fun GenderChoice(
    selected: String,
    onSelect: (String) -> Unit,
    onChoiceCue: () -> Unit,
    modifier: Modifier = Modifier,
) {
  val options =
      listOf(
          "male" to "Male",
          "female" to "Female",
          "other" to "Other",
          "prefer_not_to_say" to "Prefer not to say",
      )
  ChoiceButtonGroup(
      title = "Gender",
      options = options,
      selected = selected,
      onSelect = onSelect,
      onChoiceCue = onChoiceCue,
      modifier = modifier,
  )
}

@Composable
private fun HandednessChoice(
    selected: String,
    onSelect: (String) -> Unit,
    onChoiceCue: () -> Unit,
    modifier: Modifier = Modifier,
) {
  val options = listOf("left" to "Left", "right" to "Right", "ambidextrous" to "Ambidextrous")
  ChoiceButtonGroup(
      title = "Handedness",
      options = options,
      selected = selected,
      onSelect = onSelect,
      onChoiceCue = onChoiceCue,
      modifier = modifier,
  )
}

@Composable
private fun ChoiceButtonGroup(
    title: String,
    options: List<Pair<String, String>>,
    selected: String,
    onSelect: (String) -> Unit,
    onChoiceCue: () -> Unit,
    modifier: Modifier = Modifier,
) {
  Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
    Text(title, color = BrbMuted, fontSize = 11.sp, fontFamily = BrbMono)
    Row(horizontalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxWidth()) {
      options.forEach { (value, label) ->
        OutlinedButton(
            onClick = {
              onChoiceCue()
              onSelect(value)
            },
            colors =
                ButtonDefaults.outlinedButtonColors(
                    backgroundColor = if (selected == value) BrbRed else BrbPaperLight,
                    contentColor = if (selected == value) Color.White else BrbInk,
                ),
            modifier =
                Modifier.weight(
                        if (value == "ambidextrous" || value == "prefer_not_to_say") 1.65f else 1f
                    )
                    .height(44.dp)
                    .border(1.dp, if (selected == value) BrbRedDeep else BrbLine, RoundedCornerShape(7.dp)),
        ) {
          Text(label, fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = BrbSans, textAlign = TextAlign.Center)
        }
      }
    }
  }
}

@Composable
private fun GlitchPanelFrameOverlay(active: Boolean, frame: Int, mode: String, progress: Float, seed: Int) {
  if (!active) {
    return
  }
  Canvas(modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(18.dp))) {
    val intensity = panelGlitchEnvelope(progress, mode)
    drawInterruptedPanelContour(frame = frame, mode = mode, seed = seed, intensity = intensity)
  }
}

@Composable
private fun BlueFailureGlitchOverlay(active: Boolean, frame: Int, mode: String, progress: Float, seed: Int) {
  if (!active) {
    return
  }
  val intensity = panelGlitchEnvelope(progress, mode)
  Canvas(
      modifier =
          Modifier.fillMaxSize()
              .graphicsLayer {
                translationX = panelGlitchContentJitter(frame, mode, progress, seed, 71) * 0.55f
                translationY = panelGlitchContentJitter(frame, mode, progress, seed, 89) * 0.25f
              }
              .clip(RoundedCornerShape(18.dp)),
  ) {
    val phase = panelGlitchPhase(progress, mode)
    drawPhasedFailureWash(frame = frame, mode = mode, phase = phase, progress = progress, intensity = intensity)
    drawOnlineOfflineCues(frame = frame, mode = mode, phase = phase, progress = progress, seed = seed, intensity = intensity)
    drawScanlineTears(frame = frame, mode = mode, phase = phase, seed = seed, intensity = intensity)
    drawMacroblockCorruption(frame = frame, mode = mode, phase = phase, seed = seed, intensity = intensity)
    drawColorBreakupTears(frame = frame, seed = seed, intensity = intensity)
    drawNoiseBursts(frame = frame, phase = phase, seed = seed, intensity = intensity)
    drawPanelBorderDesync(frame = frame, mode = mode, seed = seed, intensity = intensity)
    drawGlitchedBufferSpinner(frame = frame, mode = mode, phase = phase, progress = progress, seed = seed, intensity = intensity)
  }
}

private fun panelGlitchProgress(active: Boolean, startElapsedMs: Long, durationMs: Long): Float {
  if (!active || durationMs <= 0L) {
    return 0f
  }
  val elapsedMs = (SystemClock.elapsedRealtime() - startElapsedMs).coerceAtLeast(0L)
  return (elapsedMs.toFloat() / durationMs.toFloat()).coerceIn(0f, 1f)
}

private fun panelGlitchPhase(progress: Float, mode: String): String {
  val p = progress.coerceIn(0f, 1f)
  return if (mode == "outro") {
    when {
      p < 0.18f -> "destabilize"
      p < 0.58f -> "dropout"
      p < 0.86f -> "collapse"
      else -> "dead_screen"
    }
  } else {
    when {
      p < 0.16f -> "acquire"
      p < 0.48f -> "rupture"
      p < 0.78f -> "reassemble"
      else -> "lock"
    }
  }
}

private fun panelGlitchEnvelope(progress: Float, mode: String): Float {
  val p = progress.coerceIn(0f, 1f)
  return if (mode == "outro") {
    when {
      p < 0.18f -> 0.38f + p * 3.0f
      p < 0.72f -> 1.0f
      else -> (1.0f - (p - 0.72f) * 0.75f).coerceIn(0.48f, 1.0f)
    }
  } else {
    when {
      p < 0.16f -> 1.0f
      p < 0.48f -> 0.92f
      p < 0.78f -> 0.72f
      else -> (1.0f - (p - 0.78f) * 3.3f).coerceIn(0.18f, 0.72f)
    }
  }
}

private fun panelGlitchContentJitter(frame: Int, mode: String, progress: Float, seed: Int, axisSalt: Int): Float {
  val phase = panelGlitchPhase(progress, mode)
  val phaseMultiplier =
      when (phase) {
        "rupture", "dropout", "collapse" -> 1.25f
        "dead_screen" -> 0.45f
        else -> 0.78f
      }
  return glitchSignedUnit(seed, frame, axisSalt) * 6.0f * panelGlitchEnvelope(progress, mode) * phaseMultiplier
}

private fun panelGlitchShellJitter(frame: Int, mode: String, progress: Float, seed: Int, axisSalt: Int): Float {
  val phase = panelGlitchPhase(progress, mode)
  val phaseMultiplier =
      when (phase) {
        "rupture", "dropout", "collapse" -> 1.0f
        "dead_screen" -> 0.34f
        else -> 0.62f
      }
  return glitchSignedUnit(seed, frame, axisSalt) * 9.0f * panelGlitchEnvelope(progress, mode) * phaseMultiplier
}

private fun panelGlitchShellRotation(frame: Int, mode: String, progress: Float, seed: Int): Float {
  val phase = panelGlitchPhase(progress, mode)
  val phaseMultiplier =
      when (phase) {
        "rupture", "dropout", "collapse" -> 1.0f
        "dead_screen" -> 0.25f
        else -> 0.55f
      }
  return glitchSignedUnit(seed, frame, 173) * 0.42f * panelGlitchEnvelope(progress, mode) * phaseMultiplier
}

private fun DrawScope.drawInterruptedPanelContour(frame: Int, mode: String, seed: Int, intensity: Float) {
  val edge = 10f + 7f * intensity
  val segmentCount = 30
  val topSegmentWidth = size.width / segmentCount
  val sideSegmentHeight = size.height / 18f
  val phaseShift = if (mode == "outro") 11 else 0

  for (i in 0 until segmentCount) {
    val dropped = glitchHash(seed, frame + phaseShift, 941 + i) % 6 == 0
    val x = i * topSegmentWidth + glitchSignedUnit(seed, frame, 967 + i) * 5f * intensity
    val segmentLength = topSegmentWidth * (0.46f + glitchUnit(seed, frame, 991 + i) * 0.78f)
    val topY = 2f + glitchSignedUnit(seed, frame, 1013 + i) * 5f * intensity
    val bottomY = size.height - edge + glitchSignedUnit(seed, frame, 1031 + i) * 7f * intensity
    val contourColor =
        when ((i + frame) % 5) {
          0 -> Color.White.copy(alpha = 0.48f * intensity)
          1 -> Color(0xFF00F0FF).copy(alpha = 0.58f * intensity)
          2 -> Color(0xFF001046).copy(alpha = 0.46f * intensity)
          3 -> Color(0xFFFF2D7F).copy(alpha = 0.20f * intensity)
          else -> Color(0xFF7FD4FF).copy(alpha = 0.42f * intensity)
        }
    if (dropped) {
      drawRect(
          color = Color(0xFF001046).copy(alpha = 0.52f * intensity),
          topLeft = Offset(x, 0f),
          size = Size(segmentLength * 1.2f, edge * 1.35f),
      )
      drawRect(
          color = Color(0xFF001046).copy(alpha = 0.46f * intensity),
          topLeft = Offset(x - topSegmentWidth * 0.2f, size.height - edge * 1.25f),
          size = Size(segmentLength, edge * 1.35f),
      )
    } else {
      drawRect(color = contourColor, topLeft = Offset(x, topY), size = Size(segmentLength, 4.0f + 4.0f * intensity))
      drawRect(
          color = contourColor.copy(alpha = contourColor.alpha * 0.80f),
          topLeft = Offset(x + glitchSignedUnit(seed, frame, 1049 + i) * 8f * intensity, bottomY),
          size = Size(segmentLength * 0.92f, 4.0f + 5.0f * intensity),
      )
    }
  }

  for (i in 0 until 18) {
    val dropped = glitchHash(seed, frame + phaseShift, 1063 + i) % 5 == 0
    val y = i * sideSegmentHeight + glitchSignedUnit(seed, frame, 1087 + i) * 5f * intensity
    val segmentLength = sideSegmentHeight * (0.42f + glitchUnit(seed, frame, 1109 + i) * 0.74f)
    val leftX = 1.5f + glitchSignedUnit(seed, frame, 1123 + i) * 4f * intensity
    val rightX = size.width - edge + glitchSignedUnit(seed, frame, 1151 + i) * 5f * intensity
    val color =
        when ((i + frame) % 4) {
          0 -> Color(0xFFBFEAFF).copy(alpha = 0.42f * intensity)
          1 -> Color(0xFF00F0FF).copy(alpha = 0.52f * intensity)
          2 -> Color(0xFF001046).copy(alpha = 0.42f * intensity)
          else -> Color(0xFFFF2D7F).copy(alpha = 0.16f * intensity)
        }
    if (dropped) {
      drawRect(color = Color(0xFF001046).copy(alpha = 0.44f * intensity), topLeft = Offset(0f, y), size = Size(edge * 1.2f, segmentLength))
      drawRect(color = Color(0xFF001046).copy(alpha = 0.44f * intensity), topLeft = Offset(size.width - edge * 1.1f, y), size = Size(edge * 1.2f, segmentLength))
    } else {
      drawRect(color = color, topLeft = Offset(leftX, y), size = Size(4f + intensity * 4f, segmentLength))
      drawRect(color = color, topLeft = Offset(rightX, y + glitchSignedUnit(seed, frame, 1171 + i) * 6f * intensity), size = Size(4f + intensity * 4f, segmentLength * 0.92f))
    }
  }

  for (i in 0 until 14) {
    val biteWidth = 18f + glitchUnit(seed, frame, 1193 + i) * 74f
    val biteDepth = 6f + glitchUnit(seed, frame, 1217 + i) * 26f * intensity
    val side = glitchHash(seed, frame, 1231 + i) % 4
    val color =
        if ((i + frame) % 3 == 0) {
          Color(0xFF00F0FF).copy(alpha = 0.18f * intensity)
        } else {
          Color(0xFF001046).copy(alpha = 0.58f * intensity)
        }
    when (side) {
      0 ->
          drawRect(
              color = color,
              topLeft = Offset(glitchUnit(seed, frame, 1249 + i) * size.width, 0f),
              size = Size(biteWidth, biteDepth),
          )
      1 ->
          drawRect(
              color = color,
              topLeft = Offset(glitchUnit(seed, frame, 1277 + i) * size.width, size.height - biteDepth),
              size = Size(biteWidth, biteDepth),
          )
      2 ->
          drawRect(
              color = color,
              topLeft = Offset(0f, glitchUnit(seed, frame, 1301 + i) * size.height),
              size = Size(biteDepth, biteWidth),
          )
      else ->
          drawRect(
              color = color,
              topLeft = Offset(size.width - biteDepth, glitchUnit(seed, frame, 1327 + i) * size.height),
              size = Size(biteDepth, biteWidth),
          )
    }
  }

  for (i in 0 until 9) {
    val horizontal = glitchHash(seed, frame, 1373 + i) % 2 == 0
    val fromFarEdge = glitchHash(seed, frame, 1399 + i) % 3 == 0
    val tearThickness = 5f + glitchUnit(seed, frame, 1423 + i) * 18f * intensity
    val tearLength =
        if (mode == "outro") {
          size.width * (0.18f + glitchUnit(seed, frame, 1447 + i) * 0.42f)
        } else {
          size.width * (0.10f + glitchUnit(seed, frame, 1447 + i) * 0.26f)
        }
    val tearAlpha = (0.52f + glitchUnit(seed, frame, 1471 + i) * 0.28f) * intensity
    val seamColor =
        if ((i + frame) % 3 == 0) {
          Color(0xFFFF2D7F).copy(alpha = 0.24f * intensity)
        } else {
          Color(0xFF00F0FF).copy(alpha = 0.34f * intensity)
        }
    if (horizontal) {
      val y = glitchUnit(seed, frame, 1493 + i) * size.height
      val x = if (fromFarEdge) size.width - tearLength else 0f
      drawRect(
          color = Color.Transparent,
          topLeft = Offset(x, y),
          size = Size(tearLength, tearThickness),
          blendMode = BlendMode.Clear,
      )
      drawRect(
          color = Color(0xFF001046).copy(alpha = tearAlpha),
          topLeft = Offset(x, y),
          size = Size(tearLength, tearThickness),
      )
      drawRect(
          color = seamColor,
          topLeft = Offset(x + glitchSignedUnit(seed, frame, 1511 + i) * 8f, y + tearThickness),
          size = Size(tearLength * 0.72f, 2.5f + 2f * intensity),
      )
    } else {
      val x = glitchUnit(seed, frame, 1531 + i) * size.width
      val y = if (fromFarEdge) size.height - tearLength else 0f
      drawRect(
          color = Color.Transparent,
          topLeft = Offset(x, y),
          size = Size(tearThickness, tearLength),
          blendMode = BlendMode.Clear,
      )
      drawRect(
          color = Color(0xFF001046).copy(alpha = tearAlpha),
          topLeft = Offset(x, y),
          size = Size(tearThickness, tearLength),
      )
      drawRect(
          color = seamColor,
          topLeft = Offset(x + tearThickness, y + glitchSignedUnit(seed, frame, 1553 + i) * 8f),
          size = Size(2.5f + 2f * intensity, tearLength * 0.72f),
      )
    }
  }

  val duplicateOffset = glitchSignedUnit(seed, frame, 1351) * 12f * intensity
  drawRect(
      color = Color(0xFF00F0FF).copy(alpha = 0.22f * intensity),
      topLeft = Offset(4f + duplicateOffset, 4f),
      size = Size(size.width - 8f, size.height - 8f),
      style = Stroke(width = 2.5f + intensity * 2f),
  )
  drawRect(
      color = Color(0xFFFF2D7F).copy(alpha = 0.10f * intensity),
      topLeft = Offset(4f - duplicateOffset * 0.7f, 4f + duplicateOffset * 0.35f),
      size = Size(size.width - 8f, size.height - 8f),
      style = Stroke(width = 2f),
  )
}

private fun DrawScope.drawPhasedFailureWash(frame: Int, mode: String, phase: String, progress: Float, intensity: Float) {
  val pulse = frame % 10
  val baseAlpha =
      when {
        mode == "outro" && phase == "collapse" -> 0.90f
        mode == "outro" && phase == "dead_screen" -> 0.82f
        phase == "acquire" && pulse in 0..1 -> 0.86f
        phase == "rupture" && pulse == 5 -> 0.80f
        else -> if (mode == "outro") 0.74f else 0.64f
      }
  drawRect(Color(0xFF012B7F).copy(alpha = baseAlpha))
  drawRect(
      brush =
          Brush.verticalGradient(
              listOf(
                  Color(0xFFBFEAFF).copy(alpha = 0.16f * intensity),
                  Color(0xFF002782).copy(alpha = 0.08f),
                  Color(0xFF000830).copy(alpha = 0.34f * intensity),
              ),
          ),
  )
  if (pulse == 0 && phase != "lock") {
    drawRect(Color(0xFFDDF7FF).copy(alpha = 0.18f * intensity))
  }
  if (mode == "outro") {
    val wipeProgress = ((progress - 0.54f) / 0.42f).coerceIn(0f, 1f)
    if (wipeProgress > 0f) {
      drawRect(
          color = Color(0xFF000B3A).copy(alpha = 0.52f * wipeProgress),
          topLeft = Offset(0f, size.height * (1f - wipeProgress)),
          size = Size(size.width, size.height * wipeProgress),
      )
    }
  }
}

private fun DrawScope.drawOnlineOfflineCues(
    frame: Int,
    mode: String,
    phase: String,
    progress: Float,
    seed: Int,
    intensity: Float,
) {
  val barAlpha = (0.16f + 0.32f * intensity).coerceAtMost(0.48f)
  val topY = if (mode == "intro") size.height * (0.08f + progress * 0.08f) else size.height * (0.84f - progress * 0.12f)
  val blockWidth = size.width / 28f
  for (i in 0 until 28) {
    val dropped = glitchHash(seed, frame + i, 211) % 5 == 0
    val height = 7f + (glitchHash(seed, frame, 251 + i) % 20)
    val color =
        when {
          dropped -> Color(0xFF001244).copy(alpha = barAlpha * 0.70f)
          (i + frame) % 6 == 0 -> Color(0xFFFF2D7F).copy(alpha = barAlpha * 0.70f)
          (i + frame) % 3 == 0 -> Color.White.copy(alpha = barAlpha)
          else -> Color(0xFF00F0FF).copy(alpha = barAlpha)
        }
    drawRect(
        color = color,
        topLeft = Offset(i * blockWidth + glitchSignedUnit(seed, frame, 277 + i) * 3f, topY),
        size = Size(blockWidth * if (dropped) 0.38f else 0.76f, height),
    )
  }

  val shortSide = if (size.width < size.height) size.width else size.height
  val bracket = shortSide * 0.078f
  val inset = 16f + glitchUnit(seed, frame, 293) * 5f
  val bracketAlpha = if (phase == "lock" || phase == "dead_screen") 0.20f else 0.42f * intensity
  val color = Color(0xFFBFEAFF).copy(alpha = bracketAlpha)
  drawLine(color, Offset(inset, inset), Offset(inset + bracket, inset), strokeWidth = 4f)
  drawLine(color, Offset(inset, inset), Offset(inset, inset + bracket), strokeWidth = 4f)
  drawLine(color, Offset(size.width - inset, inset), Offset(size.width - inset - bracket, inset), strokeWidth = 4f)
  drawLine(color, Offset(size.width - inset, inset), Offset(size.width - inset, inset + bracket), strokeWidth = 4f)
  drawLine(color, Offset(inset, size.height - inset), Offset(inset + bracket, size.height - inset), strokeWidth = 4f)
  drawLine(color, Offset(inset, size.height - inset), Offset(inset, size.height - inset - bracket), strokeWidth = 4f)
  drawLine(color, Offset(size.width - inset, size.height - inset), Offset(size.width - inset - bracket, size.height - inset), strokeWidth = 4f)
  drawLine(color, Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - bracket), strokeWidth = 4f)
}

private fun DrawScope.drawScanlineTears(frame: Int, mode: String, phase: String, seed: Int, intensity: Float) {
  val widthInt = size.width.toInt().coerceAtLeast(1)
  val heightInt = size.height.toInt().coerceAtLeast(1)
  val stripeCount = if (phase == "lock" || phase == "dead_screen") 42 else 64
  for (i in 0 until stripeCount) {
    val y = ((i * 19 + frame * (9 + (i % 7)) + glitchHash(seed, i, 311) % heightInt) % heightInt).toFloat()
    val stripeHeight = 1.2f + (glitchHash(seed, frame, 337 + i) % 11) * 1.8f
    val shift = glitchSignedUnit(seed, frame, 353 + i) * size.width * 0.20f * intensity
    val color =
        when ((i + frame) % 6) {
          0 -> Color.White.copy(alpha = 0.24f * intensity)
          1 -> Color(0xFF7FD4FF).copy(alpha = 0.38f * intensity)
          2 -> Color(0xFF043BCA).copy(alpha = 0.54f * intensity)
          3 -> Color(0xFF001046).copy(alpha = 0.46f * intensity)
          4 -> Color(0xFFFF2D7F).copy(alpha = 0.13f * intensity)
          else -> Color(0xFF00D8FF).copy(alpha = 0.24f * intensity)
        }
    drawRect(color = color, topLeft = Offset(-size.width * 0.22f + shift, y), size = Size(size.width * 1.44f, stripeHeight))
  }

  val tearCount = if (phase == "collapse") 14 else 10
  for (i in 0 until tearCount) {
    val tearY = ((frame * (31 + i * 3) + i * 89 + glitchHash(seed, i, 379)) % heightInt).toFloat()
    val tearHeight = 4f + (glitchHash(seed, frame, 397 + i) % 7) * 4f
    val tearOffset = glitchSignedUnit(seed, frame, 419 + i) * size.width * if (mode == "outro") 0.34f else 0.22f
    drawRect(
        color = Color.White.copy(alpha = 0.16f + 0.28f * intensity),
        topLeft = Offset(0f, tearY),
        size = Size(size.width, tearHeight),
    )
    drawRect(
        color = Color(0xFF001046).copy(alpha = 0.42f * intensity),
        topLeft = Offset(tearOffset - size.width * 0.35f, tearY + tearHeight),
        size = Size(size.width * 0.82f, tearHeight * 0.74f),
    )
    if ((i + frame) % 4 == 0) {
      drawRect(
          color = Color(0xFF00F0FF).copy(alpha = 0.20f * intensity),
          topLeft = Offset(((frame * 17 + i * 53) % widthInt).toFloat(), tearY - tearHeight * 0.40f),
          size = Size(size.width * 0.28f, tearHeight * 1.4f),
      )
    }
  }
}

private fun DrawScope.drawMacroblockCorruption(frame: Int, mode: String, phase: String, seed: Int, intensity: Float) {
  val columns = 18
  val rows = 12
  val cellWidth = size.width / columns
  val cellHeight = size.height / rows
  val blockCount =
      when (phase) {
        "rupture", "dropout", "collapse" -> 48
        "lock", "dead_screen" -> 24
        else -> 34
      }
  for (i in 0 until blockCount) {
    val col = glitchHash(seed, frame / 2 + i, 431) % columns
    val row = glitchHash(seed, frame + i, 457) % rows
    val cellsWide = 1 + glitchHash(seed, frame, 479 + i) % 4
    val cellsHigh = 1 + glitchHash(seed, frame, 503 + i) % 3
    val x = (col * cellWidth + glitchSignedUnit(seed, frame, 521 + i) * 8f * intensity).coerceIn(-cellWidth, size.width)
    val y = (row * cellHeight + glitchSignedUnit(seed, frame, 541 + i) * 5f * intensity).coerceIn(-cellHeight, size.height)
    val alpha = (0.12f + glitchUnit(seed, frame, 563 + i) * 0.34f) * intensity
    val blockColor =
        when ((frame + i + if (mode == "outro") 1 else 0) % 5) {
          0 -> Color(0xFFE8F6FF).copy(alpha = alpha * 0.76f)
          1 -> Color(0xFF36A7FF).copy(alpha = alpha)
          2 -> Color(0xFF001B66).copy(alpha = alpha * 1.35f)
          3 -> Color(0xFF00F0FF).copy(alpha = alpha * 0.70f)
          else -> Color(0xFFFF2D7F).copy(alpha = alpha * 0.42f)
        }
    drawRect(color = blockColor, topLeft = Offset(x, y), size = Size(cellWidth * cellsWide, cellHeight * cellsHigh))
  }
}

private fun DrawScope.drawColorBreakupTears(frame: Int, seed: Int, intensity: Float) {
  val heightInt = size.height.toInt().coerceAtLeast(1)
  for (i in 0 until 11) {
    val y = ((frame * (13 + i) + glitchHash(seed, i, 587)) % heightInt).toFloat()
    val stripHeight = 2f + (glitchHash(seed, frame, 601 + i) % 4)
    val shift = glitchSignedUnit(seed, frame, 617 + i) * size.width * 0.09f * intensity
    drawRect(
        color = Color(0xFF00F0FF).copy(alpha = 0.18f * intensity),
        topLeft = Offset(shift, y),
        size = Size(size.width * 0.78f, stripHeight),
    )
    drawRect(
        color = Color(0xFFFF2D7F).copy(alpha = 0.15f * intensity),
        topLeft = Offset(-shift + size.width * 0.18f, y + stripHeight * 1.8f),
        size = Size(size.width * 0.58f, stripHeight),
    )
  }
}

private fun DrawScope.drawGlitchedBufferSpinner(
    frame: Int,
    mode: String,
    phase: String,
    progress: Float,
    seed: Int,
    intensity: Float,
) {
  val shortSide = if (size.width < size.height) size.width else size.height
  val wheelIntensity = intensity.coerceAtLeast(0.82f)
  val radius = shortSide * if (phase == "collapse" || phase == "dropout") 0.166f else 0.142f
  val center =
      Offset(
          size.width * 0.50f + glitchSignedUnit(seed, frame, 641) * 12f * wheelIntensity,
          size.height * if (mode == "outro") 0.55f else 0.50f + glitchSignedUnit(seed, frame, 659) * 9f * wheelIntensity,
      )
  val rotation = (frame * if (mode == "outro") -21f else 17f) + progress * 290f + seed % 360
  val ringBounds = Size(radius * 2f, radius * 2f)
  val topLeft = Offset(center.x - radius, center.y - radius)

  drawCircle(
      color = Color(0xFF000516).copy(alpha = 0.58f),
      radius = radius * 1.36f,
      center = center,
  )
  drawCircle(
      color = Color(0xFF00F0FF).copy(alpha = 0.28f * wheelIntensity),
      radius = radius * 1.12f,
      center = Offset(center.x + glitchSignedUnit(seed, frame, 666) * 5f, center.y),
      style = Stroke(width = 6f + wheelIntensity * 6f),
  )
  drawCircle(
      color = Color.White.copy(alpha = 0.18f * wheelIntensity),
      radius = radius * 0.86f,
      center = center,
      style = Stroke(width = 3.5f + wheelIntensity * 3f),
  )

  for (i in 0 until 18) {
    val dropped = glitchHash(seed, frame + i, 677) % 6 == 0
    if (!dropped) {
      val age = ((i + frame) % 18) / 18f
      val alpha = (0.34f + age * 0.62f) * wheelIntensity
      val color =
          when (i % 5) {
            0 -> Color.White.copy(alpha = alpha)
            1 -> Color(0xFF00F0FF).copy(alpha = alpha)
            2 -> Color(0xFF7FD4FF).copy(alpha = alpha * 0.84f)
            3 -> Color(0xFF001046).copy(alpha = alpha * 1.10f)
            else -> Color(0xFFFF2D7F).copy(alpha = alpha * 0.46f)
          }
      drawArc(
          color = color,
          startAngle = rotation + i * 20f + glitchSignedUnit(seed, frame, 701 + i) * 10f,
          sweepAngle = 10f + glitchUnit(seed, frame, 719 + i) * 25f,
          useCenter = false,
          topLeft = topLeft,
          size = ringBounds,
          style = Stroke(width = 11f + wheelIntensity * 6f, cap = StrokeCap.Round),
      )
    }
  }

  drawArc(
      color = Color(0xFF001046).copy(alpha = 0.78f * wheelIntensity),
      startAngle = rotation * -0.65f,
      sweepAngle = 86f + 44f * wheelIntensity,
      useCenter = false,
      topLeft = Offset(center.x - radius * 1.18f, center.y - radius * 1.18f),
      size = Size(radius * 2.36f, radius * 2.36f),
      style = Stroke(width = 5f + wheelIntensity * 3f, cap = StrokeCap.Square),
  )

  drawArc(
      color = Color.White.copy(alpha = 0.74f * wheelIntensity),
      startAngle = rotation + 190f,
      sweepAngle = 42f + 22f * wheelIntensity,
      useCenter = false,
      topLeft = Offset(center.x - radius * 0.54f, center.y - radius * 0.54f),
      size = Size(radius * 1.08f, radius * 1.08f),
      style = Stroke(width = 7f + wheelIntensity * 5f, cap = StrokeCap.Round),
  )
  drawCircle(
      color = Color(0xFFBFEAFF).copy(alpha = 0.46f * wheelIntensity),
      radius = radius * 0.19f,
      center =
          Offset(
              center.x + glitchSignedUnit(seed, frame, 733) * 8f * wheelIntensity,
              center.y + glitchSignedUnit(seed, frame, 739) * 5f * wheelIntensity,
          ),
  )

  for (i in 0 until 28) {
    val angle = (rotation + i * 12.86f + glitchSignedUnit(seed, frame, 743 + i) * 12f) * PI.toFloat() / 180f
    val distance = radius * (1.34f + glitchUnit(seed, frame, 761 + i) * 0.30f)
    val tickCenter = Offset(center.x + cos(angle) * distance, center.y + sin(angle) * distance)
    val tickAlpha = if (glitchHash(seed, frame + i, 787) % 6 == 0) 0.10f else 0.62f * wheelIntensity
    drawRect(
        color = if ((i + frame) % 7 == 0) Color(0xFFFF2D7F).copy(alpha = tickAlpha * 0.58f) else Color(0xFFBFEAFF).copy(alpha = tickAlpha),
        topLeft = Offset(tickCenter.x - 6f, tickCenter.y - 3f),
        size = Size(12f + glitchUnit(seed, frame, 809 + i) * 24f, 5f + wheelIntensity * 4f),
    )
  }
}

private fun DrawScope.drawNoiseBursts(frame: Int, phase: String, seed: Int, intensity: Float) {
  val widthInt = size.width.toInt().coerceAtLeast(1)
  val heightInt = size.height.toInt().coerceAtLeast(1)
  val count = (34 + 62 * intensity).roundToInt()
  for (i in 0 until count) {
    val x = (glitchHash(seed, frame + i, 821) % widthInt).toFloat()
    val y = (glitchHash(seed, frame * 2 + i, 839) % heightInt).toFloat()
    val pixelWidth = 2f + (glitchHash(seed, frame, 853 + i) % 15)
    val pixelHeight = 1.5f + (glitchHash(seed, frame, 877 + i) % 9)
    val alpha = (0.08f + glitchUnit(seed, frame, 887 + i) * 0.22f) * intensity
    val color =
        when ((i + frame) % 5) {
          0 -> Color.White.copy(alpha = alpha)
          1 -> Color(0xFF00F0FF).copy(alpha = alpha)
          2 -> Color(0xFF002782).copy(alpha = alpha * 1.3f)
          3 -> Color(0xFFFF2D7F).copy(alpha = alpha * if (phase == "collapse") 0.7f else 0.36f)
          else -> Color(0xFFBFEAFF).copy(alpha = alpha)
        }
    drawRect(color = color, topLeft = Offset(x, y), size = Size(pixelWidth, pixelHeight))
  }
}

private fun DrawScope.drawPanelBorderDesync(frame: Int, mode: String, seed: Int, intensity: Float) {
  val offsetX = glitchSignedUnit(seed, frame, 907) * 8f * intensity
  val offsetY = glitchSignedUnit(seed, frame, 919) * 5f * intensity
  val borderSize = Size(size.width - 3f, size.height - 3f)
  drawRect(
      color = Color(0xFFBFEAFF).copy(alpha = 0.34f * intensity),
      topLeft = Offset(1.5f + offsetX, 1.5f),
      size = borderSize,
      style = Stroke(width = 4.5f),
  )
  drawRect(
      color = Color(0xFFFF2D7F).copy(alpha = 0.13f * intensity),
      topLeft = Offset(1.5f - offsetX * 0.70f, 1.5f + offsetY),
      size = borderSize,
      style = Stroke(width = 3f),
  )
  if (mode == "outro") {
    drawRect(
        color = Color(0xFF001046).copy(alpha = 0.42f * intensity),
        topLeft = Offset(size.width * 0.04f, size.height * 0.86f + offsetY),
        size = Size(size.width * 0.92f, 9f + 18f * intensity),
    )
  }
}

private fun glitchHash(seed: Int, frame: Int, salt: Int): Int {
  var value = seed xor (frame * 1103515245) xor (salt * 12345)
  value = value xor (value ushr 16)
  value *= 73244475
  value = value xor (value ushr 15)
  return value and Int.MAX_VALUE
}

private fun glitchUnit(seed: Int, frame: Int, salt: Int): Float {
  return (glitchHash(seed, frame, salt) % 10000) / 10000f
}

private fun glitchSignedUnit(seed: Int, frame: Int, salt: Int): Float {
  return glitchUnit(seed, frame, salt) * 2f - 1f
}

@Composable
private fun ScaleSlider(
    label: String,
    value: Float,
    left: String,
    right: String,
    onChange: (Float) -> Unit,
    onFinished: (() -> Unit)? = null,
    modifier: Modifier = Modifier.fillMaxWidth(),
) {
  Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(label, fontWeight = FontWeight.Bold, color = BrbInk, fontSize = 17.sp, fontFamily = BrbSans)
      Text(
          value.toInt().toString(),
          fontWeight = FontWeight.Black,
          color = BrbRedDeep,
          fontSize = 18.sp,
          fontFamily = BrbMono,
      )
    }
    Slider(
        value = value,
        onValueChange = onChange,
        onValueChangeFinished = {
          onFinished?.invoke()
              ?: SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
                it.playQuestionnaireNavigationCue()
              }
        },
        valueRange = 0f..100f,
        colors =
            SliderDefaults.colors(
                thumbColor = BrbRed,
                activeTrackColor = BrbRed,
                inactiveTrackColor = BrbLine,
            ),
    )
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(left, color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
      Text(right, color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
    }
  }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun LabeledTextField(
    activity: BigRedButtonStudyActivity,
    fieldId: String,
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    autoFocus: Boolean = false,
    focusRequester: FocusRequester? = null,
    nextFocusRequester: FocusRequester? = null,
    nextKeyboardFieldId: String? = null,
    nextKeyboardMode: String? = null,
    keyboardMode: String,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
) {
  val localFocusRequester = remember { FocusRequester() }
  val effectiveFocusRequester = focusRequester ?: localFocusRequester
  val focusManager = LocalFocusManager.current
  val keyboardController = LocalSoftwareKeyboardController.current
  val view = LocalView.current
  val keyboardReason = "field_" + fieldId.lowercase(Locale.US).replace(Regex("[^a-z0-9]+"), "_").trim('_')
  val nextKeyboardReason =
      nextKeyboardFieldId?.let { "field_" + it.lowercase(Locale.US).replace(Regex("[^a-z0-9]+"), "_").trim('_') }

  fun showKeyboard() {
    keyboardController?.show()
    activity.requestSoftKeyboard(view, keyboardReason, keyboardMode)
  }

  LaunchedEffect(autoFocus) {
    if (autoFocus) {
      effectiveFocusRequester.requestFocus()
      showKeyboard()
    }
  }

  TextField(
      value = value,
      onValueChange = onValueChange,
      label = { Text(label, fontFamily = BrbMono) },
      singleLine = true,
      keyboardOptions = keyboardOptions,
      keyboardActions =
          KeyboardActions(
              onNext = {
                if (nextFocusRequester != null) {
                  nextFocusRequester.requestFocus()
                } else {
                  focusManager.moveFocus(FocusDirection.Next)
                }
                if (nextKeyboardReason != null && nextKeyboardMode != null) {
                  keyboardController?.show()
                  activity.requestSoftKeyboard(view, nextKeyboardReason, nextKeyboardMode)
                }
              },
              onDone = {
                keyboardController?.hide()
                activity.hideSoftKeyboardForReason("${keyboardReason}_done")
                focusManager.clearFocus(force = true)
              },
          ),
      modifier =
          modifier.focusRequester(effectiveFocusRequester).onFocusChanged { focusState ->
            if (focusState.isFocused) {
              showKeyboard()
            } else {
              activity.retainSoftKeyboardForField(keyboardReason)
            }
          },
      colors =
          TextFieldDefaults.textFieldColors(
              textColor = BrbInk,
              backgroundColor = BrbPaperLight,
              focusedIndicatorColor = BrbRed,
              unfocusedIndicatorColor = BrbLine,
              focusedLabelColor = BrbRedDeep,
              unfocusedLabelColor = BrbMuted,
              cursorColor = BrbRed,
          ),
  )
}

@Composable
private fun BrandKicker(text: String) {
  Text(
      text.uppercase(Locale.US),
      color = BrbMuted,
      fontSize = 12.sp,
      fontWeight = FontWeight.SemiBold,
      fontFamily = BrbMono,
      modifier =
          Modifier.clip(RoundedCornerShape(999.dp))
              .background(Color.White.copy(alpha = 0.78f))
              .border(1.dp, BrbLine, RoundedCornerShape(999.dp))
              .padding(horizontal = 10.dp, vertical = 4.dp),
  )
}

@Composable
private fun PanelTitle(text: String) {
  Text(
      text,
      color = BrbInk,
      fontSize = 31.sp,
      fontWeight = FontWeight.Black,
      fontFamily = BrbSerif,
      lineHeight = 34.sp,
  )
}

@Composable
private fun PrimaryActionButton(text: String, enabled: Boolean, height: androidx.compose.ui.unit.Dp = 58.dp, onClick: () -> Unit) {
  Button(
      onClick = {
        SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
          it.playQuestionnaireNavigationCue()
        }
        onClick()
      },
      enabled = enabled,
      colors =
          ButtonDefaults.buttonColors(
              backgroundColor = BrbRed,
              contentColor = Color.White,
              disabledBackgroundColor = Color(0xFF8C8C8C),
          ),
      shape = RoundedCornerShape(10.dp),
      modifier = Modifier.fillMaxWidth().height(height).border(1.dp, BrbRedDeep, RoundedCornerShape(10.dp)),
  ) {
    Text(text, fontSize = 18.sp, fontWeight = FontWeight.Bold, fontFamily = BrbMono)
  }
}

val IPQ_ITEMS =
    listOf(
        PresenceItem(
            "ipq_g1",
            "general",
            "In the previous button session, I had a sense that the Big Red Button was really there with me.",
        ),
        PresenceItem(
            "ipq_sp1",
            "spatial_presence",
            "I felt that the Big Red Button occupied the space in front of me.",
        ),
        PresenceItem(
            "ipq_sp2",
            "spatial_presence",
            "I felt like I was only looking at a picture or display of a button.",
            reverse = true,
        ),
        PresenceItem(
            "ipq_sp3",
            "spatial_presence",
            "I did not feel present with the Big Red Button.",
            reverse = true,
        ),
        PresenceItem(
            "ipq_sp4",
            "spatial_presence",
            "I had a sense of acting around the button rather than operating something from outside.",
        ),
        PresenceItem("ipq_sp5", "spatial_presence", "I felt present with the Big Red Button."),
        PresenceItem(
            "ipq_inv1",
            "involvement",
            "While focusing on the Big Red Button, I was still very aware of the real room around me.",
            reverse = true,
        ),
        PresenceItem(
            "ipq_inv2",
            "involvement",
            "I was not aware of much else besides the Big Red Button.",
        ),
        PresenceItem(
            "ipq_inv3",
            "involvement",
            "I still paid attention to things in the real environment around me.",
            reverse = true,
        ),
        PresenceItem("ipq_inv4", "involvement", "I was completely captivated by the Big Red Button."),
        PresenceItem("ipq_real1", "experienced_realism", "The Big Red Button seemed like a real object."),
        PresenceItem(
            "ipq_real2",
            "experienced_realism",
            "The button's presence seemed consistent with something that could exist in the room.",
        ),
        PresenceItem(
            "ipq_real3",
            "experienced_realism",
            "The Big Red Button felt artificial or unreal.",
            reverse = true,
        ),
        PresenceItem(
            "ipq_real4",
            "experienced_realism",
            "The button felt as if it could affect my behavior in the moment.",
        ),
    )

fun selfButtonDistanceUnits(closeness0To100: Float): Float {
  return (100f - closeness0To100.coerceIn(0f, 100f)) * 4.40f
}

fun buttonPresenceRadiusUnits(presence0To100: Float): Float {
  return 34f + presence0To100.coerceIn(0f, 100f) * 0.95f
}

private fun formatElapsed(elapsedMs: Long): String {
  val totalSeconds = elapsedMs.coerceAtLeast(0L) / 1000L
  val minutes = totalSeconds / 60L
  val seconds = totalSeconds % 60L
  return "%02d:%02d".format(Locale.US, minutes, seconds)
}

private fun nowIso(): String = Instant.now().toString()

private fun csv(value: String?): String {
  val text = value ?: ""
  return "\"" + text.replace("\"", "\"\"") + "\""
}

private fun formatFloat(value: Float): String = "%.3f".format(Locale.US, value)

private fun formatDouble(value: Double): String {
  return if (value.isFinite()) "%.3f".format(Locale.US, value) else ""
}

private fun formatNullableDouble(value: Double?): String {
  return if (value != null && value.isFinite()) "%.3f".format(Locale.US, value) else ""
}

private fun jsonDoubleOrNull(value: Double?): Any {
  return if (value != null && value.isFinite()) value else JSONObject.NULL
}

private fun safeFileSegment(value: String): String {
  return value.lowercase(Locale.US).replace(Regex("[^a-z0-9]+"), "_").trim('_').ifBlank { "participant" }
}
