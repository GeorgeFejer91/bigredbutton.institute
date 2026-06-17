package org.bigredbutton.firststudy

import java.util.Locale
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.roundToLong
import kotlin.math.sqrt

enum class ButtonPressPhysicsPhase {
  IDLE,
  PRELOAD,
  IMPACT,
  BOTTOM_OUT,
  RELEASE,
}

data class ButtonPressPhysicsSample(
    val elapsedRealtimeNs: Long,
    val signedDistanceMeters: Float,
    val lateralDistanceMeters: Float,
)

data class ButtonPressMechanics(
    val predictionMode: String = ButtonPressPhysicsModel.PREDICTION_MODE_NONE,
    val phase: ButtonPressPhysicsPhase = ButtonPressPhysicsPhase.IDLE,
    val impactVelocityMetersPerSecond: Float = 0f,
    val predictedTimeToImpactMs: Long = -1L,
    val preloadLeadMs: Long = 0L,
    val confidence01: Float = 0f,
    val lateralVelocityMetersPerSecond: Float = 0f,
    val predictedLateralAtImpactMeters: Float = 0f,
    val trajectoryFit01: Float = 0f,
    val approachAngleDegrees: Float = 0f,
    val approachAlignment01: Float = 0f,
    val impactEnergyJoules: Float = 0f,
    val springCompressionMeters: Float = 0f,
    val dampingRatio: Float = 0f,
    val normalImpulseNewtonSeconds: Float = 0f,
    val estimatedPeakForceNewtons: Float = 0f,
    val estimatedContactPressureKilopascals: Float = 0f,
    val estimatedContactPatchAreaSquareMeters: Float = 0f,
    val compressionPeak01: Float = 0f,
    val actuationTravel01: Float = 0f,
    val actuationDelayMs: Long = 0L,
    val snapTravel01: Float = 0f,
    val snapDurationMs: Long = 0L,
    val bottomOutDelayMs: Long = 0L,
    val releaseDurationMs: Long = 0L,
    val visualStartOffsetMs: Long = 0L,
    val triggerEvidence: String = ButtonPressPhysicsModel.TRIGGER_EVIDENCE_NONE,
) {
  fun impactVelocityLog(): String =
      "%.3f".format(Locale.US, impactVelocityMetersPerSecond.coerceAtLeast(0f))

  fun confidenceLog(): String = "%.3f".format(Locale.US, confidence01.coerceIn(0f, 1f))

  fun lateralVelocityLog(): String =
      "%.3f".format(Locale.US, lateralVelocityMetersPerSecond)

  fun predictedLateralAtImpactLog(): String =
      "%.3f".format(Locale.US, predictedLateralAtImpactMeters.coerceAtLeast(0f))

  fun trajectoryFitLog(): String = "%.3f".format(Locale.US, trajectoryFit01.coerceIn(0f, 1f))

  fun approachAngleLog(): String =
      "%.1f".format(Locale.US, approachAngleDegrees.coerceIn(0f, 90f))

  fun approachAlignmentLog(): String =
      "%.3f".format(Locale.US, approachAlignment01.coerceIn(0f, 1f))

  fun impactEnergyLog(): String = "%.4f".format(Locale.US, impactEnergyJoules.coerceAtLeast(0f))

  fun springCompressionLog(): String =
      "%.4f".format(Locale.US, springCompressionMeters.coerceAtLeast(0f))

  fun dampingRatioLog(): String = "%.3f".format(Locale.US, dampingRatio.coerceAtLeast(0f))

  fun normalImpulseLog(): String =
      "%.4f".format(Locale.US, normalImpulseNewtonSeconds.coerceAtLeast(0f))

  fun estimatedPeakForceLog(): String =
      "%.3f".format(Locale.US, estimatedPeakForceNewtons.coerceAtLeast(0f))

  fun estimatedContactPressureLog(): String =
      "%.2f".format(Locale.US, estimatedContactPressureKilopascals.coerceAtLeast(0f))

  fun estimatedContactPatchAreaLog(): String =
      "%.6f".format(Locale.US, estimatedContactPatchAreaSquareMeters.coerceAtLeast(0f))

  fun compressionPeakLog(): String = "%.3f".format(Locale.US, compressionPeak01.coerceIn(0f, 1f))

  fun actuationTravelLog(): String =
      "%.3f".format(Locale.US, actuationTravel01.coerceIn(0f, 1f))

  fun snapTravelLog(): String = "%.3f".format(Locale.US, snapTravel01.coerceIn(0f, 1f))
}

data class ButtonPressPhysicsState(
    val phase: ButtonPressPhysicsPhase,
    val mechanics: ButtonPressMechanics,
    val shouldPreloadVisual: Boolean,
)

data class ButtonPressPhysicsConfig(
    val maxPreloadDistanceMeters: Float = 0.09f,
    val maxLateralDistanceMeters: Float = 0.19f,
    val minPreloadApproachVelocityMetersPerSecond: Float = 0.12f,
    val minImpactVelocityMetersPerSecond: Float = 0.03f,
    val maxPredictionHorizonMs: Long = 160L,
    val minPreloadConfidence01: Float = 0.55f,
    val minTrajectoryFit01: Float = 0.50f,
    val maxAllowedLateralDivergenceVelocityMetersPerSecond: Float = 0.08f,
    val minStableApproachSamples: Int = 3,
    val equivalentHandMassKg: Float = 0.20f,
    val buttonTravelMeters: Float = 0.018f,
    val virtualSpringStiffnessNewtonsPerMeter: Float = 160f,
    val virtualDampingRatio: Float = 0.55f,
    val virtualActuationForceNewtons: Float = 1.35f,
    val maxEstimatedPeakForceNewtons: Float = 24f,
    val estimatedContactPatchAreaSquareMeters: Float = 0.00065f,
    val minAcceptedCompression01: Float = 0.52f,
)

class ButtonPressPhysicsModel(
    private val config: ButtonPressPhysicsConfig = ButtonPressPhysicsConfig()
) {
  private var activePreload: ButtonPressMechanics? = null
  private var activePreloadStartElapsedRealtimeNs: Long = 0L

  fun reset() {
    activePreload = null
    activePreloadStartElapsedRealtimeNs = 0L
  }

  fun evaluate(
      samples: List<ButtonPressPhysicsSample>,
      actualContact: Boolean,
      triggerEvidence: String,
      nowElapsedRealtimeNs: Long = samples.lastOrNull()?.elapsedRealtimeNs ?: 0L,
  ): ButtonPressPhysicsState {
    val cleanSamples =
        samples
            .filter {
              it.elapsedRealtimeNs >= 0L &&
                  it.signedDistanceMeters.isFinite() &&
                  it.lateralDistanceMeters.isFinite()
            }
            .sortedBy { it.elapsedRealtimeNs }
    val motion = motionEstimate(cleanSamples)
    if (actualContact) {
      val preloaded = activePreload
      val preloadLeadMs =
          if (preloaded != null && activePreloadStartElapsedRealtimeNs > 0L) {
            ((nowElapsedRealtimeNs - activePreloadStartElapsedRealtimeNs) / 1_000_000L).coerceAtLeast(0L)
          } else {
            0L
          }
      val speed =
          motion.approachVelocityMetersPerSecond.coerceAtLeast(config.minImpactVelocityMetersPerSecond)
      val impact = impactResponse(speed = speed, preloaded = preloaded)
      val visualStartOffsetMs =
          if (preloaded != null) {
            (preloaded.compressionPeak01 * 70f + preloadLeadMs * 0.20f).roundToLong().coerceIn(0L, 72L)
          } else {
            (impact.compressionPeak01 * 34f).roundToLong().coerceIn(0L, 42L)
          }
      val mechanics =
          ButtonPressMechanics(
              predictionMode =
                  if (preloaded != null) PREDICTION_MODE_VISUAL_PRELOAD else PREDICTION_MODE_CONTACT_ONLY,
              phase = ButtonPressPhysicsPhase.IMPACT,
              impactVelocityMetersPerSecond = speed,
              predictedTimeToImpactMs = motion.predictedTimeToImpactMs,
              preloadLeadMs = preloadLeadMs,
              confidence01 = maxOf(motion.confidence01, preloaded?.confidence01 ?: 0f).coerceIn(0f, 1f),
              lateralVelocityMetersPerSecond = motion.lateralVelocityMetersPerSecond,
              predictedLateralAtImpactMeters = motion.predictedLateralAtImpactMeters,
              trajectoryFit01 = maxOf(motion.trajectoryFit01, preloaded?.trajectoryFit01 ?: 0f).coerceIn(0f, 1f),
              approachAngleDegrees = motion.approachAngleDegrees,
              approachAlignment01 = maxOf(motion.approachAlignment01, preloaded?.approachAlignment01 ?: 0f).coerceIn(0f, 1f),
              impactEnergyJoules = impact.impactEnergyJoules,
              springCompressionMeters = impact.springCompressionMeters,
              dampingRatio = impact.dampingRatio,
              normalImpulseNewtonSeconds = impact.normalImpulseNewtonSeconds,
              estimatedPeakForceNewtons = impact.estimatedPeakForceNewtons,
              estimatedContactPressureKilopascals = impact.estimatedContactPressureKilopascals,
              estimatedContactPatchAreaSquareMeters = impact.estimatedContactPatchAreaSquareMeters,
              compressionPeak01 = impact.compressionPeak01,
              actuationTravel01 = impact.actuationTravel01,
              actuationDelayMs = impact.actuationDelayMs,
              snapTravel01 = impact.snapTravel01,
              snapDurationMs = impact.snapDurationMs,
              bottomOutDelayMs = impact.bottomOutDelayMs,
              releaseDurationMs = impact.releaseDurationMs,
              visualStartOffsetMs = visualStartOffsetMs,
              triggerEvidence = triggerEvidence.ifBlank { TRIGGER_EVIDENCE_CONTACT },
          )
      return ButtonPressPhysicsState(ButtonPressPhysicsPhase.IMPACT, mechanics, shouldPreloadVisual = false)
    }

    if (motion.preloadAllowed) {
      val compression =
          (0.10f + motion.confidence01 * 0.24f + speedScore(motion.approachVelocityMetersPerSecond, 0.12f, 0.9f) * 0.08f)
              .coerceIn(0.10f, 0.42f)
      val mechanics =
          ButtonPressMechanics(
              predictionMode = PREDICTION_MODE_VISUAL_PRELOAD,
              phase = ButtonPressPhysicsPhase.PRELOAD,
              impactVelocityMetersPerSecond = motion.approachVelocityMetersPerSecond,
              predictedTimeToImpactMs = motion.predictedTimeToImpactMs,
              preloadLeadMs = 0L,
              confidence01 = motion.confidence01,
              lateralVelocityMetersPerSecond = motion.lateralVelocityMetersPerSecond,
              predictedLateralAtImpactMeters = motion.predictedLateralAtImpactMeters,
              trajectoryFit01 = motion.trajectoryFit01,
              approachAngleDegrees = motion.approachAngleDegrees,
              approachAlignment01 = motion.approachAlignment01,
              dampingRatio = config.virtualDampingRatio,
              compressionPeak01 = compression,
              bottomOutDelayMs =
                  lerpLong(108L, 38L, speedScore(motion.approachVelocityMetersPerSecond, 0.04f, 1.10f)),
              releaseDurationMs =
                  lerpLong(180L, 112L, speedScore(motion.approachVelocityMetersPerSecond, 0.04f, 1.10f)),
              visualStartOffsetMs = 0L,
              triggerEvidence = triggerEvidence.ifBlank { TRIGGER_EVIDENCE_PREDICTED_APPROACH },
          )
      if (activePreload == null) {
        activePreloadStartElapsedRealtimeNs = nowElapsedRealtimeNs
      }
      activePreload = mechanics
      return ButtonPressPhysicsState(ButtonPressPhysicsPhase.PRELOAD, mechanics, shouldPreloadVisual = true)
    }

    val phase =
        if (activePreload != null) {
          ButtonPressPhysicsPhase.RELEASE
        } else {
          ButtonPressPhysicsPhase.IDLE
        }
    reset()
    return ButtonPressPhysicsState(phase, ButtonPressMechanics(phase = phase), shouldPreloadVisual = false)
  }

  fun phaseAt(elapsedSinceImpactMs: Long, mechanics: ButtonPressMechanics): ButtonPressPhysicsPhase {
    if (elapsedSinceImpactMs < 0L) {
      return ButtonPressPhysicsPhase.IDLE
    }
    if (elapsedSinceImpactMs < mechanics.bottomOutDelayMs.coerceAtLeast(1L)) {
      return ButtonPressPhysicsPhase.IMPACT
    }
    val releaseStartMs = mechanics.bottomOutDelayMs
    val releaseEndMs = releaseStartMs + mechanics.releaseDurationMs.coerceAtLeast(1L)
    return when {
      elapsedSinceImpactMs < releaseStartMs + 32L -> ButtonPressPhysicsPhase.BOTTOM_OUT
      elapsedSinceImpactMs < releaseEndMs -> ButtonPressPhysicsPhase.RELEASE
      else -> ButtonPressPhysicsPhase.IDLE
    }
  }

  private fun motionEstimate(samples: List<ButtonPressPhysicsSample>): MotionEstimate {
    if (samples.size < config.minStableApproachSamples) {
      return MotionEstimate()
    }
    val recent = samples.takeLast(config.minStableApproachSamples.coerceAtLeast(2))
    val first = recent.first()
    val last = recent.last()
    val dtSec = (last.elapsedRealtimeNs - first.elapsedRealtimeNs).toFloat() / 1_000_000_000f
    if (dtSec <= 0f) {
      return MotionEstimate()
    }
    val normalVelocity = (last.signedDistanceMeters - first.signedDistanceMeters) / dtSec
    val approachVelocity = (-normalVelocity).coerceAtLeast(0f)
    val approachingPairs =
        recent.zipWithNext().count { (a, b) -> b.signedDistanceMeters < a.signedDistanceMeters - 0.0015f }
    val stableApproach = approachingPairs >= config.minStableApproachSamples - 1
    val distance = last.signedDistanceMeters.coerceAtLeast(0f)
    val lateral = last.lateralDistanceMeters.coerceAtLeast(0f)
    val lateralVelocity = (last.lateralDistanceMeters - first.lateralDistanceMeters) / dtSec
    val motionMagnitude = sqrt(approachVelocity * approachVelocity + lateralVelocity * lateralVelocity)
    val approachAngleDegrees =
        if (motionMagnitude > 0.0001f) {
          (atan2(abs(lateralVelocity), approachVelocity.coerceAtLeast(0.0001f)) * 180f / PI.toFloat())
              .coerceIn(0f, 90f)
        } else {
          0f
        }
    val predictedTimeToImpactMs =
        if (approachVelocity >= config.minImpactVelocityMetersPerSecond) {
          (distance / approachVelocity * 1000f).roundToLong().coerceAtLeast(0L)
        } else {
          -1L
        }
    val predictedLateralAtImpact =
        if (predictedTimeToImpactMs >= 0L) {
          (lateral + lateralVelocity * predictedTimeToImpactMs.toFloat() / 1000f).coerceAtLeast(0f)
        } else {
          lateral
        }
    val distanceScore = (1f - distance / config.maxPreloadDistanceMeters).coerceIn(0f, 1f)
    val lateralScore =
        (1f - maxOf(lateral, predictedLateralAtImpact) / config.maxLateralDistanceMeters).coerceIn(0f, 1f)
    val targetMagnitude = sqrt(distance * distance + lateral * lateral)
    val lateralClosingVelocity = (-lateralVelocity).coerceAtLeast(0f)
    val approachAlignment =
        if (motionMagnitude > 0.0001f && targetMagnitude > 0.0001f) {
          ((approachVelocity * distance + lateralClosingVelocity * lateral) / (motionMagnitude * targetMagnitude))
              .coerceIn(0f, 1f)
        } else if (approachVelocity > 0f && lateral <= config.maxLateralDistanceMeters * 0.25f) {
          1f
        } else {
          0f
        }
    val speedScore = speedScore(approachVelocity, config.minPreloadApproachVelocityMetersPerSecond, 0.95f)
    val horizonScore =
        if (predictedTimeToImpactMs in 0..config.maxPredictionHorizonMs) {
          (1f - predictedTimeToImpactMs.toFloat() / config.maxPredictionHorizonMs.toFloat()).coerceIn(0f, 1f)
        } else {
          0f
        }
    val stabilityScore =
        (approachingPairs.toFloat() / (config.minStableApproachSamples - 1).coerceAtLeast(1).toFloat())
            .coerceIn(0f, 1f)
    val lateralConvergingPairs =
        recent.zipWithNext().count { (a, b) -> b.lateralDistanceMeters <= a.lateralDistanceMeters + 0.004f }
    val lateralConvergenceScore =
        (lateralConvergingPairs.toFloat() / (config.minStableApproachSamples - 1).coerceAtLeast(1).toFloat())
            .coerceIn(0f, 1f)
    val lateralVelocityScore =
        when {
          lateralVelocity <= -0.20f -> 1f
          lateralVelocity <= config.maxAllowedLateralDivergenceVelocityMetersPerSecond ->
              (1f -
                      (lateralVelocity + 0.20f) /
                          (config.maxAllowedLateralDivergenceVelocityMetersPerSecond + 0.20f) *
                          0.30f)
                  .coerceIn(0.70f, 1f)
          else ->
              (1f -
                      (lateralVelocity - config.maxAllowedLateralDivergenceVelocityMetersPerSecond) /
                          0.24f)
                  .coerceIn(0f, 0.70f)
        }
    val trajectoryFit =
        (lateralScore * 0.36f +
                lateralConvergenceScore * 0.22f +
                lateralVelocityScore * 0.18f +
                stabilityScore * 0.10f +
                approachAlignment * 0.14f)
            .coerceIn(0f, 1f)
    val confidence =
        (distanceScore * 0.24f +
            lateralScore * 0.18f +
            speedScore * 0.24f +
            horizonScore * 0.22f +
            stabilityScore * 0.07f +
            trajectoryFit * 0.03f +
            approachAlignment * 0.02f)
            .coerceIn(0f, 1f)
    val allowed =
        stableApproach &&
            distance in 0f..config.maxPreloadDistanceMeters &&
            lateral <= config.maxLateralDistanceMeters &&
            predictedLateralAtImpact <= config.maxLateralDistanceMeters &&
            lateralVelocity <= config.maxAllowedLateralDivergenceVelocityMetersPerSecond &&
            trajectoryFit >= config.minTrajectoryFit01 &&
            approachVelocity >= config.minPreloadApproachVelocityMetersPerSecond &&
            predictedTimeToImpactMs in 0..config.maxPredictionHorizonMs &&
            confidence >= config.minPreloadConfidence01
    return MotionEstimate(
        approachVelocityMetersPerSecond = approachVelocity,
        predictedTimeToImpactMs = predictedTimeToImpactMs,
        confidence01 = confidence,
        lateralVelocityMetersPerSecond = lateralVelocity,
        predictedLateralAtImpactMeters = predictedLateralAtImpact,
        trajectoryFit01 = trajectoryFit,
        approachAngleDegrees = approachAngleDegrees,
        approachAlignment01 = approachAlignment,
        preloadAllowed = allowed,
    )
  }

  private data class MotionEstimate(
      val approachVelocityMetersPerSecond: Float = 0f,
      val predictedTimeToImpactMs: Long = -1L,
      val confidence01: Float = 0f,
      val lateralVelocityMetersPerSecond: Float = 0f,
      val predictedLateralAtImpactMeters: Float = 0f,
      val trajectoryFit01: Float = 0f,
      val approachAngleDegrees: Float = 0f,
      val approachAlignment01: Float = 0f,
      val preloadAllowed: Boolean = false,
  )

  private data class ImpactResponse(
      val impactEnergyJoules: Float,
      val springCompressionMeters: Float,
      val dampingRatio: Float,
      val normalImpulseNewtonSeconds: Float,
      val estimatedPeakForceNewtons: Float,
      val estimatedContactPressureKilopascals: Float,
      val estimatedContactPatchAreaSquareMeters: Float,
      val compressionPeak01: Float,
      val actuationTravel01: Float,
      val actuationDelayMs: Long,
      val snapTravel01: Float,
      val snapDurationMs: Long,
      val bottomOutDelayMs: Long,
      val releaseDurationMs: Long,
  )

  private fun impactResponse(speed: Float, preloaded: ButtonPressMechanics?): ImpactResponse {
    val massKg = config.equivalentHandMassKg.coerceAtLeast(0.001f)
    val stiffness = config.virtualSpringStiffnessNewtonsPerMeter.coerceAtLeast(1f)
    val travel = config.buttonTravelMeters.coerceAtLeast(0.001f)
    val dampingRatio = config.virtualDampingRatio.coerceIn(0.05f, 0.95f)
    val kineticEnergy = 0.5f * massKg * speed * speed
    val undampedCompression = sqrt((2f * kineticEnergy / stiffness).coerceAtLeast(0f))
    val springCompression = undampedCompression.coerceIn(0f, travel)
    val springCompression01 = (undampedCompression / travel).coerceIn(0f, 1f)
      val preloadFloor =
        ((preloaded?.compressionPeak01 ?: 0f) + if (preloaded != null) 0.22f else 0f).coerceIn(0f, 1f)
    val compression =
        maxOf(config.minAcceptedCompression01, springCompression01, preloadFloor).coerceIn(0.45f, 1f)
    val naturalOmega = sqrt(stiffness / massKg)
    val dampingCoefficient = 2f * dampingRatio * sqrt(stiffness * massKg)
    val normalImpulse = massKg * speed.coerceAtLeast(0f)
    val springForce = stiffness * springCompression
    val dampingForce = dampingCoefficient * speed.coerceAtLeast(0f)
    val peakForce =
        maxOf(config.virtualActuationForceNewtons, springForce + dampingForce)
            .coerceIn(0f, config.maxEstimatedPeakForceNewtons.coerceAtLeast(1f))
    val contactPatchArea = config.estimatedContactPatchAreaSquareMeters.coerceAtLeast(0.00005f)
    val contactPressureKPa = peakForce / contactPatchArea / 1000f
    val dampedOmega = (naturalOmega * sqrt((1f - dampingRatio * dampingRatio).coerceAtLeast(0.05f))).coerceAtLeast(1f)
    val quarterCycleMs = (PI.toFloat() / (2f * dampedOmega) * 1000f).roundToLong().coerceIn(36L, 96L)
    val bottomOutDelayMs = lerpLong(112L, quarterCycleMs, compression)
    val actuationTravel01 =
        (config.virtualActuationForceNewtons / (stiffness * travel)).coerceIn(0.30f, 0.72f)
    val preloadedCompression = preloaded?.compressionPeak01?.coerceIn(0f, 0.42f) ?: 0f
    val remainingToActuation01 = (actuationTravel01 - preloadedCompression).coerceAtLeast(0f)
    val remainingToBottom01 = (compression - preloadedCompression).coerceAtLeast(0.08f)
    val actuationDelayMs =
        (bottomOutDelayMs.toFloat() * remainingToActuation01 / remainingToBottom01)
            .roundToLong()
            .coerceIn(0L, (bottomOutDelayMs - 8L).coerceAtLeast(0L))
    val snapTravel01 = (compression - actuationTravel01).coerceIn(0f, 0.45f)
    val snapDurationMs =
        lerpLong(24L, 10L, speedScore(speed, config.minImpactVelocityMetersPerSecond, 1.10f))
    val releaseDurationMs =
        (4f / (dampingRatio * naturalOmega) * 1000f)
            .roundToLong()
            .coerceIn(112L, 190L)
    return ImpactResponse(
        impactEnergyJoules = kineticEnergy,
        springCompressionMeters = springCompression,
        dampingRatio = dampingRatio,
        normalImpulseNewtonSeconds = normalImpulse,
        estimatedPeakForceNewtons = peakForce,
        estimatedContactPressureKilopascals = contactPressureKPa,
        estimatedContactPatchAreaSquareMeters = contactPatchArea,
        compressionPeak01 = compression,
        actuationTravel01 = actuationTravel01,
        actuationDelayMs = actuationDelayMs,
        snapTravel01 = snapTravel01,
        snapDurationMs = snapDurationMs,
        bottomOutDelayMs = bottomOutDelayMs,
        releaseDurationMs = releaseDurationMs,
    )
  }

  private fun speedScore(value: Float, min: Float, max: Float): Float {
    if (max <= min) {
      return 0f
    }
    return ((value - min) / (max - min)).coerceIn(0f, 1f)
  }

  private fun lerpLong(slow: Long, fast: Long, amount01: Float): Long {
    return (slow + (fast - slow) * amount01.coerceIn(0f, 1f)).roundToLong()
  }

  companion object {
    const val PREDICTION_MODE_NONE = "none"
    const val PREDICTION_MODE_CONTACT_ONLY = "contact_only"
    const val PREDICTION_MODE_VISUAL_PRELOAD = "visual_preload"
    const val TRIGGER_EVIDENCE_NONE = "none"
    const val TRIGGER_EVIDENCE_CONTACT = "contact"
    const val TRIGGER_EVIDENCE_PREDICTED_APPROACH = "predicted_approach"
  }
}
