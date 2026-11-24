import '../core/models/game_record.dart';

/// 게임 기록 저장소 인터페이스.
///
/// UI는 이 인터페이스로만 기록에 접근한다. 지금은 [LocalScoreRepository]를
/// 쓰고, 나중에 온라인 랭킹 API 구현체로 바꿀 수 있다.
abstract interface class ScoreRepository {
  /// 기록 하나를 저장한다.
  Future<void> saveRecord(GameRecord record);

  /// 저장된 기록을 최신순으로 돌려준다. [gameId]를 주면 그 게임만 돌려준다.
  Future<List<GameRecord>> getRecords({String? gameId});

  /// 게임·난이도별 최고 기록을 돌려준다.
  ///
  /// 최고 기록 기준은 [GameRecord.isBetterThan]을 따른다.
  Future<List<GameRecord>> getBestRecords();

  /// 특정 게임·난이도의 최고 기록. 없으면 `null`.
  Future<GameRecord?> getBestRecord({
    required String gameId,
    required String difficulty,
  });

  /// 모든 기록을 지운다.
  Future<void> clearAll();
}
