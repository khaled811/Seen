// Agency details and commercial register (Figma ACC-01): the agency's data, the
// verification status, and its documents with how long each one is still valid.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../support/presentation/widgets/contact_support_sheet.dart';
import '../../../system_status/domain/services/store_launcher.dart';
import '../../domain/entities/agency_profile.dart';
import '../bloc/profile_cubits.dart';
import '../widgets/profile_strings.dart';

class AgencyDetailsScreen extends StatelessWidget {
  const AgencyDetailsScreen({super.key, this.createCubit, this.launcher, this.now});

  /// Test seams; default to the DI container and the real clock.
  final AgencyDetailsCubit Function()? createCubit;
  final StoreLauncher? launcher;
  final DateTime? now;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const AgencyDetailsScreen());

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createAgencyDetailsCubit)()..load(),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: SeenColors.of(context).card,
          body: SeenScreenBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(
                    title: s.agencyDetailsTitle,
                    trailing: SeenTextLink(
                      label: s.editAction,
                      onTap: () => _showSupportInfo(context, s.editAgencyInfo),
                    ),
                  ),
                  Expanded(child: _Body(launcher: launcher, now: now)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Editing and renewing have no in-app flow yet (no upload / edit contract):
/// say so and offer the support channels instead of a dead button.
void _showSupportInfo(BuildContext context, String body) {
  final s = SeenStrings.of(context);
  showSeenSheet<void>(
    context: context,
    title: s.contactSupportAction,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(body, style: SeenType.of(sheet).body),
        const SizedBox(height: SeenSpace.s4),
        SeenButton(
          label: s.contactSupportAction,
          expand: true,
          onPressed: () {
            Navigator.of(sheet).pop();
            showContactSupportSheet(context);
          },
        ),
      ],
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({this.launcher, this.now});

  final StoreLauncher? launcher;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return BlocBuilder<AgencyDetailsCubit, AgencyDetailsState>(
      builder: (context, state) {
        final profile = state.profile;
        if (profile == null) {
          if (state.status == LoadStatus.failure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.loadFailedTitle),
                  const SizedBox(height: SeenSpace.s3),
                  SeenButton(label: s.retry, onPressed: () => context.read<AgencyDetailsCubit>().load()),
                ],
              ),
            );
          }
          return SeenCardsSkeleton(label: SeenStrings.of(context).loadingLabel);
        }
        return RefreshIndicator(
          onRefresh: () => context.read<AgencyDetailsCubit>().load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, SeenSpace.s6),
            children: [
              _DetailsCard(profile: profile),
              const SizedBox(height: 14),
              _VerifyBanner(profile: profile),
              const SizedBox(height: 14),
              Text(s.documentsTitle, style: SeenType.of(context).title),
              const SizedBox(height: 12),
              for (final d in profile.documents) ...[
                _DocRow(doc: d, launcher: launcher, now: now),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.profile});

  final AgencyProfile profile;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    Widget row(String label, String value, {bool ltr = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(label, style: t.body.copyWith(color: c.inkSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ltr ? SeenFormat.isolate(value) : value,
                  textAlign: TextAlign.end,
                  style: t.bodyStrong,
                ),
              ),
            ],
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row(s.agencyName, profile.name),
            row(s.licenseNumber, profile.licenseNumber, ltr: true),
            row(s.cityLabel, profile.city),
            row(s.managerLabel, profile.managerName),
          ],
        ),
      ),
    );
  }
}

class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({required this.profile});

  final AgencyProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final (chip, tone) = switch (profile.verification) {
      AgencyVerification.verified => (SeenRequestStatus.confirmed, SeenRequestStatus.completed),
      AgencyVerification.pending => (SeenRequestStatus.underReview, SeenRequestStatus.underReview),
      AgencyVerification.rejected => (SeenRequestStatus.rejected, SeenRequestStatus.rejected),
      AgencyVerification.unverified => (SeenRequestStatus.cancelled, SeenRequestStatus.cancelled),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.colors.bg,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                s.verificationLine(profile.verification, profile.verifiedAt),
                style: t.label.copyWith(color: tone.colors.fg),
              ),
            ),
            const SizedBox(width: 8),
            SeenStatusChip(status: chip, label: s.verificationChip(profile.verification)),
          ],
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, this.launcher, this.now});

  final AgencyDocument doc;
  final StoreLauncher? launcher;
  final DateTime? now;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = SeenStrings.of(context);
    final url = doc.viewUrl;
    final ok = url != null && await (launcher ?? InjectionContainer.instance.storeLauncher).open(url);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.documentUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final expiry = doc.expiry(now ?? DateTime.now());
    final needsRenewal = expiry == DocumentExpiry.soon || expiry == DocumentExpiry.expired;
    final line = s.documentExpiryLine(doc, now ?? DateTime.now());
    final lineColor = switch (expiry) {
      DocumentExpiry.soon => SeenRequestStatus.actionRequired.colors.fg,
      DocumentExpiry.expired => SeenRequestStatus.rejected.colors.fg,
      _ => c.inkMuted,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(11))),
              child: SizedBox(width: 36, height: 36, child: Icon(SeenIcons.file, size: 20, color: SeenBrand.violet)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.documentName(doc.kind), style: t.label),
                  if (line.isNotEmpty) Text(line, style: t.caption.copyWith(color: lineColor)),
                ],
              ),
            ),
            if (needsRenewal)
              SeenButton.secondary(
                label: s.renewAction,
                size: SeenButtonSize.small,
                onPressed: () => _showSupportInfo(context, s.renewInfo),
              )
            else
              SeenButton.ghost(
                label: s.viewAction,
                size: SeenButtonSize.small,
                onPressed: doc.viewUrl == null ? null : () => _open(context),
              ),
          ],
        ),
      ),
    );
  }
}
