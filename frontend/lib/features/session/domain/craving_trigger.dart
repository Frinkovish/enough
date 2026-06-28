enum CravingTrigger { stress, boredom, social, habit, other }

extension CravingTriggerLabel on CravingTrigger {
  String get label {
    switch (this) {
      case CravingTrigger.stress:
        return 'Stress';
      case CravingTrigger.boredom:
        return 'Boredom';
      case CravingTrigger.social:
        return 'Social';
      case CravingTrigger.habit:
        return 'Habit';
      case CravingTrigger.other:
        return 'Other';
    }
  }
}
