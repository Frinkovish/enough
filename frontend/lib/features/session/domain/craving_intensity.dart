/// How strong the urge is right now — determines whether the
/// suggestion should focus on stabilization or growth.
enum CravingIntensity { mild, moderate, strong }

extension CravingIntensityLabel on CravingIntensity {
  String get label {
    switch (this) {
      case CravingIntensity.mild:
        return 'Mild';
      case CravingIntensity.moderate:
        return 'Moderate';
      case CravingIntensity.strong:
        return 'Strong';
    }
  }
}
