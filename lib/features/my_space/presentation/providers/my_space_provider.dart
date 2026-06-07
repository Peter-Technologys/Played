import 'package:flutter_riverpod/flutter_riverpod.dart';
// Corrected import paths: this file lives 4 levels deep
// (lib/features/my_space/presentation/providers/) so core/ needs ../../../../
import '../../../../core/utils/shelf_sorter.dart';
import '../../data/media_repository.dart';
import '../../domain/shelf_use_case.dart';

final mediaRepositoryProvider = Provider<MediaRepository>(
  (_) => MediaRepository.instance,
);

final shelfUseCaseProvider = Provider<ShelfUseCase>(
  (ref) => ShelfUseCase(ref.read(mediaRepositoryProvider)),
);

/// Async provider that scans media and builds all shelves.
final mySpaceProvider = FutureProvider<ShelfBundle>((ref) async {
  final useCase = ref.read(shelfUseCaseProvider);
  return useCase.execute();
});

/// Refresh trigger — invalidate cache and re-scan.
final refreshMySpaceProvider = Provider<void Function()>((ref) {
  return () {
    MediaRepository.instance.invalidate();
    ref.invalidate(mySpaceProvider);
  };
});
