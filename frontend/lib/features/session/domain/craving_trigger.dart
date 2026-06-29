enum CravingTrigger { stress, anxiety, boredom, sadness, loneliness, fatigue, other }

extension CravingTriggerLabel on CravingTrigger {
  String get label {
    switch (this) {
      case CravingTrigger.stress:
        return 'Stress';
      case CravingTrigger.anxiety:
        return 'Anxiety';
      case CravingTrigger.boredom:
        return 'Boredom';
      case CravingTrigger.sadness:
        return 'Sadness';
      case CravingTrigger.loneliness:
        return 'Loneliness';
      case CravingTrigger.fatigue:
        return 'Fatigue';
      case CravingTrigger.other:
        return 'Other';
    }
  }
}
