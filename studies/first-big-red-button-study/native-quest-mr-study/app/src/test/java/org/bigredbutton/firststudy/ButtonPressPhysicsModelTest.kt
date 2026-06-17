package org.bigredbutton.firststudy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ButtonPressPhysicsModelTest {
  @Test
  fun stableApproachTriggersVisualPreloadOnly() {
    val model = ButtonPressPhysicsModel()
    val state =
        model.evaluate(
            samples =
                listOf(
                    sample(0, distance = 0.080f, lateral = 0.050f),
                    sample(50, distance = 0.050f, lateral = 0.052f),
                    sample(100, distance = 0.020f, lateral = 0.054f),
                ),
            actualContact = false,
            triggerEvidence = "predicted_approach",
        )

    assertEquals(ButtonPressPhysicsPhase.PRELOAD, state.phase)
    assertTrue(state.shouldPreloadVisual)
    assertEquals(ButtonPressPhysicsModel.PREDICTION_MODE_VISUAL_PRELOAD, state.mechanics.predictionMode)
    assertTrue(state.mechanics.confidence01 >= 0.55f)
    assertTrue(state.mechanics.trajectoryFit01 >= 0.50f)
    assertTrue(state.mechanics.compressionPeak01 in 0.10f..0.42f)
    assertEquals(0f, state.mechanics.actuationTravel01, 0.001f)
    assertEquals(0f, state.mechanics.snapTravel01, 0.001f)
    assertEquals(0L, state.mechanics.snapDurationMs)
  }

  @Test
  fun convergingArcApproachTriggersPreload() {
    val model = ButtonPressPhysicsModel()
    val state =
        model.evaluate(
            samples =
                listOf(
                    sample(0, distance = 0.086f, lateral = 0.170f),
                    sample(50, distance = 0.052f, lateral = 0.118f),
                    sample(100, distance = 0.018f, lateral = 0.066f),
                ),
            actualContact = false,
            triggerEvidence = "predicted_approach",
        )

    assertEquals(ButtonPressPhysicsPhase.PRELOAD, state.phase)
    assertTrue(state.shouldPreloadVisual)
    assertTrue(state.mechanics.lateralVelocityMetersPerSecond < 0f)
    assertTrue(state.mechanics.predictedLateralAtImpactMeters <= 0.066f)
    assertTrue(state.mechanics.approachAngleDegrees > 40f)
    assertTrue(state.mechanics.approachAlignment01 >= 0.85f)
    assertTrue(state.mechanics.trajectoryFit01 >= 0.70f)
  }

  @Test
  fun divergingGlancingApproachDoesNotPreload() {
    val model = ButtonPressPhysicsModel()
    val state =
        model.evaluate(
            samples =
                listOf(
                    sample(0, distance = 0.086f, lateral = 0.070f),
                    sample(50, distance = 0.052f, lateral = 0.118f),
                    sample(100, distance = 0.018f, lateral = 0.166f),
                ),
            actualContact = false,
            triggerEvidence = "predicted_approach",
        )

    assertEquals(ButtonPressPhysicsPhase.IDLE, state.phase)
    assertFalse(state.shouldPreloadVisual)
    assertTrue(state.mechanics.approachAlignment01 <= 0.01f)
  }

  @Test
  fun straightApproachHasSmallAngleAndUsableAlignment() {
    val state =
        ButtonPressPhysicsModel()
            .evaluate(
                samples =
                    listOf(
                        sample(0, distance = 0.080f, lateral = 0.030f),
                        sample(50, distance = 0.050f, lateral = 0.030f),
                        sample(100, distance = 0.020f, lateral = 0.030f),
                    ),
                actualContact = false,
                triggerEvidence = "predicted_approach",
            )

    assertEquals(ButtonPressPhysicsPhase.PRELOAD, state.phase)
    assertTrue(state.mechanics.approachAngleDegrees < 5f)
    assertTrue(state.mechanics.approachAlignment01 > 0.50f)
  }

  @Test
  fun lateralMissDoesNotPreload() {
    val model = ButtonPressPhysicsModel()
    val state =
        model.evaluate(
            samples =
                listOf(
                    sample(0, distance = 0.080f, lateral = 0.240f),
                    sample(50, distance = 0.050f, lateral = 0.245f),
                    sample(100, distance = 0.020f, lateral = 0.250f),
                ),
            actualContact = false,
            triggerEvidence = "predicted_approach",
        )

    assertEquals(ButtonPressPhysicsPhase.IDLE, state.phase)
    assertFalse(state.shouldPreloadVisual)
  }

  @Test
  fun slowHoverDoesNotPreload() {
    val model = ButtonPressPhysicsModel()
    val state =
        model.evaluate(
            samples =
                listOf(
                    sample(0, distance = 0.050f, lateral = 0.030f),
                    sample(100, distance = 0.049f, lateral = 0.031f),
                    sample(200, distance = 0.048f, lateral = 0.030f),
                ),
            actualContact = false,
            triggerEvidence = "predicted_approach",
        )

    assertEquals(ButtonPressPhysicsPhase.IDLE, state.phase)
    assertFalse(state.shouldPreloadVisual)
  }

  @Test
  fun actualContactCreatesAcceptedMechanicsPayloadAfterPreload() {
    val model = ButtonPressPhysicsModel()
    model.evaluate(
        samples =
            listOf(
                sample(0, distance = 0.080f, lateral = 0.030f),
                sample(50, distance = 0.050f, lateral = 0.031f),
                sample(100, distance = 0.020f, lateral = 0.032f),
            ),
        actualContact = false,
        triggerEvidence = "predicted_approach",
    )

    val accepted =
        model.evaluate(
            samples =
                listOf(
                    sample(50, distance = 0.050f, lateral = 0.031f),
                    sample(100, distance = 0.020f, lateral = 0.032f),
                    sample(130, distance = 0.000f, lateral = 0.033f),
                ),
            actualContact = true,
            triggerEvidence = "hand_contact:collider_hover_contact_actuate",
            nowElapsedRealtimeNs = 130_000_000L,
        )

    assertEquals(ButtonPressPhysicsPhase.IMPACT, accepted.phase)
    assertFalse(accepted.shouldPreloadVisual)
    assertEquals(ButtonPressPhysicsModel.PREDICTION_MODE_VISUAL_PRELOAD, accepted.mechanics.predictionMode)
    assertEquals("hand_contact:collider_hover_contact_actuate", accepted.mechanics.triggerEvidence)
    assertTrue(accepted.mechanics.preloadLeadMs > 0L)
    assertTrue(accepted.mechanics.trajectoryFit01 >= 0.50f)
    assertTrue(accepted.mechanics.approachAngleDegrees > 0f)
    assertTrue(accepted.mechanics.approachAlignment01 > 0f)
    assertTrue(accepted.mechanics.impactEnergyJoules > 0f)
    assertTrue(accepted.mechanics.springCompressionMeters > 0f)
    assertTrue(accepted.mechanics.dampingRatio > 0f)
    assertTrue(accepted.mechanics.normalImpulseNewtonSeconds > 0f)
    assertTrue(accepted.mechanics.estimatedPeakForceNewtons > 0f)
    assertTrue(accepted.mechanics.estimatedContactPressureKilopascals > 0f)
    assertTrue(accepted.mechanics.estimatedContactPatchAreaSquareMeters > 0f)
    assertTrue(accepted.mechanics.compressionPeak01 > 0.55f)
    assertTrue(accepted.mechanics.actuationTravel01 in 0.30f..0.72f)
    assertTrue(accepted.mechanics.actuationDelayMs in 0L until accepted.mechanics.bottomOutDelayMs)
    assertTrue(accepted.mechanics.snapTravel01 > 0f)
    assertTrue(accepted.mechanics.snapDurationMs in 10L..24L)
  }

  @Test
  fun impactVelocityChangesBottomOutTimingAndDepth() {
    val slow =
        ButtonPressPhysicsModel()
            .evaluate(
                samples =
                    listOf(
                        sample(0, distance = 0.090f, lateral = 0.030f),
                        sample(100, distance = 0.085f, lateral = 0.030f),
                        sample(200, distance = 0.080f, lateral = 0.030f),
                    ),
                actualContact = true,
                triggerEvidence = "hand_contact:slow_contact",
            )
            .mechanics
    val fast =
        ButtonPressPhysicsModel()
            .evaluate(
                samples =
                    listOf(
                        sample(0, distance = 0.090f, lateral = 0.030f),
                        sample(50, distance = 0.040f, lateral = 0.030f),
                        sample(100, distance = 0.000f, lateral = 0.030f),
                    ),
                actualContact = true,
                triggerEvidence = "hand_contact:fast_contact",
            )
            .mechanics

    assertTrue(fast.impactVelocityMetersPerSecond > slow.impactVelocityMetersPerSecond)
    assertTrue(fast.impactEnergyJoules > slow.impactEnergyJoules)
    assertTrue(fast.springCompressionMeters > slow.springCompressionMeters)
    assertTrue(fast.normalImpulseNewtonSeconds > slow.normalImpulseNewtonSeconds)
    assertTrue(fast.estimatedPeakForceNewtons > slow.estimatedPeakForceNewtons)
    assertTrue(fast.estimatedContactPressureKilopascals > slow.estimatedContactPressureKilopascals)
    assertTrue(fast.snapTravel01 > slow.snapTravel01)
    assertTrue(fast.snapDurationMs <= slow.snapDurationMs)
    assertTrue(fast.bottomOutDelayMs < slow.bottomOutDelayMs)
    assertTrue(fast.compressionPeak01 > slow.compressionPeak01)
  }

  @Test
  fun impactEnergyFollowsVelocitySquared() {
    val model = ButtonPressPhysicsModel()
    val slow =
        model.evaluate(
            samples =
                listOf(
                    sample(0, distance = 0.080f, lateral = 0.030f),
                    sample(100, distance = 0.050f, lateral = 0.030f),
                    sample(200, distance = 0.020f, lateral = 0.030f),
                ),
            actualContact = true,
            triggerEvidence = "hand_contact:slow_contact",
        )
    val fast =
        ButtonPressPhysicsModel()
            .evaluate(
                samples =
                    listOf(
                        sample(0, distance = 0.080f, lateral = 0.030f),
                        sample(50, distance = 0.030f, lateral = 0.030f),
                        sample(100, distance = 0.000f, lateral = 0.030f),
                    ),
                actualContact = true,
                triggerEvidence = "hand_contact:fast_contact",
            )

    assertTrue(fast.mechanics.impactEnergyJoules > slow.mechanics.impactEnergyJoules * 4f)
    assertTrue(fast.mechanics.springCompressionMeters > slow.mechanics.springCompressionMeters)
    assertTrue(fast.mechanics.dampingRatio > 0f)
    assertTrue(fast.mechanics.snapTravel01 > slow.mechanics.snapTravel01)
  }

  @Test
  fun acceptedSnapIsDerivedFromActuationTravelNotPredictivePreloadAlone() {
    val model = ButtonPressPhysicsModel()
    val preload =
        model.evaluate(
            samples =
                listOf(
                    sample(0, distance = 0.080f, lateral = 0.030f),
                    sample(50, distance = 0.050f, lateral = 0.030f),
                    sample(100, distance = 0.020f, lateral = 0.030f),
                ),
            actualContact = false,
            triggerEvidence = "predicted_approach",
        )

    assertEquals(ButtonPressPhysicsPhase.PRELOAD, preload.phase)
    assertEquals(0f, preload.mechanics.snapTravel01, 0.001f)

    val accepted =
        model.evaluate(
            samples =
                listOf(
                    sample(40, distance = 0.052f, lateral = 0.030f),
                    sample(80, distance = 0.024f, lateral = 0.030f),
                    sample(120, distance = 0.000f, lateral = 0.030f),
                ),
            actualContact = true,
            triggerEvidence = "hand_contact:snap_contact",
            nowElapsedRealtimeNs = 120_000_000L,
        )

    assertEquals(ButtonPressPhysicsPhase.IMPACT, accepted.phase)
    assertTrue(accepted.mechanics.snapTravel01 > 0f)
    assertTrue(accepted.mechanics.actuationDelayMs <= accepted.mechanics.bottomOutDelayMs)
  }

  @Test
  fun estimatedImpulseForceAndPressureFollowImpactSpeed() {
    val slow =
        ButtonPressPhysicsModel()
            .evaluate(
                samples =
                    listOf(
                        sample(0, distance = 0.060f, lateral = 0.030f),
                        sample(100, distance = 0.045f, lateral = 0.030f),
                        sample(200, distance = 0.030f, lateral = 0.030f),
                    ),
                actualContact = true,
                triggerEvidence = "hand_contact:slow_force",
            )
            .mechanics
    val fast =
        ButtonPressPhysicsModel()
            .evaluate(
                samples =
                    listOf(
                        sample(0, distance = 0.060f, lateral = 0.030f),
                        sample(40, distance = 0.030f, lateral = 0.030f),
                        sample(80, distance = 0.000f, lateral = 0.030f),
                    ),
                actualContact = true,
                triggerEvidence = "hand_contact:fast_force",
            )
            .mechanics

    assertTrue(fast.normalImpulseNewtonSeconds > slow.normalImpulseNewtonSeconds)
    assertTrue(fast.estimatedPeakForceNewtons > slow.estimatedPeakForceNewtons)
    assertTrue(fast.estimatedContactPressureKilopascals > slow.estimatedContactPressureKilopascals)
    assertEquals(
        slow.estimatedContactPatchAreaSquareMeters,
        fast.estimatedContactPatchAreaSquareMeters,
        0.000001f,
    )
  }

  @Test
  fun phaseTimelineMovesFromImpactToBottomOutToRelease() {
    val model = ButtonPressPhysicsModel()
    val mechanics =
        ButtonPressMechanics(
            phase = ButtonPressPhysicsPhase.IMPACT,
            bottomOutDelayMs = 60L,
            releaseDurationMs = 120L,
        )

    assertEquals(ButtonPressPhysicsPhase.IMPACT, model.phaseAt(20L, mechanics))
    assertEquals(ButtonPressPhysicsPhase.BOTTOM_OUT, model.phaseAt(70L, mechanics))
    assertEquals(ButtonPressPhysicsPhase.RELEASE, model.phaseAt(120L, mechanics))
    assertEquals(ButtonPressPhysicsPhase.IDLE, model.phaseAt(200L, mechanics))
  }

  private fun sample(ms: Long, distance: Float, lateral: Float): ButtonPressPhysicsSample =
      ButtonPressPhysicsSample(
          elapsedRealtimeNs = ms * 1_000_000L,
          signedDistanceMeters = distance,
          lateralDistanceMeters = lateral,
      )
}
