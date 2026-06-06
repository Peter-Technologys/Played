import '../../../core/models/media_item.dart';
import '../../../core/utils/shelf_sorter.dart';
import '../data/media_repository.dart';

/// Domain use case: builds all shelves from scanned media.
class ShelfUseCase {
  final MediaRepository _repo;
  ShelfUseCase(this._repo);

  Future<ShelfBundle> execute({bool forceRefresh = false}) async {
    final items =
        await _repo.getAllMedia(forceRefresh: forceRefresh);
    return ShelfSorter.buildAllShelves(items);
  }
}
