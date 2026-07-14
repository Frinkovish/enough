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

enum AddictionType { cigarettes, weed, masturbation, other }

extension AddictionTypeWire on AddictionType {
  String get wireValue {
    switch (this) {
      case AddictionType.cigarettes:
        return 'cigarettes';
      case AddictionType.weed:
        return 'weed';
      case AddictionType.masturbation:
        return 'masturbation';
      case AddictionType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case AddictionType.cigarettes:
        return 'Cigarettes';
      case AddictionType.weed:
        return 'Weed';
      case AddictionType.masturbation:
        return 'Masturbation';
      case AddictionType.other:
        return 'Other';
    }
  }

  static AddictionType? fromWire(String value) {
    for (final type in AddictionType.values) {
      if (type.wireValue == value) return type;
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
    this.addictionTypes = const [],
    this.totalControl = false,
    this.quitDate,
    this.daysCleanTarget,
  });

  final String userId;
  final String? displayName;
  final DateTime? birthdate;
  final String? occupation;
  final Gender? gender;
  final List<QuitReason> quitReasons;

  /// The day the "days clean" counter counts from. Set on first profile
  /// save and reset to the current day whenever stats are cleared —
  /// starting the counter over along with the session history.
  final DateTime? quitDate;

  /// Personal milestone for the days-clean counter (e.g. 30, 90, 365).
  /// Purely a display target — unaffected by resetting stats.
  final int? daysCleanTarget;

  /// Which addictions this profile is tracking. When empty (or when
  /// [totalControl] is off), the craving flow defaults to cigarettes —
  /// the app's original single-addiction behavior.
  final List<AddictionType> addictionTypes;

  /// When on, logging a craving asks which of [addictionTypes] it's for
  /// instead of always assuming cigarettes.
  final bool totalControl;

  UserProfile copyWith({
    String? displayName,
    DateTime? birthdate,
    String? occupation,
    Gender? gender,
    List<QuitReason>? quitReasons,
    List<AddictionType>? addictionTypes,
    bool? totalControl,
    DateTime? quitDate,
    int? daysCleanTarget,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      birthdate: birthdate ?? this.birthdate,
      occupation: occupation ?? this.occupation,
      gender: gender ?? this.gender,
      quitReasons: quitReasons ?? this.quitReasons,
      addictionTypes: addictionTypes ?? this.addictionTypes,
      totalControl: totalControl ?? this.totalControl,
      quitDate: quitDate ?? this.quitDate,
      daysCleanTarget: daysCleanTarget ?? this.daysCleanTarget,
    );
  }
}
