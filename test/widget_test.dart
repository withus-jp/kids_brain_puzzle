import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_brain_puzzle/core/models/game_record.dart';
import 'package:kids_brain_puzzle/main.dart';

import 'helpers/fake_score_repository.dart';

GameRecord _record({
  required String id,
  required int stage,
  required int day,
  int score = 100,
  bool cleared = false,
}) => GameRecord(
  id: id,
  gameId: 'memory_match',
  stage: stage,
  cleared: cleared,
  score: score,
  elapsedSeconds: 75,
  moves: 12,
  playedAt: DateTime(2026, 11, day, 9, 30),
);

void main() {
  testWidgets('허브에 게임 카드 2개와 기록 버튼이 보인다', (tester) async {
    await tester.pumpWidget(
      KidsBrainPuzzleApp(scoreRepository: FakeScoreRepository()),
    );

    expect(find.text('기억력 짝 맞추기'), findsOneWidget);
    expect(find.text('새로운 게임'), findsOneWidget);
    expect(find.text('🔒 준비 중'), findsOneWidget);
    expect(find.text('내 기록 보기'), findsOneWidget);
  });

  testWidgets('기억력 게임 카드를 누르면 Stage 1 게임 화면으로 가고, 뒤로 가면 허브로 돌아온다', (
    tester,
  ) async {
    await tester.pumpWidget(
      KidsBrainPuzzleApp(scoreRepository: FakeScoreRepository()),
    );

    await tester.tap(find.text('기억력 짝 맞추기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stat_stage')), findsOneWidget);
    await tester.tap(find.text('시작!'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('두뇌 퍼즐 놀이터'), findsOneWidget);
  });

  testWidgets('준비 중 카드는 눌러도 이동하지 않는다', (tester) async {
    await tester.pumpWidget(
      KidsBrainPuzzleApp(scoreRepository: FakeScoreRepository()),
    );

    await tester.tap(find.text('새로운 게임'));
    await tester.pumpAndSettle();
    expect(find.text('두뇌 퍼즐 놀이터'), findsOneWidget);
  });

  group('내 기록 화면', () {
    testWidgets('기록이 없으면 안내 문구를 보여 준다', (tester) async {
      await tester.pumpWidget(
        KidsBrainPuzzleApp(scoreRepository: FakeScoreRepository()),
      );

      await tester.tap(find.text('내 기록 보기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('아직 기록이 없어요'), findsOneWidget);
    });

    testWidgets('최고 Stage 순, 같으면 최신순으로 보여 준다', (tester) async {
      final repository = FakeScoreRepository([
        _record(id: 'old3', stage: 3, day: 1),
        _record(id: 'best', stage: 8, day: 2, score: 2400),
        _record(id: 'new3', stage: 3, day: 5),
        _record(id: 's5', stage: 5, day: 4),
      ]);
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(KidsBrainPuzzleApp(scoreRepository: repository));

      await tester.tap(find.text('내 기록 보기'));
      await tester.pumpAndSettle();

      final order = ['best', 's5', 'new3', 'old3'];
      final tops = [
        for (final id in order)
          tester.getTopLeft(find.byKey(ValueKey('record_$id'))).dy,
      ];
      for (var i = 0; i + 1 < tops.length; i++) {
        expect(tops[i], lessThan(tops[i + 1]), reason: '${order[i]} 먼저');
      }

      // 순위와 최고 기록 표시
      final best = find.byKey(const ValueKey('record_best'));
      expect(
        find.descendant(of: best, matching: find.text('1위')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: best, matching: find.text('🏆')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: best, matching: find.text('5x6')),
        findsOneWidget,
        reason: 'Stage 8 = 5x6',
      );
      expect(find.text('Stage 8 · 2400점'), findsOneWidget, reason: '요약');
      expect(find.text('4판'), findsOneWidget);
    });

    testWidgets('기록 한 칸에 점수·시간·시도·날짜·모두 클리어를 보여 준다', (tester) async {
      final repository = FakeScoreRepository([
        _record(id: 'win', stage: 17, day: 24, score: 9000, cleared: true),
      ]);
      await tester.pumpWidget(KidsBrainPuzzleApp(scoreRepository: repository));

      await tester.tap(find.text('내 기록 보기'));
      await tester.pumpAndSettle();
      final tile = find.byKey(const ValueKey('record_win'));
      for (final text in [
        'Stage 17',
        '10x10',
        '🎉 모두 클리어',
        '⭐ 9000점',
        '⏱️ 1:15',
        '🔁 12번',
        '📅 2026.11.24 09:30',
      ]) {
        expect(
          find.descendant(of: tile, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(find.text('모두 클리어! · 9000점'), findsOneWidget);
    });
  });
}
