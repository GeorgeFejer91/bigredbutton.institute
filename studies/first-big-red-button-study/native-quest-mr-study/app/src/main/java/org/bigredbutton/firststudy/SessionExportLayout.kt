package org.bigredbutton.firststudy

import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption.ATOMIC_MOVE
import java.nio.file.StandardCopyOption.REPLACE_EXISTING
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

data class SessionExportLayout(
    val participantId: String,
    val safeParticipantId: String,
    val sessionId: String,
    val sessionId8: String,
    val sessionStartIso: String,
    val exportedIso: String,
    val sessionFolderName: String,
    val primaryRootName: String,
    val mirrorRootName: String,
    val manifestFilename: String = MANIFEST_FILENAME,
) {
  val baseName: String = "brb_first_study_${safeParticipantId}_$sessionId"
  val jsonFilename: String = "$baseName.json"
  val summaryCsvFilename: String = "${baseName}_summary.csv"
  val pressEventsCsvFilename: String = "${baseName}_press_events.csv"
  val finalExtraButtonPressesCsvFilename: String = "${baseName}_final_extra_button_presses.csv"
  val ecgBlinkEventsCsvFilename: String = "${baseName}_ecg_blink_events.csv"
  val polarRrEventsCsvFilename: String = "${baseName}_polar_rr_events.csv"
  val ecgTimeSeriesCsvFilename: String = "${baseName}_ecg_timeseries.csv"
  val ecgDetectorEventsCsvFilename: String = "${baseName}_ecg_detector_events.csv"
  val externalSignalSamplesCsvFilename: String = "${baseName}_external_signal_samples.csv"

  fun relativePath(filename: String): String = "$sessionFolderName/$filename"

  companion object {
    const val SCHEMA = "bigredbutton.session_folder_export.v1"
    const val MANIFEST_FILENAME = "session-manifest.json"

    private val folderTimestampFormatter =
        DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss'Z'", Locale.US).withZone(ZoneOffset.UTC)

    fun create(
        participantId: String,
        sessionId: String,
        sessionStartUtc: Instant,
        exportedUtc: Instant,
        primaryRootName: String,
        mirrorRootName: String,
    ): SessionExportLayout {
      val safeParticipantId = safeSegment(participantId)
      val sessionId8 = shortSessionId(sessionId)
      val folderName =
          "${folderTimestampFormatter.format(sessionStartUtc)}_${safeParticipantId}_$sessionId8"
      return SessionExportLayout(
          participantId = participantId,
          safeParticipantId = safeParticipantId,
          sessionId = sessionId,
          sessionId8 = sessionId8,
          sessionStartIso = sessionStartUtc.toString(),
          exportedIso = exportedUtc.toString(),
          sessionFolderName = folderName,
          primaryRootName = primaryRootName,
          mirrorRootName = mirrorRootName,
      )
    }

    fun safeSegment(value: String): String {
      return value
          .lowercase(Locale.US)
          .replace(Regex("[^a-z0-9]+"), "_")
          .trim('_')
          .ifBlank { "participant" }
    }

    private fun shortSessionId(sessionId: String): String {
      val withoutPrefix = sessionId.removePrefix("brb-")
      val alnum = withoutPrefix.filter { it.isLetterOrDigit() }.lowercase(Locale.US)
      return alnum.take(8).ifBlank { "session" }
    }
  }
}

data class SessionExportTextFile(
    val filename: String,
    val text: String,
)

object SessionExportWriter {
  fun writeBundle(
      rootDir: File,
      layout: SessionExportLayout,
      files: List<SessionExportTextFile>,
      manifestText: String,
      indexLine: String,
      beforeIndexAppend: (() -> Unit)? = null,
  ): List<File> {
    rootDir.mkdirs()
    val sessionDir = File(rootDir, layout.sessionFolderName)
    sessionDir.mkdirs()
    val written = mutableListOf<File>()
    files.forEach { exportFile ->
      val target = File(sessionDir, exportFile.filename)
      atomicWriteText(target, exportFile.text)
      written += target
    }
    val manifestFile = File(sessionDir, layout.manifestFilename)
    atomicWriteText(manifestFile, manifestText)
    written += manifestFile
    beforeIndexAppend?.invoke()
    val indexFile = File(rootDir, "session-index.jsonl")
    appendIndexLine(indexFile, indexLine)
    written += indexFile
    return written
  }

  private fun atomicWriteText(target: File, text: String) {
    target.parentFile?.mkdirs()
    val temp = File(target.parentFile, ".${target.name}.${UUID.randomUUID()}.tmp")
    try {
      FileOutputStream(temp).use { stream ->
        stream.write(text.toByteArray(StandardCharsets.UTF_8))
        stream.fd.sync()
      }
      try {
        Files.move(temp.toPath(), target.toPath(), REPLACE_EXISTING, ATOMIC_MOVE)
      } catch (_: AtomicMoveNotSupportedException) {
        Files.move(temp.toPath(), target.toPath(), REPLACE_EXISTING)
      }
    } finally {
      if (temp.exists()) {
        temp.delete()
      }
    }
  }

  private fun appendIndexLine(indexFile: File, indexLine: String) {
    indexFile.parentFile?.mkdirs()
    FileOutputStream(indexFile, true).use { stream ->
      stream.write(indexLine.toByteArray(StandardCharsets.UTF_8))
      stream.fd.sync()
    }
  }
}
