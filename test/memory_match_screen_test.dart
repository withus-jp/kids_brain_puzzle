import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_brain_puzzle/core/theme/app_theme.dart';
import 'package:kids_brain_puzzle/games/memory_match/memory_match_controller.dart';
import 'package:kids_brain_puzzle/games/memory_match/memory_match_screen.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_card.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_match_event.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_match_rules.dart';
import 'package:kids_brain_puzzle/games/memory_match/widgets/exchange_dialog.dart';
import 'package:kids_brain_puzzle/games/memory_match/widgets/game_status_bar.dart';
import 'package:kids_brain_puzzle/games/memory_match/widgets/memory_card_tile.dart';

/// 허브 역할을 하는 첫 화면에서 게임 화면을 push 한다. ('홈으로' 확인용)
Widget _app(MemoryMatchController controller) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MemoryMatchScreen(controller: controller),
            ),
          ),
          child: const Text('HUB'),
        ),
      ),
    ),
  ),
);

/// 게임 화면을 열고 Stage 시작 팝업에서 [시작!]을 누른다.
Future<void> _open(
  WidgetTester tester,
  MemoryMatchController c, {
  bool start = true,
}) async {
  await tester.pumpWidget(_app(c));
  await tester.tap(find.text('HUB'));
  await tester.pumpAndSettle();
  if (start) await _pressStart(tester);
}

Future<void> _pressStart(WidgetTester tester) async {
  await tester.tap(find.text('시작!'));
  await tester.pumpAndSettle();
}

/// 테스트가 끝날 때 화면을 내리고 컨트롤러 타이머를 정리한다.
Future<void> _close(WidgetTester tester, MemoryMatchController c) async {
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

String _stat(WidgetTester tester, String key) {
  final texts = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(Text),
  );
  return tester.widgetList<Text>(texts).elementAt(2).data!;
}

Future<void> _tapCard(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('memory_card_$index')));
  await tester.pump();
}

Future<void> _solve(WidgetTester tester, MemoryMatchController c) async {
  final pairs = <String, List<int>>{};
  for (var i = 0; i < c.cards.length; i++) {
    if (!c.cards[i].isSpecial) (pairs[c.cards[i].emoji] ??= []).add(i);
  }
  for (final pair in pairs.values) {
    await _tapCard(tester, pair[0]);
    await _tapCard(tester, pair[1]);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Stage 1(2x2)로 바로 시작하고 상태판이 보인다', (tester) async {
    final c = MemoryMatchController();
    await _open(tester, c);

    expect(find.byType(MemoryCardTile), findsNWidgets(4));
    expect(_stat(tester, 'stat_stage'), '1');
    expect(_stat(tester, 'stat_time'), '20');
    expect(_stat(tester, 'stat_chances'), '5');
    expect(_stat(tester, 'stat_score'), '0');

    await tester.pump(const Duration(seconds: 2));
    expect(_stat(tester, 'stat_time'), '18');
    await _close(tester, c);
  });

  testWidgets('모든 짝을 맞추면 스테이지 클리어 팝업 → 다음 스테이지(2x3)', (tester) async {
    final c = MemoryMatchController();
    await _open(tester, c);

    await _solve(tester, c);
    expect(find.text('스테이지 클리어!'), findsOneWidget);
    // 2쌍 × 10 + 20초 × 10 + 5번 × 50
    expect(find.text('${20 + 200 + 250}점'), findsOneWidget);

    await tester.tap(find.text('다음 스테이지 ▶'));
    await tester.pumpAndSettle();
    expect(find.text('스테이지 클리어!'), findsNothing);
    expect(find.text('Stage 2'), findsOneWidget, reason: '다음 Stage 시작 팝업');
    await _pressStart(tester);
    expect(find.byType(MemoryCardTile), findsNWidgets(6));
    expect(_stat(tester, 'stat_stage'), '2');
    expect(_stat(tester, 'stat_time'), '20');
    await _close(tester, c);
  });

  testWidgets('시간이 다 되면 게임 오버 팝업, 재도전하면 Stage 1부터', (tester) async {
    final c = MemoryMatchController(startStage: 3);
    await _open(tester, c);

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('게임 오버'), findsOneWidget);
    expect(find.text('시간이 다 됐어요.'), findsOneWidget);
    expect(find.text('Stage 3'), findsOneWidget);
    expect(find.text('0점'), findsOneWidget);

    await tester.tap(find.text('재도전'));
    await tester.pumpAndSettle();
    expect(find.text('게임 오버'), findsNothing);
    expect(_stat(tester, 'stat_stage'), '1');
    expect(find.byType(MemoryCardTile), findsNWidgets(4));
    await _close(tester, c);
  });

  testWidgets('게임 오버 팝업의 홈으로를 누르면 허브로 돌아간다', (tester) async {
    final c = MemoryMatchController();
    await _open(tester, c);

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('HUB'), findsOneWidget);
    expect(find.byType(MemoryMatchScreen), findsNothing);
    await _close(tester, c);
  });

  testWidgets('⭐ 별 카드: 찬스! 팝업을 닫으면 그때부터 카드를 3초 보여 준다', (tester) async {
    final c = MemoryMatchController(
      startStage: 3,
      pickSpecialCard: (_) => SpecialCardKind.star,
    );
    await _open(tester, c);

    final star = c.cards.indexWhere((card) => card.isSpecial);
    final faces = c.cards
        .where((card) => !card.isSpecial)
        .map((e) => e.emoji)
        .toSet();

    await _tapCard(tester, star);
    await tester.pumpAndSettle();
    expect(find.textContaining('찬스!'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text(faces.first), findsNothing, reason: '닫기 전에는 공개 안 함');

    // 팝업이 떠 있는 동안 시간은 멈춰 있다.
    await tester.pump(const Duration(seconds: 3));
    expect(_stat(tester, 'stat_time'), '20');

    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // 팝업 닫힘 애니메이션
    expect(find.textContaining('찬스!'), findsNothing);
    expect(find.byKey(const ValueKey('peek_timer_bar')), findsOneWidget);
    for (final emoji in faces) {
      expect(find.text(emoji), findsNWidgets(2));
    }

    // 팝업이 닫히고 0.3초 지난 시점 → 2.9초째에도 아직 보인다
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text(faces.first), findsNWidgets(2));
    expect(find.byKey(const ValueKey('peek_timer_bar')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(faces.first), findsNothing);
    expect(find.byKey(const ValueKey('peek_timer_bar')), findsNothing);
    await _close(tester, c);
  });

  for (final (penalty, message, stat, before, after) in [
    (BombPenalty.time, '시간 3초를 뺏겨요', 'stat_time', '40', '37'),
    (BombPenalty.chance, '남은 기회 1번을 뺏겨요', 'stat_chances', '9', '8'),
  ]) {
    testWidgets('💣 폭탄 카드(${penalty.name}): 꽝! 팝업으로 알리고 확인하면 적용', (
      tester,
    ) async {
      final c = MemoryMatchController(
        startStage: 7,
        pickSpecialCard: (_) => SpecialCardKind.bomb,
        pickBombPenalty: (_) => penalty,
      );
      await _open(tester, c);

      await _tapCard(tester, c.cards.indexWhere((card) => card.isSpecial));
      await tester.pumpAndSettle();
      expect(find.text('꽝!'), findsOneWidget);
      expect(find.textContaining(message), findsOneWidget);
      expect(_stat(tester, stat), before, reason: '확인 전에는 그대로');

      // 팝업이 떠 있는 동안 시간은 멈춰 있다.
      await tester.pump(const Duration(seconds: 3));
      expect(_stat(tester, 'stat_time'), '40');

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('꽝!'), findsNothing);
      expect(_stat(tester, stat), after);
      await _close(tester, c);
    });
  }

  testWidgets('💣 폭탄으로 0이 되면 확인 후 게임 오버 팝업', (tester) async {
    final c = MemoryMatchController(
      startStage: 7,
      pickSpecialCard: (_) => SpecialCardKind.bomb,
      pickBombPenalty: (_) => BombPenalty.time,
    );
    await _open(tester, c);
    await tester.pump(const Duration(seconds: 38)); // 2초 남음

    await _tapCard(tester, c.cards.indexWhere((card) => card.isSpecial));
    await tester.pumpAndSettle();
    expect(find.text('꽝!'), findsOneWidget);
    expect(find.text('게임 오버'), findsNothing);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('꽝!'), findsNothing);
    expect(find.text('게임 오버'), findsOneWidget);
    await _close(tester, c);
  });

  group('반응형 레이아웃', () {
    const sizes = {
      '작은 모바일 세로': Size(320, 568),
      '모바일 세로': Size(390, 844),
      '모바일 가로': Size(844, 390),
      '태블릿': Size(820, 1180),
      '넓은 웹': Size(1920, 1080),
    };

    for (var stage = 1; stage <= MemoryMatchRules.lastStage; stage++) {
      for (final entry in sizes.entries) {
        final grid = MemoryMatchRules.gridOf(stage);
        testWidgets('$grid · ${entry.key}: 카드가 화면 안에 들어간다', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final c = MemoryMatchController(startStage: stage);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: MemoryMatchScreen(controller: c),
            ),
          );
          expect(tester.takeException(), isNull, reason: '오버플로 없음');

          final screen = Offset.zero & entry.value;
          final rects = [
            for (var i = 0; i < grid.cellCount; i++)
              tester.getRect(find.byKey(ValueKey('memory_card_$i'))),
          ];
          for (final rect in rects) {
            expect(rect.width, greaterThanOrEqualTo(20), reason: '카드가 너무 작음');
            expect(rect.width, closeTo(rect.height, 0.01), reason: '정사각형');
            expect(screen.contains(rect.topLeft), isTrue);
            expect(rect.right, lessThanOrEqualTo(screen.right));
            expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
          }
          // 카드끼리 겹치지 않는다
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse);
            }
          }
          // 긴 변이 화면의 긴 쪽을 따라 놓인다 (직사각형 그리드)
          if (grid.short != grid.long) {
            final xs = rects.map((r) => r.left.round()).toSet().length;
            final ys = rects.map((r) => r.top.round()).toSet().length;
            final boardIsWide = xs > ys;
            final board = rects.reduce((a, b) => a.expandToInclude(b));
            expect(boardIsWide, board.width > board.height);
          }
          await _close(tester, c);
        });
      }
    }
  });

  group('스테이지 시작 팝업', () {
    testWidgets('처음 열면 시작 팝업이 뜨고, 시작을 누르기 전에는 시간이 안 간다', (tester) async {
      final c = MemoryMatchController();
      await _open(tester, c, start: false);

      expect(find.text('Stage 1'), findsOneWidget);
      expect(find.text('시작!'), findsOneWidget);
      expect(find.byKey(const ValueKey('exchange_guide')), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      expect(_stat(tester, 'stat_time'), '20');

      await _pressStart(tester);
      expect(find.text('시작!'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(_stat(tester, 'stat_time'), '18');
      await _close(tester, c);
    });

    testWidgets('Stage 4 시작 팝업에서 점수 교환을 안내한다', (tester) async {
      final c = MemoryMatchController(startStage: 4);
      await _open(tester, c, start: false);
      expect(find.text('Stage 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('exchange_guide')), findsOneWidget);
      expect(find.text('🆕 점수 교환이 열렸어요!'), findsOneWidget);
      await _close(tester, c);
    });

    testWidgets('Stage 5 시작 팝업에는 안내가 없다', (tester) async {
      final c = MemoryMatchController(startStage: 5);
      await _open(tester, c, start: false);
      expect(find.byKey(const ValueKey('exchange_guide')), findsNothing);
      await _close(tester, c);
    });
  });

  group('점수 교환 버튼', () {
    testWidgets('Stage 3까지는 버튼이 없다', (tester) async {
      final c = MemoryMatchController(startStage: 3, initialScore: 500);
      await _open(tester, c);
      expect(find.byKey(const ValueKey('exchange_button')), findsNothing);
      await _close(tester, c);
    });

    testWidgets('100점보다 적으면 버튼이 눌리지 않는다', (tester) async {
      final c = MemoryMatchController(startStage: 4, initialScore: 50);
      await _open(tester, c);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('exchange_button')),
      );
      expect(button.onPressed, isNull);
      await _close(tester, c);
    });

    for (final (option, key, stat, after) in [
      ('기회', 'exchange_option_chances', 'stat_chances', '8'),
      ('시간', 'exchange_option_time', 'stat_time', '30'),
    ]) {
      testWidgets('$option 선택 → 확인하면 반영되고 점수가 100점 준다', (tester) async {
        final c = MemoryMatchController(startStage: 4, initialScore: 230);
        await _open(tester, c);

        await tester.tap(find.byKey(const ValueKey('exchange_button')));
        await tester.pumpAndSettle();
        expect(find.text('점수 교환'), findsWidgets);
        expect(find.text('내 점수 230점 → 130점'), findsOneWidget);

        // 고르기 전에는 확인을 누를 수 없다
        final confirm = find.widgetWithText(FilledButton, '확인');
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

        // 팝업이 떠 있는 동안 시간은 멈춰 있다.
        await tester.pump(const Duration(seconds: 3));
        expect(_stat(tester, 'stat_time'), '25');

        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump();
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(find.byType(ExchangeDialog), findsNothing);
        expect(_stat(tester, stat), after);
        expect(_stat(tester, 'stat_score'), '130');

        // 게임이 다시 이어진다.
        await tester.pump(const Duration(seconds: 1));
        expect(_stat(tester, 'stat_time'), option == '시간' ? '29' : '24');
        await _close(tester, c);
      });
    }

    testWidgets('취소하면 바뀌지 않는다', (tester) async {
      final c = MemoryMatchController(startStage: 4, initialScore: 230);
      await _open(tester, c);
      await tester.tap(find.byKey(const ValueKey('exchange_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(ExchangeDialog), findsNothing);
      expect(_stat(tester, 'stat_score'), '230');
      expect(_stat(tester, 'stat_chances'), '6');
      await _close(tester, c);
    });
  });

  group('상태판 배치', () {
    const topLayoutSizes = {
      '작은 모바일 세로': Size(320, 568),
      '모바일 세로': Size(390, 844),
      '태블릿': Size(820, 1180),
      '넓은 웹': Size(1920, 1080),
      '작은 웹 창': Size(800, 600),
    };

    Rect rectOf(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(ValueKey(key)));

    for (final stage in [1, 4]) {
      final hasButton = stage >= MemoryMatchRules.exchangeFromStage;
      for (final entry in topLayoutSizes.entries) {
        testWidgets(
          'Stage $stage · ${entry.key}: 위쪽 Stage·점수${hasButton ? "·교환" : ""}, '
          '아래쪽 시간·기회',
          (tester) async {
            tester.view.physicalSize = entry.value;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            final c = MemoryMatchController(
              startStage: stage,
              initialScore: 230,
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                home: MemoryMatchScreen(controller: c),
              ),
            );
            await tester.pumpAndSettle();
            await _pressStart(tester);
            expect(tester.takeException(), isNull, reason: '오버플로 없음');

            final stageChip = rectOf(tester, 'stat_stage');
            final score = rectOf(tester, 'stat_score');
            final time = rectOf(tester, 'stat_time');
            final chances = rectOf(tester, 'stat_chances');
            final firstLine = [stageChip, score];
            if (hasButton) {
              firstLine.add(rectOf(tester, 'exchange_button'));
            } else {
              expect(
                find.byKey(const ValueKey('exchange_button')),
                findsNothing,
              );
            }

            // 첫 줄: 같은 높이에, 왼쪽부터 Stage → 점수 → 교환
            for (final r in firstLine) {
              expect(r.top, closeTo(stageChip.top, 0.5));
              expect(r.height, closeTo(GameStatusBar.chipHeight, 0.5));
            }
            for (var i = 0; i + 1 < firstLine.length; i++) {
              expect(firstLine[i].right, lessThan(firstLine[i + 1].left));
              expect(firstLine[i].width, closeTo(firstLine[i + 1].width, 0.5));
            }

            // 둘째 줄: 화면 아래쪽, 왼쪽부터 시간 → 기회
            expect(time.top, closeTo(chances.top, 0.5));
            expect(time.top, greaterThan(stageChip.bottom));
            expect(
              entry.value.height - time.bottom,
              lessThanOrEqualTo(24),
              reason: '화면 맨 아래에 붙어 있다',
            );
            for (final r in [time, chances]) {
              expect(r.height, closeTo(GameStatusBar.largeChipHeight, 0.5));
              expect(
                r.height,
                greaterThan(stageChip.height),
                reason: '둘째 줄이 더 크다',
              );
            }
            expect(time.right, lessThan(chances.left));
            expect(time.width, closeTo(chances.width, 0.5));

            // 두 줄의 양 끝이 맞고, 너무 넓어지지 않으며, 가운데에 있다
            final line1 = firstLine.reduce((a, b) => a.expandToInclude(b));
            final line2 = time.expandToInclude(chances);
            expect(line1.left, closeTo(line2.left, 0.5));
            expect(line1.right, closeTo(line2.right, 0.5));
            expect(line1.width, lessThanOrEqualTo(GameStatusBar.maxWidth));
            expect(
              line1.left,
              closeTo(entry.value.width - line1.right, 1),
              reason: '가운데 정렬',
            );
            expect(line1.left, greaterThanOrEqualTo(0));
            expect(line1.right, lessThanOrEqualTo(entry.value.width));

            // 게임판은 두 줄 사이에 있다
            final cards = [
              for (var i = 0; i < c.grid.cellCount; i++)
                rectOf(tester, 'memory_card_$i'),
            ].reduce((a, b) => a.expandToInclude(b));
            expect(cards.top, greaterThan(line1.bottom));
            expect(cards.bottom, lessThan(line2.top));
            await _close(tester, c);
          },
        );
      }
    }

    testWidgets('모바일 가로: 왼쪽 패널 위쪽에 Stage·점수·교환, 아래쪽에 시간·기회', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final c = MemoryMatchController(startStage: 4, initialScore: 230);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MemoryMatchScreen(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      await _pressStart(tester);
      expect(tester.takeException(), isNull, reason: '오버플로 없음');

      final order = [
        'stat_stage',
        'stat_score',
        'exchange_button',
        'stat_time',
        'stat_chances',
      ].map((k) => rectOf(tester, k)).toList();
      for (var i = 0; i + 1 < order.length; i++) {
        expect(order[i].bottom, lessThanOrEqualTo(order[i + 1].top));
        expect(order[i].left, closeTo(order[i + 1].left, 0.5));
      }
      // 패널은 왼쪽, 게임판은 그 오른쪽
      expect(order.first.left, lessThan(40));
      expect(
        rectOf(tester, 'memory_card_0').left,
        greaterThan(order.first.right),
      );
      // 시간·기회 칸이 더 크다
      expect(order[3].height, greaterThan(order[0].height));
      expect(order[4].height, greaterThan(order[0].height));
      // 패널이 화면 아래로 넘치지 않고, 시간·기회는 아래쪽에 붙어 있다
      expect(order.last.bottom, lessThanOrEqualTo(390));
      expect(390 - order.last.bottom, lessThanOrEqualTo(24));
      // Stage·점수·교환은 패널 맨 위(앱바 바로 아래)에 붙어 있고,
      // 시간·기회와는 떨어져 있다.
      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      expect(order.first.top - appBarBottom, lessThanOrEqualTo(16));
      expect(order[3].top - order[2].bottom, greaterThan(12));
      await _close(tester, c);
    });
  });

  group('이어하기 버튼 (게임 오버 팝업)', () {
    Future<void> timeOut(WidgetTester tester, MemoryMatchController c) async {
      await tester.pump(Duration(seconds: c.remainingSeconds));
      await tester.pumpAndSettle();
      expect(find.text('게임 오버'), findsOneWidget);
    }

    testWidgets('Stage 4에서는 이어하기 버튼이 없다', (tester) async {
      final c = MemoryMatchController(startStage: 4, initialScore: 900);
      await _open(tester, c);
      await timeOut(tester, c);
      expect(
        find.byKey(const ValueKey('result_highlight_action')),
        findsNothing,
      );
      expect(find.text('재도전'), findsOneWidget);
      await _close(tester, c);
    });

    testWidgets('Stage 5, 500점 미만이면 버튼이 흐리고 안내가 나온다', (tester) async {
      final c = MemoryMatchController(startStage: 5, initialScore: 300);
      await _open(tester, c);
      await timeOut(tester, c);

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('result_highlight_action')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('이어하려면 500점이 필요해요.'), findsOneWidget);
      await _close(tester, c);
    });

    testWidgets('500점으로 이어하면 같은 Stage 시작 팝업부터 다시 한다', (tester) async {
      final c = MemoryMatchController(startStage: 5, initialScore: 720);
      await _open(tester, c);
      await timeOut(tester, c);

      expect(find.text('💎 500점으로 Stage 5 이어하기'), findsOneWidget);
      expect(find.textContaining('점수 720점 → 220점'), findsOneWidget);
      // 홈으로·재도전도 그대로 있다
      expect(find.text('홈으로'), findsOneWidget);
      expect(find.text('재도전'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('result_highlight_action')));
      await tester.pumpAndSettle();
      expect(find.text('게임 오버'), findsNothing);
      expect(find.text('Stage 5'), findsOneWidget, reason: '시작 팝업');

      await _pressStart(tester);
      expect(_stat(tester, 'stat_stage'), '5');
      expect(_stat(tester, 'stat_score'), '220');
      expect(_stat(tester, 'stat_time'), '30');
      expect(_stat(tester, 'stat_chances'), '7');
      await _close(tester, c);
    });
  });

  testWidgets('Stage 4 시작 팝업에 늘어난 시간·기회를 보여 준다', (tester) async {
    final c = MemoryMatchController(startStage: 4);
    await _open(tester, c, start: false);
    expect(find.text('25초 (+5)'), findsOneWidget);
    expect(find.text('6번 (+1)'), findsOneWidget);
    await _close(tester, c);
  });
}
