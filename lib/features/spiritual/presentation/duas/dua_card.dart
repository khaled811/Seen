import 'package:flutter/material.dart';

import '../../domain/entities/dua.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import 'dua_audio_row.dart';

String duaCategoryLabel(DuaCategory c) => switch (c) {
      DuaCategory.hajj => SpiritualStrings.filterHajj,
      DuaCategory.safar => SpiritualStrings.filterSafar,
      DuaCategory.adhkar => SpiritualStrings.filterAdhkar,
      DuaCategory.jawami => SpiritualStrings.filterJawami,
    };

/// One dua (docs/03 §7): a header that expands the card, the text in large
/// type, and when open the usage note, the audio row and the
/// share / copy / save bar.
class DuaCard extends StatelessWidget {
  const DuaCard({
    super.key,
    required this.dua,
    required this.expanded,
    required this.favorite,
    required this.copied,
    required this.onToggle,
    required this.onShare,
    required this.onCopy,
    required this.onFavorite,
  });

  final Dua dua;
  final bool expanded;
  final bool favorite;
  final bool copied;
  final VoidCallback onToggle;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(SpiritualRadius.card);
    return AnimatedContainer(
      duration: SpiritualMotion.of(context, SpiritualMotion.base),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: radius,
        border: Border.all(color: expanded ? t.accentMid : t.borderCard),
        boxShadow: SpiritualTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: AnimatedSize(
          duration: SpiritualMotion.of(context, SpiritualMotion.base),
          curve: SpiritualMotion.baseCurve,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(dua: dua, expanded: expanded, onTap: onToggle),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpiritualSpace.s18,
                  SpiritualSpace.s4,
                  SpiritualSpace.s18,
                  SpiritualSpace.s16,
                ),
                child: Text(
                  dua.text,
                  maxLines: expanded ? null : 2,
                  overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: SpiritualType.dua.copyWith(
                    fontSize: expanded ? 25 : 22,
                    height: 2,
                    color: t.inkPrimary,
                  ),
                ),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpiritualSpace.s18,
                    0,
                    SpiritualSpace.s18,
                    SpiritualSpace.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (dua.note != null && dua.note!.isNotEmpty) ...[
                        Text(
                          dua.note!,
                          style: SpiritualType.caption.copyWith(color: t.inkBody),
                        ),
                        const SizedBox(height: SpiritualSpace.s14),
                      ],
                      if (dua.audioAsset != null) ...[
                        DuaAudioRow(dua: dua),
                        const SizedBox(height: SpiritualSpace.s14),
                      ],
                      _ActionBar(
                        copied: copied,
                        favorite: favorite,
                        onShare: onShare,
                        onCopy: onCopy,
                        onFavorite: onFavorite,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dua, required this.expanded, required this.onTap});

  final Dua dua;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Semantics(
      expanded: expanded,
      child: PressScale(
        onTap: onTap,
        scale: 0.99,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(
            SpiritualSpace.s18,
            SpiritualSpace.s16,
            SpiritualSpace.s18,
            SpiritualSpace.s8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dua.title,
                      style: SpiritualType.bodyStrong.copyWith(
                        fontWeight: FontWeight.w800,
                        color: t.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: SpiritualSpace.s6),
                    Wrap(
                      spacing: SpiritualSpace.s8,
                      runSpacing: SpiritualSpace.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _SourceBadge(label: dua.source),
                        Text(
                          duaCategoryLabel(dua.category),
                          style: SpiritualType.caption.copyWith(
                            fontSize: 14,
                            color: t.inkMuted,
                          ),
                        ),
                        // Only ever visible in debug/profile builds: the
                        // repository drops unreviewed duas in release.
                        if (!dua.reviewed) const _ReviewTag(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpiritualSpace.s12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: t.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: SpiritualMotion.of(context, SpiritualMotion.base),
                  curve: SpiritualMotion.baseCurve,
                  child: Icon(Icons.keyboard_arrow_down, size: 22, color: t.inkPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "صحيح مسلم" with a book glyph: where the dua is reported from.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s10),
      decoration: BoxDecoration(
        color: t.segmentTrack.withOpacity(0.6),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 14, color: t.inkBody),
          const SizedBox(width: SpiritualSpace.s4),
          Flexible(
            child: Text(
              label,
              style: SpiritualType.micro.copyWith(color: t.inkBody),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTag extends StatelessWidget {
  const _ReviewTag();

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s10),
      decoration: BoxDecoration(
        color: t.amberBar.withOpacity(0.18),
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Text(
        SpiritualStrings.duaUnderReview,
        style: SpiritualType.micro.copyWith(color: t.amber),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.copied,
    required this.favorite,
    required this.onShare,
    required this.onCopy,
    required this.onFavorite,
  });

  final bool copied;
  final bool favorite;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.ios_share,
            label: SpiritualStrings.duaShare,
            onTap: onShare,
          ),
        ),
        const SizedBox(width: SpiritualSpace.s8),
        Expanded(
          child: _ActionButton(
            icon: copied ? Icons.check : Icons.copy_outlined,
            label: copied ? SpiritualStrings.duaCopied : SpiritualStrings.duaCopy,
            onTap: onCopy,
          ),
        ),
        const SizedBox(width: SpiritualSpace.s8),
        Expanded(
          child: _ActionButton(
            icon: favorite ? Icons.bookmark : Icons.bookmark_border,
            label: favorite ? SpiritualStrings.duaSaved : SpiritualStrings.duaSave,
            onTap: onFavorite,
            highlighted: favorite,
            emphasize: true,
          ),
        ),
      ],
    );
  }
}

/// 52 dp action button. [highlighted] tints it with the accent; [emphasize]
/// plays the 1 → 1.15 → 1 pop when it becomes highlighted.
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final bool emphasize;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  // Owned here: created with the state, disposed in dispose().
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: SpiritualMotion.emphasis,
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
  ]);

  @override
  void didUpdateWidget(_ActionButton old) {
    super.didUpdateWidget(old);
    if (widget.emphasize &&
        widget.highlighted &&
        !old.highlighted &&
        !SpiritualMotion.reduced(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final fg = widget.highlighted ? t.accent : t.inkPrimary;
    final radius = BorderRadius.circular(SpiritualRadius.control);
    return Semantics(
      toggled: widget.emphasize ? widget.highlighted : null,
      child: PressScale(
        onTap: widget.onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: SpiritualMotion.of(context, SpiritualMotion.fast),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: SpiritualSpace.s6,
            vertical: SpiritualSpace.s8,
          ),
          decoration: BoxDecoration(
            color: widget.highlighted ? t.accentTint : t.surface,
            borderRadius: radius,
            border: Border.all(
              color: widget.highlighted ? t.accentMid : t.borderControl,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pop.drive(_scale),
                  child: Icon(widget.icon, size: 20, color: fg),
                ),
                const SizedBox(width: SpiritualSpace.s6),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SpiritualType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
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
