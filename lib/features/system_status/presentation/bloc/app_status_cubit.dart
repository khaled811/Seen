// App-wide gate state (Figma SYS-04 maintenance, SYS-05 hard / soft update).
//
// Fail-open: if the status call fails the app keeps working. Blocking users
// because the status endpoint is down would turn a small outage into a full one.
// Maintenance is the exception on a retry: it stays up until the server says it ended.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_status.dart';
import '../../domain/entities/app_version.dart';
import '../../domain/usecases/system_status_usecases.dart';

sealed class AppStatusState extends Equatable {
  const AppStatusState();

  @override
  List<Object?> get props => [];
}

/// Nothing to show over the app.
final class AppStatusOpen extends AppStatusState {
  const AppStatusOpen();
}

final class AppStatusMaintenance extends AppStatusState {
  const AppStatusMaintenance({this.eta, this.checking = false});

  final DateTime? eta;

  /// A retry is running.
  final bool checking;

  @override
  List<Object?> get props => [eta, checking];
}

/// This version is no longer supported: the app is blocked until it updates.
final class AppStatusUpdateRequired extends AppStatusState {
  const AppStatusUpdateRequired({this.storeUrl});

  final String? storeUrl;

  @override
  List<Object?> get props => [storeUrl];
}

/// A newer version exists; the user may postpone.
final class AppStatusUpdateAvailable extends AppStatusState {
  const AppStatusUpdateAvailable({required this.version, this.note, this.storeUrl});

  final String version;
  final String? note;
  final String? storeUrl;

  @override
  List<Object?> get props => [version, note, storeUrl];
}

class AppStatusCubit extends Cubit<AppStatusState> {
  AppStatusCubit({
    required GetAppStatusUseCase getStatus,
    required Future<String> Function() currentVersion,
    DateTime Function()? now,
    this.staleAfter = const Duration(minutes: 5),
  })  : _getStatus = getStatus,
        _currentVersion = currentVersion,
        _now = now ?? DateTime.now,
        super(const AppStatusOpen());

  final GetAppStatusUseCase _getStatus;
  final Future<String> Function() _currentVersion;
  final DateTime Function() _now;
  final Duration staleAfter;

  bool _checking = false;
  DateTime? _lastChecked;
  String? _postponedVersion;

  /// Asks the server. A second call while one is running is ignored.
  Future<void> check() async {
    if (_checking) {
      return;
    }
    _checking = true;
    try {
      final before = state;
      if (before is AppStatusMaintenance) {
        emit(AppStatusMaintenance(eta: before.eta, checking: true));
      }
      final result = await _getStatus();
      if (isClosed) {
        return;
      }
      final current = AppVersion.tryParse(await _currentVersion());
      if (isClosed) {
        return;
      }
      result.fold(
        (_) {
          // Fail-open, except that a maintenance screen stays until it is really over.
          if (before is AppStatusMaintenance) {
            emit(AppStatusMaintenance(eta: before.eta));
          }
        },
        (status) {
          _lastChecked = _now();
          emit(_stateFor(status, current));
        },
      );
    } finally {
      _checking = false;
    }
  }

  /// On app resume: always while blocked, otherwise at most once per [staleAfter].
  Future<void> checkOnResume() {
    final blocked = state is AppStatusMaintenance || state is AppStatusUpdateRequired;
    final last = _lastChecked;
    if (!blocked && last != null && _now().difference(last) < staleAfter) {
      return Future.value();
    }
    return check();
  }

  /// "Later" on the optional update; asked again only for a newer version.
  void postponeUpdate() {
    final s = state;
    if (s is AppStatusUpdateAvailable) {
      _postponedVersion = s.version;
      emit(const AppStatusOpen());
    }
  }

  AppStatusState _stateFor(AppStatus status, AppVersion? current) {
    if (status.maintenance) {
      return AppStatusMaintenance(eta: status.maintenanceEta);
    }
    if (current == null) {
      return const AppStatusOpen();
    }
    final minimum = AppVersion.tryParse(status.minimumVersion);
    if (minimum != null && current < minimum) {
      return AppStatusUpdateRequired(storeUrl: status.storeUrl);
    }
    final latest = AppVersion.tryParse(status.latestVersion);
    if (latest != null && current < latest && latest.toString() != _postponedVersion) {
      return AppStatusUpdateAvailable(
        version: latest.toString(),
        note: status.updateNote,
        storeUrl: status.storeUrl,
      );
    }
    return const AppStatusOpen();
  }
}
