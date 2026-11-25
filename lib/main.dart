import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'repositories/local_score_repository.dart';
import 'repositories/score_repository.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(KidsBrainPuzzleApp(scoreRepository: LocalScoreRepository()));
}

class KidsBrainPuzzleApp extends StatelessWidget {
  const KidsBrainPuzzleApp({super.key, required this.scoreRepository});

  /// 기록 저장소. 온라인 랭킹을 붙일 때는 여기서 구현체만 바꾸면 된다.
  final ScoreRepository scoreRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '고고씽',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HomeScreen(scoreRepository: scoreRepository),
    );
  }
}
