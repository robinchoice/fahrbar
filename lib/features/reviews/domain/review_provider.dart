import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/supabase_provider.dart';
import '../data/supabase_review_repository.dart';
import 'review.dart';
import 'review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return SupabaseReviewRepository(ref.read(supabaseClientProvider));
});

final carReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, carId) {
  return ref.read(reviewRepositoryProvider).getForCar(carId);
});
