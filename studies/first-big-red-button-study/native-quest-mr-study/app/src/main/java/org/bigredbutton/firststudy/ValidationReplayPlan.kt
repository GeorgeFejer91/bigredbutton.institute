package org.bigredbutton.firststudy

data class PostConditionReplayPlan(
    val conditionNumber: Int,
    val pictographicDirections: List<String>,
    val rednessReplay: RednessReplay,
    val presenceDirection: String,
    val lostOpportunityDirections: List<String>,
)

data class RednessReplay(
    val startVas0To100: Float?,
    val startLikert1To7: Int?,
    val conversionReason: String = "fast_controller_replay",
)

object ValidationReplayPlan {
  fun postCondition(conditionNumber: Int): PostConditionReplayPlan {
    return when (conditionNumber) {
      1 ->
          PostConditionReplayPlan(
              conditionNumber = 1,
              pictographicDirections = listOf("left", "up", "right", "down"),
              rednessReplay = RednessReplay(startVas0To100 = 60f, startLikert1To7 = null),
              presenceDirection = "right",
              lostOpportunityDirections = listOf("right", "right", "down"),
          )
      2 ->
          PostConditionReplayPlan(
              conditionNumber = 2,
              pictographicDirections = listOf("right", "right", "up", "up"),
              rednessReplay = RednessReplay(startVas0To100 = null, startLikert1To7 = 5),
              presenceDirection = "left",
              lostOpportunityDirections = listOf("left", "up", "right"),
          )
      else -> error("Unsupported post-condition replay condition: $conditionNumber")
    }
  }
}
