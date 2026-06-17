package org.bigredbutton.firststudy

/**
 * Pure transition model for the participant-facing study sequence.
 *
 * The Activity still owns Compose panels, audio, and headset hardware. This controller owns the
 * expected order and makes validation/replay logic easier to test without Android runtime state.
 */
class StudyFlowController(initialState: StudyFlowState = StudyFlowState()) {
  var state: StudyFlowState = initialState
    private set

  fun handle(event: StudyFlowEvent): StudyFlowTransition {
    val transition = transition(state, event)
    state = transition.nextState
    return transition
  }

  fun armDelayedCallback(expectedStageId: String): StudyFlowDelayToken {
    val token = state.nextDelayToken + 1
    state =
        state.copy(
            activeDelayToken = token,
            activeDelayStageId = expectedStageId,
            nextDelayToken = token,
        )
    return StudyFlowDelayToken(token, expectedStageId)
  }

  fun handleDelayed(token: StudyFlowDelayToken, event: StudyFlowEvent): StudyFlowTransition {
    if (state.activeDelayToken != token.value ||
        state.activeDelayStageId != token.expectedStageId ||
        state.stageId != token.expectedStageId) {
      return StudyFlowTransition(state, StudyFlowCommand.IgnoreStaleDelayedCallback)
    }
    return handle(event)
  }

  private fun transition(
      current: StudyFlowState,
      event: StudyFlowEvent,
  ): StudyFlowTransition {
    return when (event) {
      StudyFlowEvent.LanguageSelected ->
          requireStage(current, LANGUAGE_SELECTION) {
            current.copy(stageId = CONSENT_DEMOGRAPHICS) to
                StudyFlowCommand.ShowStage(CONSENT_DEMOGRAPHICS)
          }
      StudyFlowEvent.DemographicsSubmitted ->
          requireStage(current, CONSENT_DEMOGRAPHICS) {
            current.copy(stageId = PRIOR_BIG_RED_BUTTON_EXPERIENCE) to
                StudyFlowCommand.ShowPriorBigRedButtonExperience
          }
      StudyFlowEvent.PriorBigRedButtonExperienceSubmitted ->
          requireStage(current, PRIOR_BIG_RED_BUTTON_EXPERIENCE) {
            current.copy(
                stageId = CONDITION_1,
                activeCondition = 1,
                priorBigRedButtonPromptCount = current.priorBigRedButtonPromptCount + 1,
            ) to StudyFlowCommand.BeginCondition(1)
          }
      is StudyFlowEvent.ConditionStarted ->
          if (event.conditionNumber in 1..2) {
            transitionToCondition(current, event.conditionNumber)
          } else {
            StudyFlowTransition(current, StudyFlowCommand.IgnoreInvalidEvent)
          }
      is StudyFlowEvent.ConditionEnded ->
          if (current.activeCondition == event.conditionNumber &&
              current.stageId == conditionStageId(event.conditionNumber)) {
            current.copy(stageId = postConditionStageId(event.conditionNumber, "pictographic")) to
                StudyFlowCommand.ShowPostConditionPictographic(event.conditionNumber)
          } else {
            StudyFlowTransition(current, StudyFlowCommand.IgnoreInvalidEvent)
          }
      is StudyFlowEvent.PictographicSubmitted ->
          requirePostConditionStage(current, event.conditionNumber, "pictographic") {
            current.copy(stageId = postConditionStageId(event.conditionNumber, "presence_questionnaire")) to
                StudyFlowCommand.ShowPostConditionPresence(event.conditionNumber)
          }
      is StudyFlowEvent.PresenceQuestionnaireSubmitted ->
          requirePostConditionStage(current, event.conditionNumber, "presence_questionnaire") {
            current.copy(stageId = postConditionStageId(event.conditionNumber, "lost_opportunity")) to
                StudyFlowCommand.ShowPostConditionLostOpportunity(event.conditionNumber)
          }
      is StudyFlowEvent.LostOpportunitySubmitted ->
          requirePostConditionStage(current, event.conditionNumber, "lost_opportunity") {
            if (event.conditionNumber == 1) {
              current.copy(
                  stageId = CONDITION_2,
                  activeCondition = 2,
                  completedConditions = current.completedConditions + 1,
              ) to StudyFlowCommand.BeginCondition(2)
            } else {
              current.copy(
                  stageId = FINAL_END_CONFIRMATION,
                  activeCondition = 0,
                  completedConditions = current.completedConditions + 2,
              ) to StudyFlowCommand.ShowFinalEndConfirmation
            }
          }
      is StudyFlowEvent.FinalEndConfirmationSubmitted ->
          requireStage(current, FINAL_END_CONFIRMATION) {
            if (event.rating1To10 == 10) {
              current.copy(stageId = COMPLETE_EXPORT_SUMMARY) to StudyFlowCommand.ExportSession
            } else {
              current.copy(stageId = FINAL_EXTRA_PRESSES_OPTIONAL) to
                  StudyFlowCommand.BeginFinalExtraPresses
            }
          }
      StudyFlowEvent.FinalExtraPressesCompleted ->
          requireStage(current, FINAL_EXTRA_PRESSES_OPTIONAL) {
            current.copy(stageId = COMPLETE_EXPORT_SUMMARY) to StudyFlowCommand.ExportSession
          }
      StudyFlowEvent.ExportCompleted ->
          requireStage(current, COMPLETE_EXPORT_SUMMARY) {
            current.copy(stageId = COMPLETE_EXPORT_SUMMARY) to StudyFlowCommand.Complete
          }
    }.let { result ->
      if (result is StudyFlowTransition) {
        result
      } else {
        val (nextState, command) = result as Pair<StudyFlowState, StudyFlowCommand>
        StudyFlowTransition(
            nextState.copy(activeDelayToken = 0, activeDelayStageId = ""),
            command,
        )
      }
    }
  }

  private fun transitionToCondition(
      current: StudyFlowState,
      conditionNumber: Int,
  ): StudyFlowTransition {
    val allowed =
        (conditionNumber == 1 && current.stageId == PRIOR_BIG_RED_BUTTON_EXPERIENCE) ||
            (conditionNumber == 2 && current.stageId == postConditionStageId(1, "lost_opportunity"))
    return if (allowed) {
      StudyFlowTransition(
          current.copy(stageId = conditionStageId(conditionNumber), activeCondition = conditionNumber),
          StudyFlowCommand.BeginCondition(conditionNumber),
      )
    } else {
      StudyFlowTransition(current, StudyFlowCommand.IgnoreInvalidEvent)
    }
  }

  private fun requireStage(
      current: StudyFlowState,
      expectedStageId: String,
      block: () -> Pair<StudyFlowState, StudyFlowCommand>,
  ): Any {
    return if (current.stageId == expectedStageId) block() else StudyFlowTransition(current, StudyFlowCommand.IgnoreInvalidEvent)
  }

  private fun requirePostConditionStage(
      current: StudyFlowState,
      conditionNumber: Int,
      suffix: String,
      block: () -> Pair<StudyFlowState, StudyFlowCommand>,
  ): Any {
    return requireStage(current, postConditionStageId(conditionNumber, suffix), block)
  }

  companion object {
    const val LANGUAGE_SELECTION = "language_selection"
    const val CONSENT_DEMOGRAPHICS = "consent_demographics"
    const val PRIOR_BIG_RED_BUTTON_EXPERIENCE = "prior_big_red_button_experience"
    const val CONDITION_1 = "condition_1"
    const val CONDITION_2 = "condition_2"
    const val FINAL_END_CONFIRMATION = "final_end_confirmation"
    const val FINAL_EXTRA_PRESSES_OPTIONAL = "final_extra_presses_optional"
    const val COMPLETE_EXPORT_SUMMARY = "complete_export_summary"

    val stageSequenceIds =
        listOf(
            LANGUAGE_SELECTION,
            CONSENT_DEMOGRAPHICS,
            PRIOR_BIG_RED_BUTTON_EXPERIENCE,
            CONDITION_1,
            postConditionStageId(1, "pictographic"),
            postConditionStageId(1, "presence_questionnaire"),
            postConditionStageId(1, "lost_opportunity"),
            CONDITION_2,
            postConditionStageId(2, "pictographic"),
            postConditionStageId(2, "presence_questionnaire"),
            postConditionStageId(2, "lost_opportunity"),
            FINAL_END_CONFIRMATION,
            FINAL_EXTRA_PRESSES_OPTIONAL,
            COMPLETE_EXPORT_SUMMARY,
        )

    fun conditionStageId(conditionNumber: Int): String = "condition_$conditionNumber"

    fun postConditionStageId(conditionNumber: Int, suffix: String): String =
        "post_condition_${conditionNumber}_$suffix"
  }
}

data class StudyFlowState(
    val stageId: String = StudyFlowController.LANGUAGE_SELECTION,
    val activeCondition: Int = 0,
    val completedConditions: Set<Int> = emptySet(),
    val priorBigRedButtonPromptCount: Int = 0,
    val activeDelayToken: Int = 0,
    val activeDelayStageId: String = "",
    val nextDelayToken: Int = 0,
)

data class StudyFlowDelayToken(
    val value: Int,
    val expectedStageId: String,
)

data class StudyFlowTransition(
    val nextState: StudyFlowState,
    val command: StudyFlowCommand,
)

sealed class StudyFlowEvent {
  object LanguageSelected : StudyFlowEvent()
  object DemographicsSubmitted : StudyFlowEvent()
  object PriorBigRedButtonExperienceSubmitted : StudyFlowEvent()
  data class ConditionStarted(val conditionNumber: Int) : StudyFlowEvent()
  data class ConditionEnded(val conditionNumber: Int) : StudyFlowEvent()
  data class PictographicSubmitted(val conditionNumber: Int) : StudyFlowEvent()
  data class PresenceQuestionnaireSubmitted(val conditionNumber: Int) : StudyFlowEvent()
  data class LostOpportunitySubmitted(val conditionNumber: Int) : StudyFlowEvent()
  data class FinalEndConfirmationSubmitted(val rating1To10: Int) : StudyFlowEvent()
  object FinalExtraPressesCompleted : StudyFlowEvent()
  object ExportCompleted : StudyFlowEvent()
}

sealed class StudyFlowCommand {
  data class ShowStage(val stageId: String) : StudyFlowCommand()
  object ShowPriorBigRedButtonExperience : StudyFlowCommand()
  data class BeginCondition(val conditionNumber: Int) : StudyFlowCommand()
  data class ShowPostConditionPictographic(val conditionNumber: Int) : StudyFlowCommand()
  data class ShowPostConditionPresence(val conditionNumber: Int) : StudyFlowCommand()
  data class ShowPostConditionLostOpportunity(val conditionNumber: Int) : StudyFlowCommand()
  object ShowFinalEndConfirmation : StudyFlowCommand()
  object BeginFinalExtraPresses : StudyFlowCommand()
  object ExportSession : StudyFlowCommand()
  object Complete : StudyFlowCommand()
  object IgnoreInvalidEvent : StudyFlowCommand()
  object IgnoreStaleDelayedCallback : StudyFlowCommand()
}
