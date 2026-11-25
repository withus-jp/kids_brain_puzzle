/// Stage 하나의 그리드 크기. [short] ≤ [long] 이다.
///
/// 화면에 놓을 때는 게임판 공간이 가로로 넓으면 [long]을 가로(열)로,
/// 세로로 길면 [long]을 세로(행)로 둔다.
class MemoryGrid {
  const MemoryGrid(this.short, this.long) : assert(short <= long);

  final int short;
  final int long;

  int get cellCount => short * long;

  /// 예: `3x4`
  String get label => '${short}x$long';

  @override
  bool operator ==(Object other) =>
      other is MemoryGrid && other.short == short && other.long == long;

  @override
  int get hashCode => Object.hash(short, long);

  @override
  String toString() => label;
}

/// 점수 교환으로 받을 것
enum ExchangeOption {
  /// 기회 +[MemoryMatchRules.exchangeChances]
  chances,

  /// 시간 +[MemoryMatchRules.exchangeSeconds]초
  time,
}

/// 기억력 짝 맞추기 규칙에 쓰는 숫자 모음. (docs/specs/memory_match.md)
abstract final class MemoryMatchRules {
  static const firstStage = 1;

  /// 마지막 Stage. Stage 17이 10x10이다.
  static const lastStage = 17;

  /// Stage 1~3의 제한 시간(초)
  static const baseTimeLimitSeconds = 20;

  /// Stage 1~3의 기회
  static const baseChances = 5;

  /// 이 Stage부터 Stage마다 시간·기회가 늘어난다.
  static const growthFromStage = 4;

  /// [growthFromStage]부터 Stage마다 늘어나는 시간(초)
  static const timeGrowthPerStage = 5;

  /// [growthFromStage]부터 Stage마다 늘어나는 기회
  static const chanceGrowthPerStage = 1;

  /// 게임 오버 팝업에서 '현재 Stage부터 이어하기'를 쓸 수 있는 첫 Stage
  static const continueFromStage = 5;

  /// 이어하기에 드는 점수
  static const continueCost = 500;

  /// Stage가 [growthFromStage] 기준으로 몇 단계 올라갔는지 (Stage 1~3은 0)
  static int _growthSteps(int stage) =>
      stage < growthFromStage ? 0 : stage - growthFromStage + 1;

  /// Stage N의 제한 시간(초): Stage 1~3은 20초, Stage 4는 25초, Stage 5는 30초, …
  static int timeLimitFor(int stage) =>
      baseTimeLimitSeconds + _growthSteps(stage) * timeGrowthPerStage;

  /// Stage N의 기회: Stage 1~3은 5번, Stage 4는 6번, Stage 5는 7번, …
  static int chancesFor(int stage) =>
      baseChances + _growthSteps(stage) * chanceGrowthPerStage;

  /// 짝 하나를 찾을 때 얻는 점수
  static const pointsPerPair = 10;

  /// 클리어 시 남은 시간 1초당 보너스
  static const bonusPerSecond = 10;

  /// 클리어 시 남은 기회 1회당 보너스
  static const bonusPerChance = 50;

  /// 폭탄 카드가 뺏는 시간(초)
  static const bombTimePenaltySeconds = 3;

  /// 폭탄 카드가 뺏는 기회
  static const bombChancePenalty = 1;

  /// 틀린 카드를 다시 뒤집기까지 기다리는 시간
  static const mismatchDelay = Duration(milliseconds: 800);

  /// Stage를 시작할 때 카드를 모두 보여 주는 시간: Stage 1~4는 3초, Stage 5부터 5초.
  /// 이 동안은 제한 시간이 줄지 않고 카드를 누를 수 없다.
  static Duration previewDurationFor(int stage) => Duration(
    seconds: stage < longPreviewFromStage
        ? shortPreviewSeconds
        : longPreviewSeconds,
  );

  /// 미리 보기가 길어지는 첫 Stage
  static const longPreviewFromStage = 5;

  /// Stage 1~4 미리 보기 시간(초)
  static const shortPreviewSeconds = 3;

  /// Stage 5부터 미리 보기 시간(초)
  static const longPreviewSeconds = 5;

  /// 별 카드가 다른 카드를 보여 주는 시간 (이 동안에도 제한 시간은 줄어든다)
  static const starPeekDuration = Duration(seconds: 3);

  /// 칸 수가 짝수인 그리드에 특수 카드가 들어갈 확률
  static const evenGridSpecialChance = 0.5;

  /// 칸 수가 짝수인 그리드에 특수 카드가 들어갈 때의 장수 (짝 수를 맞추려면 2장)
  static const evenGridSpecialCount = 2;

  /// 특수 카드가 처음 나오는 Stage. 그 전(2x2, 2x3)에는 특수 카드가 없다.
  static const firstSpecialStage = 3;

  /// 이 Stage(3x3)에서는 특수 카드가 반드시 ⭐ 찬스 1장이다.
  static const guaranteedStarStage = 3;

  /// 점수 교환을 쓸 수 있는 첫 Stage
  static const exchangeFromStage = 4;

  /// 점수 교환 1번에 드는 점수
  static const exchangeCost = 100;

  /// 점수 교환으로 받는 기회
  static const exchangeChances = 2;

  /// 점수 교환으로 받는 시간(초)
  static const exchangeSeconds = 5;

  /// Stage N의 그리드: 2x2 → 2x3 → 3x3 → 3x4 → 4x4 → … → 9x10 → 10x10
  static MemoryGrid gridOf(int stage) {
    assert(stage >= firstStage && stage <= lastStage);
    final short = (stage + 3) ~/ 2;
    return stage.isOdd
        ? MemoryGrid(short, short)
        : MemoryGrid(short, short + 1);
  }
}
