import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_brain_puzzle/core/models/game_record.dart';
import 'package:kids_brain_puzzle/main.dart';
import 'package:kids_brain_puzzle/repositories/score_repository.dart';

/// 테스트용 메모리 저장소. UI가 인터페이스에만 의존하는지도 함께 확인한다.
class FakeScoreRepository implements ScoreRepository {
  FakeScoreRepository([List<GameRecord>? records]) : records = records ?? [];

  final List<GameRecord> records;

  @override
  Future<void> saveRecord(GameRecord record) async => records.add(record);

  @override
  Future<List<GameRecord>> getRecords({String? gameId}) async =>
      records.where((r) => gameId == null || r.gameId == gameId).toList();

  @override
  Future<List<GameRecord>> getBestRecords() async => records;

  @override
  Future<GameRecord?> getBestRecord({
    required String gameId,
    required String difficulty,
  }) async =>
      null;

  @override
  Future<void> clearAll() async => records.clear();
}

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

  testWidgets('기억력 게임 카드를 누르면 임시 화면으로 가고, 뒤로 가면 허브로 돌아온다',
      (tester) async {
    await tester.pumpWidget(
      KidsBrainPuzzleApp(scoreRepository: FakeScoreRepository()),
    );

    await tester.tap(find.text('기억력 짝 맞추기'));
    await tester.pumpAndSettle();
    expect(
      find.text('기억력 짝 맞추기 게임 화면 (Phase 2에서 구현 예정)'),
      findsOneWidget,
    );

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

  testWidgets('기록이 없으면 안내 문구를 보여 준다', (tester) async {
    await tester.pumpWidget(
      KidsBrainPuzzleApp(scoreRepository: FakeScoreRepository()),
    );

    await tester.tap(find.text('내 기록 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 기록이 없어요'), findsOneWidget);
  });

  testWidgets('저장된 최고 기록을 보여 준다', (tester) async {
    final repository = FakeScoreRepository([
      GameRecord(
        gameId: 'memory_match',
        difficulty: 'easy_2x2',
        moves: 3,
        elapsedSeconds: 75,
        playedAt: DateTime(2026, 11, 24),
      ),
    ]);
    await tester.pumpWidget(KidsBrainPuzzleApp(scoreRepository: repository));

    await tester.tap(find.text('내 기록 보기'));
    await tester.pumpAndSettle();
    expect(find.text('쉬움 (2x2)'), findsOneWidget);
    expect(find.text('🔁 3번'), findsOneWidget);
    expect(find.text('⏱️ 1:15'), findsOneWidget);
  });
}
