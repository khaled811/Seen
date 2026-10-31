import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/network/network_config.dart';
import 'core/storage/legacy_data_purger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NetworkConfig.validate();
  InjectionContainer.instance.init();
  // Drop what earlier versions stored on the device: traveler drafts, recent
  // searches and the persisted access token / session (now memory-only).
  unawaited(LegacyDataPurger(InjectionContainer.instance.secureStorage).purge(purgeSession: true));
  runApp(const App());
}
