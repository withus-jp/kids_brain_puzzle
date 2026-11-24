import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'memory_card_tile.dart';

/// 게임판 테두리. ⭐ 찬스로 카드를 보여 주는 동안 금색으로 빛나고,
/// 위쪽 막대가 남은 시간만큼 줄어든다.
///
/// 안쪽 여백은 항상 같아서 켜지고 꺼질 때 카드 크기가 바뀌지 않는다.
class PeekFrame extends StatelessWidget {
  const PeekFrame({
    super.key,
    required this.active,
    required this.duration,
    required this.child,
  });

  final bool active;

  /// 카드를 보여 주는 시간 (막대가 줄어드는 시간)
  final Duration duration;
  final Widget child;

  static const _padding = 10.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        color: active
            ? ChanceColors.goldLight.withValues(alpha: 0.6)
            : Colors.transparent,
        border: Border.all(
          color: active ? ChanceColors.gold : Colors.transparent,
          width: 3,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: ChanceColors.gold.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: child),
          if (active)
            Positioned(
              key: const ValueKey('peek_timer_bar'),
              left: 24,
              right: 24,
              top: -_padding + 2,
              height: 5,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: 0),
                duration: duration,
                builder: (context, remaining, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: remaining,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ChanceColors.goldDeep,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
