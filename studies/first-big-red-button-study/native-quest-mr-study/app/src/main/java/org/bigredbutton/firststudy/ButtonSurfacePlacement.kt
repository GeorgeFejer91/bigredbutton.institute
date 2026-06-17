package org.bigredbutton.firststudy

import java.util.Locale
import kotlin.math.abs

internal fun scoreButtonSupportSurfaceCandidate(
    surfaceName: String,
    surfaceType: String,
    centerX: Float,
    centerZ: Float,
    supportSurfaceY: Float,
    extentX: Float,
    extentY: Float,
    extentZ: Float,
    reachTargetZ: Float,
    minSupportY: Float,
    maxSupportY: Float,
    reachMargin: Float,
    minHalfExtent: Float,
): Float? {
  val semantic = "$surfaceName $surfaceType".lowercase(Locale.US)
  if (semantic.contains("wall") || semantic.contains("ceiling") || semantic.contains("floor")) {
    return null
  }
  if (supportSurfaceY < minSupportY || supportSurfaceY > maxSupportY) {
    return null
  }

  val reachHalfWidth = maxOf(abs(extentX), abs(extentY), minHalfExtent)
  val reachHalfDepth = maxOf(abs(extentZ), abs(extentX), abs(extentY), minHalfExtent)
  val coversArmReachTarget =
      abs(centerX) <= reachHalfWidth + reachMargin &&
          abs(centerZ - reachTargetZ) <= reachHalfDepth + reachMargin
  if (!coversArmReachTarget) {
    return null
  }

  val preferredSurface =
      listOf("table", "desk", "counter", "surface", "platform").any { semantic.contains(it) }
  return (if (preferredSurface) 1000f else 500f) +
      reachHalfWidth * reachHalfDepth -
      abs(centerX) -
      abs(centerZ - reachTargetZ)
}
