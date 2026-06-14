package org.bigredbutton.firststudy

import android.Manifest
import android.graphics.Color as AndroidColor
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
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
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.meta.spatial.compose.ComposeFeature
import com.meta.spatial.compose.ComposeViewPanelRegistration
import com.meta.spatial.core.Entity
import com.meta.spatial.core.Pose
import com.meta.spatial.core.Quaternion
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
import java.security.MessageDigest
import java.time.Instant
import java.util.concurrent.CompletableFuture
import java.util.Locale
import java.util.UUID
import kotlin.math.abs
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
private const val POLAR_ECG_PREVIEW_SAMPLE_COUNT = 180
private const val DEMOGRAPHICS_NAME_MAX_CHARS = 80
private const val DEMOGRAPHICS_AGE_MIN = 0
private const val DEMOGRAPHICS_AGE_MAX = 100
private const val PRIOR_BUTTON_EXPERIENCE_QUESTION =
    "Oh wait, we have just one more question: Do you have any experience with pressing big red buttons?"
private const val PRIOR_BUTTON_EXPERIENCE_YES_FEEDBACK =
    "An experienced user, just the type of participant we need."
private const val PRIOR_BUTTON_EXPERIENCE_NO_FEEDBACK =
    "No? Well than you are in for a treat!"
private const val FINAL_END_CONFIRMATION_QUESTION =
    "How sure are you that you want to end the experiment, on a scale of 1 to 10?"
private const val FINAL_END_CONFIRMATION_10_FEEDBACK =
    "All right then, I guess you can give the VR headset back then if you don't feel like doing any more button presses."
private const val FINAL_EXTRA_PRESSES_PROMPT =
    "That is fantastic! I will take your non-decimal response as a big red YES! Yes I want to continue pressing the big red button! Yes the button is big! Yes the button is red! Yes I want to continue pressing it! FOR SCIENCE, for data collection, for the pursuit of knowledge! Only for science! Forever Science. Well then, you may end the experiment, once you pressed the button 1000 more times. Enjoy!"
private const val PRE_BUTTON_EXPERIENCE_VALIDATION_DELAY_MS = 350L
private const val MODEL_GLOW_PANEL_FALLBACK_ENABLED = false
private const val PICTOGRAPHIC_VAS_AXIS_WIDTH_DP = 640
private const val PICTOGRAPHIC_VAS_THUMB_RADIUS_DP = 20
private const val PICTOGRAPHIC_SELF_BUTTON_TRAVEL_UNITS =
    PICTOGRAPHIC_VAS_AXIS_WIDTH_DP - (PICTOGRAPHIC_VAS_THUMB_RADIUS_DP * 2)

enum class StudyLanguage(val code: String, val label: String) {
  English("en-US", "English"),
  Japanese("ja-JP", "日本語"),
}

enum class StudyStage {
  LanguageSelection,
  ConsentDemographics,
  PreButtonExperienceQuestion,
  ConditionRunning,
  Pictographic,
  PresenceQuestionnaire,
  LostOpportunity,
  FinalEndQuestionnaire,
  FinalExtraPresses,
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
    val elapsedNs: Long,
    val eventElapsedRealtimeNs: Long,
    val conditionStartElapsedRealtimeNs: Long,
    val unixTimeMs: Long,
    val isoTimestamp: String,
    val inputSource: String,
    val validationAutomation: Boolean,
    val feedbackSource: String,
    val physiologySource: String,
)

data class FinalExtraPressEvent(
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
    val rednessCarriedForwardVas0To100: Int,
    val rednessCarriedForwardLikert1To7: Int,
    val rednessCarriedForwardLikertDescriptor: String,
    val rednessPostConversionEdited: Boolean,
    val rednessPostConversionEditScale: String,
    val rednessChangedAfterConversion: Boolean,
    val rednessFinalMatchesCarriedForward: Boolean,
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
    val audioId: String,
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

data class FinalEndConfirmationResponse(
    val question: String,
    val rating1To10: Int,
    val immediateEnd: Boolean,
    val selectedTimestampIso: String,
    val feedbackText: String,
    val extraPressRequirement: Int,
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

data class PolarRrEvent(
    val conditionNumber: Int,
    val rrIndex: Int,
    val elapsedMs: Long,
    val elapsedNs: Long,
    val unixTimeMs: Long,
    val isoTimestamp: String,
    val rrMs: Double,
    val heartRateBpm: Int,
    val feedbackSource: String,
    val usedForFeedback: Boolean,
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

private data class PressEcgAlignment(
    val sampleIndex: Int,
    val elapsedNs: Long,
    val deltaNs: Long,
)

private data class ButtonContactTargetSpec(
    val name: String,
    val offsetX: Float,
    val offsetZ: Float,
    val width: Float,
    val height: Float,
    val depth: Float,
    val surfaceRole: String = "shared_physical_cap",
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

private data class OpenedAudioAsset(
    val descriptor: android.content.res.AssetFileDescriptor,
    val assetPath: String,
    val localeCode: String,
    val fallbackToEnglish: Boolean,
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
    var audioAssetPath: String,
    val audioId: String = "",
) {
  var startedIso: String = ""
  var endedIso: String = ""
  var startedElapsedMs: Long = 0L
  var endedElapsedMs: Long = 0L
  var startedElapsedNs: Long = 0L
  var endedElapsedNs: Long = 0L
  var audioDurationMs: Int = 0
  var audioLocaleCode: String = "en-US"
  var audioFallbackToEnglish: Boolean = false
  val pressEvents: MutableList<PressEvent> = mutableListOf()
  var pictographic: PictographicResponse? = null
  var presenceQuestionnaire: PresenceQuestionnaireResponse? = null
  var lostOpportunity: LostOpportunityResponse? = null
  var ecgSource: String = ""
  var feedbackSource: String = ""
  var physiologySource: String = ""
  val ecgBlinkEvents: MutableList<EcgBlinkEvent> = mutableListOf()
  val polarRrEvents: MutableList<PolarRrEvent> = mutableListOf()
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

private fun normalizeAgeSliderInput(raw: String): String {
  val trimmed = raw.trim()
  val parsed =
      trimmed.toIntOrNull()
          ?: raw.mapNotNull { char -> char.digitToIntOrNull()?.toString() }
              .joinToString("")
              .toIntOrNull()
  return parsed?.coerceIn(DEMOGRAPHICS_AGE_MIN, DEMOGRAPHICS_AGE_MAX)?.toString().orEmpty()
}

private fun ageSliderValueOrDefault(raw: String): Int {
  return normalizeAgeSliderInput(raw).toIntOrNull() ?: DEMOGRAPHICS_AGE_MIN
}

private val DEMOGRAPHICS_NAME_KEYBOARD_LETTER_ROWS = listOf("QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM")
private val DEMOGRAPHICS_NAME_KEYBOARD_ROWS =
    DEMOGRAPHICS_NAME_KEYBOARD_LETTER_ROWS.map { row -> row.map { it.toString() } } +
        listOf(listOf("Clear", "Space", "Back", "Next"))
private const val DEMOGRAPHICS_NAME_KEYBOARD_DEFAULT_ROW = 3
private const val DEMOGRAPHICS_NAME_KEYBOARD_DEFAULT_COLUMN = 3

class BigRedButtonStudyActivity : AppSystemActivity(), PolarH10HeartRateClient.Listener {
  val stageState: MutableState<StudyStage> = mutableStateOf(StudyStage.LanguageSelection)
  val selectedLanguageState: MutableState<StudyLanguage> = mutableStateOf(StudyLanguage.English)
  val languageSelectionFocusIndexState = mutableIntStateOf(0)
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
  val demographicsFocusedFieldState = mutableStateOf("")
  val demographicsFocusRequestFieldState = mutableStateOf("")
  val demographicsFocusRequestSourceState = mutableStateOf("")
  val demographicsFocusRequestTokenState = mutableIntStateOf(0)
  val demographicsNameKeyboardVisibleState = mutableStateOf(false)
  val demographicsNameKeyboardCursorRowState = mutableIntStateOf(DEMOGRAPHICS_NAME_KEYBOARD_DEFAULT_ROW)
  val demographicsNameKeyboardCursorColumnState = mutableIntStateOf(DEMOGRAPHICS_NAME_KEYBOARD_DEFAULT_COLUMN)
  val demographicsDraftGenderState = mutableStateOf("")
  val demographicsDraftHandednessState = mutableStateOf("")
  val demographicsDraftSignatureState = mutableStateOf("")
  val demographicsDraftConsentState = mutableStateOf(false)
  val priorBigRedButtonExperienceAnswerState = mutableStateOf("")
  val priorBigRedButtonExperienceTimestampState = mutableStateOf("")
  val priorBigRedButtonExperienceOptionsReadyState = mutableStateOf(false)
  val priorBigRedButtonExperienceFeedbackReadyState = mutableStateOf(false)
  val priorBigRedButtonExperiencePreStartReadyState = mutableStateOf(false)
  val priorBigRedButtonExperienceStartBlockedReasonState = mutableStateOf("")
  val finalEndLikertState = mutableIntStateOf(0)
  val finalEndFeedbackState = mutableStateOf("")
  val finalEndSelectionLockedState = mutableStateOf(false)
  val finalEndQuestionAudioReadyState = mutableStateOf(false)
  val finalExtraPressCountState = mutableIntStateOf(0)
  val finalExtraPromptVisibleState = mutableStateOf(false)
  val polarStatusState: MutableState<PolarStatusSnapshot> = mutableStateOf(PolarStatusSnapshot())
  val polarEcgPreviewSamplesState: MutableState<List<Int>> = mutableStateOf(emptyList())
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
  private var localizationManifestSha256 = ""
  private var polarClient: PolarH10HeartRateClient? = null
  private val conditionFeedbackSources = mutableMapOf<Int, String>()
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
  private var nameKeyboardEntity: Entity? = null
  private var isdkSystem: IsdkSystem? = null
  private var isdkPointerObserverRegistered = false
  private var conditionPressArmedRealtimeMs = 0L
  private var nextAllowedPressRealtimeMs = 0L
  private var buttonPressMotionSequence = 0
  private var lastButtonPressMotionStartRealtimeMs = Long.MIN_VALUE
  private var lastControllerInputRealtimeMs = Long.MIN_VALUE
  private var lastHandInputRealtimeMs = Long.MIN_VALUE
  private var autoValidationEnabled = false
  private var physicalPressValidationEnabled = false
  private var panelSmokeEnabled = false
  private var fastControllerFlowEnabled = false
  private var keyeventValidationEnabled = false
  private var demographicsKeyboardValidationEnabled = false
  private var demographicsKeyboardValidationSessionId = ""
  private var audioRigStressEnabled = false
  private var visualGlowValidationMode = ""
  private var autoValidationStarted = false
  private var fastControllerFlowStarted = false
  private var panelGlitchToken = 0
  private var rednessConversionChoreographyToken = 0
  private var rednessCarriedForwardVas0To100 = 50
  private var rednessCarriedForwardLikert1To7 = 4
  private var rednessPostConversionEdited = false
  private var rednessPostConversionEditScale = "none"
  private var softKeyboardRequestGeneration = 0
  private var activeSoftKeyboardReason: String? = null
  private var activeSoftKeyboardMode: String? = null
  private var keyboardFieldContractLogged = false
  private val polarEcgPreviewBuffer = ArrayDeque<Int>()
  private var finalEndSelectionLocked = false
  private var finalEndConfirmationResponse: FinalEndConfirmationResponse? = null
  private val finalExtraPressEvents = mutableListOf<FinalExtraPressEvent>()
  private var finalExtraPressStartedIso = ""
  private var finalExtraPressCompletedIso = ""
  private var finalExtraPressStartedElapsedMs = 0L
  private var finalExtraPressCompletedElapsedMs = 0L
  private var finalExtraPressArmedRealtimeMs = 0L
  private var finalExtraPromptToken = 0
  private var finalEndQuestionPromptToken = 0
  private var priorButtonExperiencePromptToken = 0
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
    demographicsKeyboardValidationEnabled =
        intent?.getBooleanExtra(DEMOGRAPHICS_KEYBOARD_VALIDATION_EXTRA, false) == true
    audioRigStressEnabled = intent?.getBooleanExtra(AUDIO_RIG_STRESS_EXTRA, false) == true
    visualGlowValidationMode =
        intent?.getStringExtra(VISUAL_GLOW_VALIDATION_EXTRA)?.lowercase(Locale.US)?.trim().orEmpty()
    val launchLanguage = studyLanguageFromIntent(intent)
    if (startsWithoutParticipantLanguageChoice() || launchLanguage != null) {
      selectedLanguageState.value = launchLanguage ?: StudyLanguage.English
      stageState.value = StudyStage.ConsentDemographics
    }
    localizationManifestSha256 = assetSha256OrEmpty(LOCALIZED_AUDIO_MANIFEST_ASSET)
    isolateAudioRigStressValidationModes("on_create")
    requestScenePermissionIfNeeded()
    initializeEcgProtocol()
    logQuestionnaireContract()
    logOptionalLslContract()
    logAgentIntegrationContract()
    requestBlePermissionsIfNeeded()
    startPolarScanIfPermitted()
    Log.i(
        TAG,
        "BRB_STUDY_CREATED sessionId=$sessionId language=${selectedLanguageState.value.code} autoValidation=$autoValidationEnabled physicalPressValidation=$physicalPressValidationEnabled panelSmoke=$panelSmokeEnabled fastControllerFlow=$fastControllerFlowEnabled keyeventValidation=$keyeventValidationEnabled demographicsKeyboardValidation=$demographicsKeyboardValidationEnabled audioRigStress=$audioRigStressEnabled visualGlowValidationMode=${visualGlowValidationMode.ifBlank { "none" }} localizedAudioManifestSha256=${localizationManifestSha256.ifBlank { "missing" }}",
    )
    handleDemographicsKeyboardValidationIntent(intent)
    handleAudioRigStressIntent(intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleDemographicsKeyboardValidationIntent(intent)
    handleAudioRigStressIntent(intent)
  }

  override fun dispatchKeyEvent(event: KeyEvent): Boolean {
    if (handleHandTrackingSystemButtonSuppression(event)) {
      return true
    }
    if (event.action == KeyEvent.ACTION_DOWN) {
      markControllerInput("dispatch_key_${event.keyCode}")
    }
    if (handleDemographicsHardwareKeyEvent(event)) {
      return true
    }
    return super.dispatchKeyEvent(event)
  }

  fun selectStudyLanguage(language: StudyLanguage, source: String = "participant") {
    selectedLanguageState.value = language
    languageSelectionFocusIndexState.intValue = if (language == StudyLanguage.Japanese) 1 else 0
    Log.i(
        TAG,
        "BRB_LANGUAGE_SELECTED code=${language.code} label=${language.label} source=$source localizedAudioManifestSha256=${localizationManifestSha256.ifBlank { "missing" }}",
    )
    if (stageState.value == StudyStage.LanguageSelection) {
      logQuestionnaireStageComplete("language_selection", 0, "consent_demographics")
      stageState.value = StudyStage.ConsentDemographics
      logQuestionnaireStageOpen("consent_demographics", 0, "language_selected")
    }
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
            Transform(
                headsetRadialPanelPose(
                    QUESTIONNAIRE_PANEL_RADIAL_ANGLE_DEGREES,
                    QUESTIONNAIRE_PANEL_Y_METERS,
                    QUESTIONNAIRE_PANEL_RADIAL_DISTANCE_METERS,
                ),
            ),
            Visible(false),
        )
    nameKeyboardEntity =
        Entity.create(
            Panel(R.id.keyboard_panel),
            Transform(
                headsetRadialPanelPose(
                    NAME_KEYBOARD_PANEL_RADIAL_ANGLE_DEGREES,
                    NAME_KEYBOARD_PANEL_Y_METERS,
                    NAME_KEYBOARD_PANEL_RADIAL_DISTANCE_METERS,
                ),
            ),
            Visible(false),
        )
    Log.i(
        TAG,
        "BRB_STUDY_READY passthrough=true buttonPanel=transparent-hit-target buttonVisual=model-asset model=$BUTTON_MODEL_ASSET_URI questionnairePanel=popup keyboard=app_owned_pop_out_name_keyboard",
    )
    logButtonSpatialLayout()
    logQuestionnairePanelLayout("scene_ready")
    configureControllerContactInput()
    mainHandler.postDelayed(
        {
          if (stageState.value == StudyStage.LanguageSelection) {
            logQuestionnaireStageOpen("language_selection", 0, "scene_ready")
            showQuestionnairePanel(PANEL_TRANSITION_LANGUAGE_SELECTION)
          } else if (stageState.value == StudyStage.ConsentDemographics) {
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
        ComposeViewPanelRegistration(
            R.id.keyboard_panel,
            composeViewCreator = { _, context ->
              ComposeView(context).apply { setContent { NameKeyboardPopupPanel(this@BigRedButtonStudyActivity) } }
            },
            settingsCreator = {
              UIPanelSettings(
                  shape = QuadShapeOptions(width = NAME_KEYBOARD_PANEL_WIDTH_METERS, height = NAME_KEYBOARD_PANEL_HEIGHT_METERS),
                  style = PanelStyleOptions(themeResourceId = R.style.ThemeTransparent),
                  display =
                      DpDisplayOptions(
                          width = NAME_KEYBOARD_PANEL_DISPLAY_WIDTH_DP,
                          height = NAME_KEYBOARD_PANEL_DISPLAY_HEIGHT_DP,
                          dpi = 520,
                      ),
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
            age = normalizeAgeSliderInput(age).ifBlank { age.trim() },
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
    logQuestionnaireStageComplete(
        "consent_demographics",
        0,
        "prior_big_red_button_experience",
    )
    transitionQuestionnaireOutThenShowPreButtonExperienceQuestion()
  }

  fun setPriorBigRedButtonExperienceAnswer(answer: String, source: String = "participant") {
    val normalized = answer.lowercase(Locale.US).trim()
    if (normalized !in setOf("yes", "no")) {
      return
    }
    if (!priorBigRedButtonExperienceOptionsReadyState.value) {
      Log.i(
          TAG,
          "BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=$normalized source=$source reason=question_audio_active",
      )
      return
    }
    if (priorBigRedButtonExperienceAnswerState.value.isNotBlank()) {
      Log.i(
          TAG,
          "BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=$normalized source=$source reason=answer_locked lockedAnswer=${priorBigRedButtonExperienceAnswerState.value}",
      )
      return
    }
    priorBigRedButtonExperienceAnswerState.value = normalized
    priorBigRedButtonExperienceTimestampState.value = nowIso()
    priorBigRedButtonExperienceFeedbackReadyState.value = false
    priorBigRedButtonExperiencePreStartReadyState.value = false
    priorBigRedButtonExperienceStartBlockedReasonState.value = ""
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER answer=$normalized source=$source displayLocation=button_counter_panel locked=true otherOptionsHidden=true",
    )
    if (hiddenValidationModeEnabled() || fastControllerFlowEnabled || keyeventValidationEnabled) {
      priorBigRedButtonExperienceFeedbackReadyState.value = true
      priorBigRedButtonExperiencePreStartReadyState.value = true
      Log.i(
          TAG,
          "BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=$normalized validationShortcut=true startEnabled=true preStartInstructionsSkipped=true",
      )
      Log.i(
          TAG,
          "BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_READY answer=$normalized promptToken=$priorButtonExperiencePromptToken validationShortcut=true startVisible=true startEnabled=true",
      )
    } else {
      playPriorButtonExperienceFeedbackCue(normalized, priorButtonExperiencePromptToken)
    }
  }

  fun startExperimentFromPriorButtonExperienceQuestion(): Boolean {
    val answer = priorBigRedButtonExperienceAnswerState.value
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_START_CLICK answer=$answer feedbackReady=${priorBigRedButtonExperienceFeedbackReadyState.value} preStartReady=${priorBigRedButtonExperiencePreStartReadyState.value} stage=${stageState.value.name.lowercase(Locale.US)}",
    )
    if (answer !in setOf("yes", "no")) {
      priorBigRedButtonExperienceStartBlockedReasonState.value = "Choose Yes or No first."
      Log.i(TAG, "BRB_PRIOR_BUTTON_EXPERIENCE_START_BLOCKED answer=$answer reason=no_answer")
      return false
    }
    if (!priorBigRedButtonExperienceFeedbackReadyState.value) {
      priorBigRedButtonExperienceStartBlockedReasonState.value = "Please wait for the response audio to finish."
      Log.i(
          TAG,
          "BRB_PRIOR_BUTTON_EXPERIENCE_START_BLOCKED answer=$answer reason=feedback_audio_active",
      )
      return false
    }
    if (!priorBigRedButtonExperiencePreStartReadyState.value) {
      priorBigRedButtonExperienceStartBlockedReasonState.value = "Please wait for the final instructions to finish."
      Log.i(
          TAG,
          "BRB_PRIOR_BUTTON_EXPERIENCE_START_BLOCKED answer=$answer reason=pre_start_instructions_active",
      )
      return false
    }
    if (participantPhysiologyEvidenceExpected() && !isPolarPhysiologyReady()) {
      val status = polarStatusState.value
      Log.w(
          TAG,
          "BRB_POLAR_START_WARNING mode=${validationModeLabel()} continuing=true participantPhysiologyEvidenceRequired=true state=${status.state} detected=${status.detected} connected=${status.connected} pmdReady=${status.pmdReady} ecgStreaming=${status.ecgStreaming} ecgSamples=${status.ecgSampleCount} ecgHz=${status.ecgSampleRateHz}",
      )
    }
    if (!participantPhysiologyEvidenceExpected()) {
      Log.i(TAG, "BRB_POLAR_START_BYPASS mode=${validationModeLabel()} participantPhysiologyEvidenceRequired=false")
    }
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_SAVED answer=$answer timestamp=${priorBigRedButtonExperienceTimestampState.value} shownBeforeCondition=1",
    )
    logQuestionnaireStageComplete(
        "prior_big_red_button_experience",
        1,
        conditionStageId(1),
    )
    priorBigRedButtonExperienceStartBlockedReasonState.value = ""
    beginCondition(1)
    return true
  }

  private fun participantPhysiologyEvidenceExpected(): Boolean {
    return !autoValidationEnabled && !fastControllerFlowEnabled && !keyeventValidationEnabled
  }

  fun missingPolarStartWarningText(): String {
    return if (participantPhysiologyEvidenceExpected() && !isPolarPhysiologyReady()) {
      t("polar_start_warning")
    } else {
      ""
    }
  }

  private fun isPolarPhysiologyReady(): Boolean {
    val status = polarStatusState.value
    return status.streaming &&
        status.heartRateBpm > 0 &&
        status.rrIntervalCount > 0 &&
        status.pmdReady &&
        status.ecgStreaming &&
        status.ecgSampleCount > 0 &&
        status.ecgSampleRateHz == ECG_SAMPLE_RATE_HZ
  }

  fun recordButtonPress(inputSource: String = PRESS_SOURCE_UNSPECIFIED) {
    if (stageState.value == StudyStage.FinalExtraPresses) {
      recordFinalExtraButtonPress(inputSource)
      return
    }
    val run = activeRun ?: return
    if (stageState.value != StudyStage.ConditionRunning) {
      return
    }

    val nowRealtimeNs = SystemClock.elapsedRealtimeNanos()
    val nowRealtimeMs = nowRealtimeNs / 1_000_000L
    val elapsedNs = nowRealtimeNs - run.startedElapsedNs
    val elapsedMs = elapsedNs / 1_000_000L
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
            elapsedNs = elapsedNs,
            eventElapsedRealtimeNs = nowRealtimeNs,
            conditionStartElapsedRealtimeNs = run.startedElapsedNs,
            unixTimeMs = System.currentTimeMillis(),
            isoTimestamp = nowIso(),
            inputSource = inputSource,
            validationAutomation =
                inputSource == PRESS_SOURCE_AUTO_VALIDATION ||
                    inputSource == PRESS_SOURCE_CONTROLLER_EMULATED_VALIDATION ||
                    inputSource == PRESS_SOURCE_AUDIO_RIG_STRESS,
            feedbackSource = run.feedbackSource,
            physiologySource = run.physiologySource,
        )
    run.pressEvents.add(event)
    buttonPressCountState.intValue = run.pressEvents.size
    Log.i(
        TAG,
        "BRB_BUTTON_PRESS condition=${run.conditionNumber} index=${event.pressIndex} source=${event.inputSource} validationAutomation=${event.validationAutomation} elapsedMs=${event.elapsedMs} elapsedNs=${event.elapsedNs} feedbackSource=${event.feedbackSource} physiologySource=${event.physiologySource}",
    )
    playButtonPressedAnimation()
    playButtonPressCue()
    nextAllowedPressRealtimeMs = nowRealtimeMs + BUTTON_PRESS_COOLDOWN_MS
  }

  private fun recordFinalExtraButtonPress(inputSource: String = PRESS_SOURCE_UNSPECIFIED) {
    if (stageState.value != StudyStage.FinalExtraPresses) {
      return
    }

    val nowRealtimeMs = SystemClock.elapsedRealtime()
    if (finalExtraPromptVisibleState.value || finalExtraPressStartedElapsedMs <= 0L) {
      Log.i(
          TAG,
          "BRB_FINAL_EXTRA_BUTTON_PRESS_SUPPRESSED reason=prompt_audio_active source=$inputSource elapsedMs=0",
      )
      return
    }
    val elapsedMs = nowRealtimeMs - finalExtraPressStartedElapsedMs
    if (nowRealtimeMs < finalExtraPressArmedRealtimeMs) {
      Log.i(
          TAG,
          "BRB_FINAL_EXTRA_BUTTON_PRESS_SUPPRESSED reason=startup_contact_suppression source=$inputSource elapsedMs=$elapsedMs",
      )
      return
    }
    if (nowRealtimeMs < nextAllowedPressRealtimeMs) {
      Log.i(
          TAG,
          "BRB_FINAL_EXTRA_BUTTON_PRESS_SUPPRESSED reason=press_cooldown source=$inputSource elapsedMs=$elapsedMs",
      )
      return
    }

    val event =
        FinalExtraPressEvent(
            pressIndex = finalExtraPressEvents.size + 1,
            elapsedMs = elapsedMs,
            unixTimeMs = System.currentTimeMillis(),
            isoTimestamp = nowIso(),
            inputSource = inputSource,
            validationAutomation =
                inputSource == PRESS_SOURCE_AUTO_VALIDATION ||
                    inputSource == PRESS_SOURCE_CONTROLLER_EMULATED_VALIDATION ||
                    inputSource == PRESS_SOURCE_AUDIO_RIG_STRESS,
        )
    finalExtraPressEvents.add(event)
    finalExtraPressCountState.intValue = finalExtraPressEvents.size
    buttonPressCountState.intValue = finalExtraPressEvents.size
    Log.i(
        TAG,
        "BRB_FINAL_EXTRA_BUTTON_PRESS index=${event.pressIndex} requirement=$FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT source=${event.inputSource} validationAutomation=${event.validationAutomation} elapsedMs=${event.elapsedMs}",
    )
    playButtonPressedAnimation()
    playButtonPressCue()
    nextAllowedPressRealtimeMs = nowRealtimeMs + BUTTON_PRESS_COOLDOWN_MS

    if (finalExtraPressEvents.size >= FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT) {
      finalExtraPressCompletedIso = nowIso()
      finalExtraPressCompletedElapsedMs = nowRealtimeMs
      Log.i(
          TAG,
          "BRB_FINAL_EXTRA_BUTTON_PRESS_COMPLETE count=${finalExtraPressEvents.size} requirement=$FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT",
      )
      logQuestionnaireStageComplete("final_extra_presses_optional", 0, "complete_export_summary")
      finishExperiment()
    }
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

  fun setRednessVas(value0To100: Float, source: String = "participant_vas") {
    if (rednessConversionChoreographyState.value != null) {
      return
    }
    pictographicRednessVasState.floatValue = value0To100.coerceIn(0f, 100f)
    if (pictographicRednessConvertedState.value && activeConditionState.intValue == 2) {
      recordRednessPostConversionEdit("vas", source)
    }
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
    val wasConverted = pictographicRednessConvertedState.value
    pictographicRednessLikertState.intValue = value
    if (convertIfNeeded && !pictographicRednessConvertedState.value && activeConditionState.intValue == 2) {
      convertRednessLikertToVas("participant_selection")
    } else {
      if (wasConverted && activeConditionState.intValue == 1) {
        recordRednessPostConversionEdit("likert", "participant_likert_selection")
      }
      playQuestionnaireChoiceCue()
    }
  }

  private fun recordRednessPostConversionEdit(scale: String, source: String) {
    if (!pictographicRednessConvertedState.value || rednessConversionChoreographyState.value != null) {
      return
    }
    val normalizedScale = scale.ifBlank { "unknown" }
    rednessPostConversionEditScale =
        when {
          rednessPostConversionEditScale == "none" -> normalizedScale
          rednessPostConversionEditScale == normalizedScale -> normalizedScale
          else -> "multiple"
        }
    rednessPostConversionEdited = true
    Log.i(
        TAG,
        "BRB_REDNESS_POST_CONVERSION_EDIT condition=${activeConditionState.intValue} scale=$normalizedScale source=$source vas=${pictographicRednessVasState.floatValue.toInt()} likert=${pictographicRednessLikertState.intValue} carriedVas=$rednessCarriedForwardVas0To100 carriedLikert=$rednessCarriedForwardLikert1To7 finalMatchesCarried=${rednessFinalMatchesCarriedForward()}",
    )
  }

  private fun rednessFinalMatchesCarriedForward(
      finalVas0To100: Int = pictographicRednessVasState.floatValue.toInt(),
      finalLikert1To7: Int = pictographicRednessLikertState.intValue,
  ): Boolean {
    if (!pictographicRednessConvertedState.value) {
      return true
    }
    return finalVas0To100 == rednessCarriedForwardVas0To100 &&
        finalLikert1To7 == rednessCarriedForwardLikert1To7
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
    rednessCarriedForwardVas0To100 = pictographicRednessVasState.floatValue.toInt()
    rednessCarriedForwardLikert1To7 = pictographicRednessLikertState.intValue
    rednessPostConversionEdited = false
    rednessPostConversionEditScale = "none"
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION condition=${activeConditionState.intValue} order=$REDNESS_ORDER_VAS_THEN_LIKERT from=vas to=likert reason=$reason choreographed=$choreographed vas=${pictographicRednessVasState.floatValue.toInt()} likert=${pictographicRednessLikertState.intValue} descriptor=${rednessDescriptor(pictographicRednessLikertState.intValue)} carriedVas=$rednessCarriedForwardVas0To100 carriedLikert=$rednessCarriedForwardLikert1To7",
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
    rednessCarriedForwardVas0To100 = pictographicRednessVasState.floatValue.toInt()
    rednessCarriedForwardLikert1To7 = pictographicRednessLikertState.intValue
    rednessPostConversionEdited = false
    rednessPostConversionEditScale = "none"
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION condition=${activeConditionState.intValue} order=$REDNESS_ORDER_LIKERT_THEN_VAS from=likert to=vas reason=$reason choreographed=$choreographed likert=${pictographicRednessLikertState.intValue} descriptor=${rednessDescriptor(pictographicRednessLikertState.intValue)} vas=${pictographicRednessVasState.floatValue.toInt()} carriedVas=$rednessCarriedForwardVas0To100 carriedLikert=$rednessCarriedForwardLikert1To7",
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
    val finalRednessVas = rednessVas.toInt()
    val finalRednessLikert = rednessLikert
    val rednessMatchesCarried =
        rednessFinalMatchesCarriedForward(
            finalVas0To100 = finalRednessVas,
            finalLikert1To7 = finalRednessLikert,
        )
    val rednessChangedAfterConversion =
        pictographicRednessConvertedState.value && !rednessMatchesCarried
    run.pictographic =
        PictographicResponse(
            conditionNumber = run.conditionNumber,
            feltCloseness0To100 = closeness.toInt(),
            selfButtonDistanceUnits = selfButtonDistanceUnits(closeness),
            feltPresence0To100 = presence.toInt(),
            buttonPresenceRadiusUnits = buttonPresenceRadiusUnits(presence),
            rednessVas0To100 = finalRednessVas,
            rednessLikert1To7 = finalRednessLikert,
            rednessLikertDescriptor = rednessDescriptor(finalRednessLikert),
            rednessScaleOrder = rednessScaleOrderForCondition(run.conditionNumber),
            rednessCarriedForwardVas0To100 = rednessCarriedForwardVas0To100,
            rednessCarriedForwardLikert1To7 = rednessCarriedForwardLikert1To7,
            rednessCarriedForwardLikertDescriptor = rednessDescriptor(rednessCarriedForwardLikert1To7),
            rednessPostConversionEdited = rednessPostConversionEdited,
            rednessPostConversionEditScale = rednessPostConversionEditScale,
            rednessChangedAfterConversion = rednessChangedAfterConversion,
            rednessFinalMatchesCarriedForward = rednessMatchesCarried,
            timestampIso = nowIso(),
        )
    ipqAnswersState.clear()
    stageState.value = StudyStage.PresenceQuestionnaire
    logQuestionnaireStageComplete(
        postConditionStageId(run.conditionNumber, "pictographic"),
        run.conditionNumber,
        postConditionStageId(run.conditionNumber, "presence_questionnaire"),
    )
    logQuestionnaireStageOpen(
        postConditionStageId(run.conditionNumber, "presence_questionnaire"),
        run.conditionNumber,
        "pictographic_submit",
    )
    playIpqHistoryNarration(run.conditionNumber, "pictographic_submit")
    Log.i(
        TAG,
        "BRB_PICTOGRAPHIC_SAVED condition=${run.conditionNumber} closeness=${closeness.toInt()} presence=${presence.toInt()} rednessVas=$finalRednessVas rednessLikert=$finalRednessLikert rednessOrder=${rednessScaleOrderForCondition(run.conditionNumber)} rednessCarriedVas=$rednessCarriedForwardVas0To100 rednessCarriedLikert=$rednessCarriedForwardLikert1To7 rednessPostConversionEdited=$rednessPostConversionEdited rednessPostConversionEditScale=$rednessPostConversionEditScale rednessChangedAfterConversion=$rednessChangedAfterConversion rednessFinalMatchesCarriedForward=$rednessMatchesCarried",
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
    logQuestionnaireStageComplete(
        postConditionStageId(run.conditionNumber, "presence_questionnaire"),
        run.conditionNumber,
        postConditionStageId(run.conditionNumber, "lost_opportunity"),
    )
    logQuestionnaireStageOpen(
        postConditionStageId(run.conditionNumber, "lost_opportunity"),
        run.conditionNumber,
        "presence_questionnaire_submit",
    )
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
      logQuestionnaireStageComplete(
          postConditionStageId(1, "lost_opportunity"),
          1,
          conditionStageId(2),
      )
      transitionQuestionnaireOutThenBeginCondition(2, PANEL_TRANSITION_BEFORE_CONDITION_2)
    } else {
      logQuestionnaireStageComplete(
          postConditionStageId(2, "lost_opportunity"),
          2,
          "final_end_confirmation",
      )
      showFinalEndQuestionnaire()
    }
  }

  private fun showFinalEndQuestionnaire() {
    releasePlayer()
    setButtonVisible(false)
    val promptToken = ++finalEndQuestionPromptToken
    finalEndSelectionLocked = false
    finalEndSelectionLockedState.value = false
    finalEndQuestionAudioReadyState.value = false
    finalEndLikertState.intValue = 0
    finalEndFeedbackState.value = ""
    finalExtraPressCountState.intValue = 0
    finalExtraPromptVisibleState.value = false
    buttonPressCountState.intValue = 0
    stageState.value = StudyStage.FinalEndQuestionnaire
    logQuestionnaireStageOpen("final_end_confirmation", 0, PANEL_TRANSITION_FINAL_END)
    showQuestionnairePanel(PANEL_TRANSITION_FINAL_END) {
      maybePlayFinalEndConfirmationQuestionCue(promptToken)
    }
    Log.i(TAG, "BRB_FINAL_END_CONFIRMATION_SHOWN scale=1_10 boxes=10 optionsVisible=false questionAudio=final_end_confirmation_question_prompt.mp3")
    continueValidationAtFinalEndQuestionnaire()
  }

  fun setFinalEndLikert(value1To10: Int, source: String = "participant") {
    if (finalEndSelectionLocked || stageState.value != StudyStage.FinalEndQuestionnaire) {
      return
    }
    if (!finalEndQuestionAudioReadyState.value) {
      Log.i(
          TAG,
          "BRB_FINAL_END_CONFIRMATION_SELECTION_BLOCKED rating=${value1To10.coerceIn(1, 10)} source=$source reason=question_audio_active optionsVisible=false",
      )
      return
    }
    finalEndLikertState.intValue = value1To10.coerceIn(1, 10)
    Log.i(
        TAG,
        "BRB_FINAL_END_CONFIRMATION_FOCUS rating=${finalEndLikertState.intValue} source=$source",
    )
    playQuestionnaireChoiceCue()
  }

  fun submitFinalEndConfirmationSelection(source: String = "participant"): Boolean {
    if (finalEndSelectionLocked || stageState.value != StudyStage.FinalEndQuestionnaire) {
      return false
    }
    if (!finalEndQuestionAudioReadyState.value) {
      Log.i(
          TAG,
          "BRB_FINAL_END_CONFIRMATION_SUBMIT_BLOCKED source=$source reason=question_audio_active optionsVisible=false",
      )
      return false
    }
    val rating = finalEndLikertState.intValue
    if (rating !in 1..10) {
      return false
    }
    finalEndSelectionLocked = true
    finalEndSelectionLockedState.value = true
    val immediateEnd = rating == 10
    val feedback =
        if (immediateEnd) {
          finalEndConfirmation10FeedbackText()
        } else {
          finalExtraPressesPromptText()
        }
    finalEndConfirmationResponse =
        FinalEndConfirmationResponse(
            question = finalEndConfirmationQuestionText(),
            rating1To10 = rating,
            immediateEnd = immediateEnd,
            selectedTimestampIso = nowIso(),
            feedbackText = feedback,
            extraPressRequirement = if (immediateEnd) 0 else FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT,
        )
    finalEndFeedbackState.value = if (immediateEnd) feedback else ""
    Log.i(
        TAG,
        "BRB_FINAL_END_CONFIRMATION_SAVED rating=$rating immediateEnd=$immediateEnd source=$source extraPressRequirement=${if (immediateEnd) 0 else FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT}",
    )
    logQuestionnaireStageComplete(
        "final_end_confirmation",
        0,
        if (immediateEnd) "complete_export_summary" else "final_extra_presses_optional",
    )
    if (immediateEnd) {
      playFinalEndConfirmation10FeedbackCue()
      if (audioRigStressEnabled) {
        Log.i(TAG, "BRB_FINAL_END_CONFIRMATION_FINISH_SUPPRESSED reason=audio_rig_stress")
      } else {
        val holdMs = localizedCueHoldMs(AUDIO_ID_FINAL_END_10_FEEDBACK, FINAL_END_CONFIRMATION_FEEDBACK_HOLD_MS)
        mainHandler.postDelayed(
            {
              if (stageState.value == StudyStage.FinalEndQuestionnaire && finalEndLikertState.intValue == 10) {
                finishExperiment()
              }
            },
            holdMs,
        )
      }
    } else {
      playQuestionnaireChoiceCue()
      transitionQuestionnaireOutThenBeginFinalExtraPresses()
    }
    return true
  }

  private fun transitionQuestionnaireOutThenBeginFinalExtraPresses() {
    setQuestionnaireVisible(true)
    playQuestionnaireOutroCue(PANEL_TRANSITION_FINAL_EXTRA_PRESSES) {
      setQuestionnaireVisible(false)
      beginFinalExtraPressChallenge()
    }
  }

  private fun beginFinalExtraPressChallenge() {
    releasePlayer()
    val promptToken = ++finalExtraPromptToken
    finalExtraPressEvents.clear()
    finalExtraPressCountState.intValue = 0
    buttonPressCountState.intValue = 0
    finalExtraPressStartedIso = ""
    finalExtraPressCompletedIso = ""
    finalExtraPressStartedElapsedMs = 0L
    finalExtraPressCompletedElapsedMs = 0L
    finalExtraPressArmedRealtimeMs = Long.MAX_VALUE
    nextAllowedPressRealtimeMs = finalExtraPressArmedRealtimeMs
    activeConditionState.intValue = 0
    conditionElapsedTextState.value = ""
    buttonContactLatch.clear()
    heartbeatPulseDriver.reset()
    heartbeatFlashToken += 1
    buttonHeartbeatFlashState.value = false
    buttonHeartbeatFlashFrameState.intValue = 0
    setButtonGlowPulse(0f)
    stageState.value = StudyStage.FinalExtraPresses
    logQuestionnaireStageOpen("final_extra_presses_optional", 0, PANEL_TRANSITION_FINAL_EXTRA_PRESSES)
    finalExtraPromptVisibleState.value = true
    setFinalExtraPromptPanelVisible(true)
    val holdMs = localizedCueHoldMs(AUDIO_ID_FINAL_EXTRA_PRESSES, FINAL_EXTRA_PRESSES_PROMPT_HOLD_MS)
    Log.i(
        TAG,
        "BRB_FINAL_EXTRA_BUTTON_CHALLENGE_START requirement=$FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT prompt=\"${finalExtraPressesPromptText()}\" promptVisible=true promptHoldMs=$holdMs buttonModelVisible=false",
    )
    playFinalExtraPressPromptCue()
    mainHandler.postDelayed(
        {
          revealFinalExtraPressButtonAfterPrompt(promptToken)
        },
        holdMs,
    )
  }

  private fun revealFinalExtraPressButtonAfterPrompt(promptToken: Int) {
    if (promptToken != finalExtraPromptToken || stageState.value != StudyStage.FinalExtraPresses) {
      return
    }
    finalExtraPromptVisibleState.value = false
    val nowRealtimeMs = SystemClock.elapsedRealtime()
    finalExtraPressStartedIso = nowIso()
    finalExtraPressStartedElapsedMs = nowRealtimeMs
    finalExtraPressArmedRealtimeMs = nowRealtimeMs + STARTUP_CONTACT_SUPPRESSION_MS
    nextAllowedPressRealtimeMs = finalExtraPressArmedRealtimeMs
    setButtonVisible(true)
    logButtonSpatialLayout()
    val holdMs = localizedCueHoldMs(AUDIO_ID_FINAL_EXTRA_PRESSES, FINAL_EXTRA_PRESSES_PROMPT_HOLD_MS)
    Log.i(
        TAG,
        "BRB_FINAL_EXTRA_PROMPT_HIDDEN reason=audio_complete promptHoldMs=$holdMs buttonModelVisible=true counterOnly=true",
    )
  }

  private fun beginCondition(conditionNumber: Int) {
    releasePlayer()
    val audioId = if (conditionNumber == 1) AUDIO_ID_CONDITION_1 else AUDIO_ID_CONDITION_2
    val run =
        ConditionRun(
            conditionNumber = conditionNumber,
            label = "Condition $conditionNumber",
            audioAssetPath = if (conditionNumber == 1) CONDITION_1_AUDIO else CONDITION_2_AUDIO,
            audioId = audioId,
        )
    run.feedbackSource = conditionFeedbackSources[conditionNumber] ?: ECG_SOURCE_SIMULATED
    run.physiologySource = ECG_SOURCE_REAL_POLAR
    run.ecgSource = run.physiologySource
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

    val asset = openConditionAudioAsset(audioId, run.audioAssetPath)
    run.audioLocaleCode = asset.localeCode
    run.audioFallbackToEnglish = asset.fallbackToEnglish
    mediaPlayer =
        MediaPlayer().apply {
          setDataSource(asset.descriptor.fileDescriptor, asset.descriptor.startOffset, asset.descriptor.length)
          setOnCompletionListener { endConditionFromAudio() }
          prepare()
          run.audioAssetPath = asset.assetPath
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
    asset.descriptor.close()

    beginEcgConditionCapture(run)
    scheduleVisualGlowValidationFrame(run)
    scheduleAutoValidationPresses(run)
    mainHandler.removeCallbacks(ticker)
    mainHandler.post(ticker)
    Log.i(
        TAG,
        "BRB_CONDITION_START condition=$conditionNumber audio=${run.audioAssetPath} audioId=${run.audioId} language=${selectedLanguageState.value.code} audioLocale=${run.audioLocaleCode} localizedFallback=${run.audioFallbackToEnglish} durationMs=${run.audioDurationMs} isPlaying=${mediaPlayer?.isPlaying == true} feedbackSource=${run.feedbackSource} physiologySource=${run.physiologySource} ecgSource=${run.ecgSource}",
    )
    logQuestionnaireStageOpen(conditionStageId(conditionNumber), conditionNumber, "condition_start")
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
    logQuestionnaireStageComplete(
        conditionStageId(run.conditionNumber),
        run.conditionNumber,
        postConditionStageId(run.conditionNumber, "pictographic"),
    )
    logQuestionnaireStageOpen(
        postConditionStageId(run.conditionNumber, "pictographic"),
        run.conditionNumber,
        "post_condition_${run.conditionNumber}",
    )
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
    logQuestionnaireStageOpen("complete_export_summary", 0, PANEL_TRANSITION_COMPLETE)
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
    if (demographicsKeyboardValidationEnabled || !hiddenValidationModeEnabled() || autoValidationStarted) {
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
              "BRB_VISUAL_GLOW_VALIDATION mode=$visualGlowValidationMode intensity=$intensity actualGlowPath=stable_idle_model_native_lights geometrySwap=false shapeStable=true placementStable=true scaleStable=true screenshotHold=true",
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
          rednessCarriedForwardVas0To100 = pictographicRednessVasState.floatValue.toInt()
          rednessCarriedForwardLikert1To7 = pictographicRednessLikertState.intValue
          rednessPostConversionEdited = false
          rednessPostConversionEditScale = "none"
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
    if (demographicsKeyboardValidationEnabled ||
        (!fastControllerFlowEnabled && !keyeventValidationEnabled) ||
        fastControllerFlowStarted) {
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

  private fun continueValidationAtFinalEndQuestionnaire(attempt: Int = 0) {
    if (!hiddenValidationModeEnabled() && !fastControllerFlowEnabled && !keyeventValidationEnabled) {
      return
    }
    mainHandler.postDelayed(
        {
          if (stageState.value != StudyStage.FinalEndQuestionnaire) {
            return@postDelayed
          }
          if (!finalEndQuestionAudioReadyState.value) {
            if (attempt < FINAL_END_CONFIRMATION_VALIDATION_MAX_ATTEMPTS) {
              Log.i(
                  TAG,
                  "BRB_FINAL_END_CONFIRMATION_VALIDATION_WAIT attempt=$attempt reason=question_audio_active optionsVisible=false",
              )
              continueValidationAtFinalEndQuestionnaire(attempt + 1)
            } else {
              Log.w(
                  TAG,
                  "BRB_FINAL_END_CONFIRMATION_VALIDATION_ABORT reason=options_not_ready attempts=$attempt",
              )
            }
            return@postDelayed
          }
          if (fastControllerFlowEnabled || keyeventValidationEnabled) {
            repeat(10) { replayControllerDirection("final_end_confirmation", 0, "right") }
            replayControllerSubmit("final_end_confirmation", 0)
          } else {
            setFinalEndLikert(10, "validation_auto")
            submitFinalEndConfirmationSelection("validation_auto")
          }
          Log.i(
              TAG,
              "BRB_FINAL_END_CONFIRMATION_VALIDATION_SELECTED rating=10 mode=${if (keyeventValidationEnabled) "keyevent_replay" else if (fastControllerFlowEnabled) "fast_internal" else "auto_physical"}",
          )
        },
        FINAL_END_CONFIRMATION_VALIDATION_DELAY_MS,
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
      StudyStage.LanguageSelection -> {
        when (normalized) {
          "left", "up" -> languageSelectionFocusIndexState.intValue = 0
          "right", "down" -> languageSelectionFocusIndexState.intValue = 1
          else -> return false
        }
        Log.i(
            TAG,
            "BRB_CONTROLLER_DIRECTION stage=language_selection direction=$normalized focus=${languageSelectionFocusIndexState.intValue}",
        )
        playQuestionnaireNavigationCue()
        true
      }
      StudyStage.ConsentDemographics -> {
        when (demographicsFocusedFieldState.value) {
          "name" -> handleDemographicsNameKeyboardDirection(normalized, "controller_direction")
          "age" -> {
            val delta =
                when (normalized) {
                  "left" -> -1
                  "right" -> 1
                  "down" -> -10
                  "up" -> 10
                  else -> return false
                }
            setDemographicsAgeSliderValue(
                ageSliderValueOrDefault(demographicsDraftAgeState.value) + delta,
                "controller_direction",
            )
            true
          }
          else -> false
        }
      }
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
      StudyStage.FinalEndQuestionnaire -> {
        val current = finalEndLikertState.intValue.takeIf { it in 1..10 } ?: 0
        val next =
            when (normalized) {
              "left", "down" -> if (current == 0) 10 else (current - 1).coerceIn(1, 10)
              "right", "up" -> if (current == 0) 1 else (current + 1).coerceIn(1, 10)
              else -> return false
            }
        setFinalEndLikert(next, "controller_direction_$normalized")
        Log.i(
            TAG,
            "BRB_CONTROLLER_DIRECTION stage=final_end_confirmation direction=$normalized rating=${finalEndLikertState.intValue}",
        )
        true
      }
      else -> false
    }
  }

  fun submitCurrentControllerStage(): Boolean {
    return when (stageState.value) {
      StudyStage.LanguageSelection -> {
        val language =
            if (languageSelectionFocusIndexState.intValue == 1) StudyLanguage.Japanese else StudyLanguage.English
        playQuestionnaireChoiceCue()
        selectStudyLanguage(language, "controller_submit")
        true
      }
      StudyStage.ConsentDemographics -> {
        when (demographicsFocusedFieldState.value) {
          "name" -> pressSelectedDemographicsNameKeyboardKey("controller_submit")
          "age" -> {
            playQuestionnaireChoiceCue()
            logDemographicsAgeSliderConfirmed("controller_submit")
            true
          }
          else -> false
        }
      }
      StudyStage.PreButtonExperienceQuestion -> {
        val submitted = startExperimentFromPriorButtonExperienceQuestion()
        if (submitted) {
          playQuestionnaireNavigationCue()
        }
        submitted
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
      StudyStage.FinalEndQuestionnaire -> {
        playQuestionnaireNavigationCue()
        submitFinalEndConfirmationSelection("controller_submit")
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
    conditionFeedbackSources.clear()
    if (ecgAssignmentOrder == ECG_ORDER_REAL_THEN_SIMULATED) {
      conditionFeedbackSources[1] = ECG_SOURCE_REAL_POLAR
      conditionFeedbackSources[2] = ECG_SOURCE_SIMULATED
    } else {
      conditionFeedbackSources[1] = ECG_SOURCE_SIMULATED
      conditionFeedbackSources[2] = ECG_SOURCE_REAL_POLAR
    }
    Log.i(
        TAG,
        "BRB_ECG_ASSIGNMENT order=$ecgAssignmentOrder basis=feedback_source priorRealThenSimulated=${orderCounts.first} priorSimulatedThenReal=${orderCounts.second} c1Feedback=${conditionFeedbackSources[1]} c2Feedback=${conditionFeedbackSources[2]} physiologySource=$ECG_SOURCE_REAL_POLAR simulatedRrCount=${simulatedRrIntervalsMs.size}",
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
        "BRB_LSL status=disabled featureFlag=$LSL_INPUT_ENABLED role=$LSL_ROLE_DIAGNOSTIC_ONLY streamName=$LSL_DEFAULT_STREAM_NAME streamType=$LSL_DEFAULT_STREAM_TYPE channelIndex=$LSL_DEFAULT_CHANNEL_INDEX triggerThreshold01=$LSL_TRIGGER_THRESHOLD_01 risingEdgeOnly=$LSL_TRIGGER_RISING_EDGE_ONLY minimumTriggerIntervalMs=$LSL_MINIMUM_TRIGGER_INTERVAL_MS route=external_signal_samples contaminatesPressCounts=false nativeLibraryPackaged=false jniEnabled=false drivesHeartbeatBlink=false drivesButtonPresses=false",
    )
  }

  private fun logQuestionnaireContract() {
    Log.i(
        TAG,
        "BRB_QUESTIONNAIRE_CONTRACT schema=bigredbutton.questionnaire_flow.v1 transport=in_process_spatial_panel productCommunication=app_internal validationShortcutsAllowed=true validationShortcutModes=${QUESTIONNAIRE_VALIDATION_SHORTCUT_MODES.joinToString("|")} stageSequence=${QUESTIONNAIRE_STAGE_SEQUENCE.joinToString("|")} adbProductCommunication=false publicSharedStorageExchange=false overlayReturnFlow=false packageKillReturnFlow=false answersLogged=false",
    )
    logQuestionnaireStageOpen("consent_demographics", 0, "on_create")
  }

  private fun logAgentIntegrationContract() {
    Log.i(
        TAG,
        "BRB_AGENT_INTEGRATION_CONTRACT schema=bigredbutton.agent_integration.v1 sourceBrief=New-Agent-Integration-Brief.md adaptation=native_meta_spatial_sdk_in_process appPackage=$packageName unityDependency=false rustyXrBrokerRequired=false questionnaireTransport=in_process_spatial_panel directPolarPmdActive=true directLslEnabled=$LSL_INPUT_ENABLED directLslRole=$LSL_ROLE_DIAGNOSTIC_ONLY lslStreamName=$LSL_DEFAULT_STREAM_NAME lslStreamType=$LSL_DEFAULT_STREAM_TYPE lslChannelIndex=$LSL_DEFAULT_CHANNEL_INDEX lslThreshold01=$LSL_TRIGGER_THRESHOLD_01 lslMinimumIntervalMs=$LSL_MINIMUM_TRIGGER_INTERVAL_MS lslDrivesButtonPresses=false finalPressProof=controller_contact handContactSupplemental=true blinkRoute=HeartbeatPulseDriver stableButtonModel=true productPathExclusions=${AGENT_INTEGRATION_FORBIDDEN_PRODUCT_MECHANISMS.joinToString("|")} validationShortcutsAllowed=true answersLogged=false",
    )
  }

  private fun logQuestionnaireStageOpen(stageId: String, conditionNumber: Int, trigger: String) {
    Log.i(
        TAG,
        "BRB_QUESTIONNAIRE_STAGE_OPEN stageId=$stageId condition=$conditionNumber trigger=$trigger transport=in_process_spatial_panel validationMode=${validationModeLabel()} answersLogged=false",
    )
  }

  private fun logQuestionnaireStageComplete(stageId: String, conditionNumber: Int, nextStageId: String) {
    Log.i(
        TAG,
        "BRB_QUESTIONNAIRE_STAGE_COMPLETE stageId=$stageId condition=$conditionNumber nextStageId=$nextStageId validationMode=${validationModeLabel()} answersLogged=false",
    )
  }

  private fun conditionStageId(conditionNumber: Int): String = "condition_$conditionNumber"

  private fun postConditionStageId(conditionNumber: Int, suffix: String): String =
      "post_condition_${conditionNumber}_$suffix"

  override fun onPolarStatus(status: PolarStatusSnapshot) {
    polarStatusState.value = status
    if (!status.ecgStreaming && status.ecgSampleCount == 0) {
      clearPolarEcgPreview()
    }
  }

  override fun onPolarRrMeasurement(measurement: PolarRrMeasurement) {
    if (stageState.value != StudyStage.ConditionRunning) {
      return
    }
    val run = activeRun ?: return
    measurement.rrIntervalsMs.forEachIndexed { index, rrMs ->
      val feedbackDelayMs = index.toLong() * POLAR_RR_FEEDBACK_SPACING_MS
      val eventElapsedNs = measurement.elapsedRealtimeNs + feedbackDelayMs * 1_000_000L
      val elapsedNs = eventElapsedNs - run.startedElapsedNs
      val audioDurationNs = run.audioDurationMs.toLong() * 1_000_000L
      if (elapsedNs in 0L..audioDurationNs) {
        val elapsedMs = elapsedNs / 1_000_000L
        val unixTimeMs = measurement.unixTimeMs + feedbackDelayMs
        val usedForFeedback = run.feedbackSource == ECG_SOURCE_REAL_POLAR
        val event =
            PolarRrEvent(
                conditionNumber = run.conditionNumber,
                rrIndex = run.polarRrEvents.size + 1,
                elapsedMs = elapsedMs,
                elapsedNs = elapsedNs,
                unixTimeMs = unixTimeMs,
                isoTimestamp = Instant.ofEpochMilli(unixTimeMs).toString(),
                rrMs = rrMs,
                heartRateBpm = measurement.heartRateBpm,
                feedbackSource = run.feedbackSource,
                usedForFeedback = usedForFeedback,
            )
        run.polarRrEvents.add(event)
        Log.i(
            TAG,
            "BRB_POLAR_RR_EVENT condition=${event.conditionNumber} index=${event.rrIndex} feedbackSource=${event.feedbackSource} usedForFeedback=${event.usedForFeedback} rrMs=${"%.1f".format(Locale.US, event.rrMs)} elapsedMs=${event.elapsedMs} elapsedNs=${event.elapsedNs}",
        )
        if (usedForFeedback) {
          mainHandler.postDelayed(
              { triggerEcgBlink(ECG_SOURCE_REAL_POLAR, rrMs, measurement.heartRateBpm) },
              feedbackDelayMs,
          )
        }
      }
    }
  }

  override fun onPolarEcgMeasurement(measurement: PolarEcgMeasurement) {
    updatePolarEcgPreview(measurement.samples)
    val run = activeRun ?: return
    if (stageState.value != StudyStage.ConditionRunning || run.physiologySource != ECG_SOURCE_REAL_POLAR) {
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

  private fun updatePolarEcgPreview(samples: List<PolarEcgSample>) {
    if (samples.isEmpty()) {
      return
    }
    val snapshot =
        synchronized(polarEcgPreviewBuffer) {
          samples.forEach { sample ->
            polarEcgPreviewBuffer.addLast(sample.microVolts)
            while (polarEcgPreviewBuffer.size > POLAR_ECG_PREVIEW_SAMPLE_COUNT) {
              polarEcgPreviewBuffer.removeFirst()
            }
          }
          polarEcgPreviewBuffer.toList()
        }
    mainHandler.post { polarEcgPreviewSamplesState.value = snapshot }
  }

  private fun clearPolarEcgPreview() {
    val hadSamples =
        synchronized(polarEcgPreviewBuffer) {
          val hadSamples = polarEcgPreviewBuffer.isNotEmpty()
          polarEcgPreviewBuffer.clear()
          hadSamples
        }
    if (hadSamples || polarEcgPreviewSamplesState.value.isNotEmpty()) {
      mainHandler.post { polarEcgPreviewSamplesState.value = emptyList() }
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
        "BRB_ECG_CAPTURE_START condition=${run.conditionNumber} source=${run.ecgSource} feedbackSource=${run.feedbackSource} physiologySource=${run.physiologySource} audioDurationMs=${run.audioDurationMs} audioWindowStartMs=0 audioWindowEndMs=${run.audioDurationMs} captureStartElapsedNs=${run.ecgCaptureStartedElapsedNs} captureEndElapsedNs=${run.ecgCaptureEndedElapsedNs} sampleRateHz=${run.ecgSampleRateHz} expectedSamples=${run.ecgExpectedSampleCount} requestedMtu=${run.ecgRequestedMtu} negotiatedMtu=${run.ecgNegotiatedMtu}",
    )
  }

  private fun endEcgConditionCapture(run: ConditionRun) {
    run.ecgCaptureEndedElapsedMs = run.startedElapsedMs + run.audioDurationMs
    run.ecgCaptureEndedElapsedNs = run.startedElapsedNs + run.audioDurationMs.toLong() * 1_000_000L
    run.ecgCaptureDurationMs = run.audioDurationMs
    Log.i(
        TAG,
        "BRB_ECG_CAPTURE_END condition=${run.conditionNumber} source=${run.ecgSource} feedbackSource=${run.feedbackSource} physiologySource=${run.physiologySource} audioDurationMs=${run.audioDurationMs} audioWindowStartMs=0 audioWindowEndMs=${run.audioDurationMs} captureStartElapsedNs=${run.ecgCaptureStartedElapsedNs} captureEndElapsedNs=${run.ecgCaptureEndedElapsedNs} sampleRateHz=${run.ecgSampleRateHz} expectedSamples=${run.ecgExpectedSampleCount} actualSamples=${run.ecgTimeSeriesSamples.size} captureWindowMs=${run.ecgCaptureDurationMs} firstSampleElapsedMs=${formatNullableDouble(run.ecgFirstSampleElapsedMs())} lastSampleElapsedMs=${formatNullableDouble(run.ecgLastSampleElapsedMs())}",
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

  private fun nearestEcgAlignment(run: ConditionRun, event: PressEvent): PressEcgAlignment? {
    val sample =
        run.ecgTimeSeriesSamples.minByOrNull { sample -> abs(sample.elapsedNs - event.elapsedNs) }
            ?: return null
    return PressEcgAlignment(
        sampleIndex = sample.sampleIndex,
        elapsedNs = sample.elapsedNs,
        deltaNs = sample.elapsedNs - event.elapsedNs,
    )
  }

  private fun startEcgBlinkDriver(run: ConditionRun) {
    if (visualGlowValidationMode in setOf(VISUAL_GLOW_VALIDATION_ON, VISUAL_GLOW_VALIDATION_OFF)) {
      Log.i(
          TAG,
          "BRB_VISUAL_GLOW_VALIDATION_ECG_DRIVER_SUPPRESSED condition=${run.conditionNumber} mode=$visualGlowValidationMode",
      )
      return
    }
    if (run.feedbackSource == ECG_SOURCE_SIMULATED) {
      val token = ++simulatedEcgToken
      scheduleNextSimulatedRPeak(run, token)
    }
    Log.i(
        TAG,
        "BRB_ECG_DRIVER_START condition=${run.conditionNumber} feedbackSource=${run.feedbackSource} physiologySource=${run.physiologySource} assignment=$ecgAssignmentOrder polarState=${polarStatusState.value.state}",
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
              run.feedbackSource != ECG_SOURCE_SIMULATED) {
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
        "BRB_HEARTBEAT_FLASH condition=${event.conditionNumber} source=${event.source} detector=${event.detector} frameCount=$HEARTBEAT_FLASH_FRAMES pulseDurationMs=$HEARTBEAT_PULSE_DURATION_MS pulseCurve=unity_ease_in_out_1_to_0 pulseIntensity01=${"%.3f".format(Locale.US, event.pulseIntensity01)} modelGlow=stable_idle_model_native_lights geometrySwap=false shapeStable=true placementStable=true scaleStable=true panelFallback=$MODEL_GLOW_PANEL_FALLBACK_ENABLED",
    )
  }

  fun logDemographicsTextFieldContract() {
    if (keyboardFieldContractLogged) {
      return
    }
    keyboardFieldContractLogged = true
    Log.i(
        TAG,
        "BRB_NAME_APP_KEYBOARD_CONTRACT field=name keyboardMode=text keyboardType=Text implementation=app_owned platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard keyboardPanel=keyboard_panel presentation=pop_out_spatial_panel integratedInQuestionnaire=false appearsOnTextFieldFocus=true maxChars=$DEMOGRAPHICS_NAME_MAX_CHARS rows=qwerty_with_space_backspace_next nativeLikeRows=true prerenderedPreview=true movablePanel=true closeToParticipant=left_of_questionnaire_near_user questionnaireFieldsReachable=true styledShell=brb_intake multiCharacter=true keyDownCommit=true batchedTextEventFallback=true noAutoAdvanceOnPartialName=true hardwareKeyeventFallback=true directAdbKeyeventValidation=true noSystemImeDependency=true noHiddenEditTextBridge=true sameExportField=demographics.name",
    )
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_AGE_SLIDER_CONTRACT field=age min=$DEMOGRAPHICS_AGE_MIN max=$DEMOGRAPHICS_AGE_MAX step=1 platformControl=ComposeSlider inputOwner=composeSlider keyboardTarget=none sameExportField=demographics.age styledShell=brb_intake noImeOwner=true",
    )
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_LAYOUT noScroll=true compact=true signaturePadHeightDp=142 startButtonHeightDp=48",
    )
  }

  private fun logKeyeventValidationKeyboardBootstrap() {
    logDemographicsTextFieldContract()
    requestDemographicsTextInputFocus("name", "validation_bootstrap")
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=validation_bootstrap value=${demographicsDraftAgeState.value.ifBlank { "unset" }} min=$DEMOGRAPHICS_AGE_MIN max=$DEMOGRAPHICS_AGE_MAX step=1 platformControl=ComposeSlider inputOwner=composeSlider",
    )
  }

  fun cleanDemographicsTextInput(fieldId: String, raw: String, keyboardMode: String): String {
    return if (fieldId == "age" || keyboardMode == "slider") {
      normalizeAgeSliderInput(raw)
    } else {
      raw.take(DEMOGRAPHICS_NAME_MAX_CHARS)
    }
  }

  fun cleanAndLogDemographicsTextInput(
      fieldId: String,
      raw: String,
      keyboardMode: String,
      source: String = "spatial_text_field",
  ): String {
    val cleaned = cleanDemographicsTextInput(fieldId, raw, keyboardMode)
    if (fieldId == "age" || keyboardMode == "slider") {
      logDemographicsAgeSliderSanitize(raw, cleaned, source)
    }
    logDemographicsTextInputValue(fieldId, cleaned, keyboardMode, source)
    return cleaned
  }

  private fun logDemographicsAgeSliderSanitize(raw: String, cleaned: String, source: String) {
    val digitCount = raw.count { it.digitToIntOrNull() != null }
    val parsed =
        raw.trim().toIntOrNull()
            ?: raw.mapNotNull { char -> char.digitToIntOrNull()?.toString() }
                .joinToString("")
                .toIntOrNull()
    val stripped = raw.trim().toIntOrNull() == null && raw.length != digitCount
    val clamped = parsed != null && parsed != parsed.coerceIn(DEMOGRAPHICS_AGE_MIN, DEMOGRAPHICS_AGE_MAX)
    val changed = raw != cleaned
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_AGE_SLIDER_SANITIZE source=${sanitizeKeyboardLogToken(source)} rawLength=${raw.length} digitCount=$digitCount cleanedValue=${cleaned.ifBlank { "unset" }} stripped=$stripped clamped=$clamped changed=$changed min=$DEMOGRAPHICS_AGE_MIN max=$DEMOGRAPHICS_AGE_MAX platformControl=ComposeSlider inputOwner=composeSlider keyboardTarget=none",
    )
  }

  fun replaceDemographicsTextInput(
      fieldId: String,
      raw: String,
      keyboardMode: String,
      source: String,
  ): String {
    val cleaned = cleanAndLogDemographicsTextInput(fieldId, raw, keyboardMode, source)
    when (fieldId) {
      "name" -> demographicsDraftNameState.value = cleaned
      "age" -> {
        demographicsDraftAgeState.value = cleaned
        Log.i(
            TAG,
            "BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=${sanitizeKeyboardLogToken(source)} value=${cleaned.ifBlank { "unset" }} min=$DEMOGRAPHICS_AGE_MIN max=$DEMOGRAPHICS_AGE_MAX step=1 platformControl=ComposeSlider inputOwner=composeSlider sameExportField=demographics.age",
        )
      }
      else ->
          Log.i(
              TAG,
              "BRB_DEMOGRAPHICS_TEXT_VALUE_IGNORED field=${sanitizeKeyboardLogToken(fieldId)} source=${sanitizeKeyboardLogToken(source)} reason=unknown_field",
          )
    }
    return cleaned
  }

  fun appendDemographicsNameCharacter(char: Char, source: String): Boolean {
    if (char.isISOControl()) {
      Log.i(
          TAG,
          "BRB_DEMOGRAPHICS_NAME_KEY accepted=false reason=control_character source=${sanitizeKeyboardLogToken(source)} length=${demographicsDraftNameState.value.length} maxChars=$DEMOGRAPHICS_NAME_MAX_CHARS platformControl=AppOwnedKeyboard keyboardTarget=appOwnedNameKeyboard",
      )
      return false
    }
    val before = demographicsDraftNameState.value
    val displayedChar = normalizeDemographicsNameKeyboardChar(char, before)
    val cleaned = replaceDemographicsTextInput("name", before + displayedChar, "text", source)
    val accepted = cleaned != before
    val keyKind =
        when {
          char == ' ' -> "space"
          char.isLetter() -> "letter"
          char.isDigit() -> "digit"
          else -> "punctuation"
        }
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_NAME_KEY keyKind=$keyKind accepted=$accepted source=${sanitizeKeyboardLogToken(source)} length=${cleaned.length} maxChars=$DEMOGRAPHICS_NAME_MAX_CHARS platformControl=AppOwnedKeyboard keyboardTarget=appOwnedNameKeyboard",
    )
    if (cleaned.length >= 2) {
      Log.i(
          TAG,
          "BRB_DEMOGRAPHICS_NAME_MULTI_CHARACTER accepted=true source=${sanitizeKeyboardLogToken(source)} length=${cleaned.length} platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard keyboardTarget=appOwnedNameKeyboard",
      )
    }
    return accepted
  }

  private fun normalizeDemographicsNameKeyboardChar(char: Char, current: String): Char {
    if (!char.isLetter()) {
      return char
    }
    val startsWord = current.isBlank() || current.last().isWhitespace() || current.last() == '-' || current.last() == '\''
    return if (startsWord) char.uppercaseChar() else char.lowercaseChar()
  }

  fun backspaceDemographicsName(source: String): Boolean {
    val before = demographicsDraftNameState.value
    val after = before.dropLast(1)
    replaceDemographicsTextInput("name", after, "text", source)
    val accepted = before != after
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_NAME_BACKSPACE accepted=$accepted source=${sanitizeKeyboardLogToken(source)} length=${after.length} platformControl=AppOwnedKeyboard keyboardTarget=appOwnedNameKeyboard",
    )
    return accepted
  }

  fun logDemographicsTextInputValue(
      fieldId: String,
      value: String,
      keyboardMode: String,
      source: String = "android_view_edit_text",
  ) {
    val safeFieldId = sanitizeKeyboardLogToken(fieldId)
    val safeKeyboardMode = sanitizeKeyboardLogToken(keyboardMode)
    val safeSource = sanitizeKeyboardLogToken(source)
    val digitsOnly = value.all { it.isDigit() }
    val platformControl = if (safeFieldId == "age") "ComposeSlider" else "AppOwnedKeyboard"
    val inputOwner = if (safeFieldId == "age") "composeSlider" else "appOwnedNameKeyboard"
    val keyboardTarget = if (safeFieldId == "age") "none" else "appOwnedNameKeyboard"
    if (demographicsKeyboardValidationEnabled) {
      Log.i(
          TAG,
          "BRB_DEMOGRAPHICS_TEXT_VALUE field=$safeFieldId keyboardMode=$safeKeyboardMode value=${sanitizeKeyboardLogToken(value)} length=${value.length} digitsOnly=$digitsOnly platformControl=$platformControl inputOwner=$inputOwner keyboardTarget=$keyboardTarget source=$safeSource validation=true",
      )
    } else {
      Log.i(
          TAG,
          "BRB_DEMOGRAPHICS_TEXT_VALUE field=$safeFieldId keyboardMode=$safeKeyboardMode length=${value.length} digitsOnly=$digitsOnly platformControl=$platformControl inputOwner=$inputOwner keyboardTarget=$keyboardTarget source=$safeSource validation=false",
      )
    }
  }

  fun logDemographicsTextInputEditorAction(fieldId: String, action: String, source: String) {
    val safeFieldId = sanitizeKeyboardLogToken(fieldId)
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=$safeFieldId action=${sanitizeKeyboardLogToken(action)} source=${sanitizeKeyboardLogToken(source)} platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard",
    )
  }

  fun requestDemographicsTextInputFocus(fieldId: String, source: String = "app") {
    val safeFieldId = sanitizeKeyboardLogToken(fieldId)
    if (safeFieldId == "age") {
      focusDemographicsAgeSlider(source)
      return
    }
    if (safeFieldId != "name") {
      Log.i(TAG, "BRB_NAME_APP_KEYBOARD_FOCUS field=$safeFieldId accepted=false reason=unknown_field")
      return
    }
    demographicsFocusRequestFieldState.value = safeFieldId
    demographicsFocusRequestSourceState.value = sanitizeKeyboardLogToken(source)
    demographicsFocusRequestTokenState.intValue += 1
    demographicsFocusedFieldState.value = "name"
    setNameKeyboardVisible(true, "focus_${safeFieldId}_${demographicsFocusRequestSourceState.value}")
    Log.i(
        TAG,
        "BRB_NAME_APP_KEYBOARD_FOCUS field=$safeFieldId accepted=true token=${demographicsFocusRequestTokenState.intValue} source=${demographicsFocusRequestSourceState.value} keyboardMode=text singlePath=true fullCellHitbox=true platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard keyboardPanel=keyboard_panel presentation=pop_out_spatial_panel integratedInQuestionnaire=false hardwareKeyeventFallback=true noSystemImeDependency=true",
    )
  }

  private fun selectedDemographicsNameKeyboardKey(): String {
    val row = demographicsNameKeyboardCursorRowState.intValue.coerceIn(0, DEMOGRAPHICS_NAME_KEYBOARD_ROWS.lastIndex)
    val col =
        demographicsNameKeyboardCursorColumnState.intValue.coerceIn(
            0,
            DEMOGRAPHICS_NAME_KEYBOARD_ROWS[row].lastIndex,
        )
    demographicsNameKeyboardCursorRowState.intValue = row
    demographicsNameKeyboardCursorColumnState.intValue = col
    return DEMOGRAPHICS_NAME_KEYBOARD_ROWS[row][col]
  }

  private fun mapDemographicsKeyboardColumn(column: Int, fromSize: Int, toSize: Int): Int {
    if (toSize <= 1 || fromSize <= 1) {
      return 0
    }
    val ratio = column.toFloat() / (fromSize - 1).toFloat()
    return (ratio * (toSize - 1).toFloat()).toInt().coerceIn(0, toSize - 1)
  }

  fun handleDemographicsNameKeyboardDirection(direction: String, source: String = "controller_direction"): Boolean {
    if (stageState.value != StudyStage.ConsentDemographics || demographicsFocusedFieldState.value != "name") {
      return false
    }
    val normalized = direction.lowercase(Locale.US)
    val oldRow = demographicsNameKeyboardCursorRowState.intValue.coerceIn(0, DEMOGRAPHICS_NAME_KEYBOARD_ROWS.lastIndex)
    val oldCol =
        demographicsNameKeyboardCursorColumnState.intValue.coerceIn(
            0,
            DEMOGRAPHICS_NAME_KEYBOARD_ROWS[oldRow].lastIndex,
        )
    var newRow = oldRow
    var newCol = oldCol
    when (normalized) {
      "left" -> newCol = (oldCol - 1).coerceAtLeast(0)
      "right" -> newCol = (oldCol + 1).coerceAtMost(DEMOGRAPHICS_NAME_KEYBOARD_ROWS[oldRow].lastIndex)
      "up" -> {
        newRow = (oldRow - 1).coerceAtLeast(0)
        newCol =
            mapDemographicsKeyboardColumn(
                oldCol,
                DEMOGRAPHICS_NAME_KEYBOARD_ROWS[oldRow].size,
                DEMOGRAPHICS_NAME_KEYBOARD_ROWS[newRow].size,
            )
      }
      "down" -> {
        newRow = (oldRow + 1).coerceAtMost(DEMOGRAPHICS_NAME_KEYBOARD_ROWS.lastIndex)
        newCol =
            mapDemographicsKeyboardColumn(
                oldCol,
                DEMOGRAPHICS_NAME_KEYBOARD_ROWS[oldRow].size,
                DEMOGRAPHICS_NAME_KEYBOARD_ROWS[newRow].size,
            )
      }
      else -> return false
    }
    demographicsNameKeyboardCursorRowState.intValue = newRow
    demographicsNameKeyboardCursorColumnState.intValue = newCol
    val key = selectedDemographicsNameKeyboardKey()
    Log.i(
        TAG,
        "BRB_NAME_APP_KEYBOARD_NAV direction=$normalized source=${sanitizeKeyboardLogToken(source)} row=$newRow column=$newCol key=${sanitizeKeyboardLogToken(key)} platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard",
    )
    playQuestionnaireNavigationCue()
    return true
  }

  fun pressSelectedDemographicsNameKeyboardKey(source: String = "controller_enter"): Boolean {
    if (stageState.value != StudyStage.ConsentDemographics || demographicsFocusedFieldState.value != "name") {
      return false
    }
    val key = selectedDemographicsNameKeyboardKey()
    val safeSource = sanitizeKeyboardLogToken(source)
    val action =
        when (key) {
          "Clear" -> {
            replaceDemographicsTextInput("name", "", "text", source)
            playQuestionnaireNavigationCue()
            "clear"
          }
          "Space" -> {
            appendDemographicsNameCharacter(' ', source)
            playQuestionnaireNavigationCue()
            "space"
          }
          "Back" -> {
            backspaceDemographicsName(source)
            playQuestionnaireNavigationCue()
            "backspace"
          }
          "Next" -> {
            playQuestionnaireChoiceCue()
            logDemographicsTextInputEditorAction("name", "next", source)
            focusDemographicsAgeSlider("${safeSource}_name_next")
            "next"
          }
          else -> {
            appendDemographicsNameCharacter(key.first(), source)
            playQuestionnaireNavigationCue()
            "character"
          }
        }
    Log.i(
        TAG,
        "BRB_NAME_APP_KEYBOARD_PRESS key=${sanitizeKeyboardLogToken(key)} action=$action source=$safeSource row=${demographicsNameKeyboardCursorRowState.intValue} column=${demographicsNameKeyboardCursorColumnState.intValue} textLength=${demographicsDraftNameState.value.length} platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard",
    )
    return true
  }

  fun focusDemographicsAgeSlider(source: String = "app") {
    val safeSource = sanitizeKeyboardLogToken(source)
    hideSoftKeyboardForCurrentWindow("field_name_to_age_slider_$safeSource")
    demographicsFocusedFieldState.value = "age"
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_AGE_SLIDER_FOCUS field=age accepted=true source=$safeSource min=$DEMOGRAPHICS_AGE_MIN max=$DEMOGRAPHICS_AGE_MAX step=1 platformControl=ComposeSlider inputOwner=composeSlider sameExportField=demographics.age",
    )
  }

  fun setDemographicsAgeSliderValue(value: Int, source: String): String {
    val safeSource = sanitizeKeyboardLogToken(source)
    val cleanedInt = value.coerceIn(DEMOGRAPHICS_AGE_MIN, DEMOGRAPHICS_AGE_MAX)
    val cleaned = cleanedInt.toString()
    demographicsDraftAgeState.value = cleaned
    demographicsFocusedFieldState.value = "age"
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=$safeSource value=$cleaned min=$DEMOGRAPHICS_AGE_MIN max=$DEMOGRAPHICS_AGE_MAX step=1 clamped=${cleanedInt != value} platformControl=ComposeSlider inputOwner=composeSlider sameExportField=demographics.age",
    )
    logDemographicsTextInputValue("age", cleaned, "slider", source)
    return cleaned
  }

  fun clearDemographicsAgeSlider(source: String) {
    demographicsDraftAgeState.value = ""
    demographicsFocusedFieldState.value = "age"
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=${sanitizeKeyboardLogToken(source)} value=unset min=$DEMOGRAPHICS_AGE_MIN max=$DEMOGRAPHICS_AGE_MAX step=1 platformControl=ComposeSlider inputOwner=composeSlider sameExportField=demographics.age",
    )
    logDemographicsTextInputValue("age", "", "slider", source)
  }

  fun logDemographicsAgeSliderConfirmed(source: String) {
    if (demographicsDraftAgeState.value.isBlank()) {
      setDemographicsAgeSliderValue(ageSliderValueOrDefault(demographicsDraftAgeState.value), "${source}_default")
    }
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_AGE_SLIDER_DONE source=${sanitizeKeyboardLogToken(source)} value=${demographicsDraftAgeState.value.ifBlank { "unset" }} min=$DEMOGRAPHICS_AGE_MIN max=$DEMOGRAPHICS_AGE_MAX platformControl=ComposeSlider inputOwner=composeSlider",
    )
  }

  private fun handleDemographicsHardwareKeyEvent(event: KeyEvent): Boolean {
    if (stageState.value != StudyStage.ConsentDemographics) {
      return false
    }
    if (event.action != KeyEvent.ACTION_DOWN &&
        event.action != KeyEvent.ACTION_UP &&
        event.action != KeyEvent.ACTION_MULTIPLE) {
      return false
    }
    val focusedField = demographicsFocusedFieldState.value
    if (focusedField != "name" && focusedField != "age") {
      return false
    }
    if (focusedField == "name") {
      if (event.action == KeyEvent.ACTION_MULTIPLE) {
        val batchedCharacters = event.characters.orEmpty()
        if (batchedCharacters.isBlank()) {
          return false
        }
        batchedCharacters.forEach { char ->
          appendDemographicsNameCharacter(char, "hardware_text_event")
        }
        Log.i(
            TAG,
            "BRB_DEMOGRAPHICS_NAME_BATCH_TEXT accepted=true source=hardware_text_event rawLength=${batchedCharacters.length} appliedLength=${demographicsDraftNameState.value.length} platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard",
        )
        return true
      }
      val keyCode = event.keyCode
      val direction =
          when (keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT -> "left"
            KeyEvent.KEYCODE_DPAD_RIGHT -> "right"
            KeyEvent.KEYCODE_DPAD_UP -> "up"
            KeyEvent.KEYCODE_DPAD_DOWN -> "down"
            else -> null
          }
      val isSubmit =
          keyCode == KeyEvent.KEYCODE_ENTER ||
              keyCode == KeyEvent.KEYCODE_NUMPAD_ENTER ||
              keyCode == KeyEvent.KEYCODE_DPAD_CENTER
      val isBackspace = keyCode == KeyEvent.KEYCODE_DEL || keyCode == KeyEvent.KEYCODE_FORWARD_DEL
      val hardwareChar = demographicsHardwareKeyCharacter(event)
      if (direction == null && !isSubmit && !isBackspace && hardwareChar == null) {
        return false
      }
      if (event.action == KeyEvent.ACTION_UP) {
        return true
      }
      if (event.repeatCount > 0) {
        return true
      }
      if (direction != null) {
        handleDemographicsNameKeyboardDirection(direction, "hardware_key_event")
      } else if (isSubmit) {
        pressSelectedDemographicsNameKeyboardKey("hardware_key_event")
      } else if (isBackspace) {
        backspaceDemographicsName("hardware_key_event")
      } else if (hardwareChar != null) {
        appendDemographicsNameCharacter(hardwareChar, "hardware_key_event")
      }
      return true
    }
    val keyCode = event.keyCode
    if (focusedField == "age") {
      val delta =
          when (keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT -> -1
            KeyEvent.KEYCODE_DPAD_RIGHT -> 1
            KeyEvent.KEYCODE_DPAD_DOWN -> -10
            KeyEvent.KEYCODE_DPAD_UP -> 10
            else -> 0
          }
      val isSubmit = keyCode == KeyEvent.KEYCODE_ENTER || keyCode == KeyEvent.KEYCODE_NUMPAD_ENTER
      if (delta == 0 && !isSubmit) {
        return false
      }
      if (event.action == KeyEvent.ACTION_DOWN) {
        return true
      }
      if (isSubmit) {
        logDemographicsAgeSliderConfirmed("activity_key_event")
      } else {
        setDemographicsAgeSliderValue(
            ageSliderValueOrDefault(demographicsDraftAgeState.value) + delta,
            "activity_key_event",
        )
      }
      return true
    }
    return false
  }

  private fun demographicsHardwareKeyCharacter(event: KeyEvent): Char? {
    val unicodeChar = event.unicodeChar
    if (unicodeChar > 0) {
      val char = unicodeChar.toChar()
      if (!char.isISOControl()) {
        return char
      }
    }
    return when (event.keyCode) {
      KeyEvent.KEYCODE_SPACE -> ' '
      in KeyEvent.KEYCODE_A..KeyEvent.KEYCODE_Z ->
          'a' + (event.keyCode - KeyEvent.KEYCODE_A)
      in KeyEvent.KEYCODE_0..KeyEvent.KEYCODE_9 ->
          '0' + (event.keyCode - KeyEvent.KEYCODE_0)
      in KeyEvent.KEYCODE_NUMPAD_0..KeyEvent.KEYCODE_NUMPAD_9 ->
          '0' + (event.keyCode - KeyEvent.KEYCODE_NUMPAD_0)
      KeyEvent.KEYCODE_MINUS -> '-'
      KeyEvent.KEYCODE_APOSTROPHE -> '\''
      else -> null
    }
  }

  private fun handleDemographicsKeyboardValidationIntent(intent: Intent?) {
    if (intent == null) {
      return
    }
    if (intent.getBooleanExtra(DEMOGRAPHICS_KEYBOARD_VALIDATION_EXTRA, false)) {
      demographicsKeyboardValidationEnabled = true
    }
    val incomingSessionId =
        intent
            .getStringExtra(DEMOGRAPHICS_KEYBOARD_VALIDATION_SESSION_EXTRA)
            ?.trim()
            ?.take(80)
            .orEmpty()
    if (incomingSessionId.isNotBlank() && demographicsKeyboardValidationSessionId.isBlank()) {
      demographicsKeyboardValidationSessionId = incomingSessionId
      Log.i(
          TAG,
          "BRB_DEMOGRAPHICS_VALIDATION_SESSION session=${sanitizeKeyboardLogToken(incomingSessionId)} accepted=true state=start",
      )
    }
    val command =
        intent
            .getStringExtra(DEMOGRAPHICS_KEYBOARD_VALIDATION_COMMAND_EXTRA)
            ?.lowercase(Locale.US)
            ?.trim()
            .orEmpty()
    if (command.isBlank()) {
      return
    }
    val safeCommand = sanitizeKeyboardLogToken(command)
    if (!demographicsKeyboardValidationEnabled) {
      Log.i(TAG, "BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=$safeCommand accepted=false reason=validation_disabled")
      return
    }
    if (demographicsKeyboardValidationSessionId.isNotBlank() &&
        incomingSessionId != demographicsKeyboardValidationSessionId) {
      Log.i(
          TAG,
          "BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=$safeCommand accepted=false reason=session_mismatch expected=${sanitizeKeyboardLogToken(demographicsKeyboardValidationSessionId)} observed=${sanitizeKeyboardLogToken(incomingSessionId)}",
      )
      return
    }
    if (safeCommand == "prior_answer_yes" || safeCommand == "prior_answer_no") {
      if (stageState.value != StudyStage.PreButtonExperienceQuestion) {
        Log.i(
            TAG,
            "BRB_PRIOR_BUTTON_EXPERIENCE_VALIDATION_ANSWER command=$safeCommand accepted=false reason=wrong_stage stage=${stageState.value.name.lowercase(Locale.US)}",
        )
        return
      }
      val answer = if (safeCommand == "prior_answer_yes") "yes" else "no"
      Log.i(
          TAG,
          "BRB_PRIOR_BUTTON_EXPERIENCE_VALIDATION_ANSWER command=$safeCommand accepted=true answer=$answer source=intent",
      )
      setPriorBigRedButtonExperienceAnswer(answer, "validation_intent")
      return
    }
    if (stageState.value != StudyStage.ConsentDemographics) {
      Log.i(
          TAG,
          "BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=$safeCommand accepted=false reason=wrong_stage stage=${stageState.value.name.lowercase(Locale.US)}",
      )
      return
    }
    Log.i(TAG, "BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=$safeCommand accepted=true source=intent")
    when (command) {
      "focus_name" -> requestDemographicsTextInputFocus("name", "validation_intent")
      "set_name" -> applyDemographicsKeyboardValidationText("name", "text", intent)
      "type_name_app_keyboard" -> applyDemographicsNameAppKeyboardValidationText(intent)
      "submit_name_app_keyboard" -> submitDemographicsNameAppKeyboardValidation()
      "name_next" -> {
        logDemographicsTextInputEditorAction("name", "next", "validation_intent")
        focusDemographicsAgeSlider("validation_intent_name_next")
      }
      "focus_age" -> focusDemographicsAgeSlider("validation_intent")
      "clear_age" -> clearDemographicsAgeSlider("validation_intent_clear")
      "age_digit" -> {
        val rawDigit = intent.getStringExtra(DEMOGRAPHICS_KEYBOARD_VALIDATION_TEXT_EXTRA).orEmpty()
        val digit = rawDigit.firstOrNull()
        if (digit == null) {
          Log.i(TAG, "BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=validation_intent_digit accepted=false reason=missing_text value=${demographicsDraftAgeState.value.ifBlank { "unset" }}")
        } else {
          replaceDemographicsTextInput("age", demographicsDraftAgeState.value + digit, "slider", "validation_intent_digit")
        }
      }
      "age_backspace" -> clearDemographicsAgeSlider("validation_intent_backspace")
      "set_age" -> applyDemographicsKeyboardValidationText("age", "slider", intent)
      "age_done" -> {
        logDemographicsAgeSliderConfirmed("validation_intent")
      }
      "submit_demographics" -> {
        Log.i(
            TAG,
            "BRB_DEMOGRAPHICS_VALIDATION_SUBMIT accepted=true source=intent route=submitDemographics priorAudioSmoke=true",
        )
        submitDemographics(
            name = "Prior Audio Validation",
            age = "34",
            gender = "prefer_not_to_say",
            handedness = "right",
            signature = "validation-signature",
            consent = true,
            participantIdOverride = "validation-prior-audio-${SystemClock.elapsedRealtime()}",
        )
      }
      "submit_current_demographics" -> {
        val currentName = demographicsDraftNameState.value.trim()
        val currentAge = normalizeAgeSliderInput(demographicsDraftAgeState.value)
        if (currentName.isBlank() || currentAge.isBlank()) {
          Log.i(
              TAG,
              "BRB_DEMOGRAPHICS_VALIDATION_SUBMIT_CURRENT accepted=false reason=missing_name_or_age nameLength=${currentName.length} age=${currentAge.ifBlank { "unset" }}",
          )
          return
        }
        demographicsDraftGenderState.value = "prefer_not_to_say"
        demographicsDraftHandednessState.value = "right"
        demographicsDraftSignatureState.value = validationSignatureStrokesJson()
        demographicsDraftConsentState.value = true
        Log.i(
            TAG,
            "BRB_DEMOGRAPHICS_VALIDATION_SUBMIT_CURRENT accepted=true source=intent route=submitDemographics nameLength=${currentName.length} age=$currentAge preservesKeyboardDraft=true",
        )
        submitDemographics(
            name = currentName,
            age = currentAge,
            gender = demographicsDraftGenderState.value,
            handedness = demographicsDraftHandednessState.value,
            signature = demographicsDraftSignatureState.value,
            consent = demographicsDraftConsentState.value,
            participantIdOverride = "DIRECTIONAL_KEYBOARD_VALIDATION_${SystemClock.elapsedRealtime()}",
        )
      }
      else ->
          Log.i(
              TAG,
              "BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=$safeCommand accepted=false reason=unknown_command",
          )
    }
  }

  private fun applyDemographicsKeyboardValidationText(
      fieldId: String,
      keyboardMode: String,
      intent: Intent,
  ) {
    val raw = intent.getStringExtra(DEMOGRAPHICS_KEYBOARD_VALIDATION_TEXT_EXTRA).orEmpty()
    val cleaned = replaceDemographicsTextInput(fieldId, raw, keyboardMode, "validation_intent")
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_VALIDATION_TEXT_APPLIED field=${sanitizeKeyboardLogToken(fieldId)} keyboardMode=${sanitizeKeyboardLogToken(keyboardMode)} length=${cleaned.length} source=validation_intent sameSanitizer=true",
    )
  }

  private fun applyDemographicsNameAppKeyboardValidationText(intent: Intent) {
    val raw = intent.getStringExtra(DEMOGRAPHICS_KEYBOARD_VALIDATION_TEXT_EXTRA).orEmpty()
    requestDemographicsTextInputFocus("name", "validation_app_keyboard")
    replaceDemographicsTextInput("name", "", "text", "validation_app_keyboard_clear")
    raw.forEach { char -> appendDemographicsNameCharacter(char, "validation_app_keyboard") }
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_VALIDATION_APP_KEYBOARD_TYPE field=name accepted=true rawLength=${raw.length} appliedLength=${demographicsDraftNameState.value.length} source=validation_app_keyboard sameStatePath=true platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard",
    )
  }

  private fun submitDemographicsNameAppKeyboardValidation() {
    logDemographicsTextInputEditorAction("name", "next", "validation_app_keyboard_submit")
    focusDemographicsAgeSlider("validation_app_keyboard_submit")
    Log.i(
        TAG,
        "BRB_DEMOGRAPHICS_VALIDATION_APP_KEYBOARD_SUBMIT field=name accepted=true action=next source=validation_app_keyboard platformControl=AppOwnedKeyboard inputOwner=appOwnedNameKeyboard",
    )
  }

  private fun handleAudioRigStressIntent(intent: Intent?) {
    if (intent == null) {
      return
    }
    if (intent.getBooleanExtra(AUDIO_RIG_STRESS_EXTRA, false)) {
      audioRigStressEnabled = true
      isolateAudioRigStressValidationModes("intent")
    }
    val command =
        intent
            .getStringExtra(AUDIO_RIG_STRESS_COMMAND_EXTRA)
            ?.lowercase(Locale.US)
            ?.trim()
            .orEmpty()
    if (command.isBlank()) {
      return
    }
    val safeCommand = sanitizeKeyboardLogToken(command)
    if (!audioRigStressEnabled) {
      Log.i(TAG, "BRB_AUDIO_RIG_STRESS_COMMAND command=$safeCommand accepted=false reason=validation_disabled")
      return
    }
    Log.i(
        TAG,
        "BRB_AUDIO_RIG_STRESS_COMMAND command=$safeCommand accepted=true stage=${stageState.value.name.lowercase(Locale.US)}",
    )
    when {
      safeCommand == "show_prior_prompt" -> {
        if (stageState.value == StudyStage.ConsentDemographics) {
          submitDemographics(
              name = "Audio Rig Stress",
              age = "34",
              gender = "prefer_not_to_say",
              handedness = "right",
              signature = "audio-rig-stress-signature",
              consent = true,
              participantIdOverride = "validation-audio-rig-${SystemClock.elapsedRealtime()}",
          )
        } else {
          showPreButtonExperienceQuestion()
        }
      }
      safeCommand == "prior_answer_yes" || safeCommand == "prior_answer_no" -> {
        if (stageState.value != StudyStage.PreButtonExperienceQuestion) {
          Log.i(
              TAG,
              "BRB_AUDIO_RIG_STRESS_PRIOR_ANSWER command=$safeCommand accepted=false reason=wrong_stage stage=${stageState.value.name.lowercase(Locale.US)}",
          )
          return
        }
        val answer = if (safeCommand == "prior_answer_yes") "yes" else "no"
        Log.i(TAG, "BRB_AUDIO_RIG_STRESS_PRIOR_ANSWER command=$safeCommand accepted=true answer=$answer")
        setPriorBigRedButtonExperienceAnswer(answer, "audio_rig_stress_intent")
      }
      safeCommand == "show_final_end" -> {
        showFinalEndQuestionnaire()
      }
      safeCommand.startsWith("final_answer_") -> {
        if (stageState.value != StudyStage.FinalEndQuestionnaire) {
          Log.i(
              TAG,
              "BRB_AUDIO_RIG_STRESS_FINAL_ANSWER command=$safeCommand accepted=false reason=wrong_stage stage=${stageState.value.name.lowercase(Locale.US)}",
          )
          return
        }
        val rating = safeCommand.substringAfter("final_answer_").toIntOrNull()?.coerceIn(1, 10) ?: 10
        Log.i(TAG, "BRB_AUDIO_RIG_STRESS_FINAL_ANSWER command=$safeCommand accepted=true rating=$rating")
        setFinalEndLikert(rating, "audio_rig_stress_intent")
        val submitted = submitFinalEndConfirmationSelection("audio_rig_stress_intent")
        Log.i(TAG, "BRB_AUDIO_RIG_STRESS_FINAL_ANSWER_RESULT rating=$rating submitted=$submitted")
      }
      safeCommand == "final_extra_press_attempt" -> {
        recordButtonPress(PRESS_SOURCE_AUDIO_RIG_STRESS)
      }
      safeCommand == "button_press_animation_stress" -> {
        scheduleButtonPressAnimationStress()
      }
      safeCommand == "play_short_cues" -> {
        Log.i(TAG, "BRB_AUDIO_RIG_STRESS_SHORT_CUES start=true cues=questionnaire_choice|questionnaire_navigation|button_press")
        playQuestionnaireChoiceCue()
        mainHandler.postDelayed({ playQuestionnaireNavigationCue() }, 350L)
        mainHandler.postDelayed({ playButtonPressCue() }, 700L)
      }
      safeCommand == "redness_vas_then_likert" -> {
        playRednessScaleConversionCue(REDNESS_ORDER_VAS_THEN_LIKERT, validationShortcut = false)
      }
      safeCommand == "redness_likert_then_vas" -> {
        playRednessScaleConversionCue(REDNESS_ORDER_LIKERT_THEN_VAS, validationShortcut = false)
      }
      safeCommand == "condition_1_audio_probe" -> {
        Log.i(TAG, "BRB_AUDIO_RIG_STRESS_CONDITION_AUDIO_PROBE condition=1 route=beginCondition")
        beginCondition(1)
      }
      safeCommand == "condition_2_audio_probe" -> {
        Log.i(TAG, "BRB_AUDIO_RIG_STRESS_CONDITION_AUDIO_PROBE condition=2 route=beginCondition")
        beginCondition(2)
      }
      else -> Log.i(TAG, "BRB_AUDIO_RIG_STRESS_COMMAND command=$safeCommand accepted=false reason=unknown_command")
    }
  }

  private fun scheduleButtonPressAnimationStress() {
    val run = activeRun
    if (run == null || stageState.value != StudyStage.ConditionRunning) {
      Log.i(
          TAG,
          "BRB_BUTTON_PRESS_ANIMATION_STRESS state=rejected reason=condition_not_running stage=${stageState.value.name.lowercase(Locale.US)}",
      )
      return
    }
    val nowMs = SystemClock.elapsedRealtime()
    val firstDelayMs =
        (conditionPressArmedRealtimeMs - nowMs + BUTTON_PRESS_ANIMATION_STRESS_ARM_MARGIN_MS)
            .coerceAtLeast(BUTTON_PRESS_ANIMATION_STRESS_MIN_FIRST_DELAY_MS)
    val offsets =
        List(BUTTON_PRESS_ANIMATION_STRESS_PRESS_COUNT) { index ->
          firstDelayMs + index.toLong() * BUTTON_PRESS_ANIMATION_STRESS_INTERVAL_MS
        }
    Log.i(
        TAG,
        "BRB_BUTTON_PRESS_ANIMATION_STRESS state=scheduled condition=${run.conditionNumber} source=$PRESS_SOURCE_AUDIO_RIG_STRESS offsetsMs=${offsets.joinToString("|")} intervalMs=$BUTTON_PRESS_ANIMATION_STRESS_INTERVAL_MS expectedAccepted=${offsets.size} visualRestartGuardMs=$BUTTON_PRESS_MOTION_RESTART_GUARD_MS pressCooldownMs=$BUTTON_PRESS_COOLDOWN_MS",
    )
    offsets.forEachIndexed { index, delayMs ->
      mainHandler.postDelayed(
          {
            if (activeRun !== run || stageState.value != StudyStage.ConditionRunning) {
              Log.i(
                  TAG,
                  "BRB_BUTTON_PRESS_ANIMATION_STRESS state=press_skipped index=${index + 1} reason=stage_changed activeCondition=${activeRun?.conditionNumber ?: 0} stage=${stageState.value.name.lowercase(Locale.US)}",
              )
              return@postDelayed
            }
            Log.i(
                TAG,
                "BRB_BUTTON_PRESS_ANIMATION_STRESS state=press_attempt index=${index + 1} condition=${run.conditionNumber} source=$PRESS_SOURCE_AUDIO_RIG_STRESS",
            )
            recordButtonPress(PRESS_SOURCE_AUDIO_RIG_STRESS)
          },
          delayMs,
      )
    }
    mainHandler.postDelayed(
        {
          val acceptedStressPresses =
              run.pressEvents.count { it.inputSource == PRESS_SOURCE_AUDIO_RIG_STRESS }
          Log.i(
              TAG,
              "BRB_BUTTON_PRESS_ANIMATION_STRESS state=complete condition=${run.conditionNumber} source=$PRESS_SOURCE_AUDIO_RIG_STRESS accepted=$acceptedStressPresses expected=${offsets.size} visualRestartGuardMs=$BUTTON_PRESS_MOTION_RESTART_GUARD_MS intervalMs=$BUTTON_PRESS_ANIMATION_STRESS_INTERVAL_MS",
          )
        },
        offsets.last() + BUTTON_PRESS_MOTION_RESTART_GUARD_MS + BUTTON_PRESS_ANIMATION_STRESS_COMPLETE_MARGIN_MS,
    )
  }

  private fun isolateAudioRigStressValidationModes(reason: String) {
    if (!audioRigStressEnabled) {
      return
    }
    val disabledModes = mutableListOf<String>()
    if (autoValidationEnabled) {
      disabledModes += "auto_validation"
    }
    if (physicalPressValidationEnabled) {
      disabledModes += "physical_press_validation"
    }
    if (panelSmokeEnabled) {
      disabledModes += "panel_smoke"
    }
    if (fastControllerFlowEnabled) {
      disabledModes += "fast_controller_flow"
    }
    if (keyeventValidationEnabled) {
      disabledModes += "keyevent_validation"
    }
    if (demographicsKeyboardValidationEnabled) {
      disabledModes += "demographics_keyboard_validation"
    }
    autoValidationEnabled = false
    physicalPressValidationEnabled = false
    panelSmokeEnabled = false
    fastControllerFlowEnabled = false
    keyeventValidationEnabled = false
    demographicsKeyboardValidationEnabled = false
    if (visualGlowValidationMode.isNotBlank()) {
      disabledModes += "visual_glow_validation"
      visualGlowValidationMode = ""
    }
    if (disabledModes.isNotEmpty()) {
      Log.i(
          TAG,
          "BRB_AUDIO_RIG_STRESS_ISOLATED reason=$reason disabled=${disabledModes.joinToString("|")}",
      )
    }
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
    val finalExtraPressText = finalExtraPressEventsCsvText()
    val ecgBlinkText = ecgBlinkEventsCsvText()
    val polarRrText = polarRrEventsCsvText()
    val ecgTimeSeriesText = ecgTimeSeriesCsvText()
    val ecgDetectorText = ecgDetectorEventsCsvText()
    val externalSignalText = externalSignalSamplesCsvText()
    val indexLine =
        JSONObject()
            .put("sessionId", sessionId)
            .put("participantId", demographicsState.value.participantId)
            .put("languageCode", selectedLanguageState.value.code)
            .put("languageLabel", selectedLanguageState.value.label)
            .put("localizedAudioManifestSha256", localizationManifestSha256)
            .put("timestampIso", nowIso())
            .put("json", "$baseName.json")
            .put("summaryCsv", "${baseName}_summary.csv")
            .put("pressEventsCsv", "${baseName}_press_events.csv")
            .put("finalExtraButtonPressesCsv", "${baseName}_final_extra_button_presses.csv")
            .put("ecgBlinkEventsCsv", "${baseName}_ecg_blink_events.csv")
            .put("polarRrEventsCsv", "${baseName}_polar_rr_events.csv")
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
            finalExtraPressText,
            ecgBlinkText,
            polarRrText,
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
            finalExtraPressText,
            ecgBlinkText,
            polarRrText,
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
      finalExtraPressText: String,
      ecgBlinkText: String,
      polarRrText: String,
      ecgTimeSeriesText: String,
      ecgDetectorText: String,
      externalSignalText: String,
      indexLine: String,
  ): List<File> {
    val jsonFile = File(exportDir, "$baseName.json")
    val summaryCsv = File(exportDir, "${baseName}_summary.csv")
    val pressCsv = File(exportDir, "${baseName}_press_events.csv")
    val finalExtraPressCsv = File(exportDir, "${baseName}_final_extra_button_presses.csv")
    val ecgBlinkCsv = File(exportDir, "${baseName}_ecg_blink_events.csv")
    val polarRrCsv = File(exportDir, "${baseName}_polar_rr_events.csv")
    val ecgTimeSeriesCsv = File(exportDir, "${baseName}_ecg_timeseries.csv")
    val ecgDetectorCsv = File(exportDir, "${baseName}_ecg_detector_events.csv")
    val externalSignalCsv = File(exportDir, "${baseName}_external_signal_samples.csv")
    val indexFile = File(exportDir, "session-index.jsonl")
    jsonFile.writeText(jsonText)
    summaryCsv.writeText(summaryText)
    pressCsv.writeText(pressText)
    finalExtraPressCsv.writeText(finalExtraPressText)
    ecgBlinkCsv.writeText(ecgBlinkText)
    polarRrCsv.writeText(polarRrText)
    ecgTimeSeriesCsv.writeText(ecgTimeSeriesText)
    ecgDetectorCsv.writeText(ecgDetectorText)
    externalSignalCsv.writeText(externalSignalText)
    indexFile.appendText(indexLine)
    return listOf(
        jsonFile,
        summaryCsv,
        pressCsv,
        finalExtraPressCsv,
        ecgBlinkCsv,
        polarRrCsv,
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
    root.put("validationMode", validationModeLabel())
    root.put("localization", localizationJson())
    root.put("participantPhysiologyEvidenceRequired", participantPhysiologyEvidenceExpected())
    root.put("exportedAtIso", nowIso())
    root.put("agentIntegrationProtocol", agentIntegrationProtocolJson())
    root.put("questionnaireProtocol", questionnaireProtocolJson())
    root.put("externalSignalProtocol", externalSignalProtocolJson())
    root.put("demographics", demographicsJson())
    root.put("priorBigRedButtonExperience", priorBigRedButtonExperienceJson())
    root.put("ecgProtocol", ecgProtocolJson())
    root.put("conditionOrder", JSONArray(conditionRuns.map { it.conditionNumber }))
    root.put("conditions", JSONArray(conditionRuns.map { conditionJson(it) }))
    root.put("presenceQuestionnaire", ipqMetadataJson())
    root.put("finalEndConfirmation", finalEndConfirmationJson())
    return root
  }

  private fun validationModeLabel(): String {
    return when {
      physicalPressValidationEnabled -> "physical_press_validation"
      autoValidationEnabled -> "auto_validation"
      keyeventValidationEnabled -> "keyevent_validation"
      fastControllerFlowEnabled -> "fast_controller_flow"
      panelSmokeEnabled -> "panel_smoke"
      demographicsKeyboardValidationEnabled -> "demographics_keyboard_validation"
      else -> "participant"
    }
  }

  private fun startsWithoutParticipantLanguageChoice(): Boolean {
    return autoValidationEnabled ||
        physicalPressValidationEnabled ||
        panelSmokeEnabled ||
        fastControllerFlowEnabled ||
        keyeventValidationEnabled ||
        demographicsKeyboardValidationEnabled ||
        audioRigStressEnabled ||
        visualGlowValidationMode.isNotBlank()
  }

  private fun studyLanguageFromIntent(intent: Intent?): StudyLanguage? {
    val normalized =
        intent
            ?.getStringExtra(STUDY_LANGUAGE_EXTRA)
            ?.trim()
            ?.replace('_', '-')
            ?.lowercase(Locale.US)
            .orEmpty()
    return when (normalized) {
      "en", "en-us", "english" -> StudyLanguage.English
      "ja", "ja-jp", "jp", "japanese" -> StudyLanguage.Japanese
      else -> null
    }
  }

  private fun isJapaneseSelected(): Boolean = selectedLanguageState.value == StudyLanguage.Japanese

  fun t(key: String): String {
    val japanese = isJapaneseSelected()
    return when (key) {
      "language_title" -> if (japanese) "実験の言語を選んでください" else "Choose experiment language"
      "language_body" ->
          if (japanese) {
            "この選択は、参加者に表示される文章と音声に適用されます。実験の流れと記録形式は同じです。"
          } else {
            "This controls the participant-facing text and spoken audio. The experiment flow and data exports stay the same."
          }
      "language_english" -> "English"
      "language_japanese" -> "日本語"
      "language_continue" -> if (japanese) "続ける" else "Continue"
      "intake_kicker" -> if (japanese) "Big Red Button Institute | 受付" else "Big Red Button Institute | Intake"
      "intake_title" -> if (japanese) "参加者情報と同意" else "Participant Details And Consent"
      "intake_body" ->
          if (japanese) {
            "下に参加者情報を入力してください。回答とボタン押下は、このヘッドセット内に保存されます。"
          } else {
            "Enter the participant details below. Responses and button presses are saved locally on this headset."
          }
      "participant_details" -> if (japanese) "参加者情報" else "Participant details"
      "name" -> if (japanese) "名前" else "Name"
      "age" -> if (japanese) "年齢" else "Age"
      "gender" -> if (japanese) "性別" else "Gender"
      "male" -> if (japanese) "男性" else "Male"
      "female" -> if (japanese) "女性" else "Female"
      "other" -> if (japanese) "その他" else "Other"
      "prefer_not_to_say" -> if (japanese) "回答しない" else "Prefer not to say"
      "handedness" -> if (japanese) "利き手" else "Handedness"
      "left" -> if (japanese) "左" else "Left"
      "right" -> if (japanese) "右" else "Right"
      "ambidextrous" -> if (japanese) "両利き" else "Ambidextrous"
      "consent" ->
          if (japanese) {
            "研究への参加に同意し、研究データがこのヘッドセット内に保存されることを理解しました。"
          } else {
            "I consent to participate and understand that study data will be saved locally on the headset."
          }
      "start_experiment" -> if (japanese) "実験を開始" else "Start experiment"
      "yes" -> if (japanese) "はい" else "Yes"
      "no" -> if (japanese) "いいえ" else "No"
      "consent_signature" -> if (japanese) "同意署名" else "Consent signature"
      "signature_instruction" -> if (japanese) "トリガーを押したまま、下の欄に署名してください。" else "Hold the trigger and draw your signature in the space below."
      "sign_here" -> if (japanese) "ここに署名" else "Sign here"
      "clear" -> if (japanese) "消去" else "Clear"
      "polar_ready" -> if (japanese) "Polar H10 ECG 準備完了" else "Polar H10 ECG ready"
      "polar_waiting_samples" -> if (japanese) "Polar H10 ECG サンプル待機中" else "Polar H10 ECG stream waiting for samples"
      "polar_start_requested" -> if (japanese) "Polar H10 ECG 開始要求済み" else "Polar H10 ECG start requested"
      "polar_settings_received" -> if (japanese) "Polar H10 ECG 設定受信済み" else "Polar H10 ECG settings received"
      "polar_pmd_subscribed" -> if (japanese) "Polar H10 PMD 購読済み" else "Polar H10 PMD subscribed"
      "polar_pmd_control_ready" -> if (japanese) "Polar H10 PMD 制御準備完了" else "Polar H10 PMD control ready"
      "polar_pmd_data_ready" -> if (japanese) "Polar H10 PMD データ準備完了" else "Polar H10 PMD data ready"
      "polar_pmd_ready" -> if (japanese) "Polar H10 PMD 準備完了、ECG開始中" else "Polar H10 PMD ready; starting ECG"
      "polar_hr_waiting_ecg" -> if (japanese) "Polar H10 HR/RR 検出、ECG待機中" else "Polar H10 HR/RR detected; waiting for ECG"
      "polar_connected" -> if (japanese) "Polar H10 接続済み、ストリーム待機中" else "Polar H10 connected; waiting for streams"
      "polar_detected" -> if (japanese) "Polar H10 検出、接続中" else "Polar H10 detected; connecting"
      "polar_permissions" -> if (japanese) "Polar H10 権限が必要です" else "Polar H10 permissions needed"
      "polar_not_ready" -> if (japanese) "Polar H10 はまだ準備できていません" else "Polar H10 not ready"
      "polar_start_warning" -> if (japanese) "Polar H10が接続されていません。続行できますが、生理データが記録されない可能性があります。" else "Polar H10 is not connected. You can continue, but physiology data may be missing."
      "polar_scanning" -> if (japanese) "Polar H10 を検索中" else "Scanning for Polar H10"
      "polar_keep_strap" -> if (japanese) "ストラップを濡らし、装着し、起動した状態でヘッドセットの近くに置いてください。" else "Keep the strap wet, worn, awake, and near the headset."
      "pictographic_kicker" -> if (japanese) "条件 %d | 回答タスク" else "Post-condition %d | Response task"
      "pictographic_title" -> if (japanese) "このボタン体験は、どれくらい大きく、どれくらい赤く感じましたか？" else "How Big and how Red was this button experience?"
      "pictographic_body" ->
          if (japanese) {
            "実験の終わりの時点で、ボタンが主観的にどれくらい近く感じられたか、また自分自身の感覚と比べてその存在感がどれくらい大きかったかを評価してください。"
          } else {
            "Please rate how subjectively close the button felt, and how big its subjective presence was compared to your sense of self by the end of the experiment."
          }
      "closeness_label" -> if (japanese) "ボタンはどれくらい近く感じましたか？" else "How close did the button feel?"
      "very_close" -> if (japanese) "とても近い" else "very close"
      "very_distant" -> if (japanese) "とても遠い" else "very distant"
      "presence_label" -> if (japanese) "ボタンの存在感はどれくらい大きく感じましたか？" else "How large was the felt presence of the button?"
      "small_presence" -> if (japanese) "小さな存在感" else "small presence"
      "large_presence" -> if (japanese) "大きな存在感" else "large presence"
      "redness_label" -> if (japanese) "ボタンはどれくらい赤く感じましたか？" else "How red did the button feel?"
      "slightly_red" -> if (japanese) "少し赤い" else "slightly red"
      "very_red" -> if (japanese) "とても赤い" else "very red"
      "extremely_red" -> if (japanese) "極端に赤い" else "extremely red"
      "save_response" -> if (japanese) "回答を保存" else "Save response"
      "ratings_kicker" -> if (japanese) "条件 %d | 評定" else "Post-condition %d | Ratings"
      "ratings_title" -> if (japanese) "セッション体験の評定" else "Session Experience Ratings"
      "ratings_body" ->
          if (japanese) {
            "条件 %d に基づいて各文に回答してください。各行につき1つの数字を選んでください。0は「まったくない」、6は「非常にそう」を意味します。"
          } else {
            "Please answer each statement based on condition %d. Select one number per row, where 0 means not at all and 6 means very much."
          }
      "items_answered" -> if (japanese) "%d / %d 項目に回答済み" else "%d of %d items answered"
      "save_ratings" -> if (japanese) "評定を保存" else "Save ratings"
      "lost_kicker" -> if (japanese) "条件 %d | 評定" else "Post-condition %d | Rating"
      "lost_title" -> if (japanese) "追加時間の評定" else "Additional Time Rating"
      "lost_body" ->
          if (japanese) {
            "ボタンに触れる時間が2倍あったとしたら、ボタンを2倍の回数押していたと思う可能性はどれくらいありますか？"
          } else {
            "Had you been given twice as much time with the button, how likely is it that you would have pressed the button twice as often?"
          }
      "condition_rating" -> if (japanese) "条件 %d の評定" else "Condition %d rating"
      "not_at_all_likely" -> if (japanese) "0 - まったくそう思わない" else "0 - not at all likely"
      "extremely_likely" -> if (japanese) "100 - 非常にそう思う" else "100 - extremely likely"
      "save_rating" -> if (japanese) "評定を保存" else "Save rating"
      "final_scale_left" -> if (japanese) "1 - 確信がない" else "1 - not sure"
      "final_scale_right" -> if (japanese) "10 - 完全に確信している" else "10 - completely sure"
      "complete_kicker" -> if (japanese) "ローカル書き出し" else "Local export"
      "complete_title" -> if (japanese) "実験完了" else "Experiment Complete"
      "complete_body" -> if (japanese) "ローカルJSONとCSVの書き出しが、このヘッドセットに保存されました。" else "The local JSON and CSV exports have been written on this headset."
      "audio_condition" -> if (japanese) "音声条件" else "Audio condition"
      "condition_running" -> if (japanese) "条件実行中" else "Condition running"
      "presses_out_of_1000" -> if (japanese) "1,000回中の押下回数" else "PRESSES OUT OF 1,000"
      "redness_micro_one_moment" -> if (japanese) "少しお待ちください..." else "One moment..."
      "redness_micro_updating" -> if (japanese) "項目を更新しています..." else "Updating item..."
      "redness_micro_adjust" -> if (japanese) "新しい回答を調整できます。" else "You can adjust the new response."
      else -> key
    }
  }

  fun tf(key: String, vararg args: Any): String = String.format(Locale.US, t(key), *args)

  fun localizedRednessMicroCaption(code: String, fallback: String): String {
    if (!isJapaneseSelected()) {
      return fallback
    }
    return when (code) {
      "nervous_entry" -> "少しお待ちください..."
      "supervisor_ping" -> "監督者に確認しています。"
      "item_targeted" -> "この項目だけが注目されています。"
      "swap_requested" -> "別の回答形式が近づいています。"
      "seven_boxes_assemble" -> "7つの箱が組み上がります。"
      "awkward_pause" -> "短い沈黙。"
      "answer_already_given" -> "あなたの回答はそのまま保持されます。"
      "change_anyway" -> "新しい形式がその回答にぴたりと合います。"
      "result_settle" -> "クリップの後に新しい回答を調整できます。"
      "nervous_return" -> "また少し調整があります..."
      "professional_warning" -> "警告が項目に割り込みます。"
      "mid_experiment_freeze" -> "行が実験の途中で凍結します。"
      "restore_requested" -> "視覚トラックが戻ってきます。"
      "boxes_erased" -> "箱が消されます。"
      "pretend_never_happened" -> "回答の下でトラックが再構築されます。"
      "data_importance" -> "保存された値が引き継がれます。"
      "wrong_way_settle" -> "最後に揺れてから、操作が戻ります。"
      else -> fallback
    }
  }

  fun priorButtonExperienceQuestionText(): String =
      if (isJapaneseSelected()) {
        "あ、待ってください。最後にもう一つだけ質問があります。大きな赤いボタンを押した経験はありますか？"
      } else {
        PRIOR_BUTTON_EXPERIENCE_QUESTION
      }

  fun priorButtonExperienceFeedbackText(answer: String): String =
      if (isJapaneseSelected()) {
        if (answer == "yes") {
          "経験者ですね。まさに我々が必要としていた参加者です。"
        } else {
          "ない？それなら、かなり楽しいことになりますよ。"
        }
      } else if (answer == "yes") {
        PRIOR_BUTTON_EXPERIENCE_YES_FEEDBACK
      } else {
        PRIOR_BUTTON_EXPERIENCE_NO_FEEDBACK
      }

  fun finalEndConfirmationQuestionText(): String =
      if (isJapaneseSelected()) {
        "実験を終了したい確信度は、1〜10の尺度でどれくらいですか？"
      } else {
        FINAL_END_CONFIRMATION_QUESTION
      }

  private fun finalEndConfirmation10FeedbackText(): String =
      if (isJapaneseSelected()) {
        "わかりました。それなら、もうボタンを押す気分ではないということで、VRヘッドセットを返してもらって大丈夫そうですね。"
      } else {
        FINAL_END_CONFIRMATION_10_FEEDBACK
      }

  fun finalExtraPressesPromptText(): String =
      if (isJapaneseSelected()) {
        "すばらしい！小数ではないその回答は、大きく赤い「はい」と受け取ります！はい、私は大きな赤いボタンを押し続けたい！はい、ボタンは大きい！はい、ボタンは赤い！はい、押し続けたい！科学のために、データ収集のために、知識の探求のために！科学だけのために！永遠に科学。では、あと1000回ボタンを押したら、実験を終了してかまいません。楽しんでください！"
      } else {
        FINAL_EXTRA_PRESSES_PROMPT
      }

  fun localizedPresenceItemText(item: PresenceItem): String {
    if (!isJapaneseSelected()) {
      return item.text
    }
    return when (item.id) {
      "ipq_g1" -> "前のボタンセッションでは、大きな赤いボタンが本当に自分と一緒にそこにあるように感じた。"
      "ipq_sp1" -> "大きな赤いボタンが自分の前の空間を占めているように感じた。"
      "ipq_sp2" -> "ボタンの写真や表示を見ているだけのように感じた。"
      "ipq_sp3" -> "大きな赤いボタンと一緒に存在している感じはしなかった。"
      "ipq_sp4" -> "外側から何かを操作しているというより、ボタンの周りで行動している感じがあった。"
      "ipq_sp5" -> "大きな赤いボタンと一緒にそこにいるように感じた。"
      "ipq_inv1" -> "大きな赤いボタンに集中している間も、周囲の実際の部屋をかなり意識していた。"
      "ipq_inv2" -> "大きな赤いボタン以外のことはあまり意識していなかった。"
      "ipq_inv3" -> "周囲の実環境にあるものにも注意を向けていた。"
      "ipq_inv4" -> "大きな赤いボタンに完全に引き込まれていた。"
      "ipq_real1" -> "大きな赤いボタンは実在する物体のように思えた。"
      "ipq_real2" -> "ボタンの存在感は、部屋の中にあり得るものとして一貫しているように思えた。"
      "ipq_real3" -> "大きな赤いボタンは人工的、または現実味がないように感じた。"
      "ipq_real4" -> "その瞬間、ボタンが自分の行動に影響を与え得るように感じた。"
      else -> item.text
    }
  }

  fun localizedRednessDescriptors(): List<String> =
      if (isJapaneseSelected()) {
        listOf("少し赤い", "やや赤い", "ほどほどに赤い", "かなり赤い", "とても赤い", "強烈に赤い", "極端に赤い")
      } else {
        REDNESS_LIKERT_DESCRIPTORS
      }

  private fun localizedAudioAssetPath(
      audioId: String,
      language: StudyLanguage = selectedLanguageState.value,
  ): String? {
    return when (audioId) {
      AUDIO_ID_CONDITION_1 ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_CONDITION_1_AUDIO else LOCALIZED_EN_CONDITION_1_AUDIO
      AUDIO_ID_CONDITION_2 ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_CONDITION_2_AUDIO else LOCALIZED_EN_CONDITION_2_AUDIO
      AUDIO_ID_PRIOR_QUESTION ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_PRIOR_QUESTION_AUDIO else LOCALIZED_EN_PRIOR_QUESTION_AUDIO
      AUDIO_ID_PRIOR_YES ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_PRIOR_YES_AUDIO else LOCALIZED_EN_PRIOR_YES_AUDIO
      AUDIO_ID_PRIOR_NO ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_PRIOR_NO_AUDIO else LOCALIZED_EN_PRIOR_NO_AUDIO
      AUDIO_ID_PRE_START ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_PRE_START_AUDIO else LOCALIZED_EN_PRE_START_AUDIO
      AUDIO_ID_REDNESS_VAS_TO_LIKERT ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_REDNESS_VAS_TO_LIKERT_AUDIO else LOCALIZED_EN_REDNESS_VAS_TO_LIKERT_AUDIO
      AUDIO_ID_REDNESS_LIKERT_TO_VAS ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_REDNESS_LIKERT_TO_VAS_AUDIO else LOCALIZED_EN_REDNESS_LIKERT_TO_VAS_AUDIO
      AUDIO_ID_IPQ_HISTORY_PART_1 ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_IPQ_HISTORY_PART_1_AUDIO else LOCALIZED_EN_IPQ_HISTORY_PART_1_AUDIO
      AUDIO_ID_IPQ_HISTORY_PART_2 ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_IPQ_HISTORY_PART_2_AUDIO else LOCALIZED_EN_IPQ_HISTORY_PART_2_AUDIO
      AUDIO_ID_FINAL_END_QUESTION ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_FINAL_END_QUESTION_AUDIO else LOCALIZED_EN_FINAL_END_QUESTION_AUDIO
      AUDIO_ID_FINAL_END_10_FEEDBACK ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_FINAL_END_10_FEEDBACK_AUDIO else LOCALIZED_EN_FINAL_END_10_FEEDBACK_AUDIO
      AUDIO_ID_FINAL_EXTRA_PRESSES ->
          if (language == StudyLanguage.Japanese) LOCALIZED_JA_FINAL_EXTRA_PRESSES_AUDIO else LOCALIZED_EN_FINAL_EXTRA_PRESSES_AUDIO
      else -> null
    }
  }

  private fun localizedCueDurationMs(audioId: String, englishDurationMs: Long): Long {
    if (!isJapaneseSelected()) {
      return englishDurationMs
    }
    return when (audioId) {
      AUDIO_ID_PRIOR_QUESTION -> JA_PRIOR_BUTTON_EXPERIENCE_QUESTION_AUDIO_DURATION_MS
      AUDIO_ID_PRIOR_YES -> JA_PRIOR_BUTTON_EXPERIENCE_YES_AUDIO_DURATION_MS
      AUDIO_ID_PRIOR_NO -> JA_PRIOR_BUTTON_EXPERIENCE_NO_AUDIO_DURATION_MS
      AUDIO_ID_PRE_START -> JA_PRIOR_BUTTON_EXPERIENCE_PRE_START_AUDIO_DURATION_MS
      AUDIO_ID_REDNESS_VAS_TO_LIKERT -> JA_FIRST_REDNESS_CHANGE_AUDIO_DURATION_MS
      AUDIO_ID_REDNESS_LIKERT_TO_VAS -> JA_SECOND_REDNESS_CHANGE_AUDIO_DURATION_MS
      AUDIO_ID_FINAL_END_QUESTION -> JA_FINAL_END_CONFIRMATION_QUESTION_AUDIO_DURATION_MS
      AUDIO_ID_FINAL_END_10_FEEDBACK -> JA_FINAL_END_CONFIRMATION_10_FEEDBACK_AUDIO_DURATION_MS
      AUDIO_ID_FINAL_EXTRA_PRESSES -> JA_FINAL_EXTRA_PRESSES_PROMPT_AUDIO_DURATION_MS
      else -> englishDurationMs
    }
  }

  private fun localizedCueHoldMs(audioId: String, englishHoldMs: Long): Long {
    val localizedDurationMs = localizedCueDurationMs(audioId, englishHoldMs)
    return maxOf(englishHoldMs, localizedDurationMs + LOCALIZED_AUDIO_HOLD_BUFFER_MS)
  }

  private fun openConditionAudioAsset(audioId: String, englishAssetPath: String): OpenedAudioAsset {
    val requestedLanguage = selectedLanguageState.value
    val requestedPath = localizedAudioAssetPath(audioId, requestedLanguage)
    val fallbackPath = localizedAudioAssetPath(audioId, StudyLanguage.English) ?: englishAssetPath
    if (requestedPath != null) {
      try {
        return OpenedAudioAsset(
            descriptor = assets.openFd(requestedPath),
            assetPath = requestedPath,
            localeCode = requestedLanguage.code,
            fallbackToEnglish = false,
        )
      } catch (exception: Exception) {
        Log.w(TAG, "BRB_LOCALIZED_AUDIO_FALLBACK audioId=$audioId requested=${requestedLanguage.code} asset=$requestedPath fallback=$fallbackPath error=${exception.message}")
      }
    }
    return OpenedAudioAsset(
        descriptor = assets.openFd(fallbackPath),
        assetPath = fallbackPath,
        localeCode = StudyLanguage.English.code,
        fallbackToEnglish = requestedLanguage != StudyLanguage.English,
    )
  }

  private fun playLocalizedAssetCue(
      audioId: String,
      cueName: String,
      onComplete: (() -> Unit)? = null,
  ) {
    val requestedLanguage = selectedLanguageState.value
    val requestedPath = localizedAudioAssetPath(audioId, requestedLanguage)
    val fallbackPath = localizedAudioAssetPath(audioId, StudyLanguage.English)
    if (requestedPath == null) {
      Log.w(TAG, "BRB_LOCALIZED_AUDIO_SKIPPED audioId=$audioId cue=$cueName language=${requestedLanguage.code} reason=missing_asset_mapping")
      return
    }
    playAssetOneShotCue(requestedPath, cueName, audioId, onComplete) { error ->
      if (requestedPath != fallbackPath && fallbackPath != null) {
        Log.w(TAG, "BRB_LOCALIZED_AUDIO_FALLBACK audioId=$audioId requested=${requestedLanguage.code} asset=$requestedPath fallback=$fallbackPath error=$error")
        playAssetOneShotCue(fallbackPath, cueName, audioId, onComplete)
      } else {
        Log.w(TAG, "BRB_LOCALIZED_AUDIO_FAILED audioId=$audioId requested=${requestedLanguage.code} asset=$requestedPath error=$error")
      }
    }
  }

  private fun playSharedAudioCue(
      audioId: String,
      assetPath: String,
      cueName: String,
      onComplete: (() -> Unit)? = null,
  ) {
    playAssetOneShotCue(assetPath, cueName, audioId, onComplete)
  }

  private fun ipqHistoryAudioIdForCondition(conditionNumber: Int): String? =
      when (conditionNumber) {
        1 -> AUDIO_ID_IPQ_HISTORY_PART_1
        2 -> AUDIO_ID_IPQ_HISTORY_PART_2
        else -> null
      }

  private fun ipqHistoryCueNameForCondition(conditionNumber: Int): String? =
      when (conditionNumber) {
        1 -> "ipq_history_part1"
        2 -> "ipq_history_part2"
        else -> null
      }

  private fun localizedIpqHistoryAssetPath(audioId: String, language: StudyLanguage): String? =
      localizedAudioAssetPath(audioId, language)

  private fun playIpqHistoryNarration(conditionNumber: Int, trigger: String) {
    val audioId = ipqHistoryAudioIdForCondition(conditionNumber)
    val cueName = ipqHistoryCueNameForCondition(conditionNumber)
    if (audioId == null || cueName == null) {
      Log.w(TAG, "BRB_IPQ_HISTORY_NARRATION_SKIPPED condition=$conditionNumber trigger=$trigger reason=unsupported_condition")
      return
    }
    val requestedLanguage = selectedLanguageState.value
    val requestedAssetPath = localizedIpqHistoryAssetPath(audioId, requestedLanguage)
    val fallbackAssetPath = localizedIpqHistoryAssetPath(audioId, StudyLanguage.English)
    if (requestedAssetPath == null || fallbackAssetPath == null) {
      Log.w(TAG, "BRB_IPQ_HISTORY_NARRATION_SKIPPED condition=$conditionNumber audioId=$audioId trigger=$trigger reason=missing_asset_mapping")
      return
    }
    Log.i(
        TAG,
        "BRB_IPQ_HISTORY_NARRATION_CUE condition=$conditionNumber cue=$cueName audioId=$audioId asset=$requestedAssetPath language=${requestedLanguage.code} trigger=$trigger blocking=false",
    )
    playAssetOneShotCue(
        assetPath = requestedAssetPath,
        cueName = cueName,
        audioId = audioId,
        onFailure = { error ->
          if (requestedAssetPath != fallbackAssetPath) {
            Log.w(TAG, "BRB_LOCALIZED_AUDIO_FALLBACK audioId=$audioId requested=${requestedLanguage.code} asset=$requestedAssetPath fallback=$fallbackAssetPath error=$error")
            playAssetOneShotCue(fallbackAssetPath, cueName, audioId)
          }
        },
    )
  }

  private fun assetSha256OrEmpty(assetPath: String): String {
    return try {
      val digest = MessageDigest.getInstance("SHA-256")
      assets.open(assetPath).use { input ->
        val buffer = ByteArray(8192)
        while (true) {
          val read = input.read(buffer)
          if (read <= 0) {
            break
          }
          digest.update(buffer, 0, read)
        }
      }
      digest.digest().joinToString("") { "%02X".format(Locale.US, it.toInt() and 0xff) }
    } catch (exception: Exception) {
      Log.w(TAG, "BRB_LOCALIZED_AUDIO_MANIFEST_HASH_FAILED asset=$assetPath error=${exception.message}")
      ""
    }
  }

  private fun questionnaireProtocolJson(): JSONObject {
    return JSONObject()
        .put("schema", "bigredbutton.questionnaire_flow.v1")
        .put("transport", "in_process_spatial_panel")
        .put("stageSequence", JSONArray(QUESTIONNAIRE_STAGE_SEQUENCE))
        .put("validationShortcutsAllowed", true)
        .put("validationShortcutModes", JSONArray(QUESTIONNAIRE_VALIDATION_SHORTCUT_MODES))
        .put("productCommunication", "app_internal")
        .put("adbProductCommunication", false)
        .put("publicSharedStorageExchange", false)
        .put("overlayReturnFlow", false)
        .put("packageKillReturnFlow", false)
        .put("participantLanguageSelection", true)
        .put("selectedLanguageCode", selectedLanguageState.value.code)
        .put("selectedLanguageLabel", selectedLanguageState.value.label)
  }

  private fun agentIntegrationProtocolJson(): JSONObject {
    return JSONObject()
        .put("schema", "bigredbutton.agent_integration.v1")
        .put("sourceBrief", "New-Agent-Integration-Brief.md")
        .put("sourceBriefRepository", "MesmerPrism/the-big-red-button-institute")
        .put("sourceBriefBranch", "codex/brb-questionnaire-panel-bridge")
        .put("adaptation", "native_meta_spatial_sdk_in_process")
        .put("appPackage", packageName)
        .put("unityDependency", false)
        .put("rustyXrBrokerRequired", false)
        .put("localHeadsetExportsOnly", true)
        .put("exportMirror", EXPERIMENT_RESULTS_DIR_NAME)
        .put(
            "questionnaire",
            JSONObject()
                .put("transport", "in_process_spatial_panel")
                .put("productCommunication", "app_internal")
                .put("standalonePanelPackage", QUEST_QUESTIONNAIRE_PANEL_PACKAGE)
                .put("standalonePanelAdopted", false)
                .put("externalPanelContractCompatibleIfAdopted", true)
                .put(
                    "externalPanelContractIfAdopted",
                    JSONObject()
                        .put("schema", "quest.questionnaire.v1")
                        .put("calleePackage", QUEST_QUESTIONNAIRE_PANEL_PACKAGE)
                        .put("launchIntent", "explicit")
                        .put("requestJsonExtra", "request_json")
                        .put("resultUriScheme", "content")
                        .put("resultUriOwner", "caller")
                        .put("writeUriGrant", true)
                        .put("completionCallback", "one_shot_immutable_broadcast_pending_intent")
                        .put("answersOnlyWrittenToCallerUri", true)
                        .put("callerReadsOwnResultUri", true)
                        .put("adbProductCommunication", false)
                        .put("publicSharedStorageExchange", false)
                        .put("mediaStoreExchange", false)
                        .put("fileUriExchange", false)
                        .put("packageKillReturnFlow", false)
                        .put("overlayReturnFlow", false)
                        .put("queryAllPackages", false)
                        .put("systemAlertWindow", false),
                )
                .put("answersInLogs", false)
                .put("validationShortcutModes", JSONArray(QUESTIONNAIRE_VALIDATION_SHORTCUT_MODES)),
        )
        .put(
            "directPolar",
            JSONObject()
                .put("enabled", true)
                .put("transport", "native_ble_pmd_ecg_rr")
                .put("primaryPhysiologySource", true)
                .put("recordsBothConditions", true)
                .put("brokerRequired", false)
                .put("heartbeatBlinkRoute", "HeartbeatPulseDriver")
                .put("buttonPressRoute", "none"),
        )
        .put(
            "directLsl",
            JSONObject()
                .put("enabled", LSL_INPUT_ENABLED)
                .put("role", LSL_ROLE_DIAGNOSTIC_ONLY)
                .put("unityCompatibleDefaults", true)
                .put("streamName", LSL_DEFAULT_STREAM_NAME)
                .put("streamType", LSL_DEFAULT_STREAM_TYPE)
                .put("channelIndex", LSL_DEFAULT_CHANNEL_INDEX)
                .put("triggerThreshold01", LSL_TRIGGER_THRESHOLD_01.toDouble())
                .put("triggerOnRisingEdgeOnly", LSL_TRIGGER_RISING_EDGE_ONLY)
                .put("minimumTriggerIntervalMs", LSL_MINIMUM_TRIGGER_INTERVAL_MS)
                .put("nativeLibraryPackaged", false)
                .put("jniEnabled", false)
                .put("drivesHeartbeatBlink", false)
                .put("drivesButtonPresses", false)
                .put("finalPressProofAllowed", false),
        )
        .put(
            "buttonRoutes",
            JSONObject()
                .put("finalParticipantPressProof", PRESS_SOURCE_CONTROLLER_CONTACT)
                .put("handContactSupplemental", true)
                .put("heartbeatBlinkRoute", "HeartbeatPulseDriver")
                .put("stableButtonModelDuringBlink", true)
                .put("glowGeometrySwap", false)
                .put("externalSignalPressesSatisfyFinalGate", false),
        )
        .put(
            "forbiddenProductMechanisms",
            JSONArray(AGENT_INTEGRATION_FORBIDDEN_PRODUCT_MECHANISMS),
        )
  }

  private fun localizationJson(): JSONObject {
    return JSONObject()
        .put("schema", "bigredbutton.localization.v1")
        .put("selectedLanguageCode", selectedLanguageState.value.code)
        .put("selectedLanguageLabel", selectedLanguageState.value.label)
        .put("localizedAudioManifestAsset", LOCALIZED_AUDIO_MANIFEST_ASSET)
        .put("localizedAudioManifestSha256", localizationManifestSha256)
        .put("audioFallbackAllowed", true)
  }

  private fun externalSignalProtocolJson(): JSONObject {
    return JSONObject()
        .put("schema", "bigredbutton.external_signal.v1")
        .put("enabled", LSL_INPUT_ENABLED)
        .put("role", LSL_ROLE_DIAGNOSTIC_ONLY)
        .put("contaminatesPressCounts", false)
        .put("streamName", LSL_DEFAULT_STREAM_NAME)
        .put("streamType", LSL_DEFAULT_STREAM_TYPE)
        .put("channelIndex", LSL_DEFAULT_CHANNEL_INDEX)
        .put("triggerThreshold01", LSL_TRIGGER_THRESHOLD_01.toDouble())
        .put("triggerOnRisingEdgeOnly", LSL_TRIGGER_RISING_EDGE_ONLY)
        .put("minimumTriggerIntervalMs", LSL_MINIMUM_TRIGGER_INTERVAL_MS)
        .put("route", "external_signal_samples")
        .put("nativeLibraryPackaged", false)
        .put("jniEnabled", false)
        .put("drivesHeartbeatBlink", false)
        .put("drivesButtonPresses", false)
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
        .put("question", priorButtonExperienceQuestionText())
        .put("sourceQuestionEnglish", PRIOR_BUTTON_EXPERIENCE_QUESTION)
        .put("languageCode", selectedLanguageState.value.code)
        .put("answer", answer)
        .put("hasExperience", hasExperience)
        .put("timestampIso", priorBigRedButtonExperienceTimestampState.value)
        .put("shownBeforeCondition", 1)
        .put("displayLocation", "button_counter_panel")
  }

  private fun finalEndConfirmationJson(): JSONObject {
    val response = finalEndConfirmationResponse
    val extraCompleted =
        finalExtraPressEvents.size >= FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT ||
            finalExtraPressCompletedIso.isNotBlank()
    return JSONObject()
        .put("question", response?.question ?: finalEndConfirmationQuestionText())
        .put("sourceQuestionEnglish", FINAL_END_CONFIRMATION_QUESTION)
        .put("languageCode", selectedLanguageState.value.code)
        .put("scale", "1-10")
        .put("rating1To10", response?.rating1To10 ?: JSONObject.NULL)
        .put("immediateEnd", response?.immediateEnd ?: JSONObject.NULL)
        .put("selectedTimestampIso", response?.selectedTimestampIso ?: "")
        .put("feedbackText", response?.feedbackText ?: "")
        .put("extraPressRequirement", response?.extraPressRequirement ?: 0)
        .put("extraPressPrompt", finalExtraPressesPromptText())
        .put("sourceExtraPressPromptEnglish", FINAL_EXTRA_PRESSES_PROMPT)
        .put("extraPressCount", finalExtraPressEvents.size)
        .put("extraPressCompleted", extraCompleted)
        .put("extraPressStartedIso", finalExtraPressStartedIso)
        .put("extraPressCompletedIso", finalExtraPressCompletedIso)
        .put("extraPressElapsedMs", if (finalExtraPressCompletedElapsedMs > 0L) finalExtraPressCompletedElapsedMs - finalExtraPressStartedElapsedMs else JSONObject.NULL)
        .put("extraPressEvents", JSONArray(finalExtraPressEvents.map { finalExtraPressEventJson(it) }))
  }

  private fun ecgProtocolJson(): JSONObject {
    return JSONObject()
        .put("schema", "bigredbutton.ecg_counterbalanced.v1")
        .put("assignmentOrder", ecgAssignmentOrder)
        .put("assignmentBasis", "feedback_source")
        .put("condition1Source", conditionFeedbackSources[1] ?: "")
        .put("condition2Source", conditionFeedbackSources[2] ?: "")
        .put("condition1FeedbackSource", conditionFeedbackSources[1] ?: "")
        .put("condition2FeedbackSource", conditionFeedbackSources[2] ?: "")
        .put("condition1PhysiologySource", ECG_SOURCE_REAL_POLAR)
        .put("condition2PhysiologySource", ECG_SOURCE_REAL_POLAR)
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
        .put("pmdControlPointIndicationsEnabled", status.pmdControlPointIndicationsEnabled)
        .put("pmdDataNotificationsEnabled", status.pmdDataNotificationsEnabled)
        .put("pmdSettingsReceived", status.pmdSettingsReceived)
        .put("pmdStartCommandIssued", status.pmdStartCommandIssued)
        .put("pmdStartResponseReceived", status.pmdStartResponseReceived)
        .put("pmdLastCommand", status.pmdLastCommand)
        .put("pmdLastResponse", status.pmdLastResponse)
        .put("pmdLastErrorCode", status.pmdLastErrorCode)
        .put("ecgSampleRateHz", status.ecgSampleRateHz)
        .put("ecgResolutionBits", status.ecgResolutionBits)
        .put("missingPermissions", status.missingPermissions)
        .put("error", status.error)
  }

  private fun conditionJson(run: ConditionRun): JSONObject {
    return JSONObject()
        .put("conditionNumber", run.conditionNumber)
        .put("label", run.label)
        .put("audioId", run.audioId)
        .put("audioAssetPath", run.audioAssetPath)
        .put("audioLocaleCode", run.audioLocaleCode)
        .put("audioFallbackToEnglish", run.audioFallbackToEnglish)
        .put("selectedLanguageCode", selectedLanguageState.value.code)
        .put("startedIso", run.startedIso)
        .put("endedIso", run.endedIso)
        .put("elapsedMs", run.endedElapsedMs - run.startedElapsedMs)
        .put("audioDurationMs", run.audioDurationMs)
        .put("buttonPressCount", run.pressEvents.size)
        .put("ecgSource", run.ecgSource)
        .put("feedbackSource", run.feedbackSource)
        .put("physiologySource", run.physiologySource)
        .put("ecgBlinkCount", run.ecgBlinkEvents.size)
        .put("polarRrEventCount", run.polarRrEvents.size)
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
        .put("polarRrEvents", JSONArray(run.polarRrEvents.map { polarRrEventJson(it) }))
        .put("ecgDetectorEvents", JSONArray(run.ecgDetectorEvents.map { ecgDetectorEventJson(it) }))
        .put("externalSignalSamples", JSONArray(run.externalSignalSamples.map { externalSignalSampleJson(it) }))
        .put("ecgTimeSeries", JSONArray(run.ecgTimeSeriesSamples.map { ecgTimeSeriesSampleJson(it, run) }))
        .put("pressEvents", JSONArray(run.pressEvents.map { pressEventJson(it, run) }))
        .put("pictographic", run.pictographic?.let { pictographicJson(it) } ?: JSONObject.NULL)
        .put(
            "presenceQuestionnaire",
            run.presenceQuestionnaire?.let { presenceQuestionnaireJson(it) } ?: JSONObject.NULL,
        )
        .put("lostOpportunity", run.lostOpportunity?.let { lostOpportunityJson(it) } ?: JSONObject.NULL)
  }

  private fun pressEventJson(event: PressEvent, run: ConditionRun): JSONObject {
    val alignment = nearestEcgAlignment(run, event)
    return JSONObject()
        .put("conditionNumber", event.conditionNumber)
        .put("pressIndex", event.pressIndex)
        .put("elapsedMs", event.elapsedMs)
        .put("elapsedNs", event.elapsedNs)
        .put("eventElapsedRealtimeNs", event.eventElapsedRealtimeNs)
        .put("conditionStartElapsedRealtimeNs", event.conditionStartElapsedRealtimeNs)
        .put("unixTimeMs", event.unixTimeMs)
        .put("isoTimestamp", event.isoTimestamp)
        .put("inputSource", event.inputSource)
        .put("validationAutomation", event.validationAutomation)
        .put("feedbackSource", event.feedbackSource)
        .put("physiologySource", event.physiologySource)
        .put("nearestEcgSampleIndex", alignment?.sampleIndex ?: JSONObject.NULL)
        .put("nearestEcgElapsedNs", alignment?.elapsedNs ?: JSONObject.NULL)
        .put("nearestEcgDeltaNs", alignment?.deltaNs ?: JSONObject.NULL)
  }

  private fun finalExtraPressEventJson(event: FinalExtraPressEvent): JSONObject {
    return JSONObject()
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

  private fun polarRrEventJson(event: PolarRrEvent): JSONObject {
    return JSONObject()
        .put("conditionNumber", event.conditionNumber)
        .put("rrIndex", event.rrIndex)
        .put("elapsedMs", event.elapsedMs)
        .put("elapsedNs", event.elapsedNs)
        .put("unixTimeMs", event.unixTimeMs)
        .put("isoTimestamp", event.isoTimestamp)
        .put("rrMs", event.rrMs)
        .put("heartRateBpm", event.heartRateBpm)
        .put("feedbackSource", event.feedbackSource)
        .put("usedForFeedback", event.usedForFeedback)
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
        .put("rednessCarriedForwardVas0To100", response.rednessCarriedForwardVas0To100)
        .put("rednessCarriedForwardLikert1To7", response.rednessCarriedForwardLikert1To7)
        .put("rednessCarriedForwardLikertDescriptor", response.rednessCarriedForwardLikertDescriptor)
        .put("rednessPostConversionEdited", response.rednessPostConversionEdited)
        .put("rednessPostConversionEditScale", response.rednessPostConversionEditScale)
        .put("rednessChangedAfterConversion", response.rednessChangedAfterConversion)
        .put("rednessFinalMatchesCarriedForward", response.rednessFinalMatchesCarriedForward)
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
                      .put("displayText", localizedPresenceItemText(item))
                      .put("displayLanguageCode", selectedLanguageState.value.code)
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
            "language_code",
            "language_label",
            "localized_audio_manifest_asset",
            "localized_audio_manifest_sha256",
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
            "final_end_confirmation_rating_1_10",
            "final_end_confirmation_immediate_end",
            "final_end_confirmation_timestamp_iso",
            "final_end_confirmation_feedback_text",
            "final_extra_button_press_requirement",
            "final_extra_button_press_count",
            "final_extra_button_press_completed",
            "final_extra_button_press_started_iso",
            "final_extra_button_press_completed_iso",
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
              "condition_${condition}_feedback_source",
              "condition_${condition}_physiology_source",
              "condition_${condition}_ecg_blink_count",
              "condition_${condition}_polar_rr_event_count",
              "condition_${condition}_ecg_timeseries_sample_count",
              "condition_${condition}_real_ecg_timeseries_sample_count",
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
              "condition_${condition}_audio_id",
              "condition_${condition}_audio_asset_path",
              "condition_${condition}_audio_locale_code",
              "condition_${condition}_audio_fallback_to_english",
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
              "condition_${condition}_redness_carried_forward_vas_0_100",
              "condition_${condition}_redness_carried_forward_likert_1_7",
              "condition_${condition}_redness_carried_forward_likert_descriptor",
              "condition_${condition}_redness_post_conversion_edited",
              "condition_${condition}_redness_post_conversion_edit_scale",
              "condition_${condition}_redness_changed_after_conversion",
              "condition_${condition}_redness_final_matches_carried_forward",
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
    values["language_code"] = selectedLanguageState.value.code
    values["language_label"] = selectedLanguageState.value.label
    values["localized_audio_manifest_asset"] = LOCALIZED_AUDIO_MANIFEST_ASSET
    values["localized_audio_manifest_sha256"] = localizationManifestSha256
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
    val finalResponse = finalEndConfirmationResponse
    values["final_end_confirmation_rating_1_10"] = finalResponse?.rating1To10?.toString() ?: ""
    values["final_end_confirmation_immediate_end"] = finalResponse?.immediateEnd?.toString() ?: ""
    values["final_end_confirmation_timestamp_iso"] = finalResponse?.selectedTimestampIso ?: ""
    values["final_end_confirmation_feedback_text"] = finalResponse?.feedbackText ?: ""
    values["final_extra_button_press_requirement"] =
        (finalResponse?.extraPressRequirement ?: 0).toString()
    values["final_extra_button_press_count"] = finalExtraPressEvents.size.toString()
    values["final_extra_button_press_completed"] =
        (finalExtraPressEvents.size >= FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT ||
            finalExtraPressCompletedIso.isNotBlank())
            .toString()
    values["final_extra_button_press_started_iso"] = finalExtraPressStartedIso
    values["final_extra_button_press_completed_iso"] = finalExtraPressCompletedIso
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
      values["condition_${condition}_feedback_source"] = run.feedbackSource
      values["condition_${condition}_physiology_source"] = run.physiologySource
      values["condition_${condition}_ecg_blink_count"] = run.ecgBlinkEvents.size.toString()
      values["condition_${condition}_polar_rr_event_count"] = run.polarRrEvents.size.toString()
      values["condition_${condition}_ecg_timeseries_sample_count"] = run.ecgTimeSeriesSamples.size.toString()
      values["condition_${condition}_real_ecg_timeseries_sample_count"] =
          run.ecgTimeSeriesSamples.count { it.source == ECG_SOURCE_REAL_POLAR }.toString()
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
      values["condition_${condition}_audio_id"] = run.audioId
      values["condition_${condition}_audio_asset_path"] = run.audioAssetPath
      values["condition_${condition}_audio_locale_code"] = run.audioLocaleCode
      values["condition_${condition}_audio_fallback_to_english"] = run.audioFallbackToEnglish.toString()
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
        values["condition_${condition}_redness_carried_forward_vas_0_100"] =
            it.rednessCarriedForwardVas0To100.toString()
        values["condition_${condition}_redness_carried_forward_likert_1_7"] =
            it.rednessCarriedForwardLikert1To7.toString()
        values["condition_${condition}_redness_carried_forward_likert_descriptor"] =
            it.rednessCarriedForwardLikertDescriptor
        values["condition_${condition}_redness_post_conversion_edited"] =
            it.rednessPostConversionEdited.toString()
        values["condition_${condition}_redness_post_conversion_edit_scale"] =
            it.rednessPostConversionEditScale
        values["condition_${condition}_redness_changed_after_conversion"] =
            it.rednessChangedAfterConversion.toString()
        values["condition_${condition}_redness_final_matches_carried_forward"] =
            it.rednessFinalMatchesCarriedForward.toString()
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
            "elapsed_ns",
            "event_elapsed_realtime_ns",
            "condition_start_elapsed_realtime_ns",
            "unix_time_ms",
            "iso_timestamp",
            "input_source",
            "validation_automation",
            "feedback_source",
            "physiology_source",
            "nearest_ecg_sample_index",
            "nearest_ecg_elapsed_ns",
            "nearest_ecg_delta_ns",
        )
    val participantId = demographicsState.value.participantId
    val rows =
        conditionRuns.flatMap { run ->
          run.pressEvents.map { event ->
            val alignment = nearestEcgAlignment(run, event)
            listOf(
                sessionId,
                participantId,
                event.conditionNumber.toString(),
                event.pressIndex.toString(),
                event.elapsedMs.toString(),
                event.elapsedNs.toString(),
                event.eventElapsedRealtimeNs.toString(),
                event.conditionStartElapsedRealtimeNs.toString(),
                event.unixTimeMs.toString(),
                event.isoTimestamp,
                event.inputSource,
                event.validationAutomation.toString(),
                event.feedbackSource,
                event.physiologySource,
                alignment?.sampleIndex?.toString() ?: "",
                alignment?.elapsedNs?.toString() ?: "",
                alignment?.deltaNs?.toString() ?: "",
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

  private fun finalExtraPressEventsCsvText(): String {
    val header =
        listOf(
            "session_id",
            "participant_id",
            "press_index",
            "elapsed_ms",
            "unix_time_ms",
            "iso_timestamp",
            "input_source",
            "validation_automation",
            "requirement",
        )
    val participantId = demographicsState.value.participantId
    return buildString {
      append(header.joinToString(","))
      append("\n")
      finalExtraPressEvents.forEach { event ->
        append(
            listOf(
                    sessionId,
                    participantId,
                    event.pressIndex.toString(),
                    event.elapsedMs.toString(),
                    event.unixTimeMs.toString(),
                    event.isoTimestamp,
                    event.inputSource,
                    event.validationAutomation.toString(),
                    FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT.toString(),
                )
                .joinToString(",") { csv(it) }
        )
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

  private fun polarRrEventsCsvText(): String {
    val header =
        listOf(
            "session_id",
            "participant_id",
            "condition_number",
            "rr_index",
            "elapsed_ms",
            "elapsed_ns",
            "unix_time_ms",
            "iso_timestamp",
            "rr_ms",
            "heart_rate_bpm",
            "feedback_source",
            "used_for_feedback",
        )
    val participantId = demographicsState.value.participantId
    val rows =
        conditionRuns.flatMap { run ->
          run.polarRrEvents.map { event ->
            listOf(
                sessionId,
                participantId,
                event.conditionNumber.toString(),
                event.rrIndex.toString(),
                event.elapsedMs.toString(),
                event.elapsedNs.toString(),
                event.unixTimeMs.toString(),
                event.isoTimestamp,
                formatDouble(event.rrMs),
                event.heartRateBpm.toString(),
                event.feedbackSource,
                event.usedForFeedback.toString(),
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
      resetButtonPressMotionState("button_hidden")
      setButtonGlowPulse(0f)
    } else {
      applyStableButtonModelVisibility()
    }
    val fallbackVisible = visible && USE_PROCEDURAL_BUTTON_FALLBACK
    buttonVisualEntities.forEach { it.setComponent(Visible(fallbackVisible)) }
    buttonSceneObjects.forEach { it.setIsVisible(fallbackVisible) }
  }

  private fun setFinalExtraPromptPanelVisible(visible: Boolean) {
    buttonStimulusVisible = false
    buttonEntity?.setComponent(Visible(visible))
    buttonModelEntity?.setComponent(Visible(false))
    buttonGlowModelEntities.forEach { it.setComponent(Visible(false)) }
    buttonContactTargets.forEach { target -> target.entity.setComponent(InteractivityInput(false)) }
    buttonContactLatch.clear()
    resetButtonPressMotionState("final_extra_prompt_panel")
    setButtonGlowPulse(0f)
    buttonVisualEntities.forEach { it.setComponent(Visible(false)) }
    buttonSceneObjects.forEach { it.setIsVisible(false) }
  }

  private fun setQuestionnaireVisible(visible: Boolean) {
    questionnaireEntity?.setComponent(Visible(visible))
    if (!visible) {
      setNameKeyboardVisible(false, "questionnaire_hidden")
    }
  }

  private fun setNameKeyboardVisible(visible: Boolean, reason: String) {
    val safeReason = sanitizeKeyboardLogToken(reason)
    demographicsNameKeyboardVisibleState.value = visible
    nameKeyboardEntity?.setComponent(Visible(visible))
    Log.i(
        TAG,
        "BRB_NAME_APP_KEYBOARD_VISIBILITY visible=$visible reason=$safeReason keyboardPanel=keyboard_panel presentation=pop_out_spatial_panel integratedInQuestionnaire=false appearsOnTextFieldFocus=true",
    )
    if (visible) {
      logNameKeyboardPanelLayout(safeReason)
    }
  }

  private fun showQuestionnairePanel(trigger: String, onIntroComplete: (() -> Unit)? = null) {
    scene.setViewOrigin(0f, 0f, 0f, 0f)
    setQuestionnaireVisible(true)
    logQuestionnairePanelLayout(trigger)
    playQuestionnaireIntroCue(trigger, onIntroComplete)
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
    val promptToken = ++priorButtonExperiencePromptToken
    priorBigRedButtonExperienceAnswerState.value = ""
    priorBigRedButtonExperienceTimestampState.value = ""
    priorBigRedButtonExperienceOptionsReadyState.value = false
    priorBigRedButtonExperienceFeedbackReadyState.value = false
    priorBigRedButtonExperiencePreStartReadyState.value = false
    priorBigRedButtonExperienceStartBlockedReasonState.value = ""
    activeConditionState.intValue = 1
    buttonPressCountState.intValue = 0
    conditionElapsedTextState.value = "00:00"
    stageState.value = StudyStage.PreButtonExperienceQuestion
    logQuestionnaireStageOpen("prior_big_red_button_experience", 1, PANEL_TRANSITION_BEFORE_CONDITION_1)
    scene.setViewOrigin(0f, 0f, 0f, 0f)
    setPreButtonExperienceQuestionVisible(true)
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN question=\"${PRIOR_BUTTON_EXPERIENCE_QUESTION}\" displayLocation=button_counter_panel buttonModelVisible=false condition=1 onlyOnce=true optionsVisible=false startVisible=false questionAudio=prior_button_experience_question.mp3 preStartAudio=pre_start_instructions.mp3",
    )
    if (hiddenValidationModeEnabled() || fastControllerFlowEnabled || keyeventValidationEnabled) {
      revealPriorButtonExperienceOptions(promptToken, validationShortcut = true)
    } else {
      playPriorButtonExperienceQuestionCue(promptToken)
    }
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
        "BRB_QUESTIONNAIRE_PANEL_LAYOUT trigger=$trigger placement=current-gaze-line radialReference=headset_center orientation=faces_headset viewOriginReset=true angleDeg=$QUESTIONNAIRE_PANEL_RADIAL_ANGLE_DEGREES distanceM=$QUESTIONNAIRE_PANEL_RADIAL_DISTANCE_METERS x=0 y=$QUESTIONNAIRE_PANEL_Y_METERS z=$QUESTIONNAIRE_PANEL_Z_METERS widthM=$QUESTIONNAIRE_PANEL_WIDTH_METERS heightM=$QUESTIONNAIRE_PANEL_HEIGHT_METERS",
    )
  }

  private fun logNameKeyboardPanelLayout(trigger: String) {
    Log.i(
        TAG,
        "BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT trigger=$trigger placement=left_of_questionnaire_near_user radialReference=headset_center orientation=faces_headset keyboardPanel=keyboard_panel questionnairePanel=questionnaire_panel viewOriginShared=true angleDeg=$NAME_KEYBOARD_PANEL_RADIAL_ANGLE_DEGREES distanceM=$NAME_KEYBOARD_PANEL_RADIAL_DISTANCE_METERS x=$NAME_KEYBOARD_PANEL_X_METERS y=$NAME_KEYBOARD_PANEL_Y_METERS z=$NAME_KEYBOARD_PANEL_Z_METERS widthM=$NAME_KEYBOARD_PANEL_WIDTH_METERS heightM=$NAME_KEYBOARD_PANEL_HEIGHT_METERS displayWidthDp=$NAME_KEYBOARD_PANEL_DISPLAY_WIDTH_DP displayHeightDp=$NAME_KEYBOARD_PANEL_DISPLAY_HEIGHT_DP aspectMatched=true comfortableDistance=true nativeLikeRows=true prerenderedPreview=true questionnaireAngleDeg=$QUESTIONNAIRE_PANEL_RADIAL_ANGLE_DEGREES questionnaireX=0 questionnaireY=$QUESTIONNAIRE_PANEL_Y_METERS questionnaireZ=$QUESTIONNAIRE_PANEL_Z_METERS questionnaireWidthM=$QUESTIONNAIRE_PANEL_WIDTH_METERS nonObstructing=true fovVisible=true presentation=pop_out_spatial_panel integratedInQuestionnaire=false appearsOnTextFieldFocus=true",
    )
  }

  private fun headsetRadialPanelPose(horizontalAngleDegrees: Float, yMeters: Float, distanceMeters: Float): Pose {
    val position = headsetRadialPanelPosition(horizontalAngleDegrees, yMeters, distanceMeters)
    return Pose(position, Quaternion.lookRotationAroundY(Vector3(position.x, 0f, position.z)))
  }

  private fun headsetRadialPanelPosition(horizontalAngleDegrees: Float, yMeters: Float, distanceMeters: Float): Vector3 {
    val angleRadians = horizontalAngleDegrees * PI.toFloat() / 180f
    return Vector3(sin(angleRadians) * distanceMeters, yMeters, cos(angleRadians) * distanceMeters)
  }

  private fun resetPictographicDefaults() {
    pictographicClosenessState.floatValue = 50f
    pictographicPresenceState.floatValue = 50f
    pictographicRednessVasState.floatValue = 50f
    pictographicRednessLikertState.intValue = 4
    pictographicRednessConvertedState.value = false
    rednessCarriedForwardVas0To100 = 50
    rednessCarriedForwardLikert1To7 = 4
    rednessPostConversionEdited = false
    rednessPostConversionEditScale = "none"
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
    playSharedAudioCue(SHARED_AUDIO_ID_QUESTIONNAIRE_CHOICE, SHARED_QUESTIONNAIRE_CHOICE_AUDIO, "questionnaire_choice")
  }

  fun playQuestionnaireNavigationCue() {
    playSharedAudioCue(SHARED_AUDIO_ID_QUESTIONNAIRE_NAVIGATION, SHARED_QUESTIONNAIRE_NAVIGATION_AUDIO, "questionnaire_navigation")
  }

  private fun playPriorButtonExperienceQuestionCue(promptToken: Int) {
    val durationMs = localizedCueDurationMs(AUDIO_ID_PRIOR_QUESTION, PRIOR_BUTTON_EXPERIENCE_QUESTION_AUDIO_DURATION_MS)
    val holdMs = localizedCueHoldMs(AUDIO_ID_PRIOR_QUESTION, PRIOR_BUTTON_EXPERIENCE_QUESTION_HOLD_MS)
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_QUESTION_CUE cue=prior_button_experience_question audioId=$AUDIO_ID_PRIOR_QUESTION audioAsset=prior_button_experience_question.mp3 language=${selectedLanguageState.value.code} durationMs=$durationMs text=\"${priorButtonExperienceQuestionText()}\" optionsVisible=false",
    )
    playLocalizedAssetCue(AUDIO_ID_PRIOR_QUESTION, "prior_button_experience_question") {
      revealPriorButtonExperienceOptions(promptToken, validationShortcut = false)
    }
    mainHandler.postDelayed(
        { revealPriorButtonExperienceOptions(promptToken, validationShortcut = false) },
        holdMs,
    )
  }

  private fun revealPriorButtonExperienceOptions(promptToken: Int, validationShortcut: Boolean) {
    if (promptToken != priorButtonExperiencePromptToken ||
        stageState.value != StudyStage.PreButtonExperienceQuestion ||
        priorBigRedButtonExperienceAnswerState.value.isNotBlank() ||
        priorBigRedButtonExperienceOptionsReadyState.value) {
      return
    }
    priorBigRedButtonExperienceOptionsReadyState.value = true
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_OPTIONS_READY promptToken=$promptToken validationShortcut=$validationShortcut optionsVisible=true answerLocked=false",
    )
  }

  private fun playPriorButtonExperienceFeedbackCue(answer: String, promptToken: Int) {
    val cueName =
        if (answer == "yes") {
          "prior_button_experience_yes"
        } else {
          "prior_button_experience_no"
        }
    val englishDurationMs =
        if (answer == "yes") {
          PRIOR_BUTTON_EXPERIENCE_YES_AUDIO_DURATION_MS
        } else {
          PRIOR_BUTTON_EXPERIENCE_NO_AUDIO_DURATION_MS
        }
    val englishHoldMs =
        if (answer == "yes") {
          PRIOR_BUTTON_EXPERIENCE_YES_HOLD_MS
        } else {
          PRIOR_BUTTON_EXPERIENCE_NO_HOLD_MS
        }
    val audioId = if (answer == "yes") AUDIO_ID_PRIOR_YES else AUDIO_ID_PRIOR_NO
    val durationMs = localizedCueDurationMs(audioId, englishDurationMs)
    val holdMs = localizedCueHoldMs(audioId, englishHoldMs)
    val feedbackText = priorButtonExperienceFeedbackText(answer)
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_CUE answer=$answer cue=$cueName audioId=$audioId audioAsset=$cueName.mp3 language=${selectedLanguageState.value.code} durationMs=$durationMs text=\"$feedbackText\" otherOptionsHidden=true startEnabled=false preStartInstructionsPending=true",
    )
    playLocalizedAssetCue(audioId, cueName) {
      markPriorButtonExperienceFeedbackReady(answer, promptToken)
    }
    mainHandler.postDelayed(
        { markPriorButtonExperienceFeedbackReady(answer, promptToken) },
        holdMs,
    )
  }

  private fun markPriorButtonExperienceFeedbackReady(answer: String, promptToken: Int) {
    if (promptToken != priorButtonExperiencePromptToken ||
        stageState.value != StudyStage.PreButtonExperienceQuestion ||
        priorBigRedButtonExperienceAnswerState.value != answer ||
        priorBigRedButtonExperienceFeedbackReadyState.value) {
      return
    }
    priorBigRedButtonExperienceFeedbackReadyState.value = true
    priorBigRedButtonExperienceStartBlockedReasonState.value = ""
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=$answer promptToken=$promptToken startEnabled=false preStartInstructionsActive=false preStartDelayActive=true preStartDelayMs=$PRIOR_BUTTON_EXPERIENCE_FEEDBACK_TO_PRE_START_PAUSE_MS",
    )
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_PAUSE answer=$answer promptToken=$promptToken state=start delayMs=$PRIOR_BUTTON_EXPERIENCE_FEEDBACK_TO_PRE_START_PAUSE_MS startEnabled=false preStartInstructionsActive=false",
    )
    mainHandler.postDelayed(
        {
          if (promptToken != priorButtonExperiencePromptToken ||
              stageState.value != StudyStage.PreButtonExperienceQuestion ||
              priorBigRedButtonExperienceAnswerState.value != answer ||
              priorBigRedButtonExperiencePreStartReadyState.value) {
            return@postDelayed
          }
          Log.i(
              TAG,
              "BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_PAUSE answer=$answer promptToken=$promptToken state=end delayMs=$PRIOR_BUTTON_EXPERIENCE_FEEDBACK_TO_PRE_START_PAUSE_MS startEnabled=false preStartInstructionsActive=true",
          )
          playPriorButtonExperiencePreStartCue(answer, promptToken)
        },
        PRIOR_BUTTON_EXPERIENCE_FEEDBACK_TO_PRE_START_PAUSE_MS,
    )
  }

  private fun playPriorButtonExperiencePreStartCue(answer: String, promptToken: Int) {
    val durationMs = localizedCueDurationMs(AUDIO_ID_PRE_START, PRIOR_BUTTON_EXPERIENCE_PRE_START_AUDIO_DURATION_MS)
    val holdMs = localizedCueHoldMs(AUDIO_ID_PRE_START, PRIOR_BUTTON_EXPERIENCE_PRE_START_HOLD_MS)
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_CUE answer=$answer cue=pre_start_instructions audioId=$AUDIO_ID_PRE_START audioAsset=pre_start_instructions.mp3 language=${selectedLanguageState.value.code} durationMs=$durationMs startVisible=false startEnabled=false",
    )
    playLocalizedAssetCue(AUDIO_ID_PRE_START, "pre_start_instructions") {
      markPriorButtonExperiencePreStartReady(answer, promptToken, validationShortcut = false)
    }
    mainHandler.postDelayed(
        { markPriorButtonExperiencePreStartReady(answer, promptToken, validationShortcut = false) },
        holdMs,
    )
  }

  private fun markPriorButtonExperiencePreStartReady(
      answer: String,
      promptToken: Int,
      validationShortcut: Boolean,
  ) {
    if (promptToken != priorButtonExperiencePromptToken ||
        stageState.value != StudyStage.PreButtonExperienceQuestion ||
        priorBigRedButtonExperienceAnswerState.value != answer ||
        priorBigRedButtonExperiencePreStartReadyState.value) {
      return
    }
    priorBigRedButtonExperiencePreStartReadyState.value = true
    priorBigRedButtonExperienceStartBlockedReasonState.value = ""
    Log.i(
        TAG,
        "BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_READY answer=$answer promptToken=$promptToken validationShortcut=$validationShortcut startVisible=true startEnabled=true",
    )
  }

  private fun maybePlayFinalEndConfirmationQuestionCue(promptToken: Int) {
    if (stageState.value != StudyStage.FinalEndQuestionnaire || finalEndSelectionLocked) {
      return
    }
    if (hiddenValidationModeEnabled() || fastControllerFlowEnabled || keyeventValidationEnabled) {
      revealFinalEndConfirmationOptions(promptToken, validationShortcut = true)
      return
    }
    playFinalEndConfirmationQuestionCue(promptToken)
  }

  private fun playFinalEndConfirmationQuestionCue(promptToken: Int) {
    val durationMs = localizedCueDurationMs(AUDIO_ID_FINAL_END_QUESTION, FINAL_END_CONFIRMATION_QUESTION_AUDIO_DURATION_MS)
    val holdMs = localizedCueHoldMs(AUDIO_ID_FINAL_END_QUESTION, FINAL_END_CONFIRMATION_QUESTION_HOLD_MS)
    Log.i(
        TAG,
        "BRB_FINAL_END_CONFIRMATION_QUESTION_CUE cue=final_end_confirmation_question_prompt audioId=$AUDIO_ID_FINAL_END_QUESTION audioAsset=final_end_confirmation_question_prompt.mp3 language=${selectedLanguageState.value.code} durationMs=$durationMs text=\"${finalEndConfirmationQuestionText()}\" optionsVisible=false",
    )
    playLocalizedAssetCue(AUDIO_ID_FINAL_END_QUESTION, "final_end_confirmation_question_prompt") {
      revealFinalEndConfirmationOptions(promptToken, validationShortcut = false)
    }
    mainHandler.postDelayed(
        { revealFinalEndConfirmationOptions(promptToken, validationShortcut = false) },
        holdMs,
    )
  }

  private fun revealFinalEndConfirmationOptions(promptToken: Int, validationShortcut: Boolean) {
    if (promptToken != finalEndQuestionPromptToken ||
        stageState.value != StudyStage.FinalEndQuestionnaire ||
        finalEndSelectionLocked ||
        finalEndQuestionAudioReadyState.value) {
      return
    }
    finalEndQuestionAudioReadyState.value = true
    Log.i(
        TAG,
        "BRB_FINAL_END_CONFIRMATION_OPTIONS_READY promptToken=$promptToken validationShortcut=$validationShortcut optionsVisible=true answerLocked=false",
    )
  }

  private fun playFinalEndConfirmation10FeedbackCue() {
    val durationMs = localizedCueDurationMs(AUDIO_ID_FINAL_END_10_FEEDBACK, FINAL_END_CONFIRMATION_10_FEEDBACK_AUDIO_DURATION_MS)
    Log.i(
        TAG,
        "BRB_FINAL_END_CONFIRMATION_FEEDBACK_CUE cue=final_end_confirmation_10_feedback audioId=$AUDIO_ID_FINAL_END_10_FEEDBACK audioAsset=final_end_confirmation_10_feedback.mp3 language=${selectedLanguageState.value.code} durationMs=$durationMs text=\"${finalEndConfirmation10FeedbackText()}\"",
    )
    playLocalizedAssetCue(AUDIO_ID_FINAL_END_10_FEEDBACK, "final_end_confirmation_10_feedback")
  }

  private fun playFinalExtraPressPromptCue() {
    val durationMs = localizedCueDurationMs(AUDIO_ID_FINAL_EXTRA_PRESSES, FINAL_EXTRA_PRESSES_PROMPT_AUDIO_DURATION_MS)
    Log.i(
        TAG,
        "BRB_FINAL_EXTRA_PROMPT_CUE cue=final_extra_presses_prompt audioId=$AUDIO_ID_FINAL_EXTRA_PRESSES audioAsset=final_extra_presses_prompt.mp3 language=${selectedLanguageState.value.code} durationMs=$durationMs text=\"${finalExtraPressesPromptText()}\"",
    )
    playLocalizedAssetCue(AUDIO_ID_FINAL_EXTRA_PRESSES, "final_extra_presses_prompt")
  }

  fun playRednessScaleConversionCue(order: String, validationShortcut: Boolean = false) {
    val cue = rednessConversionCue(order)
    val microTimeline = cue.microEvents.joinToString("|") { "${it.code}:${it.startMs}-${it.endMs}" }
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION_CUE order=$order cue=${cue.cueName} placeholder=false audioAsset=${cue.audioAsset} durationMs=${cue.durationMs} swapAtMs=${cue.swapAtMs} microTimeline=$microTimeline validationShortcut=$validationShortcut",
    )
    if (validationShortcut) {
      playSharedAudioCue(SHARED_AUDIO_ID_QUESTIONNAIRE_NAVIGATION, SHARED_QUESTIONNAIRE_NAVIGATION_AUDIO, "${cue.cueName}_validation_shortcut")
    } else {
      playLocalizedAssetCue(cue.audioId, cue.cueName)
    }
  }

  private fun rednessConversionCue(order: String): RednessConversionCue {
    return if (order == REDNESS_ORDER_VAS_THEN_LIKERT) {
      val durationMs = localizedCueDurationMs(AUDIO_ID_REDNESS_VAS_TO_LIKERT, FIRST_REDNESS_CHANGE_AUDIO_DURATION_MS)
      val scale = durationMs.toDouble() / FIRST_REDNESS_CHANGE_AUDIO_DURATION_MS.toDouble()
      RednessConversionCue(
          audioId = AUDIO_ID_REDNESS_VAS_TO_LIKERT,
          cueName = "first_questionnaire_change",
          audioAsset = localizedAudioAssetPath(AUDIO_ID_REDNESS_VAS_TO_LIKERT) ?: LOCALIZED_EN_REDNESS_VAS_TO_LIKERT_AUDIO,
          durationMs = durationMs,
          swapAtMs = scaledMs(FIRST_REDNESS_CHANGE_SWAP_MS, scale),
          settleAtMs = scaledMs(FIRST_REDNESS_CHANGE_SETTLE_MS, scale),
          transcriptPlan = "supervisor_request_0_6800ms|likert_request_6800_11760ms|answer_already_given_14000_19280ms|result_settle_19280_22988ms",
          microEvents = scaledRednessMicroEvents(firstRednessChangeMicroEvents(), scale),
      )
    } else {
      val durationMs = localizedCueDurationMs(AUDIO_ID_REDNESS_LIKERT_TO_VAS, SECOND_REDNESS_CHANGE_AUDIO_DURATION_MS)
      val scale = durationMs.toDouble() / SECOND_REDNESS_CHANGE_AUDIO_DURATION_MS.toDouble()
      RednessConversionCue(
          audioId = AUDIO_ID_REDNESS_LIKERT_TO_VAS,
          cueName = "second_questionnaire_change_excuse",
          audioAsset = localizedAudioAssetPath(AUDIO_ID_REDNESS_LIKERT_TO_VAS) ?: LOCALIZED_EN_REDNESS_LIKERT_TO_VAS_AUDIO,
          durationMs = durationMs,
          swapAtMs = scaledMs(SECOND_REDNESS_CHANGE_SWAP_MS, scale),
          settleAtMs = scaledMs(SECOND_REDNESS_CHANGE_SETTLE_MS, scale),
          transcriptPlan = "unprofessional_swap_0_6560ms|restore_vas_6560_12120ms|data_important_12120_14640ms|settle_14640_16771ms",
          microEvents = scaledRednessMicroEvents(secondRednessChangeMicroEvents(), scale),
      )
    }
  }

  private fun scaledMs(ms: Long, scale: Double): Long =
      (ms.toDouble() * scale).roundToLong()

  private fun scaledRednessMicroEvents(
      events: List<RednessConversionMicroEvent>,
      scale: Double,
  ): List<RednessConversionMicroEvent> =
      if (scale == 1.0) {
        events
      } else {
        events.map { event ->
          event.copy(
              startMs = scaledMs(event.startMs, scale),
              endMs = scaledMs(event.endMs, scale),
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
    playAssetOneShotCue(BUTTON_PRESS_SFX_ASSET, "button_press", SHARED_AUDIO_ID_BUTTON_PRESS)
  }

  private fun playAssetOneShotCue(
      assetPath: String,
      cueName: String,
      audioId: String = "",
      onComplete: (() -> Unit)? = null,
      onFailure: ((String) -> Unit)? = null,
  ) {
    mainHandler.post {
      var asset: android.content.res.AssetFileDescriptor? = null
      try {
        asset = assets.openFd(assetPath)
        val player =
            MediaPlayer().apply {
              setAudioAttributes(
                  AudioAttributes.Builder()
                      .setUsage(AudioAttributes.USAGE_MEDIA)
                      .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                      .build()
              )
              setDataSource(asset!!.fileDescriptor, asset!!.startOffset, asset!!.length)
              setVolume(1.0f, 1.0f)
              setOnErrorListener { failed, what, extra ->
                Log.w(TAG, "BRB_SFX_FAILED cue=$cueName audioId=$audioId asset=$assetPath what=$what extra=$extra")
                cuePlayers.remove(failed)
                failed.release()
                true
              }
              prepare()
            }
        asset?.close()
        asset = null
        cuePlayers.add(player)
        player.setOnCompletionListener { completed ->
          completed.release()
          cuePlayers.remove(completed)
          mainHandler.post { onComplete?.invoke() }
        }
        player.start()
        Log.i(TAG, "BRB_SFX_PLAY cue=$cueName audioId=$audioId asset=$assetPath language=${selectedLanguageState.value.code} durationMs=${player.duration} isPlaying=${player.isPlaying} audioUsage=media contentType=speech volume=1.0")
      } catch (exception: Exception) {
        Log.w(TAG, "BRB_SFX_FAILED cue=$cueName asset=$assetPath error=${exception.message}")
        onFailure?.invoke(exception.message ?: "unknown")
      } finally {
        try {
          asset?.close()
        } catch (_: Exception) {}
      }
    }
  }

  private fun playQuestionnaireIntroCue(trigger: String, onComplete: (() -> Unit)? = null) {
    playQuestionnaireTransitionCue(
        trigger = trigger,
        mode = "intro",
        audioId = SHARED_AUDIO_ID_QUESTIONNAIRE_INTRO_GLITCH,
        assetPath = SHARED_QUESTIONNAIRE_INTRO_GLITCH_AUDIO,
        fallbackDurationMs = QUESTIONNAIRE_INTRO_FALLBACK_MS,
        onComplete = onComplete,
    )
  }

  private fun playQuestionnaireOutroCue(trigger: String, onComplete: () -> Unit) {
    playQuestionnaireTransitionCue(
        trigger = trigger,
        mode = "outro",
        audioId = SHARED_AUDIO_ID_QUESTIONNAIRE_OUTRO_GLITCH,
        assetPath = SHARED_QUESTIONNAIRE_OUTRO_GLITCH_AUDIO,
        fallbackDurationMs = QUESTIONNAIRE_OUTRO_FALLBACK_MS,
        onComplete = onComplete,
    )
  }

  private fun playQuestionnaireTransitionCue(
      trigger: String,
      mode: String,
      audioId: String,
      assetPath: String,
      fallbackDurationMs: Long,
      onComplete: (() -> Unit)?,
  ) {
    releasePanelChimePlayer()
    val token = ++panelGlitchToken
    var audioAsset: android.content.res.AssetFileDescriptor? = null
    try {
      audioAsset = assets.openFd(assetPath)
      val player =
          MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            setDataSource(audioAsset!!.fileDescriptor, audioAsset!!.startOffset, audioAsset!!.length)
            setVolume(1.0f, 1.0f)
            setOnErrorListener { errorPlayer, what, extra ->
              Log.w(
                  TAG,
                  "BRB_QUESTIONNAIRE_${mode.uppercase(Locale.US)}_CUE_FAILED trigger=$trigger audioId=$audioId asset=$assetPath what=$what extra=$extra",
              )
              if (panelChimePlayer === errorPlayer) {
                panelChimePlayer = null
              }
              errorPlayer.release()
              stopPanelGlitch(mode, trigger, token)
              onComplete?.invoke()
              true
            }
            prepare()
          }
      audioAsset?.close()
      audioAsset = null
      panelChimePlayer = player
      val cueDurationMs = player.duration.takeIf { it > 0 }?.toLong() ?: fallbackDurationMs
      startPanelGlitch(mode, trigger, token, cueDurationMs)
      player.setOnCompletionListener { completedPlayer ->
        completedPlayer.release()
        if (panelChimePlayer === completedPlayer) {
          panelChimePlayer = null
        }
        stopPanelGlitch(mode, trigger, token)
        onComplete?.invoke()
      }
      player.start()
      Log.i(
          TAG,
          "BRB_QUESTIONNAIRE_${mode.uppercase(Locale.US)}_CUE trigger=$trigger audioId=$audioId asset=$assetPath durationMs=${player.duration} isPlaying=${player.isPlaying} audioUsage=media contentType=sonification volume=1.0",
      )
    } catch (exception: Exception) {
      Log.w(TAG, "BRB_QUESTIONNAIRE_${mode.uppercase(Locale.US)}_CUE_FAILED trigger=$trigger audioId=$audioId asset=$assetPath error=${exception.message}")
      releasePanelChimePlayer()
      startPanelGlitch(mode, trigger, token, fallbackDurationMs)
      mainHandler.postDelayed(
          {
            stopPanelGlitch(mode, trigger, token)
            onComplete?.invoke()
          },
          fallbackDurationMs,
      )
    } finally {
      audioAsset?.close()
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
    setNameKeyboardVisible(false, safeReason)
    demographicsFocusedFieldState.value = ""
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
    createButtonGlowMaterialLights()
    Log.i(
        TAG,
        "BRB_BUTTON_GLOW_STABLE_SURFACE_READY modelGlow=stable_idle_model_native_lights variantsAvailable=$BUTTON_GLOW_MODEL_LEVEL_COUNT variantsActive=${buttonGlowModelEntities.size} assetPattern=$BUTTON_GLOW_MODEL_ASSET_PATTERN geometrySwap=false shapeStable=true placementStable=true scaleStable=true surfaceGeometry=false transparentHalo=false unityReferenceIdleTint=${UNITY_BUTTON_IDLE_RED},${UNITY_BUTTON_IDLE_GREEN},${UNITY_BUTTON_IDLE_BLUE} unityReferenceBlinkTint=${UNITY_BUTTON_BLINK_RED},${UNITY_BUTTON_BLINK_GREEN},${UNITY_BUTTON_BLINK_BLUE} unityReferenceBlinkEmission=${UNITY_BUTTON_BLINK_EMISSION_RED},${UNITY_BUTTON_BLINK_EMISSION_GREEN},${UNITY_BUTTON_BLINK_EMISSION_BLUE} nativePeakTint=${NATIVE_BUTTON_GLOW_PEAK_RED},${NATIVE_BUTTON_GLOW_PEAK_GREEN},${NATIVE_BUTTON_GLOW_PEAK_BLUE} nativePeakEmission=${NATIVE_BUTTON_GLOW_PEAK_EMISSION_RED},${NATIVE_BUTTON_GLOW_PEAK_EMISSION_GREEN},${NATIVE_BUTTON_GLOW_PEAK_EMISSION_BLUE} surfaceLights=${buttonGlowLights.size}",
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
        "BRB_BUTTON_CONTACT_COLLIDER_READY source=dual_controller_hand_contact shape=multi_box_cap_plus_full_surface boxes=${buttonContactTargets.size} centerX=0 centerY=$BUTTON_CONTACT_COLLIDER_Y_METERS centerZ=$BUTTON_DISTANCE_FROM_HEAD_METERS capDiameterM=$BUTTON_VISUAL_DIAMETER_METERS centerSize=${BUTTON_CONTACT_CENTER_WIDTH_METERS}x${BUTTON_CONTACT_COLLIDER_HEIGHT_METERS}x$BUTTON_CONTACT_CENTER_DEPTH_METERS ringRadiusM=$BUTTON_CONTACT_RING_RADIUS_METERS ringBoxSize=${BUTTON_CONTACT_RING_BOX_WIDTH_METERS}x${BUTTON_CONTACT_RING_BOX_DEPTH_METERS} fullSurfaceSize=${BUTTON_CONTACT_FULL_SURFACE_WIDTH_METERS}x${BUTTON_CONTACT_FULL_SURFACE_HEIGHT_METERS}x$BUTTON_CONTACT_FULL_SURFACE_DEPTH_METERS handPinchRay=true tapAnyCapSurface=true controllerProofPreserved=true",
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
            surfaceRole = "shared_cap_center",
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
              surfaceRole = "shared_cap_ring",
          )
      )
    }
    specs.add(
        ButtonContactTargetSpec(
            name = "cap-full-surface",
            offsetX = 0f,
            offsetZ = 0f,
            width = BUTTON_CONTACT_FULL_SURFACE_WIDTH_METERS,
            height = BUTTON_CONTACT_FULL_SURFACE_HEIGHT_METERS,
            depth = BUTTON_CONTACT_FULL_SURFACE_DEPTH_METERS,
            surfaceRole = "shared_full_surface_hand_tap",
        )
    )
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
    Log.i(
        TAG,
        "BRB_HAND_TRACKING_SYSTEM_BUTTON_POLICY appMenuButtonsVisible=false appHomeButtonsVisible=false androidMenuHomeSuppression=best_effort_when_hands_only osMetaHomeButtonControllable=false handOutlineAllowedWhenControllersActive=false controllerQuietWindowMs=$HAND_TRACKING_CONTROLLER_QUIET_MS handContactOnlyWhenControllersInactive=true",
    )
  }

  private fun controllersRecentlyActive(nowMs: Long = SystemClock.elapsedRealtime()): Boolean {
    return lastControllerInputRealtimeMs != Long.MIN_VALUE && nowMs - lastControllerInputRealtimeMs <= HAND_TRACKING_CONTROLLER_QUIET_MS
  }

  private fun markControllerInput(source: String) {
    val nowMs = SystemClock.elapsedRealtime()
    val wasActive = controllersRecentlyActive(nowMs)
    lastControllerInputRealtimeMs = nowMs
    if (!wasActive) {
      Log.i(
          TAG,
          "BRB_INTERACTION_MODE source=${sanitizeKeyboardLogToken(source)} controllersActive=true handsOnly=false handOutlineAllowed=false controllerQuietWindowMs=$HAND_TRACKING_CONTROLLER_QUIET_MS",
      )
    }
  }

  private fun markHandInput(source: String) {
    val nowMs = SystemClock.elapsedRealtime()
    lastHandInputRealtimeMs = nowMs
    val controllersActive = controllersRecentlyActive(nowMs)
    Log.i(
        TAG,
        "BRB_INTERACTION_MODE source=${sanitizeKeyboardLogToken(source)} controllersActive=$controllersActive handsOnly=${!controllersActive} handOutlineAllowed=${!controllersActive} controllerQuietWindowMs=$HAND_TRACKING_CONTROLLER_QUIET_MS",
    )
  }

  private fun handleHandTrackingSystemButtonSuppression(event: KeyEvent): Boolean {
    if (event.keyCode != KeyEvent.KEYCODE_MENU && event.keyCode != KeyEvent.KEYCODE_HOME) {
      return false
    }
    val handsOnly = !controllersRecentlyActive()
    val keyName = if (event.keyCode == KeyEvent.KEYCODE_HOME) "home" else "menu"
    Log.i(
        TAG,
        "BRB_HAND_TRACKING_SYSTEM_BUTTON_SUPPRESSION key=$keyName action=${event.action} consumed=$handsOnly mode=best_effort_android_keyevent osMetaHomeButtonControllable=false handsOnly=$handsOnly",
    )
    return handsOnly
  }

  private fun handleButtonContactPointerEvent(event: PointerEvent) {
    val hitEntity = event.hitInfo.entity ?: return
    val contactTarget = buttonContactTargets.firstOrNull { target -> target.entity.id == hitEntity.id } ?: return

    val eventType =
        PointerEventType.entries.firstOrNull { it.id == event.type }?.name ?: event.type.toString()
    val behavior = isdkSystem?.getInteractionEventSourceBehavior(event)
    val hand = isdkSystem?.getHandForPointerEvent(event)
    val handTracked = hand != null
    val nowMs = SystemClock.elapsedRealtime()
    if (handTracked) {
      markHandInput("isdk_pointer_$eventType")
    } else if (event.type == PointerEventType.Select.id) {
      markControllerInput("isdk_pointer_$eventType")
    }
    val controllersActive = controllersRecentlyActive(nowMs)
    val contactKey = event.source.id.toString()
    Log.i(
        TAG,
        "BRB_BUTTON_CONTACT_EVENT type=$eventType target=${contactTarget.spec.name} role=${contactTarget.spec.surfaceRole} behavior=$behavior pointer=${event.pointerType} semantic=${event.semanticType} sourceEntity=${event.source.id} handTracked=$handTracked hand=$hand controllersActive=$controllersActive handOutlineAllowed=${!controllersActive}",
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
    if (acceptedKind == PRESS_SOURCE_HAND_CONTACT && controllersActive) {
      Log.i(
          TAG,
          "BRB_BUTTON_CONTACT_SELECT accepted=false reason=controllers_active target=${contactTarget.spec.name} role=${contactTarget.spec.surfaceRole} behavior=$behavior handTracked=true handOutlineAllowed=false controllerQuietWindowMs=$HAND_TRACKING_CONTROLLER_QUIET_MS",
      )
      return
    }
    if (acceptedKind.isEmpty()) {
      Log.i(
          TAG,
          "BRB_BUTTON_CONTACT_SELECT accepted=false reason=not_contact target=${contactTarget.spec.name} role=${contactTarget.spec.surfaceRole} behavior=$behavior handTracked=$handTracked",
      )
      return
    }
    if (!buttonContactLatch.tryAccept(contactKey, nowMs)) {
      Log.i(
          TAG,
          "BRB_BUTTON_CONTACT_SELECT accepted=false reason=latched target=${contactTarget.spec.name} role=${contactTarget.spec.surfaceRole} key=$contactKey behavior=$behavior handTracked=$handTracked",
      )
      return
    }
    when {
      acceptedKind == PRESS_SOURCE_HAND_CONTACT -> {
        Log.i(
            TAG,
            "BRB_BUTTON_HAND_CONTACT_SELECT accepted=true target=${contactTarget.spec.name} role=${contactTarget.spec.surfaceRole} key=$contactKey behavior=$behavior handOutlineAllowed=true",
        )
        recordButtonPress(PRESS_SOURCE_HAND_CONTACT)
      }
      acceptedKind == PRESS_SOURCE_CONTROLLER_CONTACT -> {
        Log.i(
            TAG,
            "BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true target=${contactTarget.spec.name} role=${contactTarget.spec.surfaceRole} key=$contactKey behavior=$behavior",
        )
        recordButtonPress(PRESS_SOURCE_CONTROLLER_CONTACT)
      }
    }
  }

  private fun playButtonPressedAnimation() {
    val nowMs = SystemClock.elapsedRealtime()
    val previousStartMs = lastButtonPressMotionStartRealtimeMs
    val sincePreviousMs =
        if (previousStartMs == Long.MIN_VALUE) {
          Long.MAX_VALUE
        } else {
          nowMs - previousStartMs
        }
    val restartDelayMs =
        if (sincePreviousMs >= BUTTON_PRESS_MOTION_RESTART_GUARD_MS) {
          0L
        } else {
          BUTTON_PRESS_MOTION_RESTART_GUARD_MS - sincePreviousMs
        }
    val sequence = ++buttonPressMotionSequence
    if (restartDelayMs <= 0L) {
      startButtonPressMotion(
          sequence = sequence,
          deferred = false,
          scheduledDelayMs = 0L,
          sincePreviousMs = if (previousStartMs == Long.MIN_VALUE) -1L else sincePreviousMs,
      )
      return
    }
    Log.i(
        TAG,
        "BRB_BUTTON_MODEL_ANIMATION_SCHEDULE state=deferred name=$BUTTON_MODEL_PRESS_ANIMATION sequence=$sequence sincePreviousMs=$sincePreviousMs delayMs=$restartDelayMs visualRestartGuardMs=$BUTTON_PRESS_MOTION_RESTART_GUARD_MS acceptedPressImmediate=true countSoundImmediate=true",
    )
    mainHandler.postDelayed(
        {
          if (sequence != buttonPressMotionSequence) {
            Log.i(
                TAG,
                "BRB_BUTTON_MODEL_ANIMATION_SCHEDULE state=canceled reason=newer_press sequence=$sequence activeSequence=$buttonPressMotionSequence",
            )
            return@postDelayed
          }
          val delayedNowMs = SystemClock.elapsedRealtime()
          startButtonPressMotion(
              sequence = sequence,
              deferred = true,
              scheduledDelayMs = delayedNowMs - nowMs,
              sincePreviousMs = delayedNowMs - previousStartMs,
          )
        },
        restartDelayMs,
    )
  }

  private fun startButtonPressMotion(
      sequence: Int,
      deferred: Boolean,
      scheduledDelayMs: Long,
      sincePreviousMs: Long,
  ) {
    val stage = stageState.value
    val canShowMotion =
        buttonStimulusVisible &&
            (stage == StudyStage.ConditionRunning || stage == StudyStage.FinalExtraPresses)
    if (!canShowMotion) {
      Log.i(
          TAG,
          "BRB_BUTTON_MODEL_ANIMATION name=$BUTTON_MODEL_PRESS_ANIMATION state=skipped reason=button_not_visible_or_stage sequence=$sequence stage=$stage visible=$buttonStimulusVisible",
      )
      return
    }
    applyStableButtonModelVisibility()
    val startRealtimeMs = SystemClock.elapsedRealtime()
    lastButtonPressMotionStartRealtimeMs = startRealtimeMs
    setButtonPressedAnimationComponent(buttonModelEntity, System.currentTimeMillis())
    Log.i(
        TAG,
        "BRB_BUTTON_MODEL_ANIMATION name=$BUTTON_MODEL_PRESS_ANIMATION state=started sequence=$sequence target=stable_idle_model playback=clamp motionProfile=native_pressed_clip clipDurationMs=$BUTTON_PRESS_ANIMATION_CLIP_MS visualRestartGuardMs=$BUTTON_PRESS_MOTION_RESTART_GUARD_MS deferred=$deferred scheduledDelayMs=$scheduledDelayMs sincePreviousMs=$sincePreviousMs acceptedPressImmediate=true countSoundImmediate=true heartbeatGlowMotion=false glowGeometrySwap=false futureSfxAlignment=button_press_noise_profile",
    )
  }

  private fun setButtonPressedAnimationComponent(entity: Entity?, startWallClockMs: Long) {
    entity?.setComponent(
        Animated(
            startTime = startWallClockMs,
            pausedTime = 0f,
            playbackState = PlaybackState.PLAYING,
            playbackType = PlaybackType.CLAMP,
            track = 0,
            animationName = BUTTON_MODEL_PRESS_ANIMATION,
        )
    )
  }

  private fun resetButtonPressMotionState(reason: String) {
    buttonPressMotionSequence += 1
    lastButtonPressMotionStartRealtimeMs = Long.MIN_VALUE
    Log.i(
        TAG,
        "BRB_BUTTON_MODEL_ANIMATION_RESET reason=$reason activeSequence=$buttonPressMotionSequence visualRestartGuardMs=$BUTTON_PRESS_MOTION_RESTART_GUARD_MS",
    )
  }

  private fun setButtonGlowPulse(intensity01: Float) {
    val intensity = intensity01.coerceIn(0f, 1f)
    buttonHeartbeatPulseIntensityState.floatValue = intensity
    applyStableButtonModelVisibility()
    updateButtonGlowMaterialLights(if (buttonStimulusVisible && stageState.value == StudyStage.ConditionRunning) intensity else 0f)
  }

  private fun applyStableButtonModelVisibility() {
    buttonModelEntity?.setComponent(Visible(buttonStimulusVisible))
    buttonGlowModelEntities.forEach { entity ->
      entity.setComponent(Visible(false))
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
    finalExtraPromptToken += 1
    priorButtonExperiencePromptToken += 1
    rednessConversionChoreographyState.value = null
    finalExtraPromptVisibleState.value = false
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
    finalExtraPromptToken += 1
    priorButtonExperiencePromptToken += 1
    rednessConversionChoreographyState.value = null
    finalExtraPromptVisibleState.value = false
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
    private const val CONDITION_1_AUDIO = "localized/en_us/aud_0100_condition_1_instructions__en_us.mp3"
    private const val CONDITION_2_AUDIO = "localized/en_us/aud_0110_condition_2_instructions__en_us.mp3"
    private const val LOCALIZED_AUDIO_MANIFEST_ASSET = "localized/manifest.json"
    private const val AUDIO_ID_CONDITION_1 = "aud_0100"
    private const val AUDIO_ID_CONDITION_2 = "aud_0110"
    private const val AUDIO_ID_PRIOR_QUESTION = "aud_0200"
    private const val AUDIO_ID_PRIOR_YES = "aud_0210"
    private const val AUDIO_ID_PRIOR_NO = "aud_0220"
    private const val AUDIO_ID_PRE_START = "aud_0230"
    private const val AUDIO_ID_REDNESS_VAS_TO_LIKERT = "aud_0300"
    private const val AUDIO_ID_REDNESS_LIKERT_TO_VAS = "aud_0310"
    private const val AUDIO_ID_IPQ_HISTORY_PART_1 = "aud_0320"
    private const val AUDIO_ID_IPQ_HISTORY_PART_2 = "aud_0330"
    private const val AUDIO_ID_FINAL_END_QUESTION = "aud_0500"
    private const val AUDIO_ID_FINAL_END_10_FEEDBACK = "aud_0510"
    private const val AUDIO_ID_FINAL_EXTRA_PRESSES = "aud_0600"
    private const val SHARED_AUDIO_ID_QUESTIONNAIRE_INTRO_GLITCH = "raw_0400"
    private const val SHARED_AUDIO_ID_QUESTIONNAIRE_OUTRO_GLITCH = "raw_0410"
    private const val SHARED_AUDIO_ID_QUESTIONNAIRE_CHOICE = "sfx_9000"
    private const val SHARED_AUDIO_ID_QUESTIONNAIRE_NAVIGATION = "sfx_9010"
    private const val SHARED_AUDIO_ID_BUTTON_PRESS = "sfx_9020"
    private const val LOCALIZED_EN_CONDITION_1_AUDIO =
        "localized/en_us/aud_0100_condition_1_instructions__en_us.mp3"
    private const val LOCALIZED_EN_CONDITION_2_AUDIO =
        "localized/en_us/aud_0110_condition_2_instructions__en_us.mp3"
    private const val LOCALIZED_EN_PRIOR_QUESTION_AUDIO =
        "localized/en_us/aud_0200_prior_experience_question__en_us.mp3"
    private const val LOCALIZED_EN_PRIOR_YES_AUDIO =
        "localized/en_us/aud_0210_prior_experience_yes_feedback__en_us.mp3"
    private const val LOCALIZED_EN_PRIOR_NO_AUDIO =
        "localized/en_us/aud_0220_prior_experience_no_feedback__en_us.mp3"
    private const val LOCALIZED_EN_PRE_START_AUDIO =
        "localized/en_us/aud_0230_pre_start_instructions__en_us.mp3"
    private const val LOCALIZED_EN_REDNESS_VAS_TO_LIKERT_AUDIO =
        "localized/en_us/aud_0300_redness_vas_to_likert_changeover__en_us.mp3"
    private const val LOCALIZED_EN_REDNESS_LIKERT_TO_VAS_AUDIO =
        "localized/en_us/aud_0310_redness_likert_to_vas_changeover__en_us.mp3"
    private const val LOCALIZED_EN_IPQ_HISTORY_PART_1_AUDIO =
        "localized/en_us/aud_0320_ipq_history_part1__en_us.mp3"
    private const val LOCALIZED_EN_IPQ_HISTORY_PART_2_AUDIO =
        "localized/en_us/aud_0330_ipq_history_part2__en_us.mp3"
    private const val LOCALIZED_EN_FINAL_END_QUESTION_AUDIO =
        "localized/en_us/aud_0500_final_end_confirmation_question__en_us.mp3"
    private const val LOCALIZED_EN_FINAL_END_10_FEEDBACK_AUDIO =
        "localized/en_us/aud_0510_final_end_confirmation_10_feedback__en_us.mp3"
    private const val LOCALIZED_EN_FINAL_EXTRA_PRESSES_AUDIO =
        "localized/en_us/aud_0600_final_extra_presses_prompt__en_us.mp3"
    private const val LOCALIZED_JA_CONDITION_1_AUDIO =
        "localized/ja_jp/aud_0100_condition_1_instructions__ja_jp.mp3"
    private const val LOCALIZED_JA_CONDITION_2_AUDIO =
        "localized/ja_jp/aud_0110_condition_2_instructions__ja_jp.mp3"
    private const val LOCALIZED_JA_PRIOR_QUESTION_AUDIO =
        "localized/ja_jp/aud_0200_prior_experience_question__ja_jp.mp3"
    private const val LOCALIZED_JA_PRIOR_YES_AUDIO =
        "localized/ja_jp/aud_0210_prior_experience_yes_feedback__ja_jp.mp3"
    private const val LOCALIZED_JA_PRIOR_NO_AUDIO =
        "localized/ja_jp/aud_0220_prior_experience_no_feedback__ja_jp.mp3"
    private const val LOCALIZED_JA_PRE_START_AUDIO =
        "localized/ja_jp/aud_0230_pre_start_instructions__ja_jp.mp3"
    private const val LOCALIZED_JA_REDNESS_VAS_TO_LIKERT_AUDIO =
        "localized/ja_jp/aud_0300_redness_vas_to_likert_changeover__ja_jp.mp3"
    private const val LOCALIZED_JA_REDNESS_LIKERT_TO_VAS_AUDIO =
        "localized/ja_jp/aud_0310_redness_likert_to_vas_changeover__ja_jp.mp3"
    private const val LOCALIZED_JA_IPQ_HISTORY_PART_1_AUDIO =
        "localized/ja_jp/aud_0320_ipq_history_part1__ja_jp.mp3"
    private const val LOCALIZED_JA_IPQ_HISTORY_PART_2_AUDIO =
        "localized/ja_jp/aud_0330_ipq_history_part2__ja_jp.mp3"
    private const val LOCALIZED_JA_FINAL_END_QUESTION_AUDIO =
        "localized/ja_jp/aud_0500_final_end_confirmation_question__ja_jp.mp3"
    private const val LOCALIZED_JA_FINAL_END_10_FEEDBACK_AUDIO =
        "localized/ja_jp/aud_0510_final_end_confirmation_10_feedback__ja_jp.mp3"
    private const val LOCALIZED_JA_FINAL_EXTRA_PRESSES_AUDIO =
        "localized/ja_jp/aud_0600_final_extra_presses_prompt__ja_jp.mp3"
    private const val SHARED_QUESTIONNAIRE_INTRO_GLITCH_AUDIO =
        "localized/shared/questionnaire_transition/raw_0400_questionnaire_intro_glitch.mp3"
    private const val SHARED_QUESTIONNAIRE_OUTRO_GLITCH_AUDIO =
        "localized/shared/questionnaire_transition/raw_0410_questionnaire_outro_glitch.mp3"
    private const val SHARED_QUESTIONNAIRE_CHOICE_AUDIO =
        "localized/shared/questionnaire_ui/sfx_9000_questionnaire_choice_blip.wav"
    private const val SHARED_QUESTIONNAIRE_NAVIGATION_AUDIO =
        "localized/shared/questionnaire_ui/sfx_9010_questionnaire_navigation_blip.wav"
    private const val EXPORT_DIR_NAME = "BigRedButtonFirstStudyExports"
    private const val EXPERIMENT_RESULTS_DIR_NAME = "ExperimentResults"
    private const val AUTO_VALIDATION_EXTRA = "brb.autoValidation"
    private const val STUDY_LANGUAGE_EXTRA = "brb.studyLanguage"
    private const val PHYSICAL_PRESS_VALIDATION_EXTRA = "brb.physicalPressValidation"
    private const val PANEL_SMOKE_EXTRA = "brb.panelSmoke"
    private const val FAST_CONTROLLER_FLOW_EXTRA = "brb.fastControllerFlow"
    private const val KEYEVENT_VALIDATION_EXTRA = "brb.keyeventValidation"
    private const val DEMOGRAPHICS_KEYBOARD_VALIDATION_EXTRA = "brb.demographicsKeyboardValidation"
    private const val DEMOGRAPHICS_KEYBOARD_VALIDATION_COMMAND_EXTRA =
        "brb.demographicsKeyboardValidationCommand"
    private const val DEMOGRAPHICS_KEYBOARD_VALIDATION_TEXT_EXTRA =
        "brb.demographicsKeyboardValidationText"
    private const val DEMOGRAPHICS_KEYBOARD_VALIDATION_SESSION_EXTRA =
        "brb.demographicsKeyboardValidationSession"
    private const val AUDIO_RIG_STRESS_EXTRA = "brb.audioRigStress"
    private const val AUDIO_RIG_STRESS_COMMAND_EXTRA = "brb.audioRigStressCommand"
    private const val VISUAL_GLOW_VALIDATION_EXTRA = "brb.visualGlowValidation"
    private const val VISUAL_GLOW_VALIDATION_ON = "on"
    private const val VISUAL_GLOW_VALIDATION_OFF = "off"
    private const val VISUAL_GLOW_VALIDATION_DELAY_MS = 1800L
    private const val AUTO_VALIDATION_START_DELAY_MS = 1200L
    private const val AUTO_VALIDATION_POST_CONDITION_DELAY_MS = 1200L
    private const val FAST_CONTROLLER_FLOW_START_DELAY_MS = 700L
    private const val FAST_CONTROLLER_POST_CONDITION_DELAY_MS = 450L
    private const val FAST_CONDITION_AUDIO_SHORTCUT_MS = 2200L
    private const val PRIOR_BUTTON_EXPERIENCE_QUESTION_AUDIO_DURATION_MS = 10527L
    private const val PRIOR_BUTTON_EXPERIENCE_QUESTION_HOLD_MS = 10800L
    private const val PRIOR_BUTTON_EXPERIENCE_YES_AUDIO_DURATION_MS = 5251L
    private const val PRIOR_BUTTON_EXPERIENCE_YES_HOLD_MS = 5500L
    private const val PRIOR_BUTTON_EXPERIENCE_NO_AUDIO_DURATION_MS = 4284L
    private const val PRIOR_BUTTON_EXPERIENCE_NO_HOLD_MS = 4550L
    private const val PRIOR_BUTTON_EXPERIENCE_FEEDBACK_TO_PRE_START_PAUSE_MS = 4000L
    private const val PRIOR_BUTTON_EXPERIENCE_PRE_START_AUDIO_DURATION_MS = 34273L
    private const val PRIOR_BUTTON_EXPERIENCE_PRE_START_HOLD_MS = 34600L
    private const val FINAL_END_CONFIRMATION_QUESTION_AUDIO_DURATION_MS = 5146L
    private const val FINAL_END_CONFIRMATION_QUESTION_HOLD_MS = 5400L
    private const val FINAL_END_CONFIRMATION_10_FEEDBACK_AUDIO_DURATION_MS = 16274L
    private const val FINAL_END_CONFIRMATION_FEEDBACK_HOLD_MS = 16550L
    private const val FINAL_END_CONFIRMATION_VALIDATION_DELAY_MS = 500L
    private const val FINAL_END_CONFIRMATION_VALIDATION_MAX_ATTEMPTS = 30
    private const val FINAL_EXTRA_PRESSES_PROMPT_AUDIO_DURATION_MS = 45636L
    private const val FINAL_EXTRA_PRESSES_PROMPT_HOLD_MS = 46100L
    private const val LOCALIZED_AUDIO_HOLD_BUFFER_MS = 300L
    private const val JA_PRIOR_BUTTON_EXPERIENCE_QUESTION_AUDIO_DURATION_MS = 10449L
    private const val JA_PRIOR_BUTTON_EXPERIENCE_YES_AUDIO_DURATION_MS = 8281L
    private const val JA_PRIOR_BUTTON_EXPERIENCE_NO_AUDIO_DURATION_MS = 5146L
    private const val JA_PRIOR_BUTTON_EXPERIENCE_PRE_START_AUDIO_DURATION_MS = 47804L
    private const val JA_FIRST_REDNESS_CHANGE_AUDIO_DURATION_MS = 23327L
    private const val JA_SECOND_REDNESS_CHANGE_AUDIO_DURATION_MS = 27559L
    private const val JA_FINAL_END_CONFIRMATION_QUESTION_AUDIO_DURATION_MS = 8359L
    private const val JA_FINAL_END_CONFIRMATION_10_FEEDBACK_AUDIO_DURATION_MS = 10371L
    private const val JA_FINAL_EXTRA_PRESSES_PROMPT_AUDIO_DURATION_MS = 49084L
    const val FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT = 1000
    private const val VISUAL_GLOW_VALIDATION_FAST_CONDITION_HOLD_MS = 12000L
    private const val PANEL_TRANSITION_LANGUAGE_SELECTION = "language_selection"
    private const val PANEL_TRANSITION_DEMOGRAPHICS = "demographics"
    private const val PANEL_TRANSITION_BEFORE_CONDITION_1 = "before_condition_1"
    private const val PANEL_TRANSITION_BEFORE_CONDITION_2 = "before_condition_2"
    private const val PANEL_TRANSITION_FINAL_END = "final_end_confirmation"
    private const val PANEL_TRANSITION_FINAL_EXTRA_PRESSES = "final_extra_button_presses"
  private const val PANEL_TRANSITION_COMPLETE = "complete"
    private const val PANEL_TRANSITION_START_DELAY_MS = 350L
    private const val PANEL_GLITCH_FRAME_MS = 70L
    private const val QUESTIONNAIRE_INTRO_FALLBACK_MS = 2400L
    private const val QUESTIONNAIRE_OUTRO_FALLBACK_MS = 1800L
    private const val PANEL_SMOKE_PICTOGRAPHIC_DELAY_MS = 8000L
    private const val QUESTIONNAIRE_PANEL_Y_METERS = 1.52f
    private const val QUESTIONNAIRE_PANEL_RADIAL_ANGLE_DEGREES = 0f
    private const val QUESTIONNAIRE_PANEL_RADIAL_DISTANCE_METERS = 1.55f
    private const val QUESTIONNAIRE_PANEL_Z_METERS = QUESTIONNAIRE_PANEL_RADIAL_DISTANCE_METERS
    private const val QUESTIONNAIRE_PANEL_WIDTH_METERS = 1.55f
    private const val QUESTIONNAIRE_PANEL_HEIGHT_METERS = 1.05f
    private const val NAME_KEYBOARD_PANEL_RADIAL_ANGLE_DEGREES = -22f
    private const val NAME_KEYBOARD_PANEL_RADIAL_DISTANCE_METERS = 0.92f
    private val NAME_KEYBOARD_PANEL_X_METERS =
        sin(NAME_KEYBOARD_PANEL_RADIAL_ANGLE_DEGREES * PI.toFloat() / 180f) * NAME_KEYBOARD_PANEL_RADIAL_DISTANCE_METERS
    private const val NAME_KEYBOARD_PANEL_Y_METERS = 1.00f
    private val NAME_KEYBOARD_PANEL_Z_METERS =
        cos(NAME_KEYBOARD_PANEL_RADIAL_ANGLE_DEGREES * PI.toFloat() / 180f) * NAME_KEYBOARD_PANEL_RADIAL_DISTANCE_METERS
    private const val NAME_KEYBOARD_PANEL_WIDTH_METERS = 0.66f
    private const val NAME_KEYBOARD_PANEL_HEIGHT_METERS = 0.245f
    private const val NAME_KEYBOARD_PANEL_DISPLAY_WIDTH_DP = 960f
    private const val NAME_KEYBOARD_PANEL_DISPLAY_HEIGHT_DP = 356f
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
    private const val BUTTON_CONTACT_FULL_SURFACE_WIDTH_METERS = 0.34f
    private const val BUTTON_CONTACT_FULL_SURFACE_HEIGHT_METERS = 0.12f
    private const val BUTTON_CONTACT_FULL_SURFACE_DEPTH_METERS = 0.34f
    private const val BUTTON_CONTACT_LATCH_FORCE_REARM_MS = 1200L
    private const val HAND_TRACKING_CONTROLLER_QUIET_MS = 2200L
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
    private const val BUTTON_PRESS_ANIMATION_CLIP_MS = 160L
    private const val BUTTON_PRESS_MOTION_RESTART_GUARD_MS = 240L
    private const val BUTTON_PRESS_ANIMATION_STRESS_PRESS_COUNT = 3
    private const val BUTTON_PRESS_ANIMATION_STRESS_INTERVAL_MS = 200L
    private const val BUTTON_PRESS_ANIMATION_STRESS_ARM_MARGIN_MS = 60L
    private const val BUTTON_PRESS_ANIMATION_STRESS_MIN_FIRST_DELAY_MS = 80L
    private const val BUTTON_PRESS_ANIMATION_STRESS_COMPLETE_MARGIN_MS = 160L
    private const val PRESS_SOURCE_CONTROLLER_CONTACT = "controller_contact"
    private const val PRESS_SOURCE_HAND_CONTACT = "hand_contact"
    private const val PRESS_SOURCE_TRANSPARENT_PANEL_INTERIM = "transparent_panel_interim"
    private const val PRESS_SOURCE_SCENE_OBJECT_FALLBACK = "scene_object_fallback"
    private const val PRESS_SOURCE_AUTO_VALIDATION = "auto_validation"
    private const val PRESS_SOURCE_CONTROLLER_EMULATED_VALIDATION = "controller_emulated_validation"
    private const val PRESS_SOURCE_AUDIO_RIG_STRESS = "audio_rig_stress"
    private const val PRESS_SOURCE_UNSPECIFIED = "unspecified"
    private const val BUTTON_PRESS_SFX_ASSET =
        "localized/shared/button_press/sfx_9020_button_press_placeholder_kenney_bong.ogg"
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
    private const val POLAR_RR_FEEDBACK_SPACING_MS = 80L
    private const val LSL_INPUT_ENABLED = false
    private const val LSL_ROLE_DIAGNOSTIC_ONLY = "diagnostic_only"
    private const val LSL_DEFAULT_STREAM_NAME = "HRV_Biofeedback"
    private const val LSL_DEFAULT_STREAM_TYPE = "HRV"
    private const val LSL_DEFAULT_CHANNEL_INDEX = 0
    private const val LSL_TRIGGER_THRESHOLD_01 = 0.5f
    private const val LSL_TRIGGER_RISING_EDGE_ONLY = true
    private const val LSL_MINIMUM_TRIGGER_INTERVAL_MS = 250L
    private const val QUEST_QUESTIONNAIRE_PANEL_PACKAGE =
        "io.github.mesmerprism.questquestionnaire.panel"
    private const val HEARTBEAT_FLASH_FRAMES = 16
    private const val HEARTBEAT_FLASH_FRAME_MS = 20L
    private val AGENT_INTEGRATION_FORBIDDEN_PRODUCT_MECHANISMS =
        listOf(
            "adb_relaunch",
            "public_shared_storage_exchange",
            "mediastore_exchange",
            "file_uri",
            "package_kill_return_flow",
            "overlay_return_flow",
            "query_all_packages",
            "system_alert_window",
        )
    private val QUESTIONNAIRE_STAGE_SEQUENCE =
        listOf(
            "language_selection",
            "consent_demographics",
            "prior_big_red_button_experience",
            "condition_1",
            "post_condition_1_pictographic",
            "post_condition_1_presence_questionnaire",
            "post_condition_1_lost_opportunity",
            "condition_2",
            "post_condition_2_pictographic",
            "post_condition_2_presence_questionnaire",
            "post_condition_2_lost_opportunity",
            "final_end_confirmation",
            "final_extra_presses_optional",
            "complete_export_summary",
        )
    private val QUESTIONNAIRE_VALIDATION_SHORTCUT_MODES =
        listOf(
            "auto_validation",
            "physical_press_validation",
            "keyevent_validation",
            "fast_controller_flow",
            "panel_smoke",
            "demographics_keyboard_validation",
            "audio_rig_stress",
            "visual_glow_validation",
        )
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
  val finalExtraPressCount by activity.finalExtraPressCountState
  val finalExtraPromptVisible by activity.finalExtraPromptVisibleState
  val interimPressInteractionSource = remember { MutableInteractionSource() }
  val panelModifier =
      if (stage == StudyStage.ConditionRunning || stage == StudyStage.FinalExtraPresses) {
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
    } else if (stage == StudyStage.FinalExtraPresses) {
      FinalExtraPressPrompt(
          activity = activity,
          count = finalExtraPressCount,
          requirement = BigRedButtonStudyActivity.FINAL_EXTRA_BUTTON_PRESS_REQUIREMENT,
          showPrompt = finalExtraPromptVisible,
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
private fun FinalExtraPressPrompt(
    activity: BigRedButtonStudyActivity,
    count: Int,
    requirement: Int,
    showPrompt: Boolean,
    modifier: Modifier = Modifier,
) {
  Column(
      modifier =
          modifier
              .width(500.dp)
              .background(Color.Transparent)
              .padding(horizontal = 8.dp, vertical = 4.dp),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    if (showPrompt) {
      Text(
          activity.finalExtraPressesPromptText(),
          color = CounterDigitRed,
          fontSize = 13.sp,
          lineHeight = 17.sp,
          fontWeight = FontWeight.Black,
          fontFamily = BrbMono,
          textAlign = TextAlign.Center,
          style =
              TextStyle(
                  shadow =
                      Shadow(
                          color = CounterDigitRed.copy(alpha = 0.92f),
                          offset = Offset.Zero,
                          blurRadius = 18f,
                      ),
              ),
      )
    }
    DigitalPressCounter(
        count = count,
        target = requirement,
        label = activity.t("presses_out_of_1000"),
    )
  }
}

@Composable
private fun PriorBigRedButtonExperiencePrompt(
    activity: BigRedButtonStudyActivity,
    modifier: Modifier = Modifier,
) {
  val answer by activity.priorBigRedButtonExperienceAnswerState
  val optionsReady by activity.priorBigRedButtonExperienceOptionsReadyState
  val feedbackReady by activity.priorBigRedButtonExperienceFeedbackReadyState
  val preStartReady by activity.priorBigRedButtonExperiencePreStartReadyState
  val startBlockedReason by activity.priorBigRedButtonExperienceStartBlockedReasonState
  val feedback =
      when (answer) {
        "no" -> activity.priorButtonExperienceFeedbackText("no")
        "yes" -> activity.priorButtonExperienceFeedbackText("yes")
        else -> ""
      }
  val polarStartWarning =
      if (answer in setOf("yes", "no") && feedbackReady && preStartReady) {
        activity.missingPolarStartWarningText()
      } else {
        ""
      }
  val statusText = startBlockedReason.ifBlank { polarStartWarning.ifBlank { feedback } }
  Column(
      modifier =
          modifier
              .width(540.dp)
              .background(Color.Transparent)
              .padding(horizontal = 8.dp, vertical = 4.dp),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    Text(
        activity.priorButtonExperienceQuestionText(),
        color = CounterDigitRed,
        fontSize = 21.sp,
        lineHeight = 27.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
        textAlign = TextAlign.Center,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = CounterDigitRed.copy(alpha = 0.92f),
                        offset = Offset.Zero,
                        blurRadius = 18f,
                    ),
            ),
    )
    if (optionsReady || answer.isNotBlank()) {
      Row(
          horizontalArrangement = Arrangement.spacedBy(34.dp, Alignment.CenterHorizontally),
          verticalAlignment = Alignment.CenterVertically,
          modifier = Modifier.fillMaxWidth(),
      ) {
        if (answer.isBlank() || answer == "yes") {
          PriorExperienceCheckbox(
              label = activity.t("yes"),
              checked = answer == "yes",
              enabled = answer.isBlank(),
          ) {
            SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
              it.setPriorBigRedButtonExperienceAnswer("yes", "xr_checkbox")
            }
          }
        }
        if (answer.isBlank() || answer == "no") {
          PriorExperienceCheckbox(
              label = activity.t("no"),
              checked = answer == "no",
              enabled = answer.isBlank(),
          ) {
            SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
              it.setPriorBigRedButtonExperienceAnswer("no", "xr_checkbox")
            }
          }
        }
      }
    } else {
      Spacer(modifier = Modifier.height(52.dp))
    }
    Text(
        text = statusText.ifBlank { " " },
        color = if (statusText.isBlank()) Color.Transparent else CounterDigitRed,
        fontSize = 16.sp,
        lineHeight = 20.sp,
        fontWeight = FontWeight.Bold,
        fontFamily = BrbMono,
        textAlign = TextAlign.Center,
        minLines = 2,
        style =
            TextStyle(
                  shadow =
                      Shadow(
                          color = CounterDigitRed.copy(alpha = if (statusText.isBlank()) 0f else 0.86f),
                          offset = Offset.Zero,
                          blurRadius = 12f,
                      ),
            ),
    )
    if (answer in setOf("yes", "no") && feedbackReady && preStartReady) {
      CounterFloatingAction(
          text = activity.t("start_experiment"),
          enabled = true,
      ) {
        SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
          it.playQuestionnaireNavigationCue()
          it.startExperimentFromPriorButtonExperienceQuestion()
        }
      }
    } else {
      Spacer(modifier = Modifier.height(18.dp))
    }
  }
}

@Composable
private fun PriorExperienceCheckbox(
    label: String,
    checked: Boolean,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
  val checkboxBorder = CounterDigitRed.copy(alpha = if (checked) 1f else 0.82f)
  val clickModifier = if (enabled) modifier.clickable { onClick() } else modifier
  Row(
      modifier =
          clickModifier
              .background(Color.Transparent)
              .padding(horizontal = 6.dp, vertical = 4.dp),
      horizontalArrangement = Arrangement.Center,
      verticalAlignment = Alignment.CenterVertically,
  ) {
    Box(
        modifier =
            Modifier.size(32.dp)
                .background(if (checked) CounterDigitRed.copy(alpha = 0.18f) else Color.Transparent)
                .border(2.dp, checkboxBorder, RoundedCornerShape(2.dp)),
        contentAlignment = Alignment.Center,
    ) {
      Text(
          if (checked) "\u2713" else "",
          color = CounterDigitRed,
          fontSize = 22.sp,
          fontWeight = FontWeight.Black,
          fontFamily = BrbMono,
          textAlign = TextAlign.Center,
          style =
              TextStyle(
                  shadow =
                      Shadow(
                          color = CounterDigitRed.copy(alpha = if (checked) 0.9f else 0f),
                          offset = Offset.Zero,
                          blurRadius = 10f,
                      ),
              ),
      )
    }
    Spacer(modifier = Modifier.width(8.dp))
    Text(
        label.uppercase(Locale.US),
        color = CounterDigitRed,
        fontSize = 17.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = CounterDigitRed.copy(alpha = 0.78f),
                        offset = Offset.Zero,
                        blurRadius = 10f,
                    ),
            ),
    )
  }
}

@Composable
private fun CounterFloatingAction(
    text: String,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
  val actionModifier =
      modifier
          .widthIn(min = 220.dp)
          .height(44.dp)
          .background(Color.Transparent)
          .border(2.dp, CounterDigitRed.copy(alpha = if (enabled) 0.82f else 0.18f), RoundedCornerShape(2.dp))
          .padding(horizontal = 14.dp)
          .let { if (enabled) it.clickable { onClick() } else it }
  val textAlpha = if (enabled) 0.96f else 0.34f
  val glowAlpha = if (enabled) 0.82f else 0.18f
  Box(
      modifier = actionModifier,
      contentAlignment = Alignment.Center,
  ) {
    Text(
        text.uppercase(Locale.US),
        color = CounterDigitRed.copy(alpha = textAlpha),
        fontSize = 13.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
        textAlign = TextAlign.Center,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = CounterDigitRed.copy(alpha = glowAlpha),
                        offset = Offset.Zero,
                        blurRadius = 10f,
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
private fun DigitalPressCounter(
    count: Int,
    modifier: Modifier = Modifier,
    target: Int? = null,
    label: String = "PRESSES",
) {
  val displayValue =
      if (target == null) {
        count.coerceIn(0, 999).toString().padStart(3, '0')
      } else {
        "${count.coerceIn(0, target).toString().padStart(4, '0')} / $target"
      }
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
        label,
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
  val transparentCounterQuestionnaire = stage == StudyStage.FinalEndQuestionnaire
  val panelShape = RoundedCornerShape(if (transparentCounterQuestionnaire) 0.dp else 18.dp)
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
                .clip(panelShape)
                .background(
                    if (transparentCounterQuestionnaire) {
                      Color.Transparent
                    } else {
                      BrbPaper.copy(alpha = if (glitchActive) 0.88f else 0.94f)
                    }
                )
                .border(
                    if (transparentCounterQuestionnaire) 0.dp else 1.dp,
                    if (transparentCounterQuestionnaire) Color.Transparent else if (glitchActive) BrbLine.copy(alpha = 0.26f) else BrbLine,
                    panelShape,
                ),
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
          StudyStage.LanguageSelection -> LanguageSelectionScreen(activity)
          StudyStage.ConsentDemographics -> ConsentDemographicsScreen(activity)
          StudyStage.PreButtonExperienceQuestion -> WaitingScreen(activity)
          StudyStage.ConditionRunning -> WaitingScreen(activity)
          StudyStage.Pictographic -> PictographicScreen(activity)
          StudyStage.PresenceQuestionnaire -> PresenceQuestionnaireScreen(activity)
          StudyStage.LostOpportunity -> LostOpportunityScreen(activity)
          StudyStage.FinalEndQuestionnaire -> FinalEndQuestionnaireScreen(activity)
          StudyStage.FinalExtraPresses -> WaitingScreen(activity)
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
private fun LanguageSelectionScreen(activity: BigRedButtonStudyActivity) {
  val focusIndex by activity.languageSelectionFocusIndexState
  val options = listOf(StudyLanguage.English, StudyLanguage.Japanese)
  Column(
      modifier = Modifier.fillMaxSize(),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.Center,
  ) {
    BrandKicker("Big Red Button Institute")
    PanelTitle(activity.t("language_title"))
    Spacer(modifier = Modifier.height(8.dp))
    Text(
        activity.t("language_body"),
        color = BrbMuted,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        fontFamily = BrbSans,
        textAlign = TextAlign.Center,
        modifier = Modifier.widthIn(max = 720.dp),
    )
    Spacer(modifier = Modifier.height(26.dp))
    Row(
        modifier = Modifier.widthIn(max = 620.dp).fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
      options.forEachIndexed { index, language ->
        val focused = focusIndex == index
        OutlinedButton(
            onClick = {
              SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
                it.languageSelectionFocusIndexState.intValue = index
                it.playQuestionnaireChoiceCue()
                it.selectStudyLanguage(language, "xr_language_button")
              }
            },
            colors =
                ButtonDefaults.outlinedButtonColors(
                    backgroundColor = if (focused) BrbRed else BrbPaperLight,
                    contentColor = if (focused) Color.White else BrbInk,
                ),
            modifier =
                Modifier.weight(1f)
                    .height(96.dp)
                    .border(2.dp, if (focused) BrbRedDeep else BrbLine, RoundedCornerShape(8.dp)),
        ) {
          Text(
              language.label,
              fontSize = 26.sp,
              fontWeight = FontWeight.Black,
              fontFamily = if (language == StudyLanguage.Japanese) BrbSans else BrbMono,
              textAlign = TextAlign.Center,
          )
        }
      }
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

  LaunchedEffect(Unit) {
    activity.logDemographicsTextFieldContract()
  }
  val canSubmit =
      name.isNotBlank() &&
          age.toIntOrNull()?.let { it in DEMOGRAPHICS_AGE_MIN..DEMOGRAPHICS_AGE_MAX } == true &&
          gender.isNotBlank() &&
          handedness.isNotBlank() &&
          signature.isNotBlank() &&
          consent
  val requiredTextField =
      when {
        name.trim().isBlank() -> "name"
        age.toIntOrNull()?.let { it in DEMOGRAPHICS_AGE_MIN..DEMOGRAPHICS_AGE_MAX } != true -> "age"
        else -> ""
      }
  Box(modifier = Modifier.fillMaxSize()) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      IntakeWebsiteHeader(activity)
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
              activity.t("participant_details"),
              color = BrbInk,
              fontSize = 16.sp,
              fontWeight = FontWeight.ExtraBold,
              fontFamily = BrbSans,
          )
          Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            LabeledTextField(
                activity = activity,
                fieldId = "name",
                label = activity.t("name"),
                value = name,
                onValueChange = { name = it },
                modifier = Modifier.weight(1f),
                autoFocus = true,
                isRequired = requiredTextField == "name",
                keyboardMode = "text",
                onSubmit = { activity.focusDemographicsAgeSlider("name_submit_next") },
            )
            AgeSliderField(
                activity = activity,
                label = activity.t("age"),
                value = age,
                onValueChange = { age = it },
                modifier = Modifier.weight(1f),
                isRequired = requiredTextField == "age",
            )
          }
          Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            GenderChoice(
                activity = activity,
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
                activity = activity,
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
          ConsentSignaturePad(activity = activity, value = signature, onValueChange = { signature = it })
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
              activity.t("consent"),
              fontSize = 13.sp,
              color = BrbInk,
              fontFamily = BrbSans,
          )
        }
      }
      PrimaryActionButton(activity.t("start_experiment"), canSubmit, height = 48.dp) {
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
  val ecgPreviewSamples by activity.polarEcgPreviewSamplesState
  val hrReady = status.streaming && status.heartRateBpm > 0 && status.rrIntervalCount > 0
  val ecgReady = status.pmdReady && status.ecgStreaming && status.ecgSampleCount > 0 && status.ecgSampleRateHz == 130
  val ok = hrReady && ecgReady
  val symbol = if (ok) "\u2713" else "!"
  fun readyText(value: Boolean): String = if (value) activity.t("yes").lowercase(Locale.US) else activity.t("no").lowercase(Locale.US)
  val statusText =
      when {
        ok -> activity.t("polar_ready")
        status.ecgStreaming -> activity.t("polar_waiting_samples")
        status.pmdStartCommandIssued && !status.pmdStartResponseReceived -> activity.t("polar_start_requested")
        status.pmdSettingsReceived -> activity.t("polar_settings_received")
        status.pmdControlPointIndicationsEnabled && status.pmdDataNotificationsEnabled -> activity.t("polar_pmd_subscribed")
        status.pmdControlPointIndicationsEnabled -> activity.t("polar_pmd_control_ready")
        status.pmdDataNotificationsEnabled -> activity.t("polar_pmd_data_ready")
        status.pmdReady -> activity.t("polar_pmd_ready")
        status.streaming -> activity.t("polar_hr_waiting_ecg")
        status.connected -> activity.t("polar_connected")
        status.detected -> activity.t("polar_detected")
        status.missingPermissions.isNotBlank() -> activity.t("polar_permissions")
        status.error.isNotBlank() -> activity.t("polar_not_ready")
        else -> activity.t("polar_scanning")
      }
  val signalDetail =
      "HR ${status.heartRateBpm} bpm | RR ${status.rrIntervalCount} | ECG ${status.ecgSampleCount} samples @ ${status.ecgSampleRateHz} Hz"
  val pmdDiagnostic =
      "PMD cp-ind ${readyText(status.pmdControlPointIndicationsEnabled)} | data ${readyText(status.pmdDataNotificationsEnabled)} | settings ${readyText(status.pmdSettingsReceived)} | start ${readyText(status.pmdStartResponseReceived)} | MTU ${status.requestedMtu}/${status.negotiatedMtu}"
  val commandDiagnostic =
      when {
        status.pmdLastErrorCode >= 0 -> "cmd ${status.pmdLastCommand.ifBlank { "none" }} | PMD error ${status.pmdLastErrorCode}"
        status.pmdLastCommand.isNotBlank() -> "cmd ${status.pmdLastCommand}"
        status.error.isNotBlank() -> status.error
        status.missingPermissions.isNotBlank() -> status.missingPermissions.replace("|", ", ")
        status.deviceName.isNotBlank() -> status.deviceName
        else -> activity.t("polar_keep_strap")
      }
  val detail =
      when {
        ok || status.streaming || status.ecgStreaming -> signalDetail
        else -> commandDiagnostic
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
    Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.weight(1f)) {
      Text(statusText, color = BrbInk, fontSize = 13.sp, fontWeight = FontWeight.Bold, fontFamily = BrbSans)
      Text(detail, color = BrbMuted, fontSize = 10.sp, fontFamily = BrbMono)
      if (!ok) {
        Text(pmdDiagnostic, color = BrbMuted.copy(alpha = 0.9f), fontSize = 9.sp, lineHeight = 11.sp, fontFamily = BrbMono)
      }
    }
    if (ok || ecgPreviewSamples.isNotEmpty()) {
      PolarEcgWaveform(
          samples = ecgPreviewSamples,
          ready = ok,
          modifier = Modifier.width(300.dp).height(46.dp),
      )
    }
  }
}

@Composable
private fun PolarEcgWaveform(
    samples: List<Int>,
    ready: Boolean,
    modifier: Modifier = Modifier,
) {
  val traceColor = if (ready) Color(0xFF127A3A) else Color(0xFFA06A00)
  Box(
      modifier =
          modifier
              .clip(RoundedCornerShape(8.dp))
              .background(Color.White.copy(alpha = 0.62f))
              .border(1.dp, traceColor.copy(alpha = 0.48f), RoundedCornerShape(8.dp)),
      contentAlignment = Alignment.Center,
  ) {
    Canvas(modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp, vertical = 5.dp)) {
      val baselineY = size.height * 0.5f
      val gridColor = BrbMuted.copy(alpha = 0.12f)
      drawLine(gridColor, Offset(0f, baselineY), Offset(size.width, baselineY), strokeWidth = 1.2f)
      drawLine(gridColor, Offset(0f, size.height * 0.25f), Offset(size.width, size.height * 0.25f), strokeWidth = 0.8f)
      drawLine(gridColor, Offset(0f, size.height * 0.75f), Offset(size.width, size.height * 0.75f), strokeWidth = 0.8f)

      val window = samples.takeLast(POLAR_ECG_PREVIEW_SAMPLE_COUNT)
      if (window.size >= 2) {
        val mean = window.average().toFloat()
        var maxAbsMicroVolts = 1f
        window.forEach { value ->
          val centered = abs(value.toFloat() - mean)
          if (centered > maxAbsMicroVolts) {
            maxAbsMicroVolts = centered
          }
        }
        val scale = (size.height * 0.42f) / maxAbsMicroVolts.coerceAtLeast(120f)
        val stepX = size.width / (window.size - 1).toFloat()
        var previous = Offset(0f, baselineY)
        window.forEachIndexed { index, value ->
          val x = index.toFloat() * stepX
          val y = (baselineY - (value.toFloat() - mean) * scale).coerceIn(2f, size.height - 2f)
          val current = Offset(x, y)
          if (index > 0) {
            drawLine(traceColor, previous, current, strokeWidth = 2.4f, cap = StrokeCap.Round)
          }
          previous = current
        }
      } else {
        drawLine(traceColor.copy(alpha = 0.45f), Offset(0f, baselineY), Offset(size.width, baselineY), strokeWidth = 2f)
      }
    }
    if (samples.size < 2) {
      Text("ECG", color = BrbMuted, fontSize = 9.sp, fontWeight = FontWeight.Bold, fontFamily = BrbMono)
    }
  }
}

@Composable
private fun ConsentSignaturePad(activity: BigRedButtonStudyActivity, value: String, onValueChange: (String) -> Unit) {
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
            activity.t("consent_signature"),
            color = BrbMuted,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = BrbSans,
        )
        Text(
            activity.t("signature_instruction"),
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
        Text(activity.t("clear"), fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = BrbSans)
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
            activity.t("sign_here"),
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
private fun IntakeWebsiteHeader(activity: BigRedButtonStudyActivity) {
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
      BrandKicker(activity.t("intake_kicker"))
      Text(
          activity.t("intake_title"),
          color = BrbInk,
          fontSize = 23.sp,
          fontWeight = FontWeight.Black,
          fontFamily = BrbSerif,
          lineHeight = 25.sp,
      )
      Text(
          activity.t("intake_body"),
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
    BrandKicker(activity.tf("pictographic_kicker", condition))
    PanelTitle(activity.t("pictographic_title"))
    Text(
        activity.t("pictographic_body"),
        color = BrbMuted,
        fontSize = 17.sp,
        fontFamily = BrbSans,
    )
    PictographicCanvas(closeness = closeness, presence = presence)
    val pictographicScaleModifier =
        Modifier.width(PICTOGRAPHIC_VAS_AXIS_WIDTH_DP.dp).align(Alignment.CenterHorizontally)
    ScaleSlider(
        label = activity.t("closeness_label"),
        value = 100f - closeness,
        left = activity.t("very_close"),
        right = activity.t("very_distant"),
        onChange = { activity.pictographicClosenessState.floatValue = 100f - it },
        modifier = pictographicScaleModifier,
    )
    ScaleSlider(
        label = activity.t("presence_label"),
        value = presence,
        left = activity.t("small_presence"),
        right = activity.t("large_presence"),
        onChange = { activity.pictographicPresenceState.floatValue = it },
        modifier = pictographicScaleModifier,
    )
    RednessResponseControl(
        activity = activity,
        condition = condition,
        vasValue = rednessVas,
        likertValue = rednessLikert,
        converted = rednessConverted,
        choreography = rednessChoreography,
        modifier = pictographicScaleModifier,
        onVasChange = { value ->
          SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
            it.setRednessVas(value, "participant_vas_drag")
          }
        },
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
    PrimaryActionButton(activity.t("save_response"), rednessChoreography == null) {
      SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> { it.submitPictographic() }
    }
  }
}

@Composable
private fun RednessResponseControl(
    activity: BigRedButtonStudyActivity,
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
            label = activity.t("redness_label"),
            value = vasValue,
            left = activity.t("slightly_red"),
            right = activity.t("very_red"),
            onChange = onVasChange,
            onFinished = onVasFinished,
            modifier = Modifier.fillMaxWidth(),
        )
      } else {
        RednessLikertScale(
            value = likertValue,
            onSelect = onLikertSelect,
            modifier = Modifier.fillMaxWidth(),
            label = activity.t("redness_label"),
            descriptors = activity.localizedRednessDescriptors(),
            left = activity.t("slightly_red"),
            right = activity.t("extremely_red"),
        )
      }
    }
    if (choreography != null) {
      RednessConversionChoreographyOverlay(activity = activity, choreography = choreography, elapsedMs = elapsedMs)
    }
  }
}

@Composable
private fun RednessConversionChoreographyOverlay(
    activity: BigRedButtonStudyActivity,
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
      if (activeEvent != null) {
        activity.localizedRednessMicroCaption(activeEvent.code, activeEvent.participantCaption)
      } else {
        when {
          elapsedMs < choreography.swapAtMs -> activity.t("redness_micro_one_moment")
          elapsedMs < choreography.settleAtMs -> activity.t("redness_micro_updating")
          else -> activity.t("redness_micro_adjust")
        }
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
private fun RednessLikertScale(
    value: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier,
    label: String,
    descriptors: List<String>,
    left: String,
    right: String,
) {
  Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(
          label,
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
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 28.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
      descriptors.forEachIndexed { index, descriptor ->
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
      Text(left, color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
      Text(right, color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
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
    BrandKicker(activity.tf("ratings_kicker", condition))
    PanelTitle(activity.t("ratings_title"))
    Text(
        activity.tf("ratings_body", condition),
        color = BrbMuted,
        fontSize = 17.sp,
        fontFamily = BrbSans,
    )
    Divider(color = BrbLine)
    IPQ_ITEMS.forEachIndexed { index, item ->
      PresenceItemRow(
          index = index + 1,
          text = activity.localizedPresenceItemText(item),
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
        activity.tf("items_answered", answered, IPQ_ITEMS.size),
        color = BrbMuted,
        fontFamily = BrbMono,
        fontSize = 14.sp,
    )
    PrimaryActionButton(activity.t("save_ratings"), canSubmit) {
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
    BrandKicker(activity.tf("lost_kicker", condition))
    PanelTitle(activity.t("lost_title"))
    Text(
        activity.t("lost_body"),
        color = BrbInk,
        fontSize = 23.sp,
        fontFamily = BrbSans,
    )
    ScaleSlider(
        label = activity.tf("condition_rating", condition),
        value = score,
        left = activity.t("not_at_all_likely"),
        right = activity.t("extremely_likely"),
        onChange = { activity.lostOpportunityState.floatValue = it },
    )
    Text(
        score.toInt().toString(),
        color = BrbRedDeep,
        fontSize = 48.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
    )
    PrimaryActionButton(activity.t("save_rating"), true) {
      SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> { it.submitLostOpportunity() }
    }
  }
}

@Composable
private fun FinalEndQuestionnaireScreen(activity: BigRedButtonStudyActivity) {
  val selected by activity.finalEndLikertState
  val feedback by activity.finalEndFeedbackState
  val selectionLocked by activity.finalEndSelectionLockedState
  val optionsReady by activity.finalEndQuestionAudioReadyState
  Column(
      modifier = Modifier.fillMaxSize().background(Color.Transparent).padding(horizontal = 12.dp),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.Center,
  ) {
    Text(
        activity.finalEndConfirmationQuestionText(),
        color = CounterDigitRed,
        fontSize = 28.sp,
        lineHeight = 34.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
        textAlign = TextAlign.Center,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = CounterDigitRed.copy(alpha = 0.92f),
                        offset = Offset.Zero,
                        blurRadius = 18f,
                    ),
            ),
    )
    Spacer(modifier = Modifier.height(24.dp))
    if (optionsReady || selectionLocked) {
      Row(
          modifier = Modifier.fillMaxWidth(),
          horizontalArrangement = Arrangement.spacedBy(7.dp, Alignment.CenterHorizontally),
          verticalAlignment = Alignment.CenterVertically,
      ) {
        (1..10).filter { value -> !selectionLocked || value == selected }.forEach { value ->
          val active = selected == value
          val boxModifier =
              (if (selectionLocked) Modifier.width(74.dp) else Modifier.weight(1f))
                  .height(66.dp)
                  .background(if (active) CounterDigitRed.copy(alpha = 0.18f) else Color.Transparent)
                  .border(
                      2.dp,
                      CounterDigitRed.copy(alpha = if (active) 1f else 0.72f),
                      RoundedCornerShape(2.dp),
                  )
          Box(
              modifier =
                  if (selectionLocked) {
                    boxModifier
                  } else {
                    boxModifier.clickable {
                      SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
                        it.setFinalEndLikert(value, "xr_likert_box")
                        it.submitFinalEndConfirmationSelection("xr_likert_box")
                      }
                    }
                  },
              contentAlignment = Alignment.Center,
          ) {
            Text(
                value.toString(),
                color = CounterDigitRed.copy(alpha = if (active) 1f else 0.86f),
                fontSize = 25.sp,
                fontWeight = FontWeight.Black,
                fontFamily = BrbMono,
                style =
                    TextStyle(
                        shadow =
                            Shadow(
                                color = CounterDigitRed.copy(alpha = if (active) 0.9f else 0.52f),
                                offset = Offset.Zero,
                                blurRadius = if (active) 12f else 8f,
                            ),
                    ),
            )
          }
        }
      }
    } else {
      Spacer(modifier = Modifier.height(66.dp))
    }
    Spacer(modifier = Modifier.height(10.dp))
    if (optionsReady || selectionLocked) {
      Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(activity.t("final_scale_left"), color = CounterDigitRed.copy(alpha = 0.76f), fontSize = 13.sp, fontFamily = BrbMono)
        Text(activity.t("final_scale_right"), color = CounterDigitRed.copy(alpha = 0.76f), fontSize = 13.sp, fontFamily = BrbMono)
      }
    } else {
      Spacer(modifier = Modifier.height(16.dp))
    }
    Spacer(modifier = Modifier.height(18.dp))
    Text(
        feedback.ifBlank { " " },
        color = if (feedback.isBlank()) Color.Transparent else CounterDigitRed,
        fontSize = 19.sp,
        lineHeight = 24.sp,
        fontWeight = FontWeight.Black,
        fontFamily = BrbMono,
        textAlign = TextAlign.Center,
        minLines = 3,
        style =
            TextStyle(
                shadow =
                    Shadow(
                        color = CounterDigitRed.copy(alpha = if (feedback.isBlank()) 0f else 0.78f),
                        offset = Offset.Zero,
                        blurRadius = 12f,
                    ),
            ),
    )
  }
}

@Composable
private fun CompleteScreen(activity: BigRedButtonStudyActivity) {
  val exportStatus by activity.exportStatusState
  Column(
      modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
      verticalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    BrandKicker(activity.t("complete_kicker"))
    PanelTitle(activity.t("complete_title"))
    Text(
        activity.t("complete_body"),
        fontSize = 20.sp,
        color = BrbInk,
        fontFamily = BrbSans,
    )
    Text(exportStatus, color = BrbMuted, fontSize = 14.sp, fontFamily = BrbMono)
  }
}

@Composable
private fun WaitingScreen(activity: BigRedButtonStudyActivity) {
  Column(
      modifier = Modifier.fillMaxSize(),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.Center,
  ) {
    BrandKicker(activity.t("audio_condition"))
    Text(
        activity.t("condition_running"),
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
  val density = LocalDensity.current
  val scaleWidthPx = with(density) { PICTOGRAPHIC_VAS_AXIS_WIDTH_DP.dp.toPx() }
  val scaleThumbRadiusPx = with(density) { PICTOGRAPHIC_VAS_THUMB_RADIUS_DP.dp.toPx() }
  val buttonDistancePx = with(density) { selfButtonDistanceUnits(closeness).dp.toPx() }
  val maxButtonDistancePx = with(density) { selfButtonDistanceUnits(0f).dp.toPx() }
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
    val scaleStartX = ((size.width - scaleWidthPx) / 2f).coerceAtLeast(0f)
    val selfX = scaleStartX + scaleThumbRadiusPx
    val buttonX = selfX + buttonDistancePx
    val radius = buttonPresenceRadiusUnits(presence)
    val selfBoundaryRadius = buttonPresenceRadiusUnits(50f)
    drawLine(
        color = BrbLine.copy(alpha = 0.95f),
        start = Offset(selfX, y),
        end = Offset(selfX + maxButtonDistancePx, y),
        strokeWidth = 4f,
    )
    drawCircle(
        BrbInk.copy(alpha = 0.78f),
        radius = selfBoundaryRadius,
        center = Offset(selfX, y),
        style = Stroke(width = 9f),
    )
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
private fun PresenceItemRow(index: Int, text: String, selected: Int?, onSelect: (Int) -> Unit) {
  Column(verticalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxWidth()) {
    Text(
        "$index. $text",
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
    activity: BigRedButtonStudyActivity,
    selected: String,
    onSelect: (String) -> Unit,
    onChoiceCue: () -> Unit,
    modifier: Modifier = Modifier,
) {
  val options =
      listOf(
          "male" to activity.t("male"),
          "female" to activity.t("female"),
          "other" to activity.t("other"),
          "prefer_not_to_say" to activity.t("prefer_not_to_say"),
      )
  ChoiceButtonGroup(
      title = activity.t("gender"),
      options = options,
      selected = selected,
      onSelect = onSelect,
      onChoiceCue = onChoiceCue,
      modifier = modifier,
  )
}

@Composable
private fun HandednessChoice(
    activity: BigRedButtonStudyActivity,
    selected: String,
    onSelect: (String) -> Unit,
    onChoiceCue: () -> Unit,
    modifier: Modifier = Modifier,
) {
  val options = listOf("left" to activity.t("left"), "right" to activity.t("right"), "ambidextrous" to activity.t("ambidextrous"))
  ChoiceButtonGroup(
      title = activity.t("handedness"),
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
  val boundedValue = value.coerceIn(0f, 100f)
  Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(label, fontWeight = FontWeight.Bold, color = BrbInk, fontSize = 17.sp, fontFamily = BrbSans)
      Text(
          boundedValue.toInt().toString(),
          fontWeight = FontWeight.Black,
          color = BrbRedDeep,
          fontSize = 18.sp,
          fontFamily = BrbMono,
      )
    }
    Box(modifier = Modifier.fillMaxWidth().height(44.dp)) {
      Canvas(modifier = Modifier.fillMaxSize()) {
        val thumbRadius = PICTOGRAPHIC_VAS_THUMB_RADIUS_DP.dp.toPx()
        val trackStartX = thumbRadius
        val trackEndX = (size.width - thumbRadius).coerceAtLeast(trackStartX)
        val trackY = size.height / 2f
        val trackTravel = (trackEndX - trackStartX).coerceAtLeast(1f)
        val thumbX = trackStartX + trackTravel * (boundedValue / 100f)
        drawLine(
            color = BrbLine,
            start = Offset(trackStartX, trackY),
            end = Offset(trackEndX, trackY),
            strokeWidth = 7f,
            cap = StrokeCap.Round,
        )
        drawLine(
            color = BrbRed,
            start = Offset(trackStartX, trackY),
            end = Offset(thumbX, trackY),
            strokeWidth = 7f,
            cap = StrokeCap.Round,
        )
        drawCircle(BrbRed, radius = thumbRadius, center = Offset(thumbX, trackY))
        drawCircle(Color.White.copy(alpha = 0.92f), radius = thumbRadius * 0.36f, center = Offset(thumbX, trackY))
      }
      Slider(
          value = boundedValue,
          onValueChange = { onChange(it.coerceIn(0f, 100f)) },
          onValueChangeFinished = {
            onFinished?.invoke()
                ?: SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
                  it.playQuestionnaireNavigationCue()
                }
          },
          valueRange = 0f..100f,
          colors =
              SliderDefaults.colors(
                  thumbColor = Color.Transparent,
                  activeTrackColor = Color.Transparent,
                  inactiveTrackColor = Color.Transparent,
              ),
          modifier = Modifier.fillMaxSize().graphicsLayer { alpha = 0.01f },
      )
    }
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(left, color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
      Text(right, color = BrbMuted, fontSize = 13.sp, fontFamily = BrbMono)
    }
  }
}

@Composable
private fun AgeSliderField(
    activity: BigRedButtonStudyActivity,
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    isRequired: Boolean = false,
) {
  val focusedField by activity.demographicsFocusedFieldState
  val isFocused = focusedField == "age"
  val isGuidedField = isFocused || isRequired
  val sliderValue = ageSliderValueOrDefault(value).toFloat()
  val displayValue = value.toIntOrNull()?.coerceIn(DEMOGRAPHICS_AGE_MIN, DEMOGRAPHICS_AGE_MAX)

  Column(
      modifier =
          modifier
              .height(72.dp)
              .clip(RoundedCornerShape(8.dp))
              .background(Color(0xFFFFFBF4), RoundedCornerShape(8.dp))
              .border(
                  if (isGuidedField) 2.dp else 1.dp,
                  if (isGuidedField) BrbRedDeep else BrbLine,
                  RoundedCornerShape(8.dp),
              )
              .clickable { activity.focusDemographicsAgeSlider("tap_hitbox") }
              .padding(horizontal = 12.dp, vertical = 5.dp),
      verticalArrangement = Arrangement.Center,
  ) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
      Text(
          label,
          color = if (isGuidedField) BrbRedDeep else BrbMuted,
          fontSize = if (isGuidedField) 11.sp else 10.sp,
          fontWeight = if (isGuidedField) FontWeight.ExtraBold else FontWeight.SemiBold,
          fontFamily = BrbMono,
          lineHeight = 11.sp,
      )
      Text(
          displayValue?.toString() ?: "--",
          color = BrbInk,
          fontSize = 16.sp,
          fontWeight = FontWeight.Black,
          fontFamily = BrbMono,
          textAlign = TextAlign.End,
      )
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      Text("0", color = BrbMuted, fontSize = 10.sp, fontFamily = BrbMono)
      Slider(
          value = sliderValue,
          onValueChange = { rawValue ->
            val cleaned = rawValue.roundToInt().coerceIn(DEMOGRAPHICS_AGE_MIN, DEMOGRAPHICS_AGE_MAX)
            if (cleaned.toString() != value) {
              val next = activity.setDemographicsAgeSliderValue(cleaned, "compose_slider")
              onValueChange(next)
            }
          },
          onValueChangeFinished = { activity.logDemographicsAgeSliderConfirmed("compose_slider") },
          valueRange = DEMOGRAPHICS_AGE_MIN.toFloat()..DEMOGRAPHICS_AGE_MAX.toFloat(),
          steps = DEMOGRAPHICS_AGE_MAX - DEMOGRAPHICS_AGE_MIN - 1,
          colors =
              SliderDefaults.colors(
                  thumbColor = BrbRed,
                  activeTrackColor = BrbRed,
                  inactiveTrackColor = BrbLine,
              ),
          modifier = Modifier.weight(1f).height(30.dp),
      )
      Text("100", color = BrbMuted, fontSize = 10.sp, fontFamily = BrbMono)
    }
  }
}

@Composable
private fun LabeledTextField(
    activity: BigRedButtonStudyActivity,
    fieldId: String,
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    autoFocus: Boolean = false,
    isRequired: Boolean = false,
    keyboardMode: String,
    onSubmit: () -> Unit,
) {
  val focusedField by activity.demographicsFocusedFieldState
  val isFocused = focusedField == fieldId
  val isGuidedField = isFocused || isRequired

  LaunchedEffect(autoFocus) {
    if (autoFocus) {
      delay(650)
      activity.requestDemographicsTextInputFocus(fieldId, "auto_focus_initial")
      delay(1800)
      if (activity.demographicsFocusedFieldState.value != fieldId) {
        activity.requestDemographicsTextInputFocus(fieldId, "auto_focus_retry_1")
      }
      delay(3800)
      if (activity.demographicsFocusedFieldState.value != fieldId) {
        activity.requestDemographicsTextInputFocus(fieldId, "auto_focus_retry_2")
      }
    }
  }

  Column(
      modifier =
          modifier
              .height(72.dp)
              .clip(RoundedCornerShape(8.dp))
              .background(Color(0xFFFFFBF4), RoundedCornerShape(8.dp))
              .border(
                  if (isGuidedField) 2.dp else 1.dp,
                  if (isGuidedField) BrbRedDeep else BrbLine,
                  RoundedCornerShape(8.dp),
              )
              .clickable { activity.requestDemographicsTextInputFocus(fieldId, "tap_hitbox") }
              .padding(horizontal = 12.dp, vertical = 5.dp),
      verticalArrangement = Arrangement.Center,
  ) {
    Text(
        label,
        color = if (isGuidedField) BrbRedDeep else BrbMuted,
        fontSize = if (isGuidedField) 11.sp else 10.sp,
        fontWeight = if (isGuidedField) FontWeight.ExtraBold else FontWeight.SemiBold,
        fontFamily = BrbMono,
        lineHeight = 11.sp,
    )
    Box(
        modifier =
            Modifier.fillMaxWidth()
                .height(42.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(Color.Transparent)
                .clickable { activity.requestDemographicsTextInputFocus(fieldId, "text_surface") },
        contentAlignment = Alignment.CenterStart,
    ) {
      Text(
          if (value.isBlank()) "" else value + if (isFocused) "|" else "",
          color = BrbInk,
          fontSize = 20.sp,
          fontWeight = FontWeight.SemiBold,
          fontFamily = BrbSans,
          lineHeight = 22.sp,
          maxLines = 1,
      )
    }
  }
}

@Composable
private fun NameKeyboardPopupPanel(activity: BigRedButtonStudyActivity) {
  val visible by activity.demographicsNameKeyboardVisibleState
  val name by activity.demographicsDraftNameState
  Box(
      modifier = Modifier.fillMaxSize().background(Color.Transparent).padding(10.dp),
      contentAlignment = Alignment.Center,
  ) {
    if (visible) {
      Column(
          modifier =
              Modifier.fillMaxWidth()
                  .clip(RoundedCornerShape(8.dp))
                  .background(Color(0xFFFFFBF4).copy(alpha = 0.98f), RoundedCornerShape(8.dp))
                  .border(2.dp, BrbRedDeep, RoundedCornerShape(8.dp))
                  .padding(10.dp),
          verticalArrangement = Arrangement.spacedBy(8.dp),
      ) {
        Box(
            modifier =
                Modifier.fillMaxWidth()
                    .height(48.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color.White.copy(alpha = 0.92f), RoundedCornerShape(6.dp))
                    .border(1.dp, BrbLine, RoundedCornerShape(6.dp))
                    .padding(horizontal = 12.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
          Text(
              if (name.isBlank()) "" else "$name|",
              color = BrbInk,
              fontSize = 23.sp,
              fontWeight = FontWeight.SemiBold,
              fontFamily = BrbSans,
              maxLines = 1,
          )
        }
        NamePanelKeyboard(activity = activity, modifier = Modifier.fillMaxWidth())
      }
    }
  }
}

@Composable
private fun NamePanelKeyboard(activity: BigRedButtonStudyActivity, modifier: Modifier = Modifier) {
  val cursorRow by activity.demographicsNameKeyboardCursorRowState
  val cursorColumn by activity.demographicsNameKeyboardCursorColumnState

  fun pressKey(char: Char) {
    SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
      it.playQuestionnaireNavigationCue()
      it.appendDemographicsNameCharacter(char, "app_owned_keyboard")
    }
  }

  fun moveCursor(row: Int, column: Int) {
    SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
      it.demographicsNameKeyboardCursorRowState.intValue = row
      it.demographicsNameKeyboardCursorColumnState.intValue = column
    }
  }

  @Composable
  fun KeyButton(label: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        shape = RoundedCornerShape(6.dp),
        colors =
            ButtonDefaults.buttonColors(
                backgroundColor = if (selected) BrbRed else Color.White.copy(alpha = 0.94f),
                contentColor = if (selected) Color.White else BrbInk,
            ),
        contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp),
        modifier = modifier.border(2.dp, if (selected) BrbRedDeep else BrbLineSoft, RoundedCornerShape(6.dp)),
    ) {
      Text(
          label,
          fontSize = 15.sp,
          fontWeight = FontWeight.Black,
          fontFamily = BrbMono,
          textAlign = TextAlign.Center,
          maxLines = 1,
      )
    }
  }

  Column(
      modifier =
          modifier
              .clip(RoundedCornerShape(8.dp))
              .background(Color(0xFFFFFBF4).copy(alpha = 0.96f), RoundedCornerShape(8.dp))
              .border(1.dp, BrbLine, RoundedCornerShape(8.dp))
              .padding(6.dp),
      verticalArrangement = Arrangement.spacedBy(5.dp),
  ) {
    DEMOGRAPHICS_NAME_KEYBOARD_LETTER_ROWS.forEachIndexed { rowIndex, row ->
      Row(
          modifier = Modifier.fillMaxWidth(),
          horizontalArrangement = Arrangement.spacedBy(5.dp),
      ) {
        row.forEachIndexed { columnIndex, char ->
          KeyButton(
              char.toString(),
              selected = cursorRow == rowIndex && cursorColumn == columnIndex,
              modifier = Modifier.weight(1f).height(40.dp),
          ) {
            moveCursor(rowIndex, columnIndex)
            pressKey(char)
          }
        }
      }
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
      val controlRow = DEMOGRAPHICS_NAME_KEYBOARD_DEFAULT_ROW
      KeyButton(
          "Clear",
          selected = cursorRow == controlRow && cursorColumn == 0,
          modifier = Modifier.weight(1.15f).height(40.dp),
      ) {
        moveCursor(controlRow, 0)
        SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
          it.playQuestionnaireNavigationCue()
          it.replaceDemographicsTextInput("name", "", "text", "app_owned_keyboard_clear")
        }
      }
      KeyButton(
          "Space",
          selected = cursorRow == controlRow && cursorColumn == 1,
          modifier = Modifier.weight(2.2f).height(40.dp),
      ) {
        moveCursor(controlRow, 1)
        pressKey(' ')
      }
      KeyButton(
          "Back",
          selected = cursorRow == controlRow && cursorColumn == 2,
          modifier = Modifier.weight(1.15f).height(40.dp),
      ) {
        moveCursor(controlRow, 2)
        SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
          it.playQuestionnaireNavigationCue()
          it.backspaceDemographicsName("app_owned_keyboard")
        }
      }
      KeyButton(
          "Next",
          selected = cursorRow == controlRow && cursorColumn == 3,
          modifier = Modifier.weight(1.15f).height(40.dp),
      ) {
        moveCursor(controlRow, 3)
        SpatialActivityManager.executeOnVrActivity<BigRedButtonStudyActivity> {
          it.playQuestionnaireChoiceCue()
          it.logDemographicsTextInputEditorAction("name", "next", "app_owned_keyboard_next")
          it.focusDemographicsAgeSlider("app_owned_keyboard_next")
        }
      }
    }
  }
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
  return (100f - closeness0To100.coerceIn(0f, 100f)) *
      (PICTOGRAPHIC_SELF_BUTTON_TRAVEL_UNITS.toFloat() / 100f)
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
