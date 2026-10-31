import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../models/app_status_dto.dart';
import 'system_status_remote_data_source.dart';

/// DEBUG ONLY: when a real call fails in a debug build, answer "all clear" so
/// the app opens without a backend; `--dart-define=DEBUG_APP_STATUS=` takes
/// `maintenance`, `update` (hard) or `soft` to look at those screens on a device.
/// `kDebugMode` is a compile-time constant, so release builds drop every
/// fallback branch (same pattern as the other features).
class DebugFallbackSystemStatusRemoteDataSource
    implements SystemStatusRemoteDataSource {
  DebugFallbackSystemStatusRemoteDataSource(this._real);

  final SystemStatusRemoteDataSource _real;

  static const _forced = String.fromEnvironment('DEBUG_APP_STATUS');

  @override
  Future<Either<Failure, AppStatusDto>> getAppStatus() async {
    if (kDebugMode && _forced.isNotEmpty) {
      final eta = DateTime.now().add(const Duration(minutes: 30));
      return Right(switch (_forced) {
        'maintenance' => AppStatusDto(maintenance: true, maintenanceEta: eta),
        'update' => const AppStatusDto(
            maintenance: false,
            minimumVersion: '999.0.0',
            latestVersion: '999.0.0',
            storeUrl: 'https://example.invalid/store',
          ),
        'soft' => const AppStatusDto(
            maintenance: false,
            latestVersion: '999.0.0',
            storeUrl: 'https://example.invalid/store',
            updateNote: 'debug',
          ),
        _ => const AppStatusDto(maintenance: false),
      });
    }
    final result = await _real.getAppStatus();
    if (debugFallbacksEnabled && result.isLeft()) {
      return const Right(AppStatusDto(maintenance: false));
    }
    return result;
  }

  @override
  Future<Either<Failure, bool>> requestAccess(String area) async {
    final result = await _real.requestAccess(area);
    if (debugFallbacksEnabled && result.isLeft()) return const Right(true);
    return result;
  }
}
