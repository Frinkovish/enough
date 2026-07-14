/// Why the suggested task wasn't completed — captured only when the user
/// says "not this time" to the task-completion question, so the app can
/// eventually learn which suggestions actually land vs. which don't fit
/// the moment.
enum TaskSkipReason { busy, notInTheMood, forgot, notHelpful, other }

extension TaskSkipReasonWire on TaskSkipReason {
  String get wireValue {
    switch (this) {
      case TaskSkipReason.busy:
        return 'busy';
      case TaskSkipReason.notInTheMood:
        return 'not_in_the_mood';
      case TaskSkipReason.forgot:
        return 'forgot';
      case TaskSkipReason.notHelpful:
        return 'not_helpful';
      case TaskSkipReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case TaskSkipReason.busy:
        return 'Got busy';
      case TaskSkipReason.notInTheMood:
        return "Wasn't feeling it";
      case TaskSkipReason.forgot:
        return 'Forgot';
      case TaskSkipReason.notHelpful:
        return "Didn't seem right";
      case TaskSkipReason.other:
        return 'Other';
    }
  }
}
