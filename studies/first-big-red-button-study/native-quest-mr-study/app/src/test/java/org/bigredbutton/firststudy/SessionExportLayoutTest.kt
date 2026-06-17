package org.bigredbutton.firststudy

import java.nio.file.Files
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionExportLayoutTest {
  @Test
  fun folderNameIsTimestampParticipantAndShortSessionId() {
    val layout =
        SessionExportLayout.create(
            participantId = "George Fejer",
            sessionId = "brb-abcdef12-3456-7890",
            sessionStartUtc = Instant.parse("2026-06-14T12:34:56Z"),
            exportedUtc = Instant.parse("2026-06-14T12:40:00Z"),
            primaryRootName = "BigRedButtonFirstStudyExports",
            mirrorRootName = "ExperimentResults",
        )

    assertEquals("20260614-123456Z_george_fejer_abcdef12", layout.sessionFolderName)
    assertEquals("abcdef12", layout.sessionId8)
  }

  @Test
  fun unsafeParticipantTextIsSanitized() {
    assertEquals("george_fejer_lab_42", SessionExportLayout.safeSegment("  George/Fejer Lab #42  "))
    assertEquals("participant", SessionExportLayout.safeSegment("!? /"))
  }

  @Test
  fun rootIndexPointsToSessionFolderAndNoFlatRootFilesAreWritten() {
    val root = Files.createTempDirectory("brb-export-test").toFile()
    val layout =
        SessionExportLayout.create(
            participantId = "Participant 1",
            sessionId = "brb-12345678-aaaa",
            sessionStartUtc = Instant.parse("2026-06-14T12:34:56Z"),
            exportedUtc = Instant.parse("2026-06-14T12:40:00Z"),
            primaryRootName = "BigRedButtonFirstStudyExports",
            mirrorRootName = "ExperimentResults",
        )
    val indexLine =
        """{"sessionId":"${layout.sessionId}","sessionFolder":"${layout.sessionFolderName}","manifest":"${layout.relativePath(layout.manifestFilename)}","json":"${layout.relativePath(layout.jsonFilename)}","summaryCsv":"${layout.relativePath(layout.summaryCsvFilename)}"}""" +
            "\n"

    SessionExportWriter.writeBundle(
        rootDir = root,
        layout = layout,
        files =
            listOf(
                SessionExportTextFile(layout.jsonFilename, "{}"),
                SessionExportTextFile(layout.summaryCsvFilename, "session_id\n"),
            ),
        manifestText = "{}",
        indexLine = indexLine,
    )

    val indexText = root.resolve("session-index.jsonl").readText()
    assertTrue(indexText.contains(""""sessionFolder":"${layout.sessionFolderName}""""))
    assertTrue(root.resolve(layout.sessionFolderName).resolve(layout.jsonFilename).isFile)
    assertFalse(root.resolve(layout.jsonFilename).exists())
  }

  @Test
  fun partialWriteFailureDoesNotAppendIndexRow() {
    val root = Files.createTempDirectory("brb-export-failure-test").toFile()
    val layout =
        SessionExportLayout.create(
            participantId = "Participant 1",
            sessionId = "brb-12345678-aaaa",
            sessionStartUtc = Instant.parse("2026-06-14T12:34:56Z"),
            exportedUtc = Instant.parse("2026-06-14T12:40:00Z"),
            primaryRootName = "BigRedButtonFirstStudyExports",
            mirrorRootName = "ExperimentResults",
        )

    try {
      SessionExportWriter.writeBundle(
          rootDir = root,
          layout = layout,
          files = listOf(SessionExportTextFile(layout.jsonFilename, "{}")),
          manifestText = "{}",
          indexLine = """{"sessionFolder":"${layout.sessionFolderName}"}""" + "\n",
          beforeIndexAppend = { throw IllegalStateException("synthetic failure") },
      )
    } catch (_: IllegalStateException) {
      // Expected.
    }

    assertFalse(root.resolve("session-index.jsonl").exists())
    assertTrue(root.resolve(layout.sessionFolderName).resolve(layout.jsonFilename).isFile)
  }
}
