import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 상태판의 어느 줄인지
enum StatusLine {
  /// 화면 위쪽: Stage · 점수 · (점수 교환 버튼)
  first,

  /// 화면 아래쪽: 남은 시간 · 남은 기회 (크게)
  second,
}

/// 게임 상태판의 한 줄. 화면이 위쪽에 [StatusLine.first]를, 아래쪽에
/// [StatusLine.second]를 놓는다.
///
/// - 기본: 칩을 가로 한 줄로 놓는다. 칩이 너비를 똑같이 나눠 가지고, 너무
///   넓어지지 않도록 [maxWidth]로 제한해 가운데에 놓는다.
/// - [vertical]이 `true`이면(세로 높이가 낮은 가로 화면의 왼쪽 패널) 칩을
///   세로로 쌓는다.
class GameStatusBar extends StatelessWidget {
  const GameStatusBar({
    super.key,
    required this.line,
    required this.stage,
    required this.gridLabel,
    required this.remainingSeconds,
    required this.remainingChances,
    required this.score,
    this.vertical = false,
    this.action,
  });

  final StatusLine line;
  final int stage;

  /// 그리드 크기 표시 (예: `3x4`)
  final String gridLabel;
  final int remainingSeconds;
  final int remainingChances;
  final int score;
  final bool vertical;

  /// 첫째 줄 끝에 붙일 버튼 (예: 점수 교환)
  final Widget? action;

  /// 상태판 한 줄의 최대 너비
  static const maxWidth = 640.0;

  /// 첫째 줄(Stage·점수·교환) 칩 높이
  static const chipHeight = 56.0;

  /// 둘째 줄(남은 시간·기회) 칩 높이. 한눈에 보이도록 더 크게 둔다.
  static const largeChipHeight = 80.0;

  /// 왼쪽 패널(높이가 낮은 가로 화면)에서의 칩 높이
  static const _panelChipHeight = 46.0;
  static const _panelLargeChipHeight = 62.0;
  static const _panelGap = 6.0;

  static const _gap = 8.0;
  static const _warningColor = Color(0xFFFFB3B3);

  bool get _isFirst => line == StatusLine.first;

  List<Widget> _items() => _isFirst
      ? [
          _StatChip(
            key: const ValueKey('stat_stage'),
            emoji: '🚩',
            label: 'Stage',
            value: '$stage',
            caption: gridLabel,
            color: AppColors.pastelLavender,
          ),
          _StatChip(
            key: const ValueKey('stat_score'),
            emoji: '⭐',
            label: '점수',
            value: '$score',
            caption: '점',
            color: AppColors.pastelSky,
          ),
          ?action,
        ]
      : [
          _StatChip(
            key: const ValueKey('stat_time'),
            large: true,
            emoji: '⏱️',
            label: '남은 시간',
            value: '$remainingSeconds',
            caption: '초',
            color: remainingSeconds <= 5
                ? _warningColor
                : AppColors.pastelLemon,
          ),
          _StatChip(
            key: const ValueKey('stat_chances'),
            large: true,
            emoji: '❤️',
            label: '남은 기회',
            value: '$remainingChances',
            caption: '번',
            color: remainingChances <= 1 ? _warningColor : AppColors.pastelPink,
          ),
        ];

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final key = ValueKey(_isFirst ? 'status_line_1' : 'status_line_2');

    if (vertical) {
      final height = _isFirst ? _panelChipHeight : _panelLargeChipHeight;
      return Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(height: _panelGap),
            SizedBox(height: height, child: item),
          ],
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          key: key,
          height: _isFirst ? chipHeight : largeChipHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 상태 칩 하나: 왼쪽에 이모지, 오른쪽 위에 작은 이름, 아래에 큰 값.
///
/// 주어진 크기를 꽉 채우고, 글자가 넘치면 살짝 작아진다.
class _StatChip extends StatelessWidget {
  const _StatChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.caption,
    this.large = false,
  });

  final String emoji;
  final String label;
  final String value;
  final String? caption;
  final Color color;

  /// 둘째 줄(남은 시간·기회)용 큰 칩
  final bool large;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: large ? 34 : 22)),
              SizedBox(width: large ? 10 : 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: large ? 14 : 12,
                      height: 1.1,
                      fontWeight: large ? FontWeight.w600 : null,
                      color: AppColors.textSoft,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: large ? 40 : 22,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (caption != null)
                        Text(
                          ' $caption',
                          style: TextStyle(
                            fontSize: large ? 18 : 13,
                            fontWeight: large ? FontWeight.w700 : null,
                            color: AppColors.textSoft,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 점수 교환 버튼. 상태 칩과 같은 크기로 놓이며, 쓸 수 없을 때는 흐리게 보인다.
class ExchangeButton extends StatelessWidget {
  const ExchangeButton({
    super.key,
    required this.cost,
    required this.onPressed,
  });

  final int cost;

  /// 지금 교환할 수 없으면 `null`
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const ValueKey('exchange_button'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, GameStatusBar.chipHeight),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.pastelGray,
        disabledForegroundColor: AppColors.textSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔄', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '점수 교환',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$cost점 사용',
                  style: const TextStyle(fontSize: 12, height: 1.1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
