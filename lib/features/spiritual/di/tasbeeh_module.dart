import '../data/repositories/json_dhikr_catalog.dart';
import '../data/repositories/tasbeeh_repository_impl.dart';
import '../data/services/wakelock_screen_awake.dart';
import '../domain/repositories/tasbeeh_repository.dart';
import '../domain/services/screen_awake.dart';
import '../presentation/bloc/tasbeeh_cubit.dart';

/// Composition root for the tasbeeh. Tests replace [instance] with fakes.
class TasbeehModule {
  TasbeehModule({
    DhikrCatalog? catalog,
    TasbeehRepository? repository,
    ScreenAwake? screenAwake,
    DateTime Function()? clock,
  })  : catalog = catalog ?? JsonDhikrCatalog(),
        repository = repository ?? TasbeehRepositoryImpl(),
        screenAwake = screenAwake ?? const WakelockScreenAwake(),
        clock = clock ?? DateTime.now;

  static TasbeehModule instance = TasbeehModule();

  final DhikrCatalog catalog;
  final TasbeehRepository repository;
  final ScreenAwake screenAwake;
  final DateTime Function() clock;

  TasbeehCubit createCubit() => TasbeehCubit(
        catalog: catalog,
        repository: repository,
        screenAwake: screenAwake,
        clock: clock,
      );
}
