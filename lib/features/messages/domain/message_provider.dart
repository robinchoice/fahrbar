import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/supabase_provider.dart';
import '../data/supabase_message_repository.dart';
import 'message.dart';
import 'message_repository.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return SupabaseMessageRepository(ref.read(supabaseClientProvider));
});

final chatStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, bookingId) {
  return ref.read(messageRepositoryProvider).watch(bookingId);
});
