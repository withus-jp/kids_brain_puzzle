import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'memory_card_tile.dart';

/// 게임 오버·모두 클리어 팝업에 붙는 '🏆 신기록 달성!' 배지.
/// 나타날 때 한 번 '통' 튀어 오른다.
class NewBestBadge extends StatelessWidget {
  const NewBestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const ValueKey('new_best_badge'),
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3C4), Color(0xFFFFD86B)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: ChanceColors.gold, width: 3),
          boxShadow: [
            BoxShadow(
              color: ChanceColors.gold.withValues(alpha: 0.5),
              blurRadius: 16,
            ),
          ],
        ),
        child: const Text(
          '🏆 신기록 달성!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: ChanceColors.goldDeep,
          ),
        ),
      ),
    );
  }
}
