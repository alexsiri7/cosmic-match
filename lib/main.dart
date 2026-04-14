import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:cosmic_match/models/level_progress.dart';
import 'package:cosmic_match/repositories/progress_repository.dart';
import 'package:cosmic_match/screens/home_screen.dart';

late final ProgressRepository progressRepository;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(LevelProgressAdapter());

  final progressBox = await Hive.openBox<LevelProgress>(
    ProgressRepository.progressBoxName,
  );
  final settingsBox = await Hive.openBox<dynamic>(
    ProgressRepository.settingsBoxName,
  );

  progressRepository = ProgressRepository(
    progressBox: progressBox,
    settingsBox: settingsBox,
  );

  runApp(const CosmicMatchApp());
}

class CosmicMatchApp extends StatelessWidget {
  const CosmicMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
