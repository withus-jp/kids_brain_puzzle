/// 폭탄 카드가 뺏은 것
enum BombPenalty { time, chance }

/// 게임 오버 이유
enum GameOverReason { timeUp, noChances }

/// Stage를 클리어했을 때의 점수 계산 결과.
class StageClearResult {
  const StageClearResult({
    required this.stage,
    required this.remainingSeconds,
    required this.remainingChances,
    required this.timeBonus,
    required this.chanceBonus,
    required this.totalScore,
    required this.isLastStage,
  });

  final int stage;
  final int remainingSeconds;
  final int remainingChances;
  final int timeBonus;
  final int chanceBonus;

  /// 보너스를 더한 뒤의 누적 점수
  final int totalScore;

  /// 마지막 Stage(10x10)를 클리어했으면 `true`
  final bool isLastStage;
}

/// 컨트롤러가 화면에 알리는 일회성 이벤트 (팝업·안내 문구 표시용).
sealed class MemoryMatchEvent {
  const MemoryMatchEvent();
}

/// 새 Stage가 준비됨 (시작 팝업을 띄울 때)
final class StageReadyEvent extends MemoryMatchEvent {
  const StageReadyEvent(this.stage);

  final int stage;
}

/// ⭐ 별 카드를 찾음
final class ChanceEvent extends MemoryMatchEvent {
  const ChanceEvent();
}

/// 💣 폭탄 카드를 찾음
final class BombEvent extends MemoryMatchEvent {
  const BombEvent(this.penalty);

  final BombPenalty penalty;
}

/// Stage의 모든 짝을 맞춤
final class StageClearedEvent extends MemoryMatchEvent {
  const StageClearedEvent(this.result);

  final StageClearResult result;
}

/// 시간이나 기회가 모두 떨어짐
final class GameOverEvent extends MemoryMatchEvent {
  const GameOverEvent({
    required this.reason,
    required this.stage,
    required this.score,
  });

  final GameOverReason reason;
  final int stage;
  final int score;
}
