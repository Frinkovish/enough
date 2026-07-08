// `other` is not shown in the intake UI — it exists only as a fallback when
// parsing old session rows that used a trigger value no longer in the list.
enum CravingTrigger { stress, boredom, afterMeals, coffee, habit, social, morning, other }

extension CravingTriggerLabel on CravingTrigger {
  String get label {
    switch (this) {
      case CravingTrigger.stress:
        return 'Stress';
      case CravingTrigger.boredom:
        return 'Boredom';
      case CravingTrigger.afterMeals:
        return 'After meals';
      case CravingTrigger.coffee:
        return 'Coffee';
      case CravingTrigger.habit:
        return 'Habit';
      case CravingTrigger.social:
        return 'Social';
      case CravingTrigger.morning:
        return 'Morning';
      case CravingTrigger.other:
        return 'Other';
    }
  }
}
