enum Gender { male, female, nonBinary, preferNotToSay }

extension GenderWire on Gender {
  /// Snake_case wire value stored in the database — must not be confused
  /// with [Enum.name], which is camelCase for nonBinary/preferNotToSay.
  String get wireValue {
    switch (this) {
      case Gender.male:
        return 'male';
      case Gender.female:
        return 'female';
      case Gender.nonBinary:
        return 'non_binary';
      case Gender.preferNotToSay:
        return 'prefer_not_to_say';
    }
  }

  String get label {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.nonBinary:
        return 'Non-binary';
      case Gender.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  static Gender? fromWire(String? value) {
    for (final gender in Gender.values) {
      if (gender.wireValue == value) return gender;
    }
    return null;
  }
}

enum QuitReason { health, family, money, fitness, pregnancy, socialPressure, other }

extension QuitReasonWire on QuitReason {
  String get wireValue {
    switch (this) {
      case QuitReason.health:
        return 'health';
      case QuitReason.family:
        return 'family';
      case QuitReason.money:
        return 'money';
      case QuitReason.fitness:
        return 'fitness';
      case QuitReason.pregnancy:
        return 'pregnancy';
      case QuitReason.socialPressure:
        return 'social_pressure';
      case QuitReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case QuitReason.health:
        return 'Health';
      case QuitReason.family:
        return 'Family';
      case QuitReason.money:
        return 'Save money';
      case QuitReason.fitness:
        return 'Fitness';
      case QuitReason.pregnancy:
        return 'Pregnancy';
      case QuitReason.socialPressure:
        return 'Social pressure';
      case QuitReason.other:
        return 'Other';
    }
  }

  static QuitReason? fromWire(String value) {
    for (final reason in QuitReason.values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}

class UserProfile {
  const UserProfile({
    required this.userId,
    this.displayName,
    this.birthdate,
    this.occupation,
    this.gender,
    this.quitReasons = const [],
  });

  final String userId;
  final String? displayName;
  final DateTime? birthdate;
  final String? occupation;
  final Gender? gender;
  final List<QuitReason> quitReasons;

  UserProfile copyWith({
    String? displayName,
    DateTime? birthdate,
    String? occupation,
    Gender? gender,
    List<QuitReason>? quitReasons,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      birthdate: birthdate ?? this.birthdate,
      occupation: occupation ?? this.occupation,
      gender: gender ?? this.gender,
      quitReasons: quitReasons ?? this.quitReasons,
    );
  }
}
