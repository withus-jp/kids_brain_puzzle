import 'package:flutter/material.dart';

/// 게임 허브에 표시되는 게임 한 개의 메타데이터.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    this.difficultyLabels = const {},
    this.screenBuilder,
  });

  /// 게임 식별자. [GameRecord.gameId]와 같은 값을 쓴다.
  final String id;
  final String title;
  final String description;
  final String emoji;

  /// 허브 카드 배경색 (파스텔 톤)
  final Color color;

  /// 난이도 코드 → 화면 표시용 이름 (예: `easy_2x2` → `쉬움 (2x2)`)
  final Map<String, String> difficultyLabels;

  /// 게임 화면을 만드는 함수. `null`이면 '준비 중' 게임이다.
  final WidgetBuilder? screenBuilder;

  bool get isComingSoon => screenBuilder == null;

  String difficultyLabel(String difficulty) =>
      difficultyLabels[difficulty] ?? difficulty;
}
