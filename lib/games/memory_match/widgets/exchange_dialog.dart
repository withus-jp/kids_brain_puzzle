import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/memory_match_rules.dart';

/// 점수 교환 팝업: 100점으로 기회 +2 또는 시간 +5초 중 하나를 고른다.
///
/// 고른 뒤 [확인]을 누르면 [onConfirm], [취소]를 누르면 [onCancel]을 부른다.
/// 바깥을 누르거나 뒤로 가기로 닫히지 않는다.
class ExchangeDialog extends StatefulWidget {
  const ExchangeDialog({
    super.key,
    required this.score,
    required this.remainingSeconds,
    required this.remainingChances,
    required this.onConfirm,
    required this.onCancel,
  });

  final int score;
  final int remainingSeconds;
  final int remainingChances;
  final ValueChanged<ExchangeOption> onConfirm;
  final VoidCallback onCancel;

  @override
  State<ExchangeDialog> createState() => _ExchangeDialogState();
}

class _ExchangeDialogState extends State<ExchangeDialog> {
  ExchangeOption? _selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const cost = MemoryMatchRules.exchangeCost;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔄', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 4),
                Text('점수 교환', style: textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  '$cost점으로 무엇을 받을까요?',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '내 점수 ${widget.score}점 → ${widget.score - cost}점',
                  key: const ValueKey('exchange_score'),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _OptionCard(
                        key: const ValueKey('exchange_option_chances'),
                        emoji: '❤️',
                        title: '기회 +${MemoryMatchRules.exchangeChances}번',
                        detail:
                            '${widget.remainingChances}번 → '
                            '${widget.remainingChances + MemoryMatchRules.exchangeChances}번',
                        color: AppColors.pastelPink,
                        selected: _selected == ExchangeOption.chances,
                        onTap: () =>
                            setState(() => _selected = ExchangeOption.chances),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OptionCard(
                        key: const ValueKey('exchange_option_time'),
                        emoji: '⏱️',
                        title: '시간 +${MemoryMatchRules.exchangeSeconds}초',
                        detail:
                            '${widget.remainingSeconds}초 → '
                            '${widget.remainingSeconds + MemoryMatchRules.exchangeSeconds}초',
                        color: AppColors.pastelLemon,
                        selected: _selected == ExchangeOption.time,
                        onTap: () =>
                            setState(() => _selected = ExchangeOption.time),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 56),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _selected == null
                            ? null
                            : () => widget.onConfirm(_selected!),
                        child: const Text('확인'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.detail,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String detail;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.04 : 1,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primary : AppColors.textSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
