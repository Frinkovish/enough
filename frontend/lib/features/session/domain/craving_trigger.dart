enum CravingTrigger { stress, anxiety, boredom, sadness, restlessness, fatigue, other }

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
      case CravingTrigger.restlessness:
        return 'Restlessness';
      case CravingTrigger.fatigue:
        return 'Fatigue';
      case CravingTrigger.other:
        return 'Other';
    }
  }
}
