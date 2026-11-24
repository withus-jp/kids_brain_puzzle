import 'dart:math';

import 'package:flutter/material.dart';

import '../models/memory_card.dart';
import '../models/memory_match_rules.dart';
import 'memory_card_tile.dart';

/// 카드 게임판 (2x2 ~ 10x10, 직사각형 포함).
///
/// - 공간이 가로로 넓으면 긴 변을 가로(열)로, 세로로 길면 세로(행)로 둔다.
///   방향이 바뀌어도 카드 배치는 뒤집어(전치) 보여 줄 뿐이라 카드끼리의
///   이웃 관계는 그대로다.
/// - 가로·세로 모두에 들어가는 가장 큰 정사각형 카드 크기를 골라
///   넓은 웹 화면과 세로 모바일 화면 모두에서 넘치지 않고 가운데에 놓인다.
class MemoryBoard extends StatelessWidget {
  const MemoryBoard({
    super.key,
    required this.grid,
    required this.cards,
    required this.isFaceVisible,
    required this.enabled,
    required this.onCardTap,
  });

  /// 카드는 [grid]의 short x long 행 우선 순서로 [cards]에 들어 있다.
  final MemoryGrid grid;
  final List<MemoryCard> cards;
  final bool Function(int index) isFaceVisible;

  /// `false`이면 카드를 누를 수 없다.
  final bool enabled;
  final ValueChanged<int> onCardTap;

  /// 카드가 너무 커지지 않도록 하는 최대 크기
  static const maxCardSize = 160.0;

  /// 그리드 크기에 따른 기본 간격
  double get _baseSpacing => switch (grid.long) {
    <= 3 => 14,
    <= 5 => 10,
    <= 7 => 7,
    _ => 5,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // 긴 변을 공간의 긴 쪽에 맞춘다.
        final transposed = height > width;
        final columns = transposed ? grid.short : grid.long;
        final rows = transposed ? grid.long : grid.short;

        // 아주 좁은 화면에서는 간격도 카드 크기에 비례해 줄인다.
        final roughCard = min(width / columns, height / rows);
        final spacing = min(_baseSpacing, roughCard * 0.12);
        final cardSize = max(
          0.0,
          [
            maxCardSize,
            (width - spacing * (columns - 1)) / columns,
            (height - spacing * (rows - 1)) / rows,
          ].reduce(min),
        );

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < rows; row++) ...[
                if (row > 0) SizedBox(height: spacing),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var col = 0; col < columns; col++) ...[
                      if (col > 0) SizedBox(width: spacing),
                      _buildCard(
                        transposed
                            ? col * grid.long + row
                            : row * grid.long + col,
                        cardSize,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(int index, double size) {
    final card = cards[index];
    final canTap = enabled && !card.isRevealed;
    final faceVisible = isFaceVisible(index);
    return MemoryCardTile(
      key: ValueKey('memory_card_$index'),
      card: card,
      faceVisible: faceVisible,
      // 원래는 덮여 있지만 ⭐ 찬스 효과로 잠깐 보이는 카드
      peeking: faceVisible && !card.isRevealed,
      size: size,
      onTap: canTap ? () => onCardTap(index) : null,
    );
  }
}
