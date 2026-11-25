import '../core/models/game_info.dart';
import '../core/theme/app_theme.dart';
import 'memory_match/memory_match_screen.dart';
import 'memory_match/models/memory_match_rules.dart';

/// 게임 허브에 표시할 게임 목록.
///
/// 새 게임을 추가할 때는 `lib/games/<게임>/` 폴더를 만들고 여기에 한 항목을 추가한다.
final List<GameInfo> gameRegistry = [
  GameInfo(
    id: MemoryMatchScreen.gameId,
    title: '기억력 짝 맞추기',
    description: '같은 그림을 찾아 스테이지를 깨요!',
    emoji: '🃏',
    color: AppColors.pastelPink,
    stageDetail: (stage) => MemoryMatchRules.gridOf(
      stage.clamp(MemoryMatchRules.firstStage, MemoryMatchRules.lastStage),
    ).label,
    screenBuilder: (_, scoreRepository) =>
        MemoryMatchScreen(scoreRepository: scoreRepository),
  ),
  const GameInfo(
    id: 'coming_soon',
    title: '새로운 게임',
    description: '준비 중이에요. 조금만 기다려 주세요!',
    emoji: '🎁',
    color: AppColors.pastelGray,
  ),
];

/// [id]에 해당하는 게임 정보. 없으면 `null`.
GameInfo? findGame(String id) {
  for (final game in gameRegistry) {
    if (game.id == id) return game;
  }
  return null;
}
