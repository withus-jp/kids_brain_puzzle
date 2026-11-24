import 'package:flutter_test/flutter_test.dart';
import 'package:kids_brain_puzzle/core/models/game_record.dart';
import 'package:kids_brain_puzzle/repositories/local_score_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

GameRecord _record({
  String gameId = 'memory_match',
  String difficulty = 'easy_2x2',
  required int moves,
  required int seconds,
  int day = 1,
}) => GameRecord(
  gameId: gameId,
  difficulty: difficulty,
  moves: moves,
  elapsedSeconds: seconds,
  playedAt: DateTime(2026, 11, day),
);

void main() {
  late LocalScoreRepository repository;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    repository = LocalScoreRepository();
  });

  test('GameRecord는 JSON으로 왕복 변환된다', () {
    final record = _record(moves: 5, seconds: 30);
    expect(GameRecord.fromJson(record.toJson()), record);
  });

  test('저장한 기록을 최신순으로 돌려준다', () async {
    await repository.saveRecord(_record(moves: 5, seconds: 30, day: 1));
    await repository.saveRecord(_record(moves: 4, seconds: 40, day: 3));

    final records = await repository.getRecords();
    expect(records.map((r) => r.playedAt.day), [3, 1]);
  });

  test('최고 기록은 시도 횟수가 적은 순, 같으면 시간이 짧은 순이다', () async {
    await repository.saveRecord(_record(moves: 6, seconds: 10));
    await repository.saveRecord(_record(moves: 4, seconds: 50));
    await repository.saveRecord(_record(moves: 4, seconds: 20));
    await repository.saveRecord(
      _record(difficulty: 'normal_4x4', moves: 20, seconds: 90),
    );

    final best = await repository.getBestRecords();
    expect(best, hasLength(2));
    expect(best.first.difficulty, 'easy_2x2');
    expect(best.first.moves, 4);
    expect(best.first.elapsedSeconds, 20);

    final easyBest = await repository.getBestRecord(
      gameId: 'memory_match',
      difficulty: 'easy_2x2',
    );
    expect(easyBest?.elapsedSeconds, 20);
  });

  test('clearAll은 모든 기록을 지운다', () async {
    await repository.saveRecord(_record(moves: 5, seconds: 30));
    await repository.clearAll();
    expect(await repository.getRecords(), isEmpty);
  });
}
