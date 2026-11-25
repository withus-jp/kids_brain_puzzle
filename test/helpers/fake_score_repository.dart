import 'package:kids_brain_puzzle/core/models/game_record.dart';
import 'package:kids_brain_puzzle/repositories/score_repository.dart';

/// 테스트용 메모리 저장소. UI가 [ScoreRepository] 인터페이스에만 의존하는지도
/// 함께 확인한다. [LocalScoreRepository]와 같은 규칙(같은 id 덮어쓰기, 정렬)을 따른다.
class FakeScoreRepository implements ScoreRepository {
  FakeScoreRepository([List<GameRecord>? records]) : records = [...?records];

  final List<GameRecord> records;

  /// [saveRecord]가 불린 횟수
  int saveCount = 0;

  /// `true`면 [saveRecord]가 실패한다 (저장 실패 처리 확인용).
  bool failOnSave = false;

  @override
  Future<void> saveRecord(GameRecord record) async {
    if (failOnSave) throw StateError('저장 실패 (테스트)');
    saveCount++;
    records
      ..removeWhere((r) => r.id == record.id)
      ..add(record);
  }

  @override
  Future<List<GameRecord>> getRecords({String? gameId}) async =>
      records.where((r) => gameId == null || r.gameId == gameId).toList()
        ..sort(GameRecord.compareByStageThenRecent);

  @override
  Future<GameRecord?> getBestRecord({
    required String gameId,
    String? excludeId,
  }) async {
    GameRecord? best;
    for (final r in records) {
      if (r.gameId != gameId || r.id == excludeId) continue;
      if (best == null || r.isBetterThan(best)) best = r;
    }
    return best;
  }

  @override
  Future<void> clearAll() async => records.clear();
}
