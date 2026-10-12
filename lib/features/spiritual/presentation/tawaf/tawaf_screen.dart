import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/seen_haptics.dart';
import '../../data/repositories/json_dua_repository.dart';
import '../../data/repositories/tawaf_session_repository_impl.dart';
import '../../data/services/just_audio_dua_player.dart';
import '../../data/services/wakelock_screen_awake.dart';
import '../../domain/entities/rite_mode.dart';
import '../../domain/repositories/dua_repository.dart';
import '../../domain/repositories/tawaf_session_repository.dart';
import '../../domain/services/dua_audio_player.dart';
import '../../domain/services/screen_awake.dart';
import '../../domain/usecases/end_session_usecase.dart';
import '../../domain/usecases/get_duas_usecase.dart';
import '../../domain/usecases/record_lap_usecase.dart';
import '../../domain/usecases/restore_session_usecase.dart';
import '../../domain/usecases/start_session_usecase.dart';
import '../../domain/usecases/undo_lap_usecase.dart';
import '../bloc/dua_audio_cubit.dart';
import '../bloc/tawaf_bloc.dart';
import '../bloc/tawaf_event.dart';
import '../bloc/tawaf_state.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_confirm_dialog.dart';
import '../widgets/spiritual_outlined_button.dart';
import '../widgets/spiritual_primary_button.dart';
import '../widgets/spiritual_scaffold.dart';
import '../widgets/spiritual_segmented.dart';
import '../widgets/spiritual_top_bar.dart';
import 'tawaf_counter.dart';
import 'tawaf_dua_card.dart';
import 'tawaf_status_row.dart';
import 'tawaf_texts.dart';

/// Tawaf & Sa'i field companion (Screen 2). Collaborators are injectable for
/// tests; production defaults persist to `shared_preferences`, read duas from
/// the bundled JSON and play through the shared `just_audio` player.
class TawafScreen extends StatelessWidget {
  const TawafScreen({
    super.key,
    this.sessionRepository,
    this.duaRepository,
    this.audioPlayer,
    this.screenAwake,
    this.clock,
  });

  final TawafSessionRepository? sessionRepository;
  final DuaRepository? duaRepository;
  final DuaAudioPlayer? audioPlayer;
  final ScreenAwake? screenAwake;
  final DateTime Function()? clock;

  /// Route for `Navigator.push`.
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const TawafScreen());

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final sessions = sessionRepository ?? TawafSessionRepositoryImpl();
            return TawafBloc(
              restoreSession: RestoreSessionUseCase(sessions),
              startSession: StartSessionUseCase(sessions),
              recordLap: RecordLapUseCase(sessions),
              undoLap: UndoLapUseCase(sessions),
              endSession: EndSessionUseCase(sessions),
              getDuas: GetDuasUseCase(duaRepository ?? JsonDuaRepository()),
              clock: clock,
            )..add(const TawafStarted());
          },
        ),
        BlocProvider(
          create: (_) => DuaAudioCubit(audioPlayer ?? JustAudioDuaPlayer.shared),
        ),
      ],
      child: SpiritualTheme(
        child: _TawafView(screenAwake: screenAwake ?? const WakelockScreenAwake()),
      ),
    );
  }
}

class _TawafView extends StatefulWidget {
  const _TawafView({required this.screenAwake});

  final ScreenAwake screenAwake;

  @override
  State<_TawafView> createState() => _TawafViewState();
}

class _TawafViewState extends State<_TawafView> {
  static const _flashDuration = Duration(milliseconds: 1200);

  /// Owned here: cancelled in [dispose].
  Timer? _flashTimer;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.screenAwake.hold());
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    unawaited(widget.screenAwake.release());
    super.dispose();
  }

  void _startFlash() {
    _flashTimer?.cancel();
    setState(() => _flash = true);
    _flashTimer = Timer(_flashDuration, () {
      if (mounted) setState(() => _flash = false);
    });
  }

  void _stopFlash() {
    _flashTimer?.cancel();
    if (_flash) setState(() => _flash = false);
  }

  void _onState(BuildContext context, TawafState state) {
    if (state is TawafEnded) {
      Navigator.of(context).maybePop();
      return;
    }
    if (state is! TawafReady) return;
    if (state.saveFailed) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(SpiritualStrings.saveFailed)));
    }
    switch (state.action) {
      case TawafAction.none:
        break;
      case TawafAction.lapRecorded:
        SeenHaptics.lap();
        _startFlash();
        _announce(TawafTexts.lapAnnouncement(state));
      case TawafAction.completed:
        SeenHaptics.complete();
        _startFlash();
        _announce(TawafTexts.lapAnnouncement(state));
      case TawafAction.undone:
        SeenHaptics.light();
        _stopFlash();
      case TawafAction.modeChanged:
        SeenHaptics.select();
        _stopFlash();
        context.read<DuaAudioCubit>().stop();
    }
  }

  void _announce(String message) {
    SemanticsService.announce(message, TextDirection.rtl);
  }

  Future<void> _confirmFinish() async {
    final ok = await showSpiritualConfirm(
      context,
      title: SpiritualStrings.finishTitle,
      message: SpiritualStrings.finishMessage,
      confirmLabel: SpiritualStrings.finishConfirm,
    );
    if (!ok || !mounted) return;
    context.read<TawafBloc>().add(const TawafEndRequested());
  }

  Future<void> _confirmUndo() async {
    final ok = await showSpiritualConfirm(
      context,
      title: SpiritualStrings.undoTitle,
      confirmLabel: SpiritualStrings.undoConfirm,
    );
    if (!ok || !mounted) return;
    context.read<TawafBloc>().add(const TawafUndoRequested());
  }

  Future<void> _selectMode(RiteMode mode, TawafReady state) async {
    if (mode == state.session.mode) return;
    if (state.session.hasProgress) {
      final ok = await showSpiritualConfirm(
        context,
        title: SpiritualStrings.switchTitle,
        message: SpiritualStrings.switchMessage,
        confirmLabel: SpiritualStrings.switchConfirm,
      );
      if (!ok || !mounted) return;
    }
    context.read<TawafBloc>().add(TawafModeSelected(mode));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TawafBloc, TawafState>(
          listenWhen: (prev, cur) =>
              cur is TawafEnded ||
              (cur is TawafReady &&
                  (prev is! TawafReady ||
                      cur.actionSeq != (prev).actionSeq ||
                      (cur.saveFailed && !prev.saveFailed))),
          listener: _onState,
        ),
        BlocListener<DuaAudioCubit, DuaAudioState>(
          listenWhen: (prev, cur) =>
              cur.status == DuaAudioStatus.error &&
              prev.status != DuaAudioStatus.error,
          listener: (context, _) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text(SpiritualStrings.audioUnavailable)),
            ),
        ),
      ],
      child: BlocBuilder<TawafBloc, TawafState>(
        builder: (context, state) => switch (state) {
          TawafReady() => _content(context, state),
          TawafLoading() || TawafEnded() => SpiritualScaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: SpiritualTokens.of(context).accent,
                ),
              ),
            ),
        },
      ),
    );
  }

  Widget _content(BuildContext context, TawafReady state) {
    final s = state.session;
    final bloc = context.read<TawafBloc>();
    return SpiritualScaffold(
      topBar: SpiritualTopBar(
        title: TawafTexts.title(s.mode),
        trailing: SpiritualOutlinedButton(
          label: SpiritualStrings.finishRite,
          onPressed: _confirmFinish,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(
                top: SpiritualSpace.s8,
                bottom: SpiritualSpace.s20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: SpiritualStrings.riteType,
                    container: true,
                    child: SpiritualSegmented<RiteMode>(
                      options: const [
                        SegmentOption(
                          value: RiteMode.tawaf,
                          label: SpiritualStrings.modeTawaf,
                        ),
                        SegmentOption(
                          value: RiteMode.sai,
                          label: SpiritualStrings.modeSai,
                        ),
                      ],
                      value: s.mode,
                      onChanged: (m) => _selectMode(m, state),
                    ),
                  ),
                  const SizedBox(height: SpiritualSpace.s12),
                  TawafCounter(session: s),
                  const SizedBox(height: SpiritualSpace.s12),
                  TawafStatusRow(
                    status: TawafTexts.status(state),
                    flash: _flash,
                    canUndo: s.canUndo,
                    onUndo: _confirmUndo,
                  ),
                  if (state.dua != null) ...[
                    const SizedBox(height: SpiritualSpace.s12),
                    BlocBuilder<DuaAudioCubit, DuaAudioState>(
                      builder: (context, audio) => TawafDuaCard(
                        mode: s.mode,
                        dua: state.dua!,
                        audioStatus: audio.status,
                        onToggleAudio: () {
                          SeenHaptics.select();
                          context
                              .read<DuaAudioCubit>()
                              .toggle(state.dua!.audioAsset);
                        },
                      ),
                    ),
                  ],
                  const Spacer(),
                  const SizedBox(height: SpiritualSpace.s12),
                  SpiritualPrimaryButton(
                    key: const ValueKey('primary'),
                    large: true,
                    leadingIcon: s.done ? null : Icons.add,
                    label: TawafTexts.primaryLabel(s),
                    subtitle: TawafTexts.primaryHint(s),
                    onPressed: () => bloc.add(const TawafPrimaryPressed()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
