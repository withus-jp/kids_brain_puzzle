import 'package:flutter/material.dart';

import '../../core/models/game_info.dart';
import '../../core/theme/app_theme.dart';

/// 게임 허브에 표시되는 게임 카드.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap});

  final GameInfo game;

  /// 카드를 눌렀을 때 동작. '준비 중' 게임이면 `null`.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final comingSoon = game.isComingSoon;

    return Opacity(
      opacity: comingSoon ? 0.7 : 1,
      child: Material(
        color: game.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(game.emoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text(
                  game.title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  game.description,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _Badge(comingSoon: comingSoon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.comingSoon});

  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Text(
        comingSoon ? '🔒 준비 중' : '▶ 놀러 가기',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
