import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/memory_card.dart';

/// 찬스 효과에 쓰는 금색
abstract final class ChanceColors {
  static const gold = Color(0xFFF5B800);
  static const goldLight = Color(0xFFFFF3C4);
  static const goldDeep = Color(0xFFE09A00);
}

/// 꽝 효과에 쓰는 빨간색
abstract final class BombColors {
  static const red = Color(0xFFFF5252);
  static const redLight = Color(0xFFFFD6D6);
  static const redDeep = Color(0xFFD32F2F);
}

/// 카드 한 장. [size]에 맞춰 이모지·테두리·모서리도 함께 바뀐다.
///
/// 앞면이 보이고 가려질 때 세로축으로 도는 3D 회전 애니메이션으로 뒤집힌다.
class MemoryCardTile extends StatelessWidget {
  const MemoryCardTile({
    super.key,
    required this.card,
    required this.faceVisible,
    required this.size,
    required this.onTap,
    this.peeking = false,
  });

  /// 한 번 뒤집히는 데 걸리는 시간
  static const flipDuration = Duration(milliseconds: 300);

  final MemoryCard card;

  /// 앞면을 보여 줄지 여부 (별 카드로 잠깐 보여 주는 경우 포함)
  final bool faceVisible;
  final double size;

  /// 누를 수 없으면 `null`
  final VoidCallback? onTap;

  /// ⭐ 찬스 효과로 '잠깐만' 보이는 중이면 `true` (금색으로 강조)
  final bool peeking;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        // 0 = 뒷면, 1 = 앞면. 처음 그릴 때는 애니메이션 없이 바로 그 면을 보여 준다.
        tween: Tween(end: faceVisible ? 1.0 : 0.0),
        duration: flipDuration,
        curve: Curves.easeInOut,
        builder: (context, t, _) {
          final showFront = t >= 0.5;
          final side = showFront ? _front() : _back();
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // 원근감
              ..rotateY(t * pi),
            // 앞면은 반 바퀴 돈 상태에서 보이므로 글자가 뒤집히지 않게 되돌린다.
            child: showFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: side,
                  )
                : side,
          );
        },
      ),
    );
  }

  BorderRadius get _radius => BorderRadius.circular(size * 0.2);
  double get _borderWidth => max(1.5, min(3.0, size * 0.05));

  /// 뒷면: 라벤더 바탕에 '?'
  Widget _back() => _surface(
    background: AppColors.pastelLavender,
    border: const Color(0xFFC9BCF7),
    child: Text(
      '?',
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w900,
        color: AppColors.primary.withValues(alpha: 0.55),
      ),
    ),
  );

  /// 앞면: 그림. 상태(찬스로 잠깐 보임, 짝 찾음, 특수 카드)에 따라 색이 다르다.
  Widget _front() {
    final special = card.special;
    if (special != null && card.isRevealed) return _openSpecial(special);

    final (background, border) = peeking
        ? (ChanceColors.goldLight, ChanceColors.gold)
        : card.isMatched
        ? (AppColors.pastelMint, const Color(0xFF7FD6A6))
        : (Colors.white, AppColors.pastelLavender);
    return _surface(
      background: background,
      border: border,
      glow: peeking ? ChanceColors.gold : null,
      child: Text(card.emoji, style: TextStyle(fontSize: size * 0.55)),
    );
  }

  /// 열린 특수 카드. 아이가 한눈에 알 수 있게 색·글자·효과로 강조한다.
  /// - ⭐ 찬스: 금색으로 빛나고, 별이 돌며 튀어나오고 ✨가 퍼진다.
  /// - 💣 꽝: 빨갛게 바뀌어 흔들리고 💥가 터진다.
  Widget _openSpecial(SpecialCardKind special) {
    final isStar = special == SpecialCardKind.star;
    final showLabel = size >= 48;
    final emoji = Text(
      card.emoji,
      style: TextStyle(fontSize: size * (showLabel ? 0.42 : 0.55)),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        isStar ? _StarPop(child: emoji) : emoji,
        if (showLabel)
          Text(
            isStar ? '찬스!' : '꽝!',
            key: ValueKey('special_label_${special.name}'),
            style: TextStyle(
              fontSize: size * 0.17,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: isStar ? ChanceColors.goldDeep : BombColors.redDeep,
            ),
          ),
      ],
    );

    final surface = _surface(
      background: isStar ? ChanceColors.goldLight : BombColors.redLight,
      gradient: isStar
          ? const RadialGradient(
              colors: [Color(0xFFFFFBE6), ChanceColors.goldLight],
            )
          : const RadialGradient(
              colors: [Color(0xFFFFF0F0), BombColors.redLight],
            ),
      border: isStar ? ChanceColors.gold : BombColors.red,
      glow: isStar ? ChanceColors.gold : BombColors.red,
      strongGlow: true,
      child: content,
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        isStar ? surface : _Shake(size: size, child: surface),
        _Burst(
          size: size,
          particles: isStar ? const ['✨', '⭐'] : const ['💥', '🔥'],
        ),
      ],
    );
  }

  Widget _surface({
    required Color background,
    required Color border,
    required Widget child,
    Gradient? gradient,
    Color? glow,
    bool strongGlow = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: glow == null
            ? const []
            : [
                BoxShadow(
                  color: glow.withValues(alpha: 0.6),
                  blurRadius: size * (strongGlow ? 0.35 : 0.2),
                  spreadRadius: size * 0.02,
                ),
              ],
      ),
      child: Material(
        color: background,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: _radius,
              gradient: gradient,
              border: Border.all(
                color: border,
                width: glow != null ? _borderWidth * 1.4 : _borderWidth,
              ),
            ),
            child: Center(child: FittedBox(child: child)),
          ),
        ),
      ),
    );
  }
}

/// ⭐가 '톡' 튀어나오는 효과 (한 번만).
class _StarPop extends StatelessWidget {
  const _StarPop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.rotate(
        angle: (1 - t) * -pi / 2,
        child: Transform.scale(scale: 0.3 + 0.7 * t, child: child),
      ),
      child: child,
    );
  }
}

/// 💣 카드가 좌우로 '부르르' 흔들리는 효과 (한 번만).
class _Shake extends StatelessWidget {
  const _Shake({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(sin(t * pi * 8) * (1 - t) * size * 0.09, 0),
        child: child,
      ),
      child: child,
    );
  }
}

/// 카드 둘레로 작은 그림이 퍼져 나가는 효과 (한 번만).
class _Burst extends StatelessWidget {
  const _Burst({required this.size, required this.particles});

  final double size;

  /// 번갈아 쓸 그림 (예: ✨, ⭐)
  final List<String> particles;

  static const _count = 8;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          if (t >= 1) return const SizedBox.shrink();
          final distance = size * (0.35 + 0.45 * t);
          return Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < _count; i++)
                    Positioned(
                      left:
                          size / 2 +
                          cos(2 * pi * i / _count) * distance -
                          size * 0.12,
                      top:
                          size / 2 +
                          sin(2 * pi * i / _count) * distance -
                          size * 0.12,
                      child: Text(
                        particles[i % particles.length],
                        style: TextStyle(fontSize: size * 0.22),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
