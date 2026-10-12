import '../data/repositories/dua_user_data_repository_impl.dart';
import '../data/repositories/json_dua_repository.dart';
import '../data/services/just_audio_dua_player.dart';
import '../data/services/platform_dua_sharer.dart';
import '../domain/repositories/dua_repository.dart';
import '../domain/repositories/dua_user_data_repository.dart';
import '../domain/services/dua_audio_player.dart';
import '../domain/services/dua_sharer.dart';
import '../domain/usecases/dua_library_usecases.dart';
import '../domain/usecases/get_duas_usecase.dart';
import '../presentation/bloc/dua_player_cubit.dart';
import '../presentation/bloc/duas_cubit.dart';

/// Composition root for the dua library. Tests replace [instance] with fakes.
class DuaModule {
  DuaModule({
    DuaRepository? duas,
    DuaUserDataRepository? userData,
    DuaSharer? sharer,
    TextClipboard? clipboard,
    DuaAudioPlayer? player,
  })  : duas = duas ?? JsonDuaRepository(),
        userData = userData ?? DuaUserDataRepositoryImpl(),
        sharer = sharer ?? const PlatformDuaSharer(),
        clipboard = clipboard ?? const SystemTextClipboard(),
        player = player ?? JustAudioDuaPlayer.shared;

  static DuaModule instance = DuaModule();

  final DuaRepository duas;
  final DuaUserDataRepository userData;
  final DuaSharer sharer;
  final TextClipboard clipboard;
  final DuaAudioPlayer player;

  DuasCubit createCubit() => DuasCubit(
        getDuas: GetDuasUseCase(duas),
        loadUserData: LoadDuaUserDataUseCase(userData),
        toggleFavorite: ToggleFavoriteDuaUseCase(userData),
        saveFilter: SaveDuaFilterUseCase(userData),
        share: ShareDuaUseCase(sharer),
        copy: CopyDuaUseCase(clipboard),
      );

  DuaPlayerCubit createPlayerCubit() => DuaPlayerCubit(player);
}
