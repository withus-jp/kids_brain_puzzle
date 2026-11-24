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

/// 카드 한 장. [size]에 맞춰 이모지·테두리·모서리도 함께 바뀐다.
class MemoryCardTile extends StatelessWidget {
  const MemoryCardTile({
    super.key,
    required this.card,
    required this.faceVisible,
    required this.size,
    required this.onTap,
    this.peeking = false,
  });

  final MemoryCard card;

  /// 앞면을 보여 줄지 여부 (별 카드로 잠깐 보여 주는 경우 포함)
  final bool faceVisible;
  final double size;

  /// 누를 수 없으면 `null`
  final VoidCallback? onTap;

  /// ⭐ 찬스 효과로 '잠깐만' 보이는 중이면 `true` (금색으로 강조)
  final bool peeking;

  bool get _isOpenStar => faceVisible && card.special == SpecialCardKind.star;

  @override
  Widget build(BuildContext context) {
    final (background, border) = _colors();
    final radius = BorderRadius.circular(size * 0.2);
    final borderWidth = max(1.5, min(3.0, size * 0.05));
    final glowing = peeking || _isOpenStar;

    final face = faceVisible
        ? Text(card.emoji, style: TextStyle(fontSize: size * 0.55))
        : Text(
            '?',
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              color: AppColors.primary.withValues(alpha: 0.55),
            ),
          );

    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: ChanceColors.gold.withValues(alpha: 0.6),
                  blurRadius: size * (_isOpenStar ? 0.35 : 0.2),
                  spreadRadius: size * 0.02,
                ),
              ]
            : const [],
      ),
      child: Material(
        color: background,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: _isOpenStar
                  ? const RadialGradient(
                      colors: [Color(0xFFFFFBE6), ChanceColors.goldLight],
                    )
                  : null,
              border: Border.all(
                color: border,
                width: glowing ? borderWidth * 1.4 : borderWidth,
              ),
            ),
            child: Center(
              child: FittedBox(
                child: _isOpenStar ? _StarPop(size: size, child: face) : face,
              ),
            ),
          ),
        ),
      ),
    );

    if (_isOpenStar) {
      tile = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          tile,
          _SparkleBurst(size: size),
        ],
      );
    }

    return SizedBox.square(dimension: size, child: tile);
  }

  (Color, Color) _colors() {
    if (!faceVisible) {
      return (AppColors.pastelLavender, const Color(0xFFC9BCF7));
    }
    if (peeking) return (ChanceColors.goldLight, ChanceColors.gold);
    return switch (card.special) {
      SpecialCardKind.star => (ChanceColors.goldLight, ChanceColors.gold),
      SpecialCardKind.bomb => (AppColors.pastelGray, const Color(0xFFB9B2C6)),
      null when card.isMatched => (
        AppColors.pastelMint,
        const Color(0xFF7FD6A6),
      ),
      null => (Colors.white, AppColors.pastelLavender),
    };
  }
}

/// 별 카드가 열릴 때 ⭐가 '톡' 튀어나오는 효과 (한 번만).
class _StarPop extends StatelessWidget {
  const _StarPop({required this.size, required this.child});

  final double size;
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

/// 별 카드가 열릴 때 카드 둘레로 ✨가 퍼져 나가는 효과 (한 번만).
class _SparkleBurst extends StatelessWidget {
  const _SparkleBurst({required this.size});

  final double size;

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
                        i.isEven ? '✨' : '⭐',
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
