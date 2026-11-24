import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'memory_card_tile.dart';

/// ⭐ 찬스 팝업. 금색 배경, 튀어나오는 별, 반짝이는 장식으로 크게 축하한다.
///
/// 바깥을 누르거나 뒤로 가기로 닫히지 않는다. [onConfirm] 버튼으로만 닫는다.
class ChanceDialog extends StatelessWidget {
  const ChanceDialog({
    super.key,
    required this.peekSeconds,
    required this.onConfirm,
  });

  final int peekSeconds;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF8D6), Color(0xFFFFE27A)],
                ),
                border: Border.all(color: ChanceColors.gold, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: ChanceColors.gold.withValues(alpha: 0.55),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _BigStar(),
                    const Text(
                      '✨ 찬스! ✨',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: ChanceColors.goldDeep,
                        shadows: [
                          Shadow(color: Colors.white, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '확인을 누르면 숨은 카드를\n'
                      '$peekSeconds초 동안 모두 보여 줄게요.\n'
                      '잘 기억해 두세요!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: ChanceColors.goldDeep,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('확인'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 팝업 위쪽의 큰 별. 빙그르르 돌며 튀어나오고 주위에 반짝이가 둘러싼다.
class _BigStar extends StatelessWidget {
  const _BigStar();

  static const _size = 130.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutBack,
        builder: (context, t, _) => Stack(
          alignment: Alignment.center,
          children: [
            // 뒤에서 퍼지는 빛
            Container(
              width: _size * (0.5 + 0.5 * t),
              height: _size * (0.5 + 0.5 * t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.9),
                    ChanceColors.gold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            // 둘레의 반짝이
            for (var i = 0; i < 6; i++)
              Transform.translate(
                offset: Offset.fromDirection(
                  2 * pi * i / 6 + t * pi / 3,
                  _size * 0.42 * t.clamp(0.0, 1.0),
                ),
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Text(
                    '✨',
                    style: TextStyle(fontSize: i.isEven ? 22 : 16),
                  ),
                ),
              ),
            // 가운데 별
            Transform.rotate(
              angle: (1 - t) * -2 * pi,
              child: Transform.scale(
                scale: t,
                child: const Text('⭐', style: TextStyle(fontSize: 72)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
