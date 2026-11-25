import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../repositories/score_repository.dart';
import 'memory_match_controller.dart';
import 'models/memory_card.dart';
import 'models/memory_match_event.dart';
import 'models/memory_match_rules.dart';
import 'widgets/chance_dialog.dart';
import 'widgets/exchange_dialog.dart';
import 'widgets/game_status_bar.dart';
import 'widgets/memory_card_tile.dart';
import 'widgets/memory_board.dart';
import 'widgets/new_best_badge.dart';
import 'widgets/peek_frame.dart';
import 'widgets/result_dialog.dart';

/// 기억력 짝 맞추기 게임 화면 (스테이지 방식).
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({
    super.key,
    required this.scoreRepository,
    this.controller,
  });

  static const gameId = MemoryMatchController.gameId;

  /// 특수 카드를 연 뒤 팝업을 띄우기까지 보여 주는 짧은 피드백 시간
  static const specialFeedbackDuration = Duration(milliseconds: 700);

  /// 게임 오버·모두 클리어 때 기록을 저장하는 저장소
  final ScoreRepository scoreRepository;

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

  /// 특수 카드 피드백(화면 번쩍임) 중인 종류. 없으면 `null`.
  SpecialCardKind? _flashKind;

  /// 번쩍임 애니메이션을 매번 처음부터 다시 하도록 바꾸는 값
  int _flashCount = 0;
  Timer? _popupDelay;

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
    _popupDelay?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onEvent(MemoryMatchEvent event) {
    if (!mounted) return;
    switch (event) {
      case StageReadyEvent():
        _showStageStart();
      case ChanceEvent():
        _flashThen(SpecialCardKind.star, _showChance);
      case BombEvent(:final penalty):
        _flashThen(SpecialCardKind.bomb, () => _showBomb(penalty));
      case StageClearedEvent(:final result):
        _showStageCleared(result);
      case GameOverEvent():
        _showGameOver(event);
    }
  }

  /// 특수 카드를 열면 카드가 뒤집히고 화면이 번쩍이는 것을 잠깐 보여 준 뒤
  /// [showPopup]을 부른다. 그동안 컨트롤러는 시간을 멈추고 입력을 막고 있다.
  void _flashThen(SpecialCardKind kind, VoidCallback showPopup) {
    _popupDelay?.cancel();
    setState(() {
      _flashKind = kind;
      _flashCount++;
    });
    _popupDelay = Timer(MemoryMatchScreen.specialFeedbackDuration, () {
      _popupDelay = null;
      if (!mounted) return;
      setState(() => _flashKind = null);
      showPopup();
    });
  }

  /// 게임 오버·모두 클리어 때 이번 판 기록을 저장하고 신기록인지 알려 준다.
  /// 저장에 실패하면 신기록 배지 없이 진행한다.
  Future<bool> _saveRecord() async {
    try {
      return await widget.scoreRepository.saveAndCheckNewBest(
        _controller.toRecord(),
      );
    } on Object catch (error) {
      debugPrint('기록 저장 실패: $error');
      return false;
    }
  }

  /// 판 결과 팝업에 붙는 플레이 시간·시도 횟수
  List<(String, String)> _runDetails() => [
    ('⏱️ 플레이 시간', formatDuration(_controller.runPlaySeconds)),
    ('🔁 시도 횟수', '${_controller.runMoves}번'),
  ];

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
        message:
            '${grid.label} 그리드, 짝 ${_controller.totalPairs}쌍을 찾아요!\n'
            '👀 시작하면 카드를 ${_controller.previewDuration.inSeconds}초 동안 '
            '모두 보여 줘요. 잘 기억하세요!',
        details: [
          (
            '⏱️ 제한 시간',
            '${_controller.remainingSeconds}초${_growth(MemoryMatchRules.timeLimitFor)}',
          ),
          (
            '❤️ 기회',
            '${_controller.remainingChances}번${_growth(MemoryMatchRules.chancesFor)}',
          ),
          ('👀 미리 보기', '${_controller.previewDuration.inSeconds}초'),
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
      _showAllCleared(result, details);
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

  Future<void> _showAllCleared(
    StageClearResult result,
    List<(String, String)> details,
  ) async {
    final isNewBest = await _saveRecord();
    if (!mounted) return;
    _showResult(
      (dialogContext) => ResultDialog(
        emoji: '🏆',
        title: '모든 스테이지 클리어!',
        message: '10x10까지 전부 해냈어요. 정말 대단해요!',
        details: [...details, ..._runDetails()],
        score: result.totalScore,
        extra: isNewBest ? const NewBestBadge() : null,
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
  }

  Future<void> _showGameOver(GameOverEvent event) async {
    final isNewBest = await _saveRecord();
    if (!mounted) return;
    _showResult(
      (dialogContext) => ResultDialog(
        emoji: '😵',
        title: '게임 오버',
        message: switch (event.reason) {
          GameOverReason.timeUp => '시간이 다 됐어요.',
          GameOverReason.noChances => '기회를 모두 썼어요.',
        },
        details: [('🚩 도달한 스테이지', 'Stage ${event.stage}'), ..._runDetails()],
        score: event.score,
        extra: isNewBest ? const NewBestBadge() : null,
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
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody()),
          if (_flashKind case final kind?)
            Positioned.fill(
              child: _ScreenFlash(key: ValueKey(_flashCount), kind: kind),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            // 기본: 위쪽에 첫째 줄(Stage·점수·교환), 바로 아래 둘째 줄
            // (남은 시간·기회), 그 아래 게임판. 높이가 낮은 가로 화면(모바일 가로 등)
            // 에서만 두 줄을 왼쪽 패널 위쪽에 차례로 쌓아 게임판이 세로 공간을
            // 최대한 쓰게 한다.
            final wide =
                constraints.maxWidth >= 600 &&
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxHeight < 480;

            final board = PeekFrame(
              active: _controller.isPeeking || _controller.isPreviewing,
              duration: _controller.isPreviewing
                  ? _controller.previewDuration
                  : MemoryMatchRules.starPeekDuration,
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
                            children: [
                              _statusBar(StatusLine.first, vertical: true),
                              // 높이가 아주 낮으면 간격부터 줄인다.
                              const Flexible(child: SizedBox(height: 12)),
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
                        const SizedBox(height: 8),
                        _statusBar(StatusLine.second),
                        const SizedBox(height: 12),
                        Expanded(child: board),
                      ],
                    ),
            );
          },
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

/// 특수 카드를 열었을 때 화면 전체가 한 번 번쩍이는 효과.
/// ⭐ 찬스는 금색, 💣 꽝은 빨간색이며 가운데에 큰 글자를 잠깐 띄운다.
class _ScreenFlash extends StatelessWidget {
  const _ScreenFlash({super.key, required this.kind});

  final SpecialCardKind kind;

  @override
  Widget build(BuildContext context) {
    final isStar = kind == SpecialCardKind.star;
    final color = isStar ? ChanceColors.gold : const Color(0xFFFF5252);
    final label = isStar ? '⭐ 찬스!' : '💥 꽝!';

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MemoryMatchScreen.specialFeedbackDuration,
        builder: (context, t, _) {
          // 빠르게 켜졌다가 천천히 사라진다.
          final glow = t < 0.15 ? t / 0.15 : (1 - t) / 0.85;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [
                  color.withValues(alpha: 0.10 * glow),
                  color.withValues(alpha: 0.45 * glow),
                ],
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: glow.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale:
                      0.8 +
                      0.4 * Curves.easeOutBack.transform(t.clamp(0.0, 1.0)),
                  child: Text(
                    label,
                    key: ValueKey('special_flash_${kind.name}'),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: color, blurRadius: 24),
                        Shadow(color: color, offset: const Offset(0, 3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
