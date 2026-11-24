/// 한 번의 게임 플레이 결과.
///
/// 로컬 저장소와 (향후) 온라인 랭킹 API에서 공통으로 사용하는 모델이다.
class GameRecord {
  const GameRecord({
    required this.gameId,
    required this.difficulty,
    required this.moves,
    required this.elapsedSeconds,
    required this.playedAt,
  });

  /// 게임 식별자 (예: `memory_match`)
  final String gameId;

  /// 난이도 (예: `easy_2x2`, `normal_4x4`)
  final String difficulty;

  /// 시도 횟수
  final int moves;

  /// 클리어 소요 시간(초)
  final int elapsedSeconds;

  /// 플레이 일시
  final DateTime playedAt;

  /// 같은 게임·난이도 안에서 이 기록이 [other]보다 좋은지 여부.
  ///
  /// 시도 횟수가 적을수록 좋고, 같으면 소요 시간이 짧을수록 좋다.
  bool isBetterThan(GameRecord other) {
    if (moves != other.moves) return moves < other.moves;
    return elapsedSeconds < other.elapsedSeconds;
  }

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'difficulty': difficulty,
        'moves': moves,
        'elapsedSeconds': elapsedSeconds,
        'playedAt': playedAt.toIso8601String(),
      };

  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
        gameId: json['gameId'] as String,
        difficulty: json['difficulty'] as String,
        moves: json['moves'] as int,
        elapsedSeconds: json['elapsedSeconds'] as int,
        playedAt: DateTime.parse(json['playedAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is GameRecord &&
      other.gameId == gameId &&
      other.difficulty == difficulty &&
      other.moves == moves &&
      other.elapsedSeconds == elapsedSeconds &&
      other.playedAt == playedAt;

  @override
  int get hashCode =>
      Object.hash(gameId, difficulty, moves, elapsedSeconds, playedAt);
}
