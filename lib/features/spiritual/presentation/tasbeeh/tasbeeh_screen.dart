import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/arabic_digits.dart';
import '../../core/seen_haptics.dart';
import '../../di/tasbeeh_module.dart';
import '../../domain/entities/tasbeeh.dart';
import '../bloc/tasbeeh_cubit.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_bottom_sheet.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_confirm_dialog.dart';
import '../widgets/spiritual_icon_button.dart';
import '../widgets/spiritual_outlined_button.dart';
import '../widgets/spiritual_segmented.dart';
import '../widgets/spiritual_top_bar.dart';
import 'tasbeeh_surface.dart';

/// Digital tasbeeh (Screen 8): full screen, no bottom navigation, the display
/// kept awake while it is open.
class TasbeehScreen extends StatelessWidget {
  const TasbeehScreen({super.key, this.module});

  final TasbeehModule? module;

  static Route<void> route({TasbeehModule? module}) =>
      MaterialPageRoute<void>(builder: (_) => TasbeehScreen(module: module));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (module ?? TasbeehModule.instance).createCubit()..load(),
      child: const SpiritualTheme(child: _TasbeehView()),
    );
  }
}

class _TasbeehView extends StatelessWidget {
  const _TasbeehView();

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return BlocConsumer<TasbeehCubit, TasbeehState>(
      listenWhen: (p, c) => c.saveFailed && !p.saveFailed,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(SpiritualStrings.saveFailed)),
          );
      },
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.progress != c.progress ||
          p.adhkar != c.adhkar,
      builder: (context, state) => Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: switch (state.status) {
            TasbeehStatus.loading => Center(
                child: CircularProgressIndicator(color: t.accent),
              ),
            TasbeehStatus.failure => _Failure(
                onRetry: () => context.read<TasbeehCubit>().load(),
              ),
            TasbeehStatus.ready => _Body(state: state),
          },
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            SpiritualStrings.loadFailed,
            style: SpiritualType.body.copyWith(color: t.inkBody),
          ),
          const SizedBox(height: SpiritualSpace.s12),
          SpiritualOutlinedButton(
            label: SpiritualStrings.retry,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final TasbeehState state;

  Future<void> _confirmReset(BuildContext context) async {
    final cubit = context.read<TasbeehCubit>();
    if ((cubit.state.progress?.count ?? 0) == 0) return;
    final ok = await showSpiritualConfirm(
      context,
      title: SpiritualStrings.tasbeehResetTitle,
      message: SpiritualStrings.tasbeehResetMessage,
      confirmLabel: SpiritualStrings.tasbeehReset,
    );
    if (!ok || cubit.isClosed) return;
    SeenHaptics.reset();
    cubit.reset();
  }

  void _tap(BuildContext context) {
    final reached = context.read<TasbeehCubit>().tap();
    if (reached) {
      SeenHaptics.targetReached();
      SemanticsService.announce(SpiritualStrings.roundComplete, TextDirection.rtl);
    } else {
      SeenHaptics.select();
    }
  }

  void _pickDhikr(BuildContext context) {
    final cubit = context.read<TasbeehCubit>();
    showSpiritualBottomSheet<void>(
      context,
      title: SpiritualStrings.pickDhikr,
      builder: (sheetContext) => _DhikrOptions(
        adhkar: state.adhkar,
        selectedId: state.progress!.dhikrId,
        onPick: (id) {
          SeenHaptics.select();
          cubit.selectDhikr(id);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = state.progress!;
    final dhikr = state.dhikr?.label ?? '';
    final cubit = context.read<TasbeehCubit>();
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SpiritualSpace.gutter,
              SpiritualSpace.s8,
              SpiritualSpace.gutter,
              SpiritualSpace.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpiritualTopBar(
                  title: SpiritualStrings.tasbeehTitle,
                  leading: SpiritualIconButton(
                    icon: Icons.close,
                    semanticLabel: SpiritualStrings.closeTasbeeh,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  trailing: SpiritualOutlinedButton(
                    label: SpiritualStrings.tasbeehReset,
                    onPressed: () => _confirmReset(context),
                  ),
                ),
                const SizedBox(height: SpiritualSpace.s14),
                _DhikrSelector(label: dhikr, onTap: () => _pickDhikr(context)),
                const SizedBox(height: SpiritualSpace.s14),
                Semantics(
                  label: SpiritualStrings.targetLabel,
                  child: SpiritualSegmented<TasbeehTarget>(
                    options: [
                      SegmentOption(
                        value: TasbeehTarget.thirtyThree,
                        label: toArabicDigits(33),
                      ),
                      SegmentOption(
                        value: TasbeehTarget.hundred,
                        label: toArabicDigits(100),
                      ),
                      const SegmentOption(
                        value: TasbeehTarget.open,
                        label: SpiritualStrings.targetOpen,
                      ),
                    ],
                    value: progress.target,
                    onChanged: (target) {
                      SeenHaptics.select();
                      cubit.selectTarget(target);
                    },
                  ),
                ),
                const SizedBox(height: SpiritualSpace.s14),
                Expanded(
                  child: TasbeehSurface(
                    progress: progress,
                    dhikrLabel: dhikr,
                    onTap: () => _tap(context),
                  ),
                ),
                const SizedBox(height: SpiritualSpace.s14),
                _Stats(
                  rounds: progress.today.rounds,
                  total: progress.today.total,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DhikrSelector extends StatelessWidget {
  const _DhikrSelector({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(18);
    return PressScale(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: '${SpiritualStrings.currentDhikr}: $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: SpiritualSpace.s18,
          vertical: SpiritualSpace.s8,
        ),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: radius,
          border: Border.all(color: t.borderControl),
          boxShadow: SpiritualTokens.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    SpiritualStrings.currentDhikr,
                    style: SpiritualType.micro.copyWith(
                      fontWeight: FontWeight.w500,
                      color: t.inkMuted,
                    ),
                  ),
                  Text(
                    label,
                    style: SpiritualType.title.copyWith(color: t.inkPrimary),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 26, color: t.inkPrimary),
          ],
        ),
      ),
    );
  }
}

class _DhikrOptions extends StatelessWidget {
  const _DhikrOptions({
    required this.adhkar,
    required this.selectedId,
    required this.onPick,
  });

  final List<TasbeehDhikr> adhkar;
  final String selectedId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final d in adhkar)
          Padding(
            padding: const EdgeInsets.only(bottom: SpiritualSpace.s4),
            child: Semantics(
              selected: d.id == selectedId,
              child: PressScale(
                onTap: () => onPick(d.id),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s14),
                  decoration: BoxDecoration(
                    color: d.id == selectedId ? t.accentTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.label,
                          style: SpiritualType.bodyStrong.copyWith(
                            fontWeight: d.id == selectedId
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: d.id == selectedId ? t.accent : t.inkPrimary,
                          ),
                        ),
                      ),
                      if (d.id == selectedId)
                        Icon(Icons.check, size: 22, color: t.accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.rounds, required this.total});

  final int rounds;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: SpiritualStrings.roundsCompleted,
            value: toArabicDigits(rounds),
          ),
        ),
        const SizedBox(width: SpiritualSpace.s12),
        Expanded(
          child: _StatCard(
            label: SpiritualStrings.todayTotal,
            value: toArabicDigits(total),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: SpiritualCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(
            horizontal: SpiritualSpace.s16,
            vertical: SpiritualSpace.s12,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: SpiritualType.caption.copyWith(
                    fontSize: 14,
                    color: t.inkMuted,
                  ),
                ),
                Text(
                  value,
                  style: SpiritualType.section.copyWith(
                    fontSize: 22,
                    color: t.inkPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
