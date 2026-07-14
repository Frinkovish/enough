import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/reminder_repository.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(baseUrl: Env.backendBaseUrl, client: ref.watch(supabaseClientProvider));
});
