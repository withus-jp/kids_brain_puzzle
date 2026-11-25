import '../core/models/game_record.dart';

/// 게임 기록 저장소 인터페이스.
///
/// UI는 이 인터페이스로만 기록에 접근한다. 지금은 [LocalScoreRepository]를
/// 쓰고, 나중에 온라인 랭킹 API 구현체로 바꿀 수 있다.
abstract interface class ScoreRepository {
  /// 기록을 저장한다. 같은 [GameRecord.id]가 이미 있으면 새 기록으로 덮어쓴다.
  Future<void> saveRecord(GameRecord record);

  /// 저장된 기록을 도달 Stage가 높은 순, 같으면 최신순으로 돌려준다.
  /// [gameId]를 주면 그 게임만 돌려준다.
  Future<List<GameRecord>> getRecords({String? gameId});

  /// [gameId]의 최고 기록 ([GameRecord.isBetterThan] 기준). 없으면 `null`.
  /// [excludeId]를 주면 그 id의 기록은 빼고 찾는다 (같은 판의 이전 저장분 제외용).
  Future<GameRecord?> getBestRecord({
    required String gameId,
    String? excludeId,
  });

  /// 모든 기록을 지운다.
  Future<void> clearAll();
}

/// [ScoreRepository]에 기록을 저장하고 신기록인지 알려 준다.
extension SaveWithNewBest on ScoreRepository {
  /// [record]를 저장하고, 저장 전의 다른 판 기록보다 좋았으면 `true`.
  /// 첫 기록도 신기록이다.
  Future<bool> saveAndCheckNewBest(GameRecord record) async {
    final previousBest = await getBestRecord(
      gameId: record.gameId,
      excludeId: record.id,
    );
    await saveRecord(record);
    return previousBest == null || record.isBetterThan(previousBest);
  }
}
