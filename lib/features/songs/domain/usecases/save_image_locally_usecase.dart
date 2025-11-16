import 'package:mezgebe_sibhat/features/songs/data/local/song_model.dart';
import 'package:mezgebe_sibhat/features/songs/domain/repository/song_repo.dart';

class SaveImageLocallyUsecase {
  final SongRepository repository;
  SaveImageLocallyUsecase(this.repository);
  Future<List<SongModel>> call(SongModel song, String imagePath) {
    return repository.saveImageLocally(song, imagePath);
  }
}
