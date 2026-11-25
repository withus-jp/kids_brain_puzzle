import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_brain_puzzle/games/memory_match/memory_match_controller.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_card.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_match_event.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_match_rules.dart';

import 'helpers/no_preview.dart';

/// 일반 카드의 그림 → 두 위치
Map<String, List<int>> _pairs(MemoryMatchController c) {
  final pairs = <String, List<int>>{};
  for (var i = 0; i < c.cards.length; i++) {
    if (!c.cards[i].isSpecial) (pairs[c.cards[i].emoji] ??= []).add(i);
  }
  return pairs;
}

/// 서로 다른 그림인 일반 카드 두 위치
(int, int) _mismatch(MemoryMatchController c) {
  final pairs = _pairs(c).values.toList();
  return (pairs[0][0], pairs[1][0]);
}

int _specialIndex(MemoryMatchController c) =>
    c.cards.indexWhere((card) => card.isSpecial);

/// 남은 짝을 모두 맞춘다.
void _solve(MemoryMatchController c) {
  for (final pair in _pairs(c).values) {
    if (!c.cards[pair[0]].isMatched) {
      c.flip(pair[0]);
      c.flip(pair[1]);
    }
  }
}

/// 테스트용 컨트롤러. 짝수 그리드의 특수 카드는 기본으로 넣지 않는다.
/// [start]가 `true`이면 시작 팝업에서 확인을 누른 상태로 만든다.
MemoryMatchController _controller({
  int stage = 1,
  int score = 0,
  SpecialCardKind special = SpecialCardKind.star,
  BombPenalty penalty = BombPenalty.time,
  bool evenGridSpecials = false,
  bool start = true,
}) {
  final c = MemoryMatchController(
    previewDurationFor: noPreview,
    startStage: stage,
    initialScore: score,
    pickSpecialCard: (_) => special,
    pickBombPenalty: (_) => penalty,
    decideEvenGridSpecials: (_) => evenGridSpecials,
  );
  if (start) c.start();
  return c;
}

void main() {
  group('스테이지 구성', () {
    test('Stage 순서: 2x2, 2x3, 3x3, 3x4, … 9x10, 10x10', () {
      expect(
        [
          for (var s = 1; s <= MemoryMatchRules.lastStage; s++)
            MemoryMatchRules.gridOf(s).label,
        ],
        [
          '2x2', '2x3', '3x3', '3x4', '4x4', '4x5', '5x5', '5x6', '6x6', //
          '6x7', '7x7', '7x8', '8x8', '8x9', '9x9', '9x10', '10x10',
        ],
      );
    });

    for (var stage = 1; stage <= MemoryMatchRules.lastStage; stage++) {
      final grid = MemoryMatchRules.gridOf(stage);
      final cells = grid.cellCount;

      for (final evenSpecials in [false, true]) {
        // 홀수 칸: 항상 1장 / 짝수 칸: 넣기로 하면 2장 (단 2x2는 제외)
        // 2x2·2x3: 없음 / 홀수 칸: 1장 / 짝수 칸: 넣기로 하면 2장
        final expectedSpecials = stage < 3
            ? 0
            : cells.isOdd
            ? 1
            : (evenSpecials ? 2 : 0);
        test('Stage $stage ($grid, 짝수 특수 카드 ${evenSpecials ? "넣음" : "안 넣음"}): '
            '특수 카드 $expectedSpecials장, 나머지는 그림마다 2장', () {
          final c = _controller(stage: stage, evenGridSpecials: evenSpecials);
          expect(c.grid, grid);
          expect(c.cards, hasLength(cells));
          expect(
            c.cards.where((card) => card.isSpecial),
            hasLength(expectedSpecials),
          );
          expect(_pairs(c).values.map((p) => p.length), everyElement(2));
          expect(c.totalPairs, (cells - expectedSpecials) ~/ 2);
          expect(c.cards.every((card) => !card.isRevealed), isTrue);
          c.dispose();
        });
      }
    }

    test('2x2·2x3에는 특수 카드가 전혀 없다 (짝수 특수 카드를 넣기로 해도)', () {
      for (final stage in [1, 2]) {
        for (var seed = 0; seed < 20; seed++) {
          final c = MemoryMatchController(
            previewDurationFor: noPreview,
            startStage: stage,
            random: Random(seed),
            decideEvenGridSpecials: (_) => true,
          );
          expect(c.cards.where((card) => card.isSpecial), isEmpty);
          c.dispose();
        }
      }
    });

    test('3x3의 특수 카드는 항상 ⭐ 찬스 1장 (폭탄을 고르게 해도)', () {
      for (var seed = 0; seed < 20; seed++) {
        final c = MemoryMatchController(
          previewDurationFor: noPreview,
          startStage: 3,
          random: Random(seed),
          pickSpecialCard: (_) => SpecialCardKind.bomb,
        );
        final specials = c.cards.where((card) => card.isSpecial).toList();
        expect(specials, hasLength(1));
        expect(specials.single.special, SpecialCardKind.star);
        c.dispose();
      }
    });

    test('짝수 그리드는 무작위로 특수 카드가 들어가기도, 안 들어가기도 한다', () {
      final counts = {
        for (var seed = 0; seed < 30; seed++)
          (MemoryMatchController(
            previewDurationFor: noPreview,
            startStage: 4,
            random: Random(seed),
          )..dispose()).cards.where((c) => c.isSpecial).length,
      };
      expect(counts, {0, 2});
    });

    test('시작 시 20초, 기회 5번, 점수 0', () {
      final c = MemoryMatchController(previewDurationFor: noPreview);
      expect(c.stage, 1);
      expect(c.remainingSeconds, 20);
      expect(c.remainingChances, 5);
      expect(c.score, 0);
      expect(c.status, MemoryMatchStatus.ready, reason: '시작 팝업을 기다린다');
      c.dispose();
    });

    test('셔플: 시드마다 배치가 달라진다', () {
      final layouts = {
        for (var seed = 0; seed < 10; seed++)
          (MemoryMatchController(
            previewDurationFor: noPreview,
            startStage: 3,
            random: Random(seed),
          )..dispose()).cards.map((c) => c.emoji).join(),
      };
      expect(layouts.length, greaterThan(1));
    });

    test('특수 카드 종류는 별과 폭탄이 모두 나온다', () {
      final kinds = {
        for (var seed = 0; seed < 30; seed++)
          (MemoryMatchController(
            previewDurationFor: noPreview,
            startStage: 7,
            random: Random(seed),
          )..dispose()).cards.firstWhere((c) => c.isSpecial).special,
      };
      expect(kinds, {SpecialCardKind.star, SpecialCardKind.bomb});
    });
  });

  group('타이머', () {
    test('Stage가 시작되면 바로 1초씩 줄어든다', () {
      fakeAsync((async) {
        final c = _controller();
        async.elapse(const Duration(seconds: 3));
        expect(c.remainingSeconds, 17);
        c.dispose();
      });
    });

    test('0초가 되면 게임 오버', () {
      fakeAsync((async) {
        final c = _controller();
        final events = <MemoryMatchEvent>[];
        c.events.listen(events.add);

        async.elapse(const Duration(seconds: 20));
        expect(c.remainingSeconds, 0);
        expect(c.status, MemoryMatchStatus.gameOver);
        expect(c.isTimerRunning, isFalse);
        expect(
          events.single,
          isA<GameOverEvent>().having(
            (e) => e.reason,
            'reason',
            GameOverReason.timeUp,
          ),
        );

        // 게임 오버 후에는 카드를 뒤집을 수 없다.
        c.flip(0);
        expect(c.cards[0].isFaceUp, isFalse);
        c.dispose();
      });
    });
  });

  group('짝 맞추기', () {
    test('짝을 찾으면 10점, 기회는 그대로', () {
      fakeAsync((async) {
        final c = _controller(stage: 3);
        final pair = _pairs(c).values.first;
        c.flip(pair[0]);
        c.flip(pair[1]);
        expect(c.score, 10);
        expect(c.matchedPairs, 1);
        expect(c.remainingChances, 5);
        c.dispose();
      });
    });

    test('틀리면 기회가 1 줄고 0.8초 뒤 다시 뒤집힌다', () {
      fakeAsync((async) {
        final c = _controller(stage: 3);
        final (a, b) = _mismatch(c);
        c.flip(a);
        c.flip(b);
        expect(c.remainingChances, 4);
        expect(c.isChecking, isTrue);

        async.elapse(const Duration(milliseconds: 799));
        expect(c.cards[a].isFaceUp, isTrue);
        async.elapse(const Duration(milliseconds: 1));
        expect(c.cards[a].isFaceUp, isFalse);
        expect(c.cards[b].isFaceUp, isFalse);
        c.dispose();
      });
    });

    test('틀린 카드를 기다리는 동안에는 다른 카드를 못 뒤집는다', () {
      fakeAsync((async) {
        final c = _controller(stage: 3);
        final (a, b) = _mismatch(c);
        final third = _pairs(c).values.toList()[2][0];
        c.flip(a);
        c.flip(b);
        c.flip(third);
        expect(c.cards[third].isFaceUp, isFalse);
        c.dispose();
      });
    });

    test('기회가 0이 되면 게임 오버', () {
      fakeAsync((async) {
        final c = _controller(stage: 3);
        final events = <MemoryMatchEvent>[];
        c.events.listen(events.add);

        for (var i = 0; i < 5; i++) {
          final (a, b) = _mismatch(c);
          c.flip(a);
          c.flip(b);
          async.elapse(MemoryMatchRules.mismatchDelay);
        }
        async.flushMicrotasks();
        expect(c.remainingChances, 0);
        expect(c.status, MemoryMatchStatus.gameOver);
        expect(
          events.single,
          isA<GameOverEvent>().having(
            (e) => e.reason,
            'reason',
            GameOverReason.noChances,
          ),
        );
        c.dispose();
      });
    });
  });

  group('스테이지 클리어', () {
    test('남은 시간 1초당 10점, 남은 기회 1번당 50점 보너스', () {
      fakeAsync((async) {
        final c = _controller(stage: 5); // 4x4, 8쌍, 30초 / 7번
        final events = <MemoryMatchEvent>[];
        c.events.listen(events.add);

        final (a, b) = _mismatch(c);
        c.flip(a);
        c.flip(b); // 기회 6
        async.elapse(const Duration(seconds: 5)); // 25초 남음
        _solve(c);
        async.flushMicrotasks();

        expect(c.status, MemoryMatchStatus.stageCleared);
        expect(c.isTimerRunning, isFalse);
        final result = (events.single as StageClearedEvent).result;
        expect(result.remainingSeconds, 25);
        expect(result.remainingChances, 6);
        expect(result.timeBonus, 250);
        expect(result.chanceBonus, 300);
        expect(result.totalScore, 8 * 10 + 250 + 300);
        expect(c.score, result.totalScore);

        // 다음 스테이지 대기 중에는 시간이 줄지 않는다.
        async.elapse(const Duration(seconds: 5));
        expect(c.remainingSeconds, 25);
        c.dispose();
      });
    });

    test('다음 스테이지는 한 칸 큰 그리드, 시간·기회 초기화, 점수 유지', () {
      fakeAsync((async) {
        final c = _controller();
        _solve(c);
        final score = c.score;

        c.nextStage();
        expect(c.stage, 2);
        expect(c.grid, const MemoryGrid(2, 3));
        expect(c.remainingSeconds, 20);
        expect(c.remainingChances, 5);
        expect(c.score, score);
        expect(c.status, MemoryMatchStatus.ready, reason: '시작 팝업을 기다린다');
        c.dispose();
      });
    });

    test('특수 카드를 열지 않아도 짝만 다 맞추면 클리어', () {
      fakeAsync((async) {
        final c = _controller(stage: 3);
        _solve(c);
        expect(c.cards[_specialIndex(c)].isRevealed, isFalse);
        expect(c.status, MemoryMatchStatus.stageCleared);
        c.dispose();
      });
    });

    test('마지막 Stage(10x10)를 클리어하면 모두 클리어', () {
      fakeAsync((async) {
        final c = _controller(stage: MemoryMatchRules.lastStage);
        expect(c.grid, const MemoryGrid(10, 10));
        _solve(c);
        expect(c.status, MemoryMatchStatus.allCleared);
        expect(c.lastClearResult?.isLastStage, isTrue);

        c.nextStage(); // 무시된다
        expect(c.stage, MemoryMatchRules.lastStage);
        c.dispose();
      });
    });

    test('재도전은 Stage 1, 점수 0부터 다시', () {
      fakeAsync((async) {
        final c = _controller(stage: 4);
        _solve(c);
        c.restart();
        expect(c.stage, 1);
        expect(c.score, 0);
        expect(c.remainingSeconds, 20);
        expect(c.remainingChances, 5);
        expect(c.status, MemoryMatchStatus.ready, reason: '시작 팝업을 기다린다');
        c.dispose();
      });
    });
  });

  group('특수 카드', () {
    test('⭐ 별: 찬스 팝업을 기다리는 동안 타이머·입력이 멈추고, 확인 후 3초 공개', () {
      fakeAsync((async) {
        final c = _controller(stage: 3, special: SpecialCardKind.star);
        final events = <MemoryMatchEvent>[];
        c.events.listen(events.add);
        final star = _specialIndex(c);
        final pair = _pairs(c).values.first;

        c.flip(star);
        async.flushMicrotasks();
        expect(events.single, isA<ChanceEvent>());
        expect(c.pendingSpecial, SpecialCardKind.star);
        expect(c.isPeeking, isFalse, reason: '팝업을 닫기 전에는 공개하지 않는다');
        expect(c.isFaceVisible(pair[0]), isFalse);

        // 팝업이 떠 있는 동안: 시간 멈춤, 카드 입력 무시
        async.elapse(const Duration(seconds: 5));
        expect(c.remainingSeconds, 20);
        expect(c.isTimerRunning, isFalse);
        c.flip(pair[0]);
        expect(c.cards[pair[0]].isFaceUp, isFalse);

        // 팝업 닫기 → 3초 동안 모든 카드 공개
        c.confirmSpecial();
        expect(c.pendingSpecial, isNull);
        expect(c.isPeeking, isTrue);
        expect(c.isTimerRunning, isTrue);
        expect(
          List.generate(c.cards.length, c.isFaceVisible),
          everyElement(isTrue),
        );
        c.flip(pair[0]); // 보여 주는 동안에도 무시
        expect(c.cards[pair[0]].isFaceUp, isFalse);

        expect(MemoryMatchRules.starPeekDuration, const Duration(seconds: 3));
        async.elapse(const Duration(milliseconds: 2999));
        expect(c.isPeeking, isTrue, reason: '3초가 되기 전까지는 계속 보인다');
        expect(c.isFaceVisible(pair[0]), isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(c.isPeeking, isFalse);
        expect(c.isFaceVisible(pair[0]), isFalse);
        expect(c.isFaceVisible(star), isTrue, reason: '별은 열린 채로 남는다');

        // 보여 주는 3초 동안 제한 시간은 흐른다. 기회·점수에는 영향 없음
        expect(c.remainingSeconds, 17);
        expect(c.remainingChances, 5);
        expect(c.score, 0);
        c.dispose();
      });
    });

    test('⭐ 별은 먼저 열어 둔 카드를 덮지 않는다', () {
      fakeAsync((async) {
        final c = _controller(stage: 3, special: SpecialCardKind.star);
        final pair = _pairs(c).values.first;
        c.flip(pair[0]);
        c.flip(_specialIndex(c));
        c.confirmSpecial();
        async.elapse(MemoryMatchRules.starPeekDuration);
        expect(c.cards[pair[0]].isFaceUp, isTrue);

        c.flip(pair[1]);
        expect(c.matchedPairs, 1);
        c.dispose();
      });
    });

    test('💣 폭탄(시간): 꽝 팝업 동안 시간이 멈추고, 확인하면 3초 감소', () {
      fakeAsync((async) {
        final c = _controller(
          stage: 7,
          special: SpecialCardKind.bomb,
          penalty: BombPenalty.time,
        );
        final events = <MemoryMatchEvent>[];
        c.events.listen(events.add);
        final pair = _pairs(c).values.first;

        c.flip(_specialIndex(c));
        async.flushMicrotasks();
        expect(
          events.single,
          isA<BombEvent>().having(
            (e) => e.penalty,
            'penalty',
            BombPenalty.time,
          ),
        );
        expect(c.pendingSpecial, SpecialCardKind.bomb);
        expect(c.pendingBombPenalty, BombPenalty.time);
        expect(c.remainingSeconds, 40, reason: '확인 전에는 아직 안 뺏는다');

        // 팝업이 떠 있는 동안: 시간 멈춤, 카드 입력 무시
        async.elapse(const Duration(seconds: 5));
        expect(c.remainingSeconds, 40);
        expect(c.isTimerRunning, isFalse);
        c.flip(pair[0]);
        expect(c.cards[pair[0]].isFaceUp, isFalse);

        c.confirmSpecial();
        expect(c.remainingSeconds, 37);
        expect(c.remainingChances, 9);
        expect(c.pendingSpecial, isNull);
        expect(c.isTimerRunning, isTrue);
        expect(c.acceptsInput, isTrue);

        async.elapse(const Duration(seconds: 1));
        expect(c.remainingSeconds, 36);
        c.dispose();
      });
    });

    test('💣 폭탄(기회): 확인하면 기회 1 감소', () {
      fakeAsync((async) {
        final c = _controller(
          stage: 7,
          special: SpecialCardKind.bomb,
          penalty: BombPenalty.chance,
        );
        c.flip(_specialIndex(c));
        expect(c.remainingChances, 9, reason: '확인 전에는 아직 안 뺏는다');
        c.confirmSpecial();
        expect(c.remainingChances, 8);
        expect(c.remainingSeconds, 40);
        c.dispose();
      });
    });

    test('💣 폭탄으로 시간이 0이 되면 확인 후 게임 오버', () {
      fakeAsync((async) {
        final c = _controller(
          stage: 7,
          special: SpecialCardKind.bomb,
          penalty: BombPenalty.time,
        );
        final events = <MemoryMatchEvent>[];
        c.events.listen(events.add);
        async.elapse(const Duration(seconds: 38)); // 2초 남음

        c.flip(_specialIndex(c));
        expect(c.status, MemoryMatchStatus.playing);

        c.confirmSpecial();
        async.flushMicrotasks();
        expect(c.remainingSeconds, 0);
        expect(c.status, MemoryMatchStatus.gameOver);
        expect(c.isTimerRunning, isFalse);
        expect(
          events.last,
          isA<GameOverEvent>().having(
            (e) => e.reason,
            'reason',
            GameOverReason.timeUp,
          ),
        );
        c.dispose();
      });
    });

    test('💣 폭탄으로 기회가 0이 되면 확인 후 게임 오버', () {
      fakeAsync((async) {
        final c = _controller(
          stage: 7,
          special: SpecialCardKind.bomb,
          penalty: BombPenalty.chance,
        );
        for (var i = 0; i < 8; i++) {
          final (a, b) = _mismatch(c);
          c.flip(a);
          c.flip(b);
          async.elapse(MemoryMatchRules.mismatchDelay);
        }
        expect(c.remainingChances, 1);
        c.flip(_specialIndex(c));
        expect(c.status, MemoryMatchStatus.playing);

        c.confirmSpecial();
        expect(c.remainingChances, 0);
        expect(c.status, MemoryMatchStatus.gameOver);
        c.dispose();
      });
    });

    test('재시작하면 팝업 대기 상태가 풀린다', () {
      fakeAsync((async) {
        final c = _controller(stage: 7, special: SpecialCardKind.bomb);
        c.flip(_specialIndex(c));
        c.restart();
        expect(c.pendingSpecial, isNull);
        expect(c.pendingBombPenalty, isNull);
        c.start(); // 새 Stage 시작 팝업에서 확인
        expect(c.acceptsInput, isTrue);
        c.confirmSpecial(); // 무시된다
        expect(c.remainingSeconds, 20);
        c.dispose();
      });
    });
  });

  group('스테이지 시작', () {
    test('시작을 누르기 전에는 시간이 안 줄고 카드도 안 뒤집힌다', () {
      fakeAsync((async) {
        final c = _controller(start: false);
        expect(c.status, MemoryMatchStatus.ready);
        expect(c.acceptsInput, isFalse);

        async.elapse(const Duration(seconds: 5));
        expect(c.remainingSeconds, 20);
        c.flip(0);
        expect(c.cards[0].isFaceUp, isFalse);

        c.start();
        expect(c.status, MemoryMatchStatus.playing);
        expect(c.isTimerRunning, isTrue);
        async.elapse(const Duration(seconds: 2));
        expect(c.remainingSeconds, 18);
        c.flip(0);
        expect(c.cards[0].isFaceUp, isTrue);
        c.dispose();
      });
    });

    test('다음 스테이지·재도전 때 StageReadyEvent를 보낸다', () {
      fakeAsync((async) {
        final c = _controller();
        final events = <MemoryMatchEvent>[];
        c.events.listen(events.add);

        _solve(c);
        c.nextStage();
        async.flushMicrotasks();
        expect(
          events.last,
          isA<StageReadyEvent>().having((e) => e.stage, 'stage', 2),
        );

        // 다음 스테이지 대기 중에는 시간이 안 줄어든다.
        async.elapse(const Duration(seconds: 3));
        expect(c.remainingSeconds, 20);

        c.restart();
        async.flushMicrotasks();
        expect(
          events.last,
          isA<StageReadyEvent>().having((e) => e.stage, 'stage', 1),
        );
        c.dispose();
      });
    });
  });

  group('점수 교환', () {
    test('Stage 3까지는 쓸 수 없고 Stage 4부터 열린다', () {
      final s3 = _controller(stage: 3, score: 500);
      expect(s3.isExchangeUnlocked, isFalse);
      expect(s3.canExchange, isFalse);
      expect(s3.beginExchange(), isFalse);
      s3.dispose();

      final s4 = _controller(stage: 4, score: 500);
      expect(s4.isExchangeUnlocked, isTrue);
      expect(s4.canExchange, isTrue);
      s4.dispose();
    });

    test('100점보다 적으면 쓸 수 없다', () {
      final c = _controller(stage: 4, score: 99);
      expect(c.canExchange, isFalse);
      expect(c.beginExchange(), isFalse);
      c.dispose();
    });

    test('시작 팝업 전에는 쓸 수 없다', () {
      final c = _controller(stage: 4, score: 500, start: false);
      expect(c.canExchange, isFalse);
      c.dispose();
    });

    test('교환 팝업 동안 시간이 멈추고 카드가 안 뒤집힌다', () {
      fakeAsync((async) {
        final c = _controller(stage: 4, score: 300);
        expect(c.beginExchange(), isTrue);
        expect(c.isExchanging, isTrue);
        expect(c.isTimerRunning, isFalse);

        async.elapse(const Duration(seconds: 5));
        expect(c.remainingSeconds, 25);
        c.flip(0);
        expect(c.cards[0].isFaceUp, isFalse);
        c.dispose();
      });
    });

    test('기회 +2: 100점을 내고 기회가 2번 늘고, 게임이 이어진다', () {
      fakeAsync((async) {
        final c = _controller(stage: 4, score: 250);
        c.beginExchange();
        c.confirmExchange(ExchangeOption.chances);
        expect(c.score, 150);
        expect(c.remainingChances, 8);
        expect(c.remainingSeconds, 25);
        expect(c.isExchanging, isFalse);
        expect(c.isTimerRunning, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(c.remainingSeconds, 24);
        c.dispose();
      });
    });

    test('시간 +5초: 100점을 내고 시간이 5초 는다', () {
      fakeAsync((async) {
        final c = _controller(stage: 4, score: 100);
        async.elapse(const Duration(seconds: 4)); // 21초 남음
        c.beginExchange();
        c.confirmExchange(ExchangeOption.time);
        expect(c.score, 0);
        expect(c.remainingSeconds, 26);
        expect(c.remainingChances, 6);
        expect(c.canExchange, isFalse, reason: '이제 점수가 모자란다');
        c.dispose();
      });
    });

    test('취소하면 아무것도 바뀌지 않고 게임이 이어진다', () {
      fakeAsync((async) {
        final c = _controller(stage: 4, score: 300);
        c.beginExchange();
        c.cancelExchange();
        expect(c.score, 300);
        expect(c.remainingChances, 6);
        expect(c.remainingSeconds, 25);
        expect(c.isExchanging, isFalse);
        expect(c.isTimerRunning, isTrue);
        expect(c.acceptsInput, isTrue);
        c.dispose();
      });
    });

    test('여러 번 바꿀 수 있다', () {
      final c = _controller(stage: 4, score: 300);
      for (var i = 0; i < 3; i++) {
        c.beginExchange();
        c.confirmExchange(ExchangeOption.chances);
      }
      expect(c.score, 0);
      expect(c.remainingChances, 12);
      c.dispose();
    });
  });

  group('Stage별 시간·기회', () {
    test('Stage 1~3은 20초/5번, Stage 4부터 Stage마다 +5초/+1번', () {
      expect(
        [for (var s = 1; s <= 7; s++) MemoryMatchRules.timeLimitFor(s)],
        [20, 20, 20, 25, 30, 35, 40],
      );
      expect(
        [for (var s = 1; s <= 7; s++) MemoryMatchRules.chancesFor(s)],
        [5, 5, 5, 6, 7, 8, 9],
      );
      expect(MemoryMatchRules.timeLimitFor(MemoryMatchRules.lastStage), 90);
      expect(MemoryMatchRules.chancesFor(MemoryMatchRules.lastStage), 19);
    });

    for (final stage in [1, 3, 4, 5, 17]) {
      test('Stage $stage는 정해진 시간·기회로 시작한다', () {
        final c = _controller(stage: stage, start: false);
        expect(c.remainingSeconds, MemoryMatchRules.timeLimitFor(stage));
        expect(c.remainingChances, MemoryMatchRules.chancesFor(stage));
        c.dispose();
      });
    }

    test('다음 Stage로 넘어가면 늘어난 값으로 시작한다 (3 → 4)', () {
      fakeAsync((async) {
        final c = _controller(stage: 3);
        _solve(c);
        c.nextStage();
        expect(c.stage, 4);
        expect(c.remainingSeconds, 25);
        expect(c.remainingChances, 6);
        c.dispose();
      });
    });
  });

  group('이어하기 (Stage 5부터)', () {
    /// 기회를 모두 써서 게임 오버로 만든다.
    void loseByChances(MemoryMatchController c, FakeAsync async) {
      while (c.status == MemoryMatchStatus.playing) {
        final (a, b) = _mismatch(c);
        c.flip(a);
        c.flip(b);
        async.elapse(MemoryMatchRules.mismatchDelay);
      }
    }

    test('Stage 4에서는 쓸 수 없다', () {
      fakeAsync((async) {
        final c = _controller(stage: 4, score: 900);
        loseByChances(c, async);
        expect(c.status, MemoryMatchStatus.gameOver);
        expect(c.isContinueUnlocked, isFalse);
        expect(c.canContinue, isFalse);
        expect(c.continueStage(), isFalse);
        c.dispose();
      });
    });

    test('게임 오버가 아니면 쓸 수 없다', () {
      final c = _controller(stage: 5, score: 900);
      expect(c.isContinueUnlocked, isTrue);
      expect(c.canContinue, isFalse);
      c.dispose();
    });

    test('500점보다 적으면 쓸 수 없다', () {
      fakeAsync((async) {
        final c = _controller(stage: 5, score: 499);
        loseByChances(c, async);
        expect(c.canContinue, isFalse);
        expect(c.continueStage(), isFalse);
        expect(c.status, MemoryMatchStatus.gameOver);
        c.dispose();
      });
    });

    test('500점을 내고 같은 Stage를 새 카드·처음 시간·기회로 다시 한다', () {
      fakeAsync((async) {
        final c = _controller(stage: 6, score: 800);
        final events = <MemoryMatchEvent>[];
        c.events.listen(events.add);
        final before = c.cards.map((card) => card.emoji).join();

        async.elapse(const Duration(seconds: 3));
        loseByChances(c, async);
        expect(c.canContinue, isTrue);

        expect(c.continueStage(), isTrue);
        async.flushMicrotasks();
        expect(c.stage, 6, reason: '같은 Stage');
        expect(c.score, 300);
        expect(c.remainingSeconds, MemoryMatchRules.timeLimitFor(6));
        expect(c.remainingChances, MemoryMatchRules.chancesFor(6));
        expect(c.status, MemoryMatchStatus.ready, reason: '시작 팝업부터');
        expect(c.cards.every((card) => !card.isRevealed), isTrue);
        expect(
          events.last,
          isA<StageReadyEvent>().having((e) => e.stage, 'stage', 6),
        );
        // 대부분의 경우 배치가 새로 섞인다 (같을 확률은 거의 0)
        expect(c.cards.map((card) => card.emoji).join(), isNot(before));
        c.dispose();
      });
    });
  });

  group('판 기록 (Phase 3)', () {
    test('시도 횟수는 카드 두 장을 뒤집을 때마다 센다 (맞든 틀리든)', () {
      fakeAsync((async) {
        final c = _controller(stage: 3);
        final (a, b) = _mismatch(c);
        c.flip(a);
        expect(c.runMoves, 0, reason: '한 장만 뒤집으면 아직 아니다');
        c.flip(b);
        expect(c.runMoves, 1);
        async.elapse(MemoryMatchRules.mismatchDelay);

        final pair = _pairs(c).values.first;
        c.flip(pair[0]);
        c.flip(pair[1]);
        expect(c.runMoves, 2);

        // 특수 카드는 세지 않는다
        c.flip(_specialIndex(c));
        expect(c.runMoves, 2);
        c.dispose();
      });
    });

    test('플레이 시간은 시간이 흐른 동안만 센다 (팝업·시작 전 제외)', () {
      fakeAsync((async) {
        final c = _controller(stage: 4, score: 500, start: false);
        async.elapse(const Duration(seconds: 5)); // 시작 팝업
        expect(c.runPlaySeconds, 0);

        c.start();
        async.elapse(const Duration(seconds: 3));
        expect(c.runPlaySeconds, 3);

        c.beginExchange(); // 교환 팝업 동안 멈춤
        async.elapse(const Duration(seconds: 10));
        c.cancelExchange();
        async.elapse(const Duration(seconds: 2));
        expect(c.runPlaySeconds, 5);
        c.dispose();
      });
    });

    test('toRecord: 지금 판의 결과를 담는다', () {
      fakeAsync((async) {
        final now = DateTime(2026, 11, 24, 15, 0);
        final c = MemoryMatchController(
          previewDurationFor: noPreview,
          startStage: 2,
          clock: () => now,
        )..start();
        async.elapse(const Duration(seconds: 4));
        final (a, b) = _mismatch(c);
        c.flip(a);
        c.flip(b);

        final record = c.toRecord();
        expect(record.id, c.runId);
        expect(record.gameId, 'memory_match');
        expect(record.stage, 2);
        expect(record.cleared, isFalse);
        expect(record.score, c.score);
        expect(record.elapsedSeconds, 4);
        expect(record.moves, 1);
        expect(record.playedAt, now);
        c.dispose();
      });
    });

    test('Stage를 넘어가도 이어서 센다', () {
      fakeAsync((async) {
        final c = _controller();
        async.elapse(const Duration(seconds: 2));
        _solve(c); // 2쌍 → 시도 2
        c.nextStage();
        c.start();
        async.elapse(const Duration(seconds: 3));
        final (a, b) = _mismatch(c);
        c.flip(a);
        c.flip(b);
        expect(c.runPlaySeconds, 5);
        expect(c.runMoves, 3);
        c.dispose();
      });
    });

    test('재도전은 새 판: id가 바뀌고 0부터 센다', () {
      fakeAsync((async) {
        final c = _controller();
        final firstId = c.runId;
        async.elapse(const Duration(seconds: 3));
        _solve(c);
        c.restart();
        expect(c.runId, isNot(firstId));
        expect(c.runPlaySeconds, 0);
        expect(c.runMoves, 0);
        c.dispose();
      });
    });

    test('이어하기는 같은 판: id와 누적 값이 그대로다', () {
      fakeAsync((async) {
        final c = _controller(stage: 5, score: 900);
        final id = c.runId;
        async.elapse(const Duration(seconds: 2));
        while (c.status == MemoryMatchStatus.playing) {
          final (a, b) = _mismatch(c);
          c.flip(a);
          c.flip(b);
          async.elapse(MemoryMatchRules.mismatchDelay);
        }
        final moves = c.runMoves;
        final seconds = c.runPlaySeconds;

        c.continueStage();
        expect(c.runId, id);
        expect(c.runMoves, moves);
        expect(c.runPlaySeconds, seconds);
        c.dispose();
      });
    });

    test('마지막 Stage를 클리어하면 cleared 기록이 된다', () {
      fakeAsync((async) {
        final c = _controller(stage: MemoryMatchRules.lastStage);
        _solve(c);
        expect(c.status, MemoryMatchStatus.allCleared);
        final record = c.toRecord();
        expect(record.cleared, isTrue);
        expect(record.stage, MemoryMatchRules.lastStage);
        c.dispose();
      });
    });
  });

  group('시작 미리 보기', () {
    test('미리 보기 시간: Stage 1~4는 3초, Stage 5부터 5초', () {
      expect(
        [for (var s = 1; s <= 6; s++) MemoryMatchRules.previewDurationFor(s)],
        [
          for (final sec in [3, 3, 3, 3, 5, 5]) Duration(seconds: sec),
        ],
      );
      expect(
        MemoryMatchRules.previewDurationFor(MemoryMatchRules.lastStage),
        const Duration(seconds: 5),
      );
    });

    for (final (stage, seconds) in [(1, 3), (4, 3), (5, 5), (9, 5)]) {
      test('Stage $stage: 시작하면 $seconds초 동안 카드를 모두 보여 주고, 그동안 시간이 멈춘다', () {
        fakeAsync((async) {
          final c = MemoryMatchController(
            startStage: stage,
            decideEvenGridSpecials: (_) => false,
          );
          expect(c.previewDuration, Duration(seconds: seconds));
          final limit = c.remainingSeconds;

          c.start();
          expect(c.isPreviewing, isTrue);
          expect(c.acceptsInput, isFalse);
          expect(c.isTimerRunning, isFalse);
          for (var i = 0; i < c.cards.length; i++) {
            expect(
              c.isFaceVisible(i),
              !c.cards[i].isSpecial,
              reason: '특수 카드만 빼고 모두 보인다',
            );
          }
          c.flip(0);
          expect(c.cards[0].isFaceUp, isFalse, reason: '미리 보기 중에는 못 뒤집는다');

          async.elapse(
            Duration(seconds: seconds) - const Duration(milliseconds: 1),
          );
          expect(c.isPreviewing, isTrue);
          expect(c.remainingSeconds, limit);

          async.elapse(const Duration(milliseconds: 1));
          expect(c.isPreviewing, isFalse);
          expect(c.acceptsInput, isTrue);
          expect(c.isTimerRunning, isTrue);
          expect(
            [for (var i = 0; i < c.cards.length; i++) c.isFaceVisible(i)],
            everyElement(isFalse),
            reason: '미리 보기가 끝나면 모두 덮는다',
          );

          async.elapse(const Duration(seconds: 1));
          expect(c.remainingSeconds, limit - 1, reason: '이때부터 시간이 준다');
          expect(c.runPlaySeconds, 1, reason: '미리 보기는 플레이 시간에 넣지 않는다');
          c.dispose();
        });
      });
    }

    test('특수 카드가 있는 Stage에서도 특수 카드는 미리 보기에 보이지 않는다', () {
      fakeAsync((async) {
        final c = MemoryMatchController(startStage: 3)..start();
        final special = c.cards.indexWhere((card) => card.isSpecial);
        expect(special, isNot(-1));
        expect(c.isFaceVisible(special), isFalse);
        c.dispose();
      });
    });

    test('미리 보기 중에는 점수 교환을 할 수 없다', () {
      fakeAsync((async) {
        final c = MemoryMatchController(startStage: 4, initialScore: 500)
          ..start();
        expect(c.canExchange, isFalse);
        async.elapse(c.previewDuration);
        expect(c.canExchange, isTrue);
        c.dispose();
      });
    });

    test('다음 Stage도 시작할 때마다 다시 미리 보여 준다', () {
      fakeAsync((async) {
        final c = MemoryMatchController(decideEvenGridSpecials: (_) => false)
          ..start();
        async.elapse(c.previewDuration);
        _solve(c);
        c.nextStage();
        expect(c.isPreviewing, isFalse, reason: '시작 팝업을 누르기 전');
        c.start();
        expect(c.isPreviewing, isTrue);
        async.elapse(c.previewDuration);
        expect(c.isPreviewing, isFalse);
        c.dispose();
      });
    });

    test('미리 보기 중에 재도전하면 미리 보기가 풀린다', () {
      fakeAsync((async) {
        final c = MemoryMatchController()..start();
        c.restart();
        expect(c.isPreviewing, isFalse);
        async.elapse(const Duration(seconds: 10));
        expect(c.status, MemoryMatchStatus.ready, reason: '타이머가 남아 돌지 않는다');
        c.dispose();
      });
    });
  });
}
