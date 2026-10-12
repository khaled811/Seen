import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/prayer_location.dart';
import '../bloc/qibla_cubit.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_bottom_sheet.dart';
import '../widgets/spiritual_chip.dart';

/// Pick a city by hand (or go back to the GPS) when the location is wrong or
/// unavailable. The same choice drives the prayer times.
Future<void> showQiblaCitySheet(
  BuildContext context,
  QiblaCubit cubit, {
  required String? selectedCityId,
}) =>
    showSpiritualBottomSheet<void>(
      context,
      title: SpiritualStrings.chooseCity,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: Wrap(
          spacing: SpiritualSpace.s8,
          runSpacing: SpiritualSpace.s8,
          children: [
            SpiritualChip(
              label: SpiritualStrings.automaticLocation,
              selected: selectedCityId == null,
              onTap: () {
                Navigator.of(sheetContext).pop();
                cubit.relocate(useGps: true);
              },
            ),
            for (final c in SaudiCities.all)
              SpiritualChip(
                label: c.nameAr,
                selected: selectedCityId == c.id,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  cubit.relocate(cityId: c.id);
                },
              ),
          ],
        ),
      ),
    );
