package org.bigredbutton.firststudy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StudyFlowControllerTest {
  @Test
  fun condition1LostOpportunitySubmitsIntoCondition2() {
    val controller = controllerAtLostOpportunity(conditionNumber = 1)

    val transition = controller.handle(StudyFlowEvent.LostOpportunitySubmitted(1))

    assertEquals(StudyFlowCommand.BeginCondition(2), transition.command)
    assertEquals(StudyFlowController.CONDITION_2, controller.state.stageId)
    assertEquals(2, controller.state.activeCondition)
  }

  @Test
  fun condition2EndOpensPictographicPresenceLostOpportunityThenFinalConfirmation() {
    val controller = controllerAtCondition2()

    val endTransition = controller.handle(StudyFlowEvent.ConditionEnded(2))
    assertEquals(StudyFlowCommand.ShowPostConditionPictographic(2), endTransition.command)
    assertEquals(StudyFlowController.postConditionStageId(2, "pictographic"), controller.state.stageId)

    val pictographicTransition = controller.handle(StudyFlowEvent.PictographicSubmitted(2))
    assertEquals(StudyFlowCommand.ShowPostConditionPresence(2), pictographicTransition.command)
    assertEquals(StudyFlowController.postConditionStageId(2, "presence_questionnaire"), controller.state.stageId)

    val presenceTransition = controller.handle(StudyFlowEvent.PresenceQuestionnaireSubmitted(2))
    assertEquals(StudyFlowCommand.ShowPostConditionLostOpportunity(2), presenceTransition.command)
    assertEquals(StudyFlowController.postConditionStageId(2, "lost_opportunity"), controller.state.stageId)

    val lostTransition = controller.handle(StudyFlowEvent.LostOpportunitySubmitted(2))
    assertEquals(StudyFlowCommand.ShowFinalEndConfirmation, lostTransition.command)
    assertEquals(StudyFlowController.FINAL_END_CONFIRMATION, controller.state.stageId)
  }

  @Test
  fun priorBigRedButtonPromptOccursOnceAndNeverBeforeCondition2() {
    val controller = StudyFlowController()

    controller.handle(StudyFlowEvent.LanguageSelected)
    controller.handle(StudyFlowEvent.DemographicsSubmitted)
    val priorTransition = controller.handle(StudyFlowEvent.PriorBigRedButtonExperienceSubmitted)
    assertEquals(StudyFlowCommand.BeginCondition(1), priorTransition.command)
    assertEquals(1, controller.state.priorBigRedButtonPromptCount)

    controller.handle(StudyFlowEvent.ConditionEnded(1))
    controller.handle(StudyFlowEvent.PictographicSubmitted(1))
    controller.handle(StudyFlowEvent.PresenceQuestionnaireSubmitted(1))
    val condition2Transition = controller.handle(StudyFlowEvent.LostOpportunitySubmitted(1))

    assertEquals(StudyFlowCommand.BeginCondition(2), condition2Transition.command)
    assertEquals(StudyFlowController.CONDITION_2, controller.state.stageId)
    assertEquals(1, controller.state.priorBigRedButtonPromptCount)
    assertTrue(condition2Transition.command !is StudyFlowCommand.ShowStage)
  }

  @Test
  fun staleDelayedCallbacksCannotAdvanceSupersededStage() {
    val controller = controllerAtCondition1()
    val delayedEndToken = controller.armDelayedCallback(StudyFlowController.CONDITION_1)

    controller.handle(StudyFlowEvent.ConditionEnded(1))
    val staleTransition = controller.handleDelayed(delayedEndToken, StudyFlowEvent.ConditionEnded(1))

    assertEquals(StudyFlowCommand.IgnoreStaleDelayedCallback, staleTransition.command)
    assertEquals(StudyFlowController.postConditionStageId(1, "pictographic"), controller.state.stageId)
  }

  private fun controllerAtCondition1(): StudyFlowController {
    val controller = StudyFlowController()
    controller.handle(StudyFlowEvent.LanguageSelected)
    controller.handle(StudyFlowEvent.DemographicsSubmitted)
    controller.handle(StudyFlowEvent.PriorBigRedButtonExperienceSubmitted)
    return controller
  }

  private fun controllerAtLostOpportunity(conditionNumber: Int): StudyFlowController {
    val controller =
        if (conditionNumber == 1) {
          controllerAtCondition1()
        } else {
          controllerAtCondition2()
        }
    controller.handle(StudyFlowEvent.ConditionEnded(conditionNumber))
    controller.handle(StudyFlowEvent.PictographicSubmitted(conditionNumber))
    controller.handle(StudyFlowEvent.PresenceQuestionnaireSubmitted(conditionNumber))
    return controller
  }

  private fun controllerAtCondition2(): StudyFlowController {
    val controller = controllerAtLostOpportunity(conditionNumber = 1)
    controller.handle(StudyFlowEvent.LostOpportunitySubmitted(1))
    return controller
  }
}
