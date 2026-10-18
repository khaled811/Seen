// Choose the hospital (Figma BOOK-10): each hospital with the places it has left this
// week; a full one is dimmed and cannot be chosen. Opened before the medical-visa request.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/hospital.dart';
import '../bloc/hospital_picker_cubit.dart';

extension _Strings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  String get chooseHospital => _t('اختر المستشفى', 'Choose the hospital');
  String get remainingThisWeek => _t('السعة المتبقية هذا الأسبوع', 'Places left this week');
  String seatsLeft(int n) => _t('${numeral(n)} مقعد متبقٍ', '$n places left');
  String get hospitalFull => _t('مكتمل', 'Full');
  String get hospitalNextStep => _t('بعد اختيار المستشفى ننتقل تلقائيًا إلى طلب التأشيرة العلاجية.',
      'After you choose the hospital we go straight to the medical visa request.');
  String get continueToVisa => _t('متابعة إلى التأشيرة', 'Continue to the visa');
  String get allHospitalsFull =>
      _t('كل المستشفيات مكتملة هذا الأسبوع. جرّب الأسبوع القادم.', 'Every hospital is full this week. Try next week.');
  String get hospitalsLoadFailed => _t('تعذّر تحميل المستشفيات.', 'Could not load the hospitals.');
}

/// Opens the picker for the medical service [serviceId]; resolves the chosen hospital or null.
/// [createCubit] is a test seam.
Future<HospitalChoice?> showHospitalPickerSheet(
  BuildContext context, {
  required String serviceId,
  HospitalPickerCubit Function()? createCubit,
}) {
  return showModalBottomSheet<HospitalChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) => (createCubit ?? () => InjectionContainer.instance.createHospitalPickerCubit(serviceId))()..load(),
      child: const _Body(),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    return BlocBuilder<HospitalPickerCubit, HospitalPickerState>(
      builder: (context, state) {
        final cubit = context.read<HospitalPickerCubit>();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.chooseHospital, style: t.h2),
                        Text(s.remainingThisWeek, style: t.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                  SeenIconButton(icon: SeenIcons.x, semanticLabel: s.close, onPressed: () => Navigator.of(context).maybePop()),
                ],
              ),
              const SizedBox(height: 16),
              switch (state.status) {
                HospitalsStatus.loading => Semantics(
                    label: s.loadingLabel,
                    child: const ExcludeSemantics(
                      child: SeenSkeletonGroup(
                        child: Column(children: [
                          SeenSkeletonBox(height: 70, radius: 16),
                          SizedBox(height: 12),
                          SeenSkeletonBox(height: 70, radius: 16),
                        ]),
                      ),
                    ),
                  ),
                HospitalsStatus.failure => Column(
                    children: [
                      Text(s.hospitalsLoadFailed, textAlign: TextAlign.center, style: t.body),
                      const SizedBox(height: 12),
                      SeenButton(label: s.retryAction, onPressed: cubit.load),
                    ],
                  ),
                HospitalsStatus.loaded => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final h in state.hospitals) ...[
                        _HospitalRow(hospital: h, selected: h.id == state.selectedId, onTap: () => cubit.select(h.id)),
                        const SizedBox(height: 12),
                      ],
                      if (state.allFull) ...[
                        SeenInlineBanner(tone: SeenBannerTone.warn, message: s.allHospitalsFull),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
              },
              if (state.status == HospitalsStatus.loaded && !state.allFull) ...[
                SeenInlineBanner(tone: SeenBannerTone.info, message: s.hospitalNextStep),
                const SizedBox(height: 16),
              ],
              SeenButton(
                label: s.continueToVisa,
                expand: true,
                onPressed: state.selected == null
                    ? null
                    : () => Navigator.of(context).pop(HospitalChoice(id: state.selected!.id, name: state.selected!.name)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HospitalRow extends StatelessWidget {
  const _HospitalRow({required this.hospital, required this.selected, required this.onTap});

  final Hospital hospital;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final tone = hospital.isFull
        ? SeenRequestStatus.rejected
        : (hospital.isLow ? SeenRequestStatus.actionRequired : SeenRequestStatus.completed);
    final fill = hospital.isFull ? tone.colors.fg : (hospital.isLow ? SeenBrand.progressWaiting : SeenBrand.violet);
    const radius = BorderRadius.all(Radius.circular(16));
    return Opacity(
      opacity: hospital.isFull ? .6 : 1,
      child: Semantics(
        button: !hospital.isFull,
        selected: selected,
        enabled: !hospital.isFull,
        label: '${hospital.name}, ${hospital.isFull ? s.hospitalFull : s.seatsLeft(hospital.remaining)}',
        excludeSemantics: true,
        child: Material(
          color: selected ? SeenBrand.violet05 : c.card,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: selected ? SeenBrand.violet : c.border),
          ),
          child: InkWell(
            onTap: hospital.isFull ? null : onTap,
            customBorder: const RoundedRectangleBorder(borderRadius: radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      SeenRadioDot(selected: selected),
                      const SizedBox(width: 10),
                      Expanded(child: Text(hospital.name, style: t.label)),
                      SeenStatusChip(
                        status: tone,
                        label: hospital.isFull ? s.hospitalFull : s.seatsLeft(hospital.remaining),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _UsedBar(fraction: hospital.usedFraction, color: fill),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How much of the week's places are taken, in the status colour (drawn from the reading start).
class _UsedBar extends StatelessWidget {
  const _UsedBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: SeenBrand.progressTodo, borderRadius: BorderRadius.all(SeenRadius.full)),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.all(Radius.circular(3))),
              child: const SizedBox(height: 6),
            ),
          ),
        ),
      ),
    );
  }
}
