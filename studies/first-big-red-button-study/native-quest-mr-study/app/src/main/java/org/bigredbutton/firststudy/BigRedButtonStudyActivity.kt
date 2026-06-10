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
import org.json.JSONArray
import org.json.JSONObject

private const val ECG_SAMPLE_RATE_HZ = 130
private const val SIMULATED_ECG_FRAME_SAMPLES = 16
private const val PRIOR_BUTTON_EXPERIENCE_QUESTION =
    "Oh wait, we have just one more question: Do you have any experience with pressing big red buttons?"
private const val PRE_BUTTON_EXPERIENCE_VALIDATION_DELAY_MS = 350L

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
  private var autoValidationStarted = false
  private var fastControllerFlowStarted = false
  private var panelGlitchToken = 0
  private var softKeyboardRequestGeneration = 0
  private var activeSoftKeyboardReason: String? = null
  private var activeSoftKeyboardMode: String? = null
  private var keyboardFieldContractLogged = false
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
    requestScenePermissionIfNeeded()
    initializeEcgProtocol()
    requestBlePermissionsIfNeeded()
    startPolarScanIfPermitted()
    Log.i(
        TAG,
        "BRB_STUDY_CREATED sessionId=$sessionId autoValidation=$autoValidationEnabled physicalPressValidation=$physicalPressValidationEnabled panelSmoke=$panelSmokeEnabled fastControllerFlow=$fastControllerFlowEnabled keyeventValidation=$keyeventValidationEnabled",
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
    if (pictographicRednessConvertedState.value) {
      return
    }
    val vas = pictographicRednessVasState.floatValue.coerceIn(0f, 100f)
    val likert = rednessLikertFromVas(vas)
    pictographicRednessVasState.floatValue = vas
    pictographicRednessLikertState.intValue = likert
    pictographicRednessConvertedState.value = true
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION condition=${activeConditionState.intValue} order=$REDNESS_ORDER_VAS_THEN_LIKERT from=vas to=likert reason=$reason vas=${vas.toInt()} likert=$likert descriptor=${rednessDescriptor(likert)}",
    )
    playRednessScaleConversionCue(REDNESS_ORDER_VAS_THEN_LIKERT)
  }

  fun convertRednessLikertToVas(reason: String) {
    if (pictographicRednessConvertedState.value) {
      return
    }
    val likert = pictographicRednessLikertState.intValue.coerceIn(1, 7)
    val vas = rednessVasCenterFromLikert(likert)
    pictographicRednessLikertState.intValue = likert
    pictographicRednessVasState.floatValue = vas
    pictographicRednessConvertedState.value = true
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION condition=${activeConditionState.intValue} order=$REDNESS_ORDER_LIKERT_THEN_VAS from=likert to=vas reason=$reason likert=$likert descriptor=${rednessDescriptor(likert)} vas=${vas.toInt()}",
    )
    playRednessScaleConversionCue(REDNESS_ORDER_LIKERT_THEN_VAS)
  }

  fun setRednessLikert(value1To7: Int, convertIfNeeded: Boolean) {
    val value = value1To7.coerceIn(1, 7)
    pictographicRednessLikertState.intValue = value
    if (convertIfNeeded && !pictographicRednessConvertedState.value && activeConditionState.intValue == 2) {
      convertRednessLikertToVas("participant_selection")
    } else {
      playQuestionnaireChoiceCue()
    }
  }

  fun submitPictographic() {
    val run = activeRun ?: return
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
    Log.i(
        TAG,
        "BRB_FAST_CONDITION_AUDIO_SHORTCUT condition=${run.conditionNumber} realDurationMs=${run.audioDurationMs} shortcutMs=$FAST_CONDITION_AUDIO_SHORTCUT_MS",
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
        FAST_CONDITION_AUDIO_SHORTCUT_MS,
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
        true
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
      run.ecgSampleRateHz = sample.sampleRateHz
      run.ecgRequestedMtu = sample.requestedMtu
      run.ecgNegotiatedMtu = sample.negotiatedMtu
    }
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
    for (index in 0 until expectedSamples) {
      val elapsedNs = ((index.toDouble() * 1_000_000_000.0) / sampleRateHz.toDouble()).roundToLong()
      val elapsedMs = elapsedNs.toDouble() / 1_000_000.0
      val unixTimeMs = run.startedElapsedMsToUnix(elapsedMs)
      run.ecgTimeSeriesSamples.add(
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
      )
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
        )
    run.ecgBlinkEvents.add(event)
    startHeartbeatFlash(event)
    Log.i(
        TAG,
        "BRB_ECG_BLINK condition=${event.conditionNumber} index=${event.blinkIndex} source=${event.source} rrMs=${"%.1f".format(Locale.US, event.rrMs)} bpm=${event.heartRateBpm} elapsedMs=${event.elapsedMs}",
    )
  }

  private fun startHeartbeatFlash(event: EcgBlinkEvent) {
    val token = ++heartbeatFlashToken
    buttonHeartbeatFlashState.value = true
    buttonHeartbeatFlashFrameState.intValue = 0
    fun advance(frame: Int) {
      if (token != heartbeatFlashToken) {
        return
      }
      if (frame >= HEARTBEAT_FLASH_FRAMES) {
        buttonHeartbeatFlashState.value = false
        buttonHeartbeatFlashFrameState.intValue = 0
        return
      }
      buttonHeartbeatFlashFrameState.intValue = frame
      mainHandler.postDelayed({ advance(frame + 1) }, HEARTBEAT_FLASH_FRAME_MS)
    }
    advance(0)
    Log.i(TAG, "BRB_HEARTBEAT_FLASH condition=${event.conditionNumber} source=${event.source} frameCount=$HEARTBEAT_FLASH_FRAMES")
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
      indexLine: String,
  ): List<File> {
    val jsonFile = File(exportDir, "$baseName.json")
    val summaryCsv = File(exportDir, "${baseName}_summary.csv")
    val pressCsv = File(exportDir, "${baseName}_press_events.csv")
    val ecgBlinkCsv = File(exportDir, "${baseName}_ecg_blink_events.csv")
    val ecgTimeSeriesCsv = File(exportDir, "${baseName}_ecg_timeseries.csv")
    val indexFile = File(exportDir, "session-index.jsonl")
    jsonFile.writeText(jsonText)
    summaryCsv.writeText(summaryText)
    pressCsv.writeText(pressText)
    ecgBlinkCsv.writeText(ecgBlinkText)
    ecgTimeSeriesCsv.writeText(ecgTimeSeriesText)
    indexFile.appendText(indexLine)
    return listOf(jsonFile, summaryCsv, pressCsv, ecgBlinkCsv, ecgTimeSeriesCsv, indexFile)
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
    buttonEntity?.setComponent(Visible(visible))
    buttonModelEntity?.setComponent(Visible(visible))
    buttonContactEntity?.setComponent(InteractivityInput(visible))
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
    buttonEntity?.setComponent(Visible(visible))
    buttonModelEntity?.setComponent(Visible(false))
    buttonContactEntity?.setComponent(InteractivityInput(false))
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

  fun playRednessScaleConversionCue(order: String) {
    Log.i(
        TAG,
        "BRB_REDNESS_SCALE_CONVERSION_CUE order=$order cue=redness_scale_conversion_pending_apology placeholder=true pendingAudioAsset=redness-scale-conversion-apology",
    )
    playRawOneShotCue(R.raw.ui_navigation_blip, "redness_scale_conversion_pending_apology")
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

  private fun createButtonContactColliderEntity() {
    buttonContactEntity =
        Entity.create(
            Transform(
                Pose(
                    Vector3(
                        0f,
                        BUTTON_CONTACT_COLLIDER_Y_METERS,
                        BUTTON_DISTANCE_FROM_HEAD_METERS,
                    )
                )
            ),
            IsdkBoxCollider(
                Vector3(
                    BUTTON_CONTACT_COLLIDER_WIDTH_METERS,
                    BUTTON_CONTACT_COLLIDER_HEIGHT_METERS,
                    BUTTON_CONTACT_COLLIDER_DEPTH_METERS,
                ),
                Vector3(0f, 0f, 0f),
            ),
            Hittable(MeshCollision.LineTest_IgnoreVisible),
            InteractivityInput(false),
        )
    Log.i(
        TAG,
        "BRB_BUTTON_CONTACT_COLLIDER_READY source=dual_controller_hand_contact shape=box x=0 y=$BUTTON_CONTACT_COLLIDER_Y_METERS z=$BUTTON_DISTANCE_FROM_HEAD_METERS size=${BUTTON_CONTACT_COLLIDER_WIDTH_METERS}x${BUTTON_CONTACT_COLLIDER_HEIGHT_METERS}x$BUTTON_CONTACT_COLLIDER_DEPTH_METERS",
    )
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
    val contactEntity = buttonContactEntity ?: return
    val hitEntity = event.hitInfo.entity ?: return
    if (hitEntity.id != contactEntity.id) {
      return
    }

    val eventType =
        PointerEventType.entries.firstOrNull { it.id == event.type }?.name ?: event.type.toString()
    val behavior = isdkSystem?.getInteractionEventSourceBehavior(event)
    val hand = isdkSystem?.getHandForPointerEvent(event)
    val handTracked = hand != null
    Log.i(
        TAG,
        "BRB_BUTTON_CONTACT_EVENT type=$eventType behavior=$behavior pointer=${event.pointerType} semantic=${event.semanticType} sourceEntity=${event.source.id} handTracked=$handTracked hand=$hand",
    )

    if (event.type != PointerEventType.Select.id) {
      return
    }
    val handSignalOnCollider =
        handTracked && behavior == InteractionEventSourceBehavior.COLLIDER_HOVER_SIGNAL_ACTUATE
    val physicalContact = behavior == InteractionEventSourceBehavior.COLLIDER_HOVER_CONTACT_ACTUATE
    when {
      handTracked && (physicalContact || handSignalOnCollider) -> {
        Log.i(TAG, "BRB_BUTTON_HAND_CONTACT_SELECT accepted=true behavior=$behavior")
        recordButtonPress(PRESS_SOURCE_HAND_CONTACT)
      }
      physicalContact -> {
        Log.i(TAG, "BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true")
        recordButtonPress(PRESS_SOURCE_CONTROLLER_CONTACT)
      }
      else -> {
        Log.i(TAG, "BRB_BUTTON_CONTACT_SELECT accepted=false reason=not_contact behavior=$behavior handTracked=$handTracked")
      }
    }
  }

  private fun playButtonPressedAnimation() {
    buttonModelEntity?.setComponent(
        Animated(
            startTime = System.currentTimeMillis(),
            pausedTime = 0f,
            playbackState = PlaybackState.PLAYING,
            playbackType = PlaybackType.CLAMP,
            track = 0,
            animationName = BUTTON_MODEL_PRESS_ANIMATION,
        )
    )
    Log.i(TAG, "BRB_BUTTON_MODEL_ANIMATION name=$BUTTON_MODEL_PRESS_ANIMATION playback=clamp")
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
    releasePlayer()
    releasePanelChimePlayer()
    releaseCuePlayers()
    polarClient?.stop()
    polarClient = null
    super.onDestroy()
  }

  override fun onSpatialShutdown() {
    mainHandler.removeCallbacks(ticker)
    if (isdkPointerObserverRegistered) {
      isdkSystem?.unregisterObserver(buttonContactPointerObserver)
      isdkPointerObserverRegistered = false
    }
    releasePlayer()
    releasePanelChimePlayer()
    releaseCuePlayers()
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
    private const val AUTO_VALIDATION_START_DELAY_MS = 1200L
    private const val AUTO_VALIDATION_POST_CONDITION_DELAY_MS = 1200L
    private const val FAST_CONTROLLER_FLOW_START_DELAY_MS = 700L
    private const val FAST_CONTROLLER_POST_CONDITION_DELAY_MS = 450L
    private const val FAST_CONDITION_AUDIO_SHORTCUT_MS = 2200L
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
    private const val BUTTON_PANEL_Y_METERS = 1.05f
    private const val BUTTON_BASE_Y_METERS = 0.95f
    private const val BUTTON_BEVEL_Y_METERS = 0.995f
    private const val BUTTON_DOME_Y_METERS = 1.04f
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
    private const val ECG_SOURCE_REAL_POLAR = "real_polar_h10"
    private const val ECG_SOURCE_SIMULATED = "simulated_neurokit2"
    private const val ECG_ORDER_REAL_THEN_SIMULATED = "real_then_simulated"
    private const val ECG_ORDER_SIMULATED_THEN_REAL = "simulated_then_real"
    private const val SIMULATED_RR_ASSET = "ecg/neurokit2_simulated_rr_intervals_ms.csv"
    private const val HEARTBEAT_FLASH_FRAMES = 10
    private const val HEARTBEAT_FLASH_FRAME_MS = 28L
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
      WarmButtonEmissionOverlay(active = heartbeatFlash, frame = heartbeatFlashFrame)
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
                .clip(RoundedCornerShape(18.dp))
                .background(BrbPaper.copy(alpha = 0.94f))
                .border(1.dp, BrbLine, RoundedCornerShape(18.dp))
                .padding(18.dp),
    ) {
      Box(
          modifier =
              Modifier.fillMaxSize()
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
    PrimaryActionButton("Save response", true) {
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
    modifier: Modifier,
    onVasChange: (Float) -> Unit,
    onVasFinished: () -> Unit,
    onLikertSelect: (Int) -> Unit,
) {
  val showVas = (condition == 1 && !converted) || (condition == 2 && converted)
  if (showVas) {
    ScaleSlider(
        label = "How red did the button feel?",
        value = vasValue,
        left = "slightly red",
        right = "very red",
        onChange = onVasChange,
        onFinished = onVasFinished,
        modifier = modifier,
    )
  } else {
    RednessLikertScale(value = likertValue, onSelect = onLikertSelect, modifier = modifier)
  }
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
private fun BlueFailureGlitchOverlay(active: Boolean, frame: Int, mode: String) {
  if (!active) {
    return
  }
  Canvas(modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(18.dp))) {
    val widthInt = size.width.toInt().coerceAtLeast(1)
    val heightInt = size.height.toInt().coerceAtLeast(1)
    val seizurePulse = frame % 12
    val baseAlpha =
        when {
          mode == "outro" && seizurePulse in 0..2 -> 0.88f
          seizurePulse == 0 || seizurePulse == 7 -> 0.82f
          else -> if (mode == "outro") 0.74f else 0.66f
        }
    drawRect(Color(0xFF012B7F).copy(alpha = baseAlpha))
    if (seizurePulse == 0 || seizurePulse == 6) {
      drawRect(Color(0xFFB7D7FF).copy(alpha = 0.22f))
    }
    if (seizurePulse == 3) {
      drawRect(Color(0xFF0000AA).copy(alpha = 0.48f))
    }

    for (i in 0 until 34) {
      val y = ((i * 29 + frame * (17 + (i % 5))) % heightInt).toFloat()
      val stripeHeight = 1.5f + ((i * 3 + frame) % 9) * 2.2f
      val xOffset = if ((i + frame) % 4 == 0) -size.width * 0.18f else 0f
      val stripeWidth = size.width * (1.05f + ((i + frame) % 3) * 0.10f)
      val color =
          when ((i + frame) % 5) {
            0 -> Color.White.copy(alpha = 0.30f)
            1 -> Color(0xFF7FD4FF).copy(alpha = 0.38f)
            2 -> Color(0xFF043BCA).copy(alpha = 0.54f)
            3 -> Color(0xFF001046).copy(alpha = 0.44f)
            else -> Color(0xFF00D8FF).copy(alpha = 0.24f)
          }
      drawRect(color = color, topLeft = Offset(xOffset, y), size = Size(stripeWidth, stripeHeight))
    }

    for (i in 0 until 18) {
      val blockWidth = size.width * (0.12f + ((i * 5 + frame) % 7) * 0.035f)
      val blockHeight = 10f + ((i * 13 + frame * 3) % 64)
      val x = ((frame * (41 + i) + i * 97) % widthInt).toFloat() - blockWidth / 2f
      val y = ((frame * (23 + i) + i * 61) % heightInt).toFloat()
      val blockColor =
          when ((frame + i) % 4) {
            0 -> Color(0xFFE8F6FF).copy(alpha = 0.24f)
            1 -> Color(0xFF36A7FF).copy(alpha = 0.30f)
            2 -> Color(0xFF001B66).copy(alpha = 0.54f)
            else -> Color(0xFF00F0FF).copy(alpha = 0.18f)
          }
      drawRect(color = blockColor, topLeft = Offset(x, y), size = Size(blockWidth, blockHeight))
    }

    for (i in 0 until 7) {
      val tearY = ((frame * (37 + i * 3) + i * 89) % heightInt).toFloat()
      val tearHeight = 5f + ((frame + i) % 6) * 4f
      val alpha = if ((frame + i) % 3 == 0) 0.42f else 0.18f
      drawRect(
          color = Color.White.copy(alpha = alpha),
          topLeft = Offset(0f, tearY),
          size = Size(size.width, tearHeight),
      )
      drawRect(
          color = Color(0xFF001046).copy(alpha = 0.38f),
          topLeft = Offset(((frame * 17 + i * 53) % widthInt).toFloat() - size.width * 0.40f, tearY + tearHeight),
          size = Size(size.width * 0.74f, tearHeight * 0.70f),
      )
    }

    val columnWidth = size.width / 18f
    for (i in 0 until 18) {
      if ((frame + i) % 5 == 0) {
        drawRect(
            color = Color(0xFF021A5F).copy(alpha = 0.24f),
            topLeft = Offset(i * columnWidth, 0f),
            size = Size(columnWidth * 0.52f, size.height),
        )
      }
    }
  }
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
