import 'package:mezgebe_sibhat/features/songs/data/local/song_model.dart';
import 'package:mezgebe_sibhat/features/songs/domain/repository/song_repo.dart';

class LoadSongsUsecase {
  final SongRepository repository;
  LoadSongsUsecase(this.repository);
  Future<List<SongModel>> call() async {
    return await repository.loadSongs();
  }
}
