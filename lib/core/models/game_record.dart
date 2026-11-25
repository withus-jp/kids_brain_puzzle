/// 게임 한 판의 결과.
///
/// 한 판은 Stage 1에서 시작해 게임 오버 또는 모두 클리어로 끝날 때까지다.
/// 로컬 저장소와 (향후) 온라인 랭킹 API에서 공통으로 사용하는 모델이다.
class GameRecord {
  const GameRecord({
    required this.id,
    required this.gameId,
    required this.stage,
    required this.score,
    required this.elapsedSeconds,
    required this.moves,
    required this.playedAt,
    this.cleared = false,
  });

  /// 판 식별자. 이어하기로 같은 판을 계속하면 같은 id로 덮어쓴다.
  final String id;

  /// 게임 식별자 (예: `memory_match`)
  final String gameId;

  /// 도달한 최고 Stage
  final int stage;

  /// 마지막 Stage까지 모두 클리어했는지
  final bool cleared;

  /// 최종 점수
  final int score;

  /// 실제로 플레이한 총 시간(초)
  final int elapsedSeconds;

  /// 총 시도 횟수 (카드 두 장을 뒤집은 횟수)
  final int moves;

  /// 판이 끝난 일시
  final DateTime playedAt;

  /// 이 기록이 [other]보다 좋은지 여부.
  ///
  /// 도달 Stage가 높을수록 → 같으면 모두 클리어한 쪽 → 같으면 점수가 높을수록 좋다.
  bool isBetterThan(GameRecord other) => compareByRank(this, other) < 0;

  /// 좋은 기록이 앞에 오도록 정렬하는 비교 함수 (순위 기준).
  static int compareByRank(GameRecord a, GameRecord b) {
    if (a.stage != b.stage) return b.stage.compareTo(a.stage);
    if (a.cleared != b.cleared) return a.cleared ? -1 : 1;
    return b.score.compareTo(a.score);
  }

  /// 내 기록 화면 정렬: 도달 Stage가 높은 순, 같으면 최신순.
  static int compareByStageThenRecent(GameRecord a, GameRecord b) {
    if (a.stage != b.stage) return b.stage.compareTo(a.stage);
    return b.playedAt.compareTo(a.playedAt);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'gameId': gameId,
    'stage': stage,
    'cleared': cleared,
    'score': score,
    'elapsedSeconds': elapsedSeconds,
    'moves': moves,
    'playedAt': playedAt.toIso8601String(),
  };

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    final playedAt = DateTime.parse(json['playedAt'] as String);
    return GameRecord(
      // 이전 형식(id 없음)도 읽을 수 있게 일시로 대신한다.
      id: json['id'] as String? ?? playedAt.toIso8601String(),
      gameId: json['gameId'] as String,
      stage: json['stage'] as int? ?? 1,
      cleared: json['cleared'] as bool? ?? false,
      score: json['score'] as int? ?? 0,
      elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
      moves: json['moves'] as int? ?? 0,
      playedAt: playedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameRecord &&
      other.id == id &&
      other.gameId == gameId &&
      other.stage == stage &&
      other.cleared == cleared &&
      other.score == score &&
      other.elapsedSeconds == elapsedSeconds &&
      other.moves == moves &&
      other.playedAt == playedAt;

  @override
  int get hashCode => Object.hash(
    id,
    gameId,
    stage,
    cleared,
    score,
    elapsedSeconds,
    moves,
    playedAt,
  );
}
