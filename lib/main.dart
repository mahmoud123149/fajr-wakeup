import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: const FajrWakeUpApp(),
    ),
  );
}
