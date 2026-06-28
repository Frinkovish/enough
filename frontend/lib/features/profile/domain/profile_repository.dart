import 'user_profile.dart';

abstract class ProfileRepository {
  /// Null if the user hasn't filled in a profile yet.
  Future<UserProfile?> getProfile();

  Future<void> saveProfile(UserProfile profile);
}
