import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models/memory_card.dart';
import 'models/memory_match_event.dart';
import 'models/memory_match_rules.dart';

/// 카드 앞면에 쓰는 귀여운 동물·과일 이모지. 10x10(50쌍)까지 겹치지 않는다.
const memoryMatchEmojiPool = [
  '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', //
  '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐤', '🦆', '🦉',
  '🐴', '🦄', '🐝', '🐛', '🦋', '🐌', '🐞', '🐢', '🦖', '🐙',
  '🦀', '🐠', '🐬', '🐳', '🐘', '🦒', '🦔', '🦩', '🐿️', '🦦',
  '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍒', '🍑',
  '🥭', '🍍', '🥥', '🥝',
];

/// 게임 진행 상태
enum MemoryMatchStatus {
  /// Stage 시작 팝업을 기다리는 중 (타이머 멈춤, 카드 입력 막힘)
  ready,
  playing,
  stageCleared,
  allCleared,
  gameOver,
}

/// 기억력 짝 맞추기의 게임 상태와 규칙 (스테이지 방식).
///
/// UI와 분리되어 있어 위젯 없이도 테스트할 수 있다. 팝업처럼 한 번만
/// 보여 줄 일은 [events]로 알린다.
class MemoryMatchController extends ChangeNotifier {
  MemoryMatchController({
    int startStage = MemoryMatchRules.firstStage,
    int initialScore = 0,
    Random? random,
    List<String> emojiPool = memoryMatchEmojiPool,
    SpecialCardKind Function(Random random)? pickSpecialCard,
    BombPenalty Function(Random random)? pickBombPenalty,
    bool Function(Random random)? decideEvenGridSpecials,
  }) : assert(
         startStage >= MemoryMatchRules.firstStage &&
             startStage <= MemoryMatchRules.lastStage,
       ),
       _random = random ?? Random(),
       _emojiPool = emojiPool.toSet().toList(),
       _pickSpecialCard = pickSpecialCard ?? _randomSpecialCard,
       _pickBombPenalty = pickBombPenalty ?? _randomBombPenalty,
       _decideEvenGridSpecials =
           decideEvenGridSpecials ?? _randomEvenGridSpecials,
       _stage = startStage,
       _score = initialScore {
    _startStage();
  }

  static SpecialCardKind _randomSpecialCard(Random r) =>
      SpecialCardKind.values[r.nextInt(SpecialCardKind.values.length)];

  static BombPenalty _randomBombPenalty(Random r) =>
      BombPenalty.values[r.nextInt(BombPenalty.values.length)];

  static bool _randomEvenGridSpecials(Random r) =>
      r.nextDouble() < MemoryMatchRules.evenGridSpecialChance;

  final Random _random;
  final List<String> _emojiPool;
  final SpecialCardKind Function(Random) _pickSpecialCard;
  final BombPenalty Function(Random) _pickBombPenalty;
  final bool Function(Random) _decideEvenGridSpecials;
  final _events = StreamController<MemoryMatchEvent>.broadcast();

  int _stage;
  int _score;
  int _remainingSeconds = 0;
  int _remainingChances = 0;
  MemoryMatchStatus _status = MemoryMatchStatus.ready;
  List<MemoryCard> _cards = const [];
  int? _firstIndex;
  bool _isChecking = false;
  bool _isPeeking = false;
  SpecialCardKind? _pendingSpecial;
  BombPenalty? _pendingBombPenalty;
  bool _isExchanging = false;
  StageClearResult? _lastClearResult;
  bool _isDisposed = false;

  Timer? _ticker;
  Timer? _flipBackTimer;
  Timer? _peekTimer;

  /// 팝업·안내 문구 이벤트
  Stream<MemoryMatchEvent> get events => _events.stream;

  int get stage => _stage;
  MemoryGrid get grid => MemoryMatchRules.gridOf(_stage);
  bool get isLastStage => _stage == MemoryMatchRules.lastStage;

  /// 누적 점수
  int get score => _score;
  int get remainingSeconds => _remainingSeconds;
  int get remainingChances => _remainingChances;
  MemoryMatchStatus get status => _status;
  List<MemoryCard> get cards => List.unmodifiable(_cards);
  StageClearResult? get lastClearResult => _lastClearResult;

  int get totalPairs => _cards.where((c) => !c.isSpecial).length ~/ 2;
  int get matchedPairs =>
      _cards.where((c) => !c.isSpecial && c.isMatched).length ~/ 2;

  /// 틀린 두 장이 다시 뒤집히기를 기다리는 중
  bool get isChecking => _isChecking;

  /// ⭐ 별 카드로 모든 카드를 잠깐 보여 주는 중
  bool get isPeeking => _isPeeking;

  /// 찬스!/꽝! 팝업이 떠 있어 [confirmSpecial]을 기다리는 특수 카드.
  /// 이 동안에는 타이머가 멈추고 카드를 누를 수 없다.
  SpecialCardKind? get pendingSpecial => _pendingSpecial;

  /// 꽝! 팝업에서 안내 중인, 아직 적용 전인 벌칙
  BombPenalty? get pendingBombPenalty => _pendingBombPenalty;

  bool get isTimerRunning => _ticker != null;

  /// 이 Stage에서 점수 교환 버튼을 보여 주는지 여부 (Stage 4부터)
  bool get isExchangeUnlocked => _stage >= MemoryMatchRules.exchangeFromStage;

  /// 점수 교환 팝업이 떠 있는 중 (타이머 멈춤, 카드 입력 막힘)
  bool get isExchanging => _isExchanging;

  /// 지금 점수 교환을 시작할 수 있는지 여부
  bool get canExchange =>
      isExchangeUnlocked &&
      _score >= MemoryMatchRules.exchangeCost &&
      acceptsInput;

  /// 카드를 누를 수 있는 상태인지 여부
  bool get acceptsInput =>
      _status == MemoryMatchStatus.playing &&
      !_isChecking &&
      !_isPeeking &&
      !_isExchanging &&
      _pendingSpecial == null;

  /// [index] 카드의 앞면을 화면에 보여야 하는지 여부 (별 카드 효과 포함)
  bool isFaceVisible(int index) {
    final card = _cards[index];
    return card.isRevealed || (_isPeeking && !card.isSpecial);
  }

  /// [index] 위치의 카드를 뒤집는다. 뒤집을 수 없는 상황이면 무시한다.
  void flip(int index) {
    if (!acceptsInput) return;
    if (index < 0 || index >= _cards.length) return;
    final card = _cards[index];
    if (card.isRevealed) return;

    final special = card.special;
    if (special != null) {
      _setCard(index, card.copyWith(isFaceUp: true, isMatched: true));
      switch (special) {
        case SpecialCardKind.star:
          _openStar();
        case SpecialCardKind.bomb:
          _explodeBomb();
      }
      notifyListeners();
      return;
    }

    _setCard(index, card.copyWith(isFaceUp: true));

    final firstIndex = _firstIndex;
    if (firstIndex == null) {
      _firstIndex = index;
      notifyListeners();
      return;
    }
    _firstIndex = null;

    if (_cards[firstIndex].emoji == _cards[index].emoji) {
      _setCard(firstIndex, _cards[firstIndex].copyWith(isMatched: true));
      _setCard(index, _cards[index].copyWith(isMatched: true));
      _score += MemoryMatchRules.pointsPerPair;
      if (matchedPairs == totalPairs) _clearStage();
    } else {
      _remainingChances--;
      if (_remainingChances <= 0) {
        _remainingChances = 0;
        _gameOver(GameOverReason.noChances);
      } else {
        _isChecking = true;
        _flipBackTimer = Timer(MemoryMatchRules.mismatchDelay, () {
          _flipBackTimer = null;
          _isChecking = false;
          _setCard(firstIndex, _cards[firstIndex].copyWith(isFaceUp: false));
          _setCard(index, _cards[index].copyWith(isFaceUp: false));
          _notify();
        });
      }
    }
    notifyListeners();
  }

  /// Stage 시작 팝업에서 확인을 눌렀을 때 호출한다. 이때부터 시간이 줄어든다.
  void start() {
    if (_status != MemoryMatchStatus.ready) return;
    _status = MemoryMatchStatus.playing;
    _startTicker();
    notifyListeners();
  }

  /// 점수 교환 버튼을 눌렀을 때 호출한다. 팝업이 떠 있는 동안 타이머를 멈춘다.
  /// 시작했으면 `true`.
  bool beginExchange() {
    if (!canExchange) return false;
    _isExchanging = true;
    _pauseTicker();
    notifyListeners();
    return true;
  }

  /// 점수 교환 팝업에서 확인을 눌렀을 때 호출한다.
  /// 점수를 내고 [option]을 받은 뒤 게임을 이어 간다.
  void confirmExchange(ExchangeOption option) {
    if (!_isExchanging) return;
    _isExchanging = false;
    if (_score >= MemoryMatchRules.exchangeCost) {
      _score -= MemoryMatchRules.exchangeCost;
      switch (option) {
        case ExchangeOption.chances:
          _remainingChances += MemoryMatchRules.exchangeChances;
        case ExchangeOption.time:
          _remainingSeconds += MemoryMatchRules.exchangeSeconds;
      }
    }
    _resumeAfterExchange();
  }

  /// 점수 교환 팝업에서 취소를 눌렀을 때 호출한다. 그대로 게임을 이어 간다.
  void cancelExchange() {
    if (!_isExchanging) return;
    _isExchanging = false;
    _resumeAfterExchange();
  }

  void _resumeAfterExchange() {
    if (_status == MemoryMatchStatus.playing) _startTicker();
    notifyListeners();
  }

  /// 찬스!/꽝! 팝업에서 확인을 눌렀을 때 호출한다.
  ///
  /// - ⭐ 별: 멈췄던 타이머를 다시 돌리고, 이때부터 [MemoryMatchRules.starPeekDuration](3초) 동안 카드를 보여 준다.
  /// - 💣 폭탄: 이때 벌칙을 적용한다. 0이 되면 게임 오버, 아니면 타이머를 다시 돌린다.
  void confirmSpecial() {
    final special = _pendingSpecial;
    if (special == null || _status != MemoryMatchStatus.playing) return;
    _pendingSpecial = null;

    switch (special) {
      case SpecialCardKind.star:
        _startTicker();
        _startPeek();
      case SpecialCardKind.bomb:
        final penalty = _pendingBombPenalty!;
        _pendingBombPenalty = null;
        _applyBombPenalty(penalty);
        if (_status == MemoryMatchStatus.playing) _startTicker();
    }
    notifyListeners();
  }

  /// 클리어한 Stage 다음으로 넘어간다.
  void nextStage() {
    if (_status != MemoryMatchStatus.stageCleared) return;
    _stage++;
    _startStage();
    _emit(StageReadyEvent(_stage));
    notifyListeners();
  }

  /// 게임 오버 팝업에서 '이어하기'를 보여 주는 Stage인지 (Stage 5부터)
  bool get isContinueUnlocked => _stage >= MemoryMatchRules.continueFromStage;

  /// 지금 이어하기를 쓸 수 있는지 (게임 오버 상태 + Stage 5부터 + 500점 이상)
  bool get canContinue =>
      _status == MemoryMatchStatus.gameOver &&
      isContinueUnlocked &&
      _score >= MemoryMatchRules.continueCost;

  /// 게임 오버 후 500점을 내고 현재 Stage를 처음부터 다시 한다.
  /// 카드는 새로 섞고 시간·기회도 그 Stage의 처음 값으로 돌아간다.
  /// 시작했으면 `true`.
  bool continueStage() {
    if (!canContinue) return false;
    _score -= MemoryMatchRules.continueCost;
    _startStage();
    _emit(StageReadyEvent(_stage));
    notifyListeners();
    return true;
  }

  /// Stage 1부터 점수 0으로 다시 시작한다.
  void restart() {
    _stage = MemoryMatchRules.firstStage;
    _score = 0;
    _startStage();
    _emit(StageReadyEvent(_stage));
    notifyListeners();
  }

  /// 새 Stage를 준비한다. 시간은 [start]를 부를 때부터 줄어든다.
  void _startStage() {
    _cancelTimers();
    _remainingSeconds = MemoryMatchRules.timeLimitFor(_stage);
    _remainingChances = MemoryMatchRules.chancesFor(_stage);
    _status = MemoryMatchStatus.ready;
    _isExchanging = false;
    _firstIndex = null;
    _isChecking = false;
    _isPeeking = false;
    _pendingSpecial = null;
    _pendingBombPenalty = null;
    _lastClearResult = null;
    _deal();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _pauseTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _deal() {
    final cellCount = grid.cellCount;
    final specialCount = _specialCountFor(cellCount);
    final pairCount = (cellCount - specialCount) ~/ 2;
    assert(_emojiPool.length >= pairCount, '이모지가 부족해요');

    final emojis = ([..._emojiPool]..shuffle(_random)).take(pairCount);
    _cards = [
      for (final emoji in emojis) ...[
        MemoryCard(emoji: emoji),
        MemoryCard(emoji: emoji),
      ],
      for (var i = 0; i < specialCount; i++) MemoryCard.special(_specialKind()),
    ]..shuffle(_random);
  }

  /// 특수 카드 장수.
  /// - Stage 1~2 (2x2, 2x3): 없음
  /// - 칸 수가 홀수: 남는 1칸에 꼭 1장
  /// - 칸 수가 짝수: 일정 확률로 2장 (짝 수가 맞아야 하므로)
  int _specialCountFor(int cellCount) {
    if (_stage < MemoryMatchRules.firstSpecialStage) return 0;
    if (cellCount.isOdd) return 1;
    return _decideEvenGridSpecials(_random)
        ? MemoryMatchRules.evenGridSpecialCount
        : 0;
  }

  /// 특수 카드 종류. 3x3에서는 찬스를 꼭 경험하도록 ⭐만 나온다.
  SpecialCardKind _specialKind() =>
      _stage == MemoryMatchRules.guaranteedStarStage
      ? SpecialCardKind.star
      : _pickSpecialCard(_random);

  void _tick() {
    _remainingSeconds--;
    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      _gameOver(GameOverReason.timeUp);
    }
    _notify();
  }

  /// ⭐ 별: 타이머를 멈추고 찬스 팝업을 띄운다. 카드 공개는 [confirmSpecial]에서 시작한다.
  void _openStar() {
    _pendingSpecial = SpecialCardKind.star;
    _pauseTicker();
    _emit(const ChanceEvent());
  }

  void _startPeek() {
    _isPeeking = true;
    _peekTimer = Timer(MemoryMatchRules.starPeekDuration, () {
      _peekTimer = null;
      _isPeeking = false;
      _notify();
    });
  }

  /// 💣 폭탄: 벌칙을 정하고 타이머를 멈춘 뒤 꽝 팝업으로 알린다.
  /// 벌칙은 [confirmSpecial]에서 적용한다.
  void _explodeBomb() {
    final penalty = _pickBombPenalty(_random);
    _pendingSpecial = SpecialCardKind.bomb;
    _pendingBombPenalty = penalty;
    _pauseTicker();
    _emit(BombEvent(penalty));
  }

  /// 벌칙을 적용한다. 0이 되면 게임 오버.
  void _applyBombPenalty(BombPenalty penalty) {
    switch (penalty) {
      case BombPenalty.time:
        _remainingSeconds -= MemoryMatchRules.bombTimePenaltySeconds;
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
          _gameOver(GameOverReason.timeUp);
        }
      case BombPenalty.chance:
        _remainingChances -= MemoryMatchRules.bombChancePenalty;
        if (_remainingChances <= 0) {
          _remainingChances = 0;
          _gameOver(GameOverReason.noChances);
        }
    }
  }

  void _clearStage() {
    _cancelTimers();
    final timeBonus = _remainingSeconds * MemoryMatchRules.bonusPerSecond;
    final chanceBonus = _remainingChances * MemoryMatchRules.bonusPerChance;
    _score += timeBonus + chanceBonus;
    _status = isLastStage
        ? MemoryMatchStatus.allCleared
        : MemoryMatchStatus.stageCleared;
    final result = StageClearResult(
      stage: _stage,
      remainingSeconds: _remainingSeconds,
      remainingChances: _remainingChances,
      timeBonus: timeBonus,
      chanceBonus: chanceBonus,
      totalScore: _score,
      isLastStage: isLastStage,
    );
    _lastClearResult = result;
    _emit(StageClearedEvent(result));
  }

  void _gameOver(GameOverReason reason) {
    _cancelTimers();
    _isChecking = false;
    _isPeeking = false;
    _pendingSpecial = null;
    _pendingBombPenalty = null;
    _isExchanging = false;
    _status = MemoryMatchStatus.gameOver;
    _emit(GameOverEvent(reason: reason, stage: _stage, score: _score));
  }

  void _setCard(int index, MemoryCard card) {
    _cards = [..._cards]..[index] = card;
  }

  void _cancelTimers() {
    _ticker?.cancel();
    _ticker = null;
    _flipBackTimer?.cancel();
    _flipBackTimer = null;
    _peekTimer?.cancel();
    _peekTimer = null;
  }

  void _emit(MemoryMatchEvent event) {
    if (!_isDisposed) _events.add(event);
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelTimers();
    _events.close();
    super.dispose();
  }
}
