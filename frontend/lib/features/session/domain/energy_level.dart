/// Self-reported executive capacity right now — a task that exceeds
/// this is likely to be rejected, so it calibrates task difficulty.
enum EnergyLevel { empty, low, okay, high }

extension EnergyLevelLabel on EnergyLevel {
  String get label {
    switch (this) {
      case EnergyLevel.empty:
        return 'Empty';
      case EnergyLevel.low:
        return 'Low';
      case EnergyLevel.okay:
        return 'Okay';
      case EnergyLevel.high:
        return 'High';
    }
  }
}
