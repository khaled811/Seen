import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/seen_haptics.dart';
import '../../di/dua_module.dart';
import '../../domain/entities/dua_filter.dart';
import '../bloc/duas_cubit.dart';
import '../spiritual_strings.dart';
import '../tasbeeh/tasbeeh_screen.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_chip_row.dart';
import '../widgets/spiritual_icon_button.dart';
import '../widgets/spiritual_outlined_button.dart';
import '../widgets/spiritual_search_field.dart';
import '../widgets/spiritual_top_bar.dart';
import 'dua_card.dart';

/// Supplications library (Screen 7).
class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key, this.module});

  final DuaModule? module;

  static Route<void> route({DuaModule? module}) =>
      MaterialPageRoute<void>(builder: (_) => DuasScreen(module: module));

  @override
  Widget build(BuildContext context) {
    final m = module ?? DuaModule.instance;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => m.createCubit()..load()),
        BlocProvider(create: (_) => m.createPlayerCubit()),
      ],
      child: const SpiritualTheme(child: _DuasView()),
    );
  }
}

class _DuasView extends StatelessWidget {
  const _DuasView();

  static const _chips = {
    DuaFilter.all: SpiritualStrings.filterAll,
    DuaFilter.hajj: SpiritualStrings.filterHajj,
    DuaFilter.safar: SpiritualStrings.filterSafar,
    DuaFilter.adhkar: SpiritualStrings.filterAdhkar,
    DuaFilter.jawami: SpiritualStrings.filterJawami,
    DuaFilter.saved: SpiritualStrings.filterSaved,
  };

  static String? _message(DuasNotice n) => switch (n) {
        DuasNotice.none => null,
        DuasNotice.shareFailed => SpiritualStrings.duaShareFailed,
        DuasNotice.copyFailed => SpiritualStrings.duaCopyFailed,
        DuasNotice.saveFailed => SpiritualStrings.duaSaveFailed,
      };

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final cubit = context.read<DuasCubit>();
    return BlocListener<DuasCubit, DuasState>(
      listenWhen: (p, c) => c.noticeSeq != p.noticeSeq,
      listener: (context, state) {
        final message = _message(state.notice);
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpiritualSpace.gutter,
                  SpiritualSpace.s8,
                  SpiritualSpace.gutter,
                  0,
                ),
                child: SpiritualTopBar(
                  title: SpiritualStrings.duasTitle,
                  trailing: SpiritualIconButton(
                    icon: Icons.blur_circular,
                    color: t.accent,
                    semanticLabel: SpiritualStrings.tasbeehShortcut,
                    onPressed: () =>
                        Navigator.of(context).push(TasbeehScreen.route()),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.gutter),
                child: SpiritualSearchField(
                  hint: SpiritualStrings.duaSearchHint,
                  onChanged: cubit.search,
                  onCleared: () => cubit.search(''),
                ),
              ),
              const SizedBox(height: SpiritualSpace.s12),
              BlocBuilder<DuasCubit, DuasState>(
                buildWhen: (p, c) => p.filter != c.filter,
                builder: (context, state) => Semantics(
                  label: SpiritualStrings.filtersLabel,
                  child: SpiritualChipRow<DuaFilter>(
                    labels: _chips,
                    selected: state.filter,
                    onSelected: (f) {
                      SeenHaptics.select();
                      cubit.selectFilter(f);
                    },
                  ),
                ),
              ),
              const SizedBox(height: SpiritualSpace.s8),
              const Expanded(child: _DuaList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuaList extends StatelessWidget {
  const _DuaList();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DuasCubit>();
    return BlocBuilder<DuasCubit, DuasState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.visible != c.visible ||
          p.favorites != c.favorites ||
          p.openId != c.openId ||
          p.copiedId != c.copiedId,
      builder: (context, state) {
        switch (state.status) {
          case DuasStatus.loading:
            return Center(
              child: CircularProgressIndicator(
                color: SpiritualTokens.of(context).accent,
              ),
            );
          case DuasStatus.failure:
            return _Message(
              text: SpiritualStrings.loadFailed,
              action: SpiritualOutlinedButton(
                label: SpiritualStrings.retry,
                onPressed: cubit.load,
              ),
            );
          case DuasStatus.ready:
            if (state.visible.isEmpty) {
              return _Message(text: _emptyText(state));
            }
            return ListView.separated(
              // A new filter or search starts from the top.
              key: ValueKey((state.filter, state.query)),
              padding: const EdgeInsets.fromLTRB(
                SpiritualSpace.gutter,
                SpiritualSpace.s4,
                SpiritualSpace.gutter,
                SpiritualSpace.s24,
              ),
              itemCount: state.visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: SpiritualSpace.s12),
              itemBuilder: (context, i) {
                final dua = state.visible[i];
                return DuaCard(
                  key: ValueKey(dua.id),
                  dua: dua,
                  expanded: state.openId == dua.id,
                  favorite: state.favorites.contains(dua.id),
                  copied: state.copiedId == dua.id,
                  onToggle: () {
                    SeenHaptics.select();
                    cubit.toggleOpen(dua.id);
                  },
                  onShare: () => cubit.share(dua),
                  onCopy: () {
                    SeenHaptics.light();
                    cubit.copy(dua);
                  },
                  onFavorite: () {
                    SeenHaptics.light();
                    cubit.toggleFavorite(dua.id);
                  },
                );
              },
            );
        }
      },
    );
  }

  static String _emptyText(DuasState s) {
    if (s.query.trim().isNotEmpty) return SpiritualStrings.duasEmptySearch;
    if (s.filter == DuaFilter.saved) return SpiritualStrings.duasEmptySaved;
    return SpiritualStrings.duasEmptyAll;
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpiritualSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: SpiritualType.body.copyWith(color: t.inkBody),
            ),
            if (action != null) ...[
              const SizedBox(height: SpiritualSpace.s12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
