import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 팝업 안의 버튼 하나
class ResultAction {
  const ResultAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;

  /// `null`이면 버튼이 흐리게 보이고 눌리지 않는다.
  final VoidCallback? onPressed;
  final bool primary;
}

/// 스테이지 클리어 · 게임 오버 · 모두 클리어 팝업.
///
/// 바깥을 누르거나 뒤로 가기로 닫히지 않는다. 버튼으로만 닫는다.
class ResultDialog extends StatelessWidget {
  const ResultDialog({
    super.key,
    required this.emoji,
    required this.title,
    this.message,
    this.details = const [],
    this.score,
    this.extra,
    this.highlightAction,
    this.highlightNote,
    required this.actions,
  });

  final String emoji;
  final String title;
  final String? message;

  /// 점수 계산 내역 (왼쪽 설명, 오른쪽 값)
  final List<(String, String)> details;

  /// 보여 줄 점수. `null`이면 점수 칸을 숨긴다.
  final int? score;

  /// 점수 칸 위에 넣을 추가 안내 (예: 새 기능 소개)
  final Widget? extra;

  /// 버튼 줄 위에 한 줄을 다 쓰는 강조 버튼 (예: 이어하기).
  /// [highlightNote]가 있으면 버튼 아래에 작게 안내한다.
  final ResultAction? highlightAction;
  final String? highlightNote;
  final List<ResultAction> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          // 내용이 길면 내용만 스크롤하고, 버튼은 항상 아래에 보이게 둔다.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Text(title, style: textTheme.headlineMedium),
                      if (message != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge,
                        ),
                      ],
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        for (final (label, value) in details)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                                Text(value, style: textTheme.titleMedium),
                              ],
                            ),
                          ),
                      ],
                      if (extra != null) ...[
                        const SizedBox(height: 16),
                        extra!,
                      ],
                      if (score != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          key: const ValueKey('result_score'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.pastelSky,
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text('점수', style: textTheme.bodyMedium),
                              Text('$score점', style: textTheme.headlineMedium),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (highlightAction case final action?) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('result_highlight_action'),
                          onPressed: action.onPressed,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8A3D),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.pastelGray,
                            disabledForegroundColor: AppColors.textSoft,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(action.label),
                          ),
                        ),
                      ),
                      if (highlightNote != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          highlightNote!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        for (final (i, action) in actions.indexed) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: action.primary
                                ? FilledButton(
                                    onPressed: action.onPressed,
                                    child: Text(action.label),
                                  )
                                : OutlinedButton(
                                    onPressed: action.onPressed,
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
                                    child: Text(action.label),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
