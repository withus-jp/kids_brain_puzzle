import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'memory_match_controller.dart';
import 'models/memory_match_event.dart';
import 'models/memory_match_rules.dart';
import 'widgets/chance_dialog.dart';
import 'widgets/exchange_dialog.dart';
import 'widgets/game_status_bar.dart';
import 'widgets/memory_board.dart';
import 'widgets/peek_frame.dart';
import 'widgets/result_dialog.dart';

/// 기억력 짝 맞추기 게임 화면 (스테이지 방식).
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key, this.controller});

  static const gameId = 'memory_match';

  /// 테스트에서 카드 배치를 고정하고 싶을 때 주입한다. 없으면 새로 만든다.
  /// 주입한 컨트롤러는 호출한 쪽에서 dispose한다.
  final MemoryMatchController? controller;

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  late final MemoryMatchController _controller =
      widget.controller ?? MemoryMatchController();
  late final StreamSubscription<MemoryMatchEvent> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _controller.events.listen(_onEvent);
    // 첫 Stage도 시작 팝업부터 띄운다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.status == MemoryMatchStatus.ready) {
        _showStageStart();
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onEvent(MemoryMatchEvent event) {
    if (!mounted) return;
    switch (event) {
      case StageReadyEvent():
        _showStageStart();
      case ChanceEvent():
        _showChance();
      case BombEvent(:final penalty):
        _showBomb(penalty);
      case StageClearedEvent(:final result):
        _showStageCleared(result);
      case GameOverEvent():
        _showGameOver(event);
    }
  }

  Future<void> _showResult(ResultDialog Function(BuildContext) builder) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: builder,
    );
  }

  void _goHome(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    Navigator.of(context).pop();
  }

  void _retry(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    _controller.restart();
  }

  /// Stage 시작 팝업. [시작!]을 누르면 그때부터 시간이 줄어든다.
  /// 점수 교환이 처음 열리는 Stage 4에서는 사용법도 안내한다.
  void _showStageStart() {
    final stage = _controller.stage;
    final grid = _controller.grid;
    _showResult(
      (dialogContext) => ResultDialog(
        emoji: stage == MemoryMatchRules.firstStage ? '🧠' : '🚩',
        title: 'Stage $stage',
        message: '${grid.label} 그리드, 짝 ${_controller.totalPairs}쌍을 찾아요!',
        details: [
          (
            '⏱️ 제한 시간',
            '${_controller.remainingSeconds}초${_growth(MemoryMatchRules.timeLimitFor)}',
          ),
          (
            '❤️ 기회',
            '${_controller.remainingChances}번${_growth(MemoryMatchRules.chancesFor)}',
          ),
          if (_controller.score > 0) ('⭐ 지금 점수', '${_controller.score}점'),
        ],
        extra: stage == MemoryMatchRules.exchangeFromStage
            ? const _ExchangeGuide()
            : null,
        actions: [
          ResultAction(
            label: '시작!',
            primary: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _controller.start();
            },
          ),
        ],
      ),
    );
  }

  /// 앞 Stage보다 늘어난 만큼 ` (+5)`처럼 붙인다. 늘지 않았으면 빈 문자열.
  String _growth(int Function(int stage) valueOf) {
    final stage = _controller.stage;
    if (stage <= MemoryMatchRules.firstStage) return '';
    final diff = valueOf(stage) - valueOf(stage - 1);
    return diff > 0 ? ' (+$diff)' : '';
  }

  /// 점수 교환 팝업. 떠 있는 동안 타이머가 멈추고, 확인하면 반영 후 이어 간다.
  void _showExchange() {
    if (!_controller.beginExchange()) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ExchangeDialog(
        score: _controller.score,
        remainingSeconds: _controller.remainingSeconds,
        remainingChances: _controller.remainingChances,
        onConfirm: (option) {
          Navigator.of(dialogContext).pop();
          _controller.confirmExchange(option);
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
          _controller.cancelExchange();
        },
      ),
    );
  }

  /// '찬스!' 팝업. 닫으면 그때부터 3초 동안 카드를 보여 준다.
  /// 팝업이 떠 있는 동안 타이머는 멈춰 있다.
  void _showChance() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xAA3D2E00),
      builder: (dialogContext) => ChanceDialog(
        peekSeconds: MemoryMatchRules.starPeekDuration.inSeconds,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          _controller.confirmSpecial();
        },
      ),
    );
  }

  /// '꽝!' 팝업. 무엇을 뺏기는지 알려 주고, 확인을 누르면 그때 적용한다.
  /// 팝업이 떠 있는 동안 타이머는 멈춰 있다.
  void _showBomb(BombPenalty penalty) {
    _showResult(
      (dialogContext) => ResultDialog(
        emoji: '💣',
        title: '꽝!',
        message: switch (penalty) {
          BombPenalty.time =>
            '폭탄이 터졌어요!\n'
                '확인을 누르면 시간 ${MemoryMatchRules.bombTimePenaltySeconds}초를 뺏겨요.',
          BombPenalty.chance =>
            '폭탄이 터졌어요!\n'
                '확인을 누르면 남은 기회 ${MemoryMatchRules.bombChancePenalty}번을 뺏겨요.',
        },
        details: [
          switch (penalty) {
            BombPenalty.time => (
              '⏱️ 남은 시간',
              '${_controller.remainingSeconds}초 → '
                  '${max(0, _controller.remainingSeconds - MemoryMatchRules.bombTimePenaltySeconds)}초',
            ),
            BombPenalty.chance => (
              '❤️ 남은 기회',
              '${_controller.remainingChances}번 → '
                  '${max(0, _controller.remainingChances - MemoryMatchRules.bombChancePenalty)}번',
            ),
          },
        ],
        actions: [
          ResultAction(
            label: '확인',
            primary: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _controller.confirmSpecial();
            },
          ),
        ],
      ),
    );
  }

  void _showStageCleared(StageClearResult result) {
    final details = [
      (
        '남은 시간 ${result.remainingSeconds}초 × ${MemoryMatchRules.bonusPerSecond}',
        '+${result.timeBonus}',
      ),
      (
        '남은 기회 ${result.remainingChances}번 × ${MemoryMatchRules.bonusPerChance}',
        '+${result.chanceBonus}',
      ),
    ];

    if (result.isLastStage) {
      _showResult(
        (dialogContext) => ResultDialog(
          emoji: '🏆',
          title: '모든 스테이지 클리어!',
          message: '10x10까지 전부 해냈어요. 정말 대단해요!',
          details: details,
          score: result.totalScore,
          actions: [
            ResultAction(label: '홈으로', onPressed: () => _goHome(dialogContext)),
            ResultAction(
              label: '처음부터',
              primary: true,
              onPressed: () => _retry(dialogContext),
            ),
          ],
        ),
      );
      return;
    }

    _showResult(
      (dialogContext) => ResultDialog(
        emoji: '🎉',
        title: '스테이지 클리어!',
        message:
            'Stage ${result.stage} 성공!\n'
            '다음 스테이지는 '
            '${MemoryMatchRules.gridOf(result.stage + 1).label} 그리드예요.',
        details: details,
        score: result.totalScore,
        actions: [
          ResultAction(
            label: '다음 스테이지 ▶',
            primary: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _controller.nextStage();
            },
          ),
        ],
      ),
    );
  }

  void _showGameOver(GameOverEvent event) {
    _showResult(
      (dialogContext) => ResultDialog(
        emoji: '😵',
        title: '게임 오버',
        message: switch (event.reason) {
          GameOverReason.timeUp => '시간이 다 됐어요.',
          GameOverReason.noChances => '기회를 모두 썼어요.',
        },
        details: [('도달한 스테이지', 'Stage ${event.stage}')],
        score: event.score,
        highlightAction: _controller.isContinueUnlocked
            ? ResultAction(
                label: _controller.canContinue
                    ? '💎 ${MemoryMatchRules.continueCost}점으로 '
                          'Stage ${event.stage} 이어하기'
                    : '💎 Stage ${event.stage} 이어하기',
                onPressed: _controller.canContinue
                    ? () {
                        Navigator.of(dialogContext).pop();
                        _controller.continueStage();
                      }
                    : null,
              )
            : null,
        highlightNote: !_controller.isContinueUnlocked
            ? null
            : _controller.canContinue
            ? '점수 ${event.score}점 → '
                  '${event.score - MemoryMatchRules.continueCost}점, '
                  '이 Stage를 처음부터 다시 해요.'
            : '이어하려면 ${MemoryMatchRules.continueCost}점이 필요해요.',
        actions: [
          ResultAction(label: '홈으로', onPressed: () => _goHome(dialogContext)),
          ResultAction(
            label: '재도전',
            primary: true,
            onPressed: () => _retry(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기억력 짝 맞추기')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              // 가로가 넓은 화면(웹, 모바일 가로)은 상태판을 왼쪽에 둬서
              // 게임판이 세로 공간을 최대한 쓰게 한다.
              // 기본: 위쪽에 첫째 줄(Stage·점수·교환), 가운데 게임판, 아래쪽에
              // 둘째 줄(남은 시간·기회). 높이가 낮은 가로 화면(모바일 가로 등)에서만
              // 왼쪽 패널의 위·아래에 두 줄을 나눠 놓아 게임판이 세로 공간을 최대한 쓴다.
              final wide =
                  constraints.maxWidth >= 600 &&
                  constraints.maxWidth > constraints.maxHeight &&
                  constraints.maxHeight < 480;

              final board = PeekFrame(
                active: _controller.isPeeking,
                duration: MemoryMatchRules.starPeekDuration,
                child: MemoryBoard(
                  grid: _controller.grid,
                  cards: _controller.cards,
                  isFaceVisible: _controller.isFaceVisible,
                  enabled: _controller.acceptsInput,
                  onCardTap: _controller.flip,
                ),
              );

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: wide
                    ? Row(
                        children: [
                          SizedBox(
                            width: 200,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _statusBar(StatusLine.first, vertical: true),
                                _statusBar(StatusLine.second, vertical: true),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: board),
                        ],
                      )
                    : Column(
                        children: [
                          _statusBar(StatusLine.first),
                          const SizedBox(height: 12),
                          Expanded(child: board),
                          const SizedBox(height: 12),
                          _statusBar(StatusLine.second),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _statusBar(StatusLine line, {bool vertical = false}) => GameStatusBar(
    line: line,
    stage: _controller.stage,
    gridLabel: _controller.grid.label,
    remainingSeconds: _controller.remainingSeconds,
    remainingChances: _controller.remainingChances,
    score: _controller.score,
    vertical: vertical,
    action: _controller.isExchangeUnlocked
        ? ExchangeButton(
            cost: MemoryMatchRules.exchangeCost,
            onPressed: _controller.canExchange ? _showExchange : null,
          )
        : null,
  );
}

/// Stage 4 시작 팝업에 넣는 점수 교환 안내.
class _ExchangeGuide extends StatelessWidget {
  const _ExchangeGuide();

  @override
  Widget build(BuildContext context) {
    const cost = MemoryMatchRules.exchangeCost;
    return Container(
      key: const ValueKey('exchange_guide'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pastelLavender,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🆕 점수 교환이 열렸어요!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '[🔄 점수 교환] 버튼을 누르면 점수 $cost점으로\n'
            '❤️ 기회 +${MemoryMatchRules.exchangeChances}번 또는 '
            '⏱️ 시간 +${MemoryMatchRules.exchangeSeconds}초를 받을 수 있어요.\n'
            '고르는 동안에는 시간이 멈춰요.',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
