package org.bigredbutton.firststudy

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ButtonSurfacePlacementTest {
  @Test
  fun tableAtArmReachIsAcceptedAndPreferred() {
    val tableScore =
        scoreButtonSupportSurfaceCandidate(
            surfaceName = "Dining Table",
            surfaceType = "TABLE",
            centerX = 0.02f,
            centerZ = REACH_Z,
            supportSurfaceY = 0.76f,
            extentX = 0.42f,
            extentY = 0.03f,
            extentZ = 0.36f,
            reachTargetZ = REACH_Z,
            minSupportY = MIN_Y,
            maxSupportY = MAX_Y,
            reachMargin = REACH_MARGIN,
            minHalfExtent = MIN_HALF_EXTENT,
        )
    val genericScore =
        scoreButtonSupportSurfaceCandidate(
            surfaceName = "Unknown horizontal plane",
            surfaceType = "plane",
            centerX = 0.02f,
            centerZ = REACH_Z,
            supportSurfaceY = 0.76f,
            extentX = 0.42f,
            extentY = 0.03f,
            extentZ = 0.36f,
            reachTargetZ = REACH_Z,
            minSupportY = MIN_Y,
            maxSupportY = MAX_Y,
            reachMargin = REACH_MARGIN,
            minHalfExtent = MIN_HALF_EXTENT,
        )

    assertNotNull(tableScore)
    assertNotNull(genericScore)
    assertTrue(tableScore!! > genericScore!!)
  }

  @Test
  fun floorWallAndOutOfReachPlanesAreRejected() {
    assertNull(
        scoreButtonSupportSurfaceCandidate(
            surfaceName = "Floor",
            surfaceType = "FLOOR",
            centerX = 0f,
            centerZ = REACH_Z,
            supportSurfaceY = 0.02f,
            extentX = 2f,
            extentY = 0.01f,
            extentZ = 2f,
            reachTargetZ = REACH_Z,
            minSupportY = MIN_Y,
            maxSupportY = MAX_Y,
            reachMargin = REACH_MARGIN,
            minHalfExtent = MIN_HALF_EXTENT,
        )
    )
    assertNull(
        scoreButtonSupportSurfaceCandidate(
            surfaceName = "Front Wall",
            surfaceType = "WALL",
            centerX = 0f,
            centerZ = REACH_Z,
            supportSurfaceY = 0.85f,
            extentX = 2f,
            extentY = 1f,
            extentZ = 0.02f,
            reachTargetZ = REACH_Z,
            minSupportY = MIN_Y,
            maxSupportY = MAX_Y,
            reachMargin = REACH_MARGIN,
            minHalfExtent = MIN_HALF_EXTENT,
        )
    )
    assertNull(
        scoreButtonSupportSurfaceCandidate(
            surfaceName = "Side table",
            surfaceType = "TABLE",
            centerX = 0.9f,
            centerZ = REACH_Z,
            supportSurfaceY = 0.76f,
            extentX = 0.18f,
            extentY = 0.03f,
            extentZ = 0.18f,
            reachTargetZ = REACH_Z,
            minSupportY = MIN_Y,
            maxSupportY = MAX_Y,
            reachMargin = REACH_MARGIN,
            minHalfExtent = MIN_HALF_EXTENT,
        )
    )
  }

  private companion object {
    const val REACH_Z = 0.48f
    const val MIN_Y = 0.62f
    const val MAX_Y = 1.02f
    const val REACH_MARGIN = 0.08f
    const val MIN_HALF_EXTENT = 0.16f
  }
}
