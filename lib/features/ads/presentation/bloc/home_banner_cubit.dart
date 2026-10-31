import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/ad_banner.dart';
import '../../domain/repositories/ads_repository.dart';

class HomeBannerState extends Equatable {
  const HomeBannerState({this.ad, this.failure});

  /// The ad to show; null shows nothing (none offered, not read yet, or the read failed).
  final AdBanner? ad;

  /// Why the last read failed. A promotion is never worth an error on the home
  /// screen, so the screen shows nothing; the reason is kept for tests and logs.
  final Failure? failure;

  @override
  List<Object?> get props => [ad, failure];
}

/// Reads the home banner once per [load]. Owner: the home screen (closes it with its provider).
class HomeBannerCubit extends Cubit<HomeBannerState> {
  HomeBannerCubit(this._repository) : super(const HomeBannerState());

  final AdsRepository _repository;
  bool _loading = false;

  /// The ads already counted as shown by this cubit (once per showing, not per refresh).
  final _counted = <String>{};

  /// Counts a tap on the ad's button (the screen then opens the link).
  void clicked() {
    final ad = state.ad;
    if (ad != null) unawaited(_repository.recordClick(ad.id));
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final result = await _repository.homeBanner();
      if (isClosed) return;
      result.fold(
        // The banner already on screen stays through a failed refresh.
        (f) => emit(HomeBannerState(ad: state.ad, failure: f)),
        (ad) {
          emit(HomeBannerState(ad: ad));
          if (ad != null && _counted.add(ad.id)) unawaited(_repository.recordImpression(ad.id));
        },
      );
    } finally {
      _loading = false;
    }
  }
}
