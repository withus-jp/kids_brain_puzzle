import 'package:flutter_test/flutter_test.dart';
import 'package:kids_brain_puzzle/core/models/game_record.dart';
import 'package:kids_brain_puzzle/repositories/local_score_repository.dart';
import 'package:kids_brain_puzzle/repositories/score_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

GameRecord _record({
  String id = 'run',
  String gameId = 'memory_match',
  int stage = 1,
  bool cleared = false,
  int score = 0,
  int day = 1,
}) => GameRecord(
  id: id,
  gameId: gameId,
  stage: stage,
  cleared: cleared,
  score: score,
  elapsedSeconds: 60,
  moves: 10,
  playedAt: DateTime(2026, 11, day),
);

void main() {
  late LocalScoreRepository repository;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    repository = LocalScoreRepository();
  });

  group('GameRecord', () {
    test('JSON으로 왕복 변환된다', () {
      final record = _record(stage: 7, cleared: true, score: 1234);
      expect(GameRecord.fromJson(record.toJson()), record);
    });

    test('순위: 점수 높은 쪽 → Stage 높은 쪽 → 모두 클리어', () {
      expect(
        _record(
          stage: 4,
          score: 300,
        ).isBetterThan(_record(stage: 9, score: 100)),
        isTrue,
        reason: '점수가 먼저',
      );
      expect(
        _record(
          stage: 5,
          score: 200,
        ).isBetterThan(_record(stage: 4, score: 200)),
        isTrue,
        reason: '점수가 같으면 Stage',
      );
      expect(
        _record(
          stage: 17,
          cleared: true,
          score: 500,
        ).isBetterThan(_record(stage: 17, score: 500)),
        isTrue,
        reason: '그것도 같으면 모두 클리어',
      );
      expect(
        _record(
          stage: 5,
          score: 200,
        ).isBetterThan(_record(stage: 5, score: 200)),
        isFalse,
        reason: '완전히 같으면 더 좋지 않다',
      );
    });
  });

  test('점수가 모두 같으면 Stage 높은 순, 같으면 최신순으로 돌려준다', () async {
    await repository.saveRecord(_record(id: 'a', stage: 3, day: 1));
    await repository.saveRecord(_record(id: 'b', stage: 7, day: 2));
    await repository.saveRecord(_record(id: 'c', stage: 3, day: 5));
    await repository.saveRecord(_record(id: 'd', stage: 10, day: 3));

    final ids = (await repository.getRecords()).map((r) => r.id);
    expect(ids, ['d', 'b', 'c', 'a']);
  });

  test('랭킹 순서: 점수 → Stage → 모두 클리어 → 최신순', () async {
    await repository.saveRecord(
      _record(id: 'new_low', stage: 5, score: 200, day: 9),
    );
    await repository.saveRecord(
      _record(id: 'old_high', stage: 5, score: 300, day: 1),
    );
    await repository.saveRecord(
      _record(id: 'tie_old', stage: 5, score: 100, day: 2),
    );
    await repository.saveRecord(
      _record(id: 'tie_new', stage: 5, score: 100, day: 3),
    );
    await repository.saveRecord(
      _record(id: 'cleared', stage: 17, cleared: true, score: 100, day: 4),
    );
    await repository.saveRecord(
      _record(id: 's9', stage: 9, score: 100, day: 5),
    );
    await repository.saveRecord(
      _record(id: 'top', stage: 3, score: 9999, day: 6),
    );

    final ids = (await repository.getRecords()).map((r) => r.id);
    expect(ids, [
      'top', // 점수가 가장 높다 (Stage는 낮아도)
      'old_high',
      'new_low',
      'cleared', // 100점끼리: 모두 클리어(Stage 17)
      's9', // 100점끼리: Stage 9
      'tie_new', // 100점·Stage 5끼리: 최신순
      'tie_old',
    ]);
    expect(
      (await repository.getBestRecord(gameId: 'memory_match'))?.id,
      ids.first,
      reason: '1위가 곧 최고 기록',
    );
  });

  test('같은 id로 저장하면 덮어쓴다 (이어하기)', () async {
    await repository.saveRecord(_record(id: 'run1', stage: 5, score: 300));
    await repository.saveRecord(_record(id: 'run1', stage: 8, score: 900));

    final records = await repository.getRecords();
    expect(records, hasLength(1));
    expect(records.single.stage, 8);
    expect(records.single.score, 900);
  });

  test('gameId로 거를 수 있다', () async {
    await repository.saveRecord(_record(id: 'a'));
    await repository.saveRecord(_record(id: 'b', gameId: 'other'));
    expect(await repository.getRecords(gameId: 'other'), hasLength(1));
  });

  test('최고 기록 찾기 (excludeId로 같은 판 제외)', () async {
    await repository.saveRecord(_record(id: 'a', stage: 9, score: 50));
    await repository.saveRecord(_record(id: 'b', stage: 4, score: 80));
    await repository.saveRecord(_record(id: 'c', stage: 5, score: 100));

    expect((await repository.getBestRecord(gameId: 'memory_match'))?.id, 'c');
    expect(
      (await repository.getBestRecord(
        gameId: 'memory_match',
        excludeId: 'c',
      ))?.id,
      'b',
    );
    expect(await repository.getBestRecord(gameId: 'nothing'), isNull);
  });

  group('saveAndCheckNewBest', () {
    test('첫 기록은 신기록', () async {
      expect(await repository.saveAndCheckNewBest(_record(id: 'a')), isTrue);
    });

    test('이전 최고보다 좋으면 신기록, 아니면 아니다', () async {
      await repository.saveRecord(_record(id: 'a', stage: 6, score: 500));
      expect(
        await repository.saveAndCheckNewBest(_record(id: 'b', stage: 5)),
        isFalse,
      );
      expect(
        await repository.saveAndCheckNewBest(
          _record(id: 'c', stage: 6, score: 501),
        ),
        isTrue,
      );
      expect(await repository.getRecords(), hasLength(3));
    });

    test('같은 판의 이전 저장분과는 비교하지 않는다', () async {
      // 이어하기 전 게임 오버로 저장된 같은 판
      await repository.saveRecord(_record(id: 'run', stage: 5, score: 900));
      // 이어하기 뒤 다시 게임 오버: 점수가 줄었어도 다른 판보다 좋으면 신기록
      expect(
        await repository.saveAndCheckNewBest(
          _record(id: 'run', stage: 5, score: 400),
        ),
        isTrue,
      );
      expect(await repository.getRecords(), hasLength(1));
    });
  });

  test('새 저장소 인스턴스로 열어도 기록이 남아 있다 (앱 재시작)', () async {
    await repository.saveRecord(_record(id: 'a', stage: 4));
    final reopened = LocalScoreRepository();
    expect((await reopened.getRecords()).single.id, 'a');
  });

  test('형식이 깨진 항목은 건너뛴다', () async {
    await repository.saveRecord(_record(id: 'ok'));
    // 저장된 목록에 깨진 문자열을 섞는다.
    const key = 'game_records_v2';
    final prefs = SharedPreferencesAsync();
    final stored = await prefs.getStringList(key) ?? [];
    await prefs.setStringList(key, [...stored, '{broken']);
    final records = await LocalScoreRepository().getRecords();
    expect(records.map((r) => r.id), ['ok']);
  });

  test('clearAll은 모든 기록을 지운다', () async {
    await repository.saveRecord(_record(id: 'a'));
    await repository.clearAll();
    expect(await repository.getRecords(), isEmpty);
  });
}
