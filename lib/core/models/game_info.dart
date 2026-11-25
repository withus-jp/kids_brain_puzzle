import 'package:flutter/material.dart';

import '../../repositories/score_repository.dart';

/// 게임 화면을 만드는 함수. 기록을 저장할 수 있도록 [ScoreRepository]를 받는다.
typedef GameScreenBuilder = Widget Function(
  BuildContext context,
  ScoreRepository scoreRepository,
);

/// 게임 허브에 표시되는 게임 한 개의 메타데이터.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    this.stageDetail,
    this.screenBuilder,
  });

  /// 게임 식별자. [GameRecord.gameId]와 같은 값을 쓴다.
  final String id;
  final String title;
  final String description;
  final String emoji;

  /// 허브 카드 배경색 (파스텔 톤)
  final Color color;

  /// 내 기록 화면에서 Stage 옆에 붙일 설명 (예: Stage 4 → `3x4`). 없으면 생략.
  final String Function(int stage)? stageDetail;

  /// 게임 화면을 만드는 함수. `null`이면 '준비 중' 게임이다.
  final GameScreenBuilder? screenBuilder;

  bool get isComingSoon => screenBuilder == null;
}
