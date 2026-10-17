/// Opens the app's store listing. `false` = nothing could open it.
abstract interface class StoreLauncher {
  Future<bool> open(String url);
}
