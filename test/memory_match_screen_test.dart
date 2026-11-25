import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_brain_puzzle/core/models/game_record.dart';
import 'package:kids_brain_puzzle/main.dart';
import 'package:kids_brain_puzzle/repositories/local_score_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:kids_brain_puzzle/core/theme/app_theme.dart';
import 'package:kids_brain_puzzle/games/memory_match/memory_match_controller.dart';
import 'package:kids_brain_puzzle/games/memory_match/memory_match_screen.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_card.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_match_event.dart';
import 'package:kids_brain_puzzle/games/memory_match/models/memory_match_rules.dart';
import 'package:kids_brain_puzzle/games/memory_match/widgets/exchange_dialog.dart';
import 'package:kids_brain_puzzle/games/memory_match/widgets/game_status_bar.dart';
import 'package:kids_brain_puzzle/games/memory_match/widgets/memory_card_tile.dart';

import 'helpers/no_preview.dart';
import 'helpers/fake_score_repository.dart';

/// 허브 역할을 하는 첫 화면에서 게임 화면을 push 한다. ('홈으로' 확인용)
Widget _app(MemoryMatchController controller) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MemoryMatchScreen(
                scoreRepository: FakeScoreRepository(),
                controller: controller,
              ),
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

/// 팝업 안에서만 찾는다 (카드에 붙은 '찬스!'/'꽝!' 글자와 구분하려고).
Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(Dialog), matching: finder);

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
    final c = MemoryMatchController(previewDurationFor: noPreview);
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
    final c = MemoryMatchController(previewDurationFor: noPreview);
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
    final c = MemoryMatchController(
      previewDurationFor: noPreview,
      startStage: 3,
    );
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
    final c = MemoryMatchController(previewDurationFor: noPreview);
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
      previewDurationFor: noPreview,
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
    expect(_inDialog(find.textContaining('찬스!')), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text(faces.first), findsNothing, reason: '닫기 전에는 공개 안 함');

    // 팝업이 떠 있는 동안 시간은 멈춰 있다.
    await tester.pump(const Duration(seconds: 3));
    expect(_stat(tester, 'stat_time'), '20');

    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // 팝업 닫힘 애니메이션
    expect(_inDialog(find.textContaining('찬스!')), findsNothing);
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
        previewDurationFor: noPreview,
        startStage: 7,
        pickSpecialCard: (_) => SpecialCardKind.bomb,
        pickBombPenalty: (_) => penalty,
      );
      await _open(tester, c);

      await _tapCard(tester, c.cards.indexWhere((card) => card.isSpecial));
      await tester.pumpAndSettle();
      expect(_inDialog(find.text('꽝!')), findsOneWidget);
      expect(find.textContaining(message), findsOneWidget);
      expect(_stat(tester, stat), before, reason: '확인 전에는 그대로');

      // 팝업이 떠 있는 동안 시간은 멈춰 있다.
      await tester.pump(const Duration(seconds: 3));
      expect(_stat(tester, 'stat_time'), '40');

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(_inDialog(find.text('꽝!')), findsNothing);
      expect(_stat(tester, stat), after);
      await _close(tester, c);
    });
  }

  testWidgets('💣 폭탄으로 0이 되면 확인 후 게임 오버 팝업', (tester) async {
    final c = MemoryMatchController(
      previewDurationFor: noPreview,
      startStage: 7,
      pickSpecialCard: (_) => SpecialCardKind.bomb,
      pickBombPenalty: (_) => BombPenalty.time,
    );
    await _open(tester, c);
    await tester.pump(const Duration(seconds: 38)); // 2초 남음

    await _tapCard(tester, c.cards.indexWhere((card) => card.isSpecial));
    await tester.pumpAndSettle();
    expect(_inDialog(find.text('꽝!')), findsOneWidget);
    expect(find.text('게임 오버'), findsNothing);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(_inDialog(find.text('꽝!')), findsNothing);
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

          final c = MemoryMatchController(
            previewDurationFor: noPreview,
            startStage: stage,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: MemoryMatchScreen(
                scoreRepository: FakeScoreRepository(),
                controller: c,
              ),
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
      final c = MemoryMatchController(previewDurationFor: noPreview);
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
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 4,
      );
      await _open(tester, c, start: false);
      expect(find.text('Stage 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('exchange_guide')), findsOneWidget);
      expect(find.text('🆕 점수 교환이 열렸어요!'), findsOneWidget);
      await _close(tester, c);
    });

    testWidgets('Stage 5 시작 팝업에는 안내가 없다', (tester) async {
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 5,
      );
      await _open(tester, c, start: false);
      expect(find.byKey(const ValueKey('exchange_guide')), findsNothing);
      await _close(tester, c);
    });
  });

  group('점수 교환 버튼', () {
    testWidgets('Stage 3까지는 버튼이 없다', (tester) async {
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 3,
        initialScore: 500,
      );
      await _open(tester, c);
      expect(find.byKey(const ValueKey('exchange_button')), findsNothing);
      await _close(tester, c);
    });

    testWidgets('100점보다 적으면 버튼이 눌리지 않는다', (tester) async {
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 4,
        initialScore: 50,
      );
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
        final c = MemoryMatchController(
          previewDurationFor: noPreview,
          startStage: 4,
          initialScore: 230,
        );
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
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 4,
        initialScore: 230,
      );
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
          'Stage $stage · ${entry.key}: 첫 줄 Stage·점수${hasButton ? "·교환" : ""}, '
          '바로 아래 시간·기회, 그 아래 게임판',
          (tester) async {
            tester.view.physicalSize = entry.value;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            final c = MemoryMatchController(
              previewDurationFor: noPreview,
              startStage: stage,
              initialScore: 230,
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                home: MemoryMatchScreen(
                  scoreRepository: FakeScoreRepository(),
                  controller: c,
                ),
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

            // 둘째 줄: 첫 줄 바로 아래, 왼쪽부터 시간 → 기회
            expect(time.top, closeTo(chances.top, 0.5));
            expect(time.top, greaterThan(stageChip.bottom));
            expect(
              time.top - stageChip.bottom,
              lessThanOrEqualTo(12),
              reason: '첫 줄 바로 아래에 붙어 있다',
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

            // 게임판은 두 줄 아래에 있고 화면 안에 들어온다
            final cards = [
              for (var i = 0; i < c.grid.cellCount; i++)
                rectOf(tester, 'memory_card_$i'),
            ].reduce((a, b) => a.expandToInclude(b));
            expect(line2.top, greaterThan(line1.bottom));
            expect(cards.top, greaterThan(line2.bottom));
            expect(cards.bottom, lessThanOrEqualTo(entry.value.height));
            await _close(tester, c);
          },
        );
      }
    }

    testWidgets('모바일 가로: 왼쪽 패널 위쪽에 Stage·점수·교환, 바로 아래 시간·기회', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 4,
        initialScore: 230,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MemoryMatchScreen(
            scoreRepository: FakeScoreRepository(),
            controller: c,
          ),
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
      // 패널이 화면 아래로 넘치지 않는다
      expect(order.last.bottom, lessThanOrEqualTo(390));
      // Stage·점수·교환은 패널 맨 위(앱바 바로 아래)에 붙어 있고,
      // 시간·기회는 그 바로 아래에 이어진다.
      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      expect(order.first.top - appBarBottom, lessThanOrEqualTo(16));
      expect(order[3].top - order[2].bottom, lessThanOrEqualTo(16));
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
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 4,
        initialScore: 900,
      );
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
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 5,
        initialScore: 300,
      );
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
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 5,
        initialScore: 720,
      );
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
    final c = MemoryMatchController(
      previewDurationFor: noPreview,
      startStage: 4,
    );
    await _open(tester, c, start: false);
    expect(find.text('25초 (+5)'), findsOneWidget);
    expect(find.text('6번 (+1)'), findsOneWidget);
    await _close(tester, c);
  });

  group('기록 저장 (Phase 3)', () {
    Future<void> openWith(
      WidgetTester tester,
      MemoryMatchController c,
      FakeScoreRepository repository,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MemoryMatchScreen(scoreRepository: repository, controller: c),
        ),
      );
      await tester.pumpAndSettle();
      await _pressStart(tester);
    }

    Future<void> timeOut(WidgetTester tester, MemoryMatchController c) async {
      await tester.pump(Duration(seconds: c.remainingSeconds));
      await tester.pumpAndSettle();
      expect(find.text('게임 오버'), findsOneWidget);
    }

    GameRecord record({
      required String id,
      required int stage,
      int score = 0,
    }) => GameRecord(
      id: id,
      gameId: 'memory_match',
      stage: stage,
      score: score,
      elapsedSeconds: 10,
      moves: 3,
      playedAt: DateTime(2026, 11, 1),
    );

    testWidgets('게임 오버가 되면 기록을 저장하고, 첫 기록이면 신기록 배지', (tester) async {
      final repository = FakeScoreRepository();
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 3,
      );
      await openWith(tester, c, repository);
      final (a, b) = (
        0,
        c.cards.indexWhere(
          (x) =>
              x.emoji != c.cards[0].emoji &&
              !x.isSpecial &&
              !c.cards[0].isSpecial,
        ),
      );
      if (!c.cards[0].isSpecial && b >= 0) {
        await _tapCard(tester, a);
        await _tapCard(tester, b);
        await tester.pumpAndSettle();
      }
      await timeOut(tester, c);

      expect(repository.records, hasLength(1));
      final saved = repository.records.single;
      expect(saved.id, c.runId);
      expect(saved.stage, 3);
      expect(saved.cleared, isFalse);
      expect(saved.score, c.score);
      expect(saved.moves, c.runMoves);
      expect(saved.elapsedSeconds, 20);

      expect(find.byKey(const ValueKey('new_best_badge')), findsOneWidget);
      expect(find.text('🏆 신기록 달성!'), findsOneWidget);
      expect(find.text('⏱️ 플레이 시간'), findsOneWidget);
      expect(find.text('0:20'), findsOneWidget);
      expect(find.text('🔁 시도 횟수'), findsOneWidget);
      await _close(tester, c);
    });

    testWidgets('이전 최고 기록보다 낮으면 배지가 없다', (tester) async {
      final repository = FakeScoreRepository([
        record(id: 'old', stage: 9, score: 3000),
      ]);
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 2,
      );
      await openWith(tester, c, repository);
      await timeOut(tester, c);

      expect(repository.records, hasLength(2));
      expect(find.byKey(const ValueKey('new_best_badge')), findsNothing);
      await _close(tester, c);
    });

    testWidgets('이전 최고 기록보다 높으면 배지가 뜬다', (tester) async {
      final repository = FakeScoreRepository([record(id: 'old', stage: 4)]);
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 6,
      );
      await openWith(tester, c, repository);
      await timeOut(tester, c);
      expect(find.byKey(const ValueKey('new_best_badge')), findsOneWidget);
      await _close(tester, c);
    });

    testWidgets('이어하기 뒤 다시 게임 오버면 같은 판 기록을 덮어쓴다', (tester) async {
      final repository = FakeScoreRepository();
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 5,
        initialScore: 800,
      );
      await openWith(tester, c, repository);
      await timeOut(tester, c);
      expect(repository.records.single.score, 800);

      await tester.tap(find.byKey(const ValueKey('result_highlight_action')));
      await tester.pumpAndSettle();
      await _pressStart(tester);
      await timeOut(tester, c);

      expect(repository.records, hasLength(1), reason: '한 판 = 기록 1개');
      expect(repository.records.single.score, 300);
      expect(repository.records.single.elapsedSeconds, 60, reason: '30초 + 30초');
      expect(repository.saveCount, 2);
      await _close(tester, c);
    });

    testWidgets('재도전 뒤 게임 오버는 새 판 기록이 된다', (tester) async {
      final repository = FakeScoreRepository();
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 2,
      );
      await openWith(tester, c, repository);
      await timeOut(tester, c);
      await tester.tap(find.text('재도전'));
      await tester.pumpAndSettle();
      await _pressStart(tester);
      await timeOut(tester, c);

      expect(repository.records, hasLength(2));
      expect(repository.records[0].id, isNot(repository.records[1].id));
      await _close(tester, c);
    });

    testWidgets('모든 스테이지를 클리어하면 cleared 기록을 저장하고 배지를 띄운다', (tester) async {
      final repository = FakeScoreRepository([record(id: 'old', stage: 17)]);
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: MemoryMatchRules.lastStage,
      );
      await openWith(tester, c, repository);
      await _solve(tester, c);

      expect(find.text('모든 스테이지 클리어!'), findsOneWidget);
      final saved = repository.records.firstWhere((r) => r.id == c.runId);
      expect(saved.cleared, isTrue);
      expect(saved.stage, 17);
      expect(
        find.byKey(const ValueKey('new_best_badge')),
        findsOneWidget,
        reason: '같은 Stage 17이어도 모두 클리어가 더 좋다',
      );
      await _close(tester, c);
    });

    testWidgets('저장에 실패해도 게임 오버 팝업은 뜬다 (배지 없음)', (tester) async {
      final repository = FakeScoreRepository()..failOnSave = true;
      final c = MemoryMatchController(previewDurationFor: noPreview);
      await openWith(tester, c, repository);
      await timeOut(tester, c);
      expect(find.byKey(const ValueKey('new_best_badge')), findsNothing);
      expect(find.text('재도전'), findsOneWidget);
      await _close(tester, c);
    });

    testWidgets('실제 저장소: 게임 오버 기록이 내 기록 화면에 남는다 (다시 열어도)', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await tester.pumpWidget(
        KidsBrainPuzzleApp(scoreRepository: LocalScoreRepository()),
      );
      await tester.tap(find.text('기억력 짝 맞추기'));
      await tester.pumpAndSettle();
      await _pressStart(tester);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('게임 오버'), findsOneWidget);
      await tester.tap(find.text('홈으로'));
      await tester.pumpAndSettle();

      // 앱을 다시 켠 것처럼 새 저장소 인스턴스로 시작한다.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        KidsBrainPuzzleApp(scoreRepository: LocalScoreRepository()),
      );
      await tester.tap(find.text('내 기록 보기'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Stage 1'), findsOneWidget);
      expect(find.text('1위'), findsOneWidget);
    });
  });

  group('카드 뒤집기 애니메이션 (Phase 3)', () {
    testWidgets('누르면 세로축으로 돌며 뒤집히고, 반쯤 돌았을 때 앞면이 나온다', (tester) async {
      final c = MemoryMatchController(previewDurationFor: noPreview);
      await _open(tester, c);
      final emoji = c.cards[0].emoji;
      final card = find.byKey(const ValueKey('memory_card_0'));

      Matrix4 transformOf() => tester
          .widget<Transform>(
            find.descendant(of: card, matching: find.byType(Transform)).first,
          )
          .transform;

      // entry(0,0) = cos(회전각): 1이면 돌지 않은 상태
      expect(
        transformOf().entry(0, 0),
        closeTo(1, 1e-6),
        reason: '처음엔 돌지 않은 상태',
      );

      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text(emoji), findsNothing, reason: '아직 뒷면');
      expect(transformOf().entry(0, 0), lessThan(0.99), reason: '돌고 있다');

      await tester.pump(MemoryCardTile.flipDuration);
      expect(find.text(emoji), findsOneWidget, reason: '다 돌면 앞면');
      await _close(tester, c);
    });

    testWidgets('틀린 카드는 다시 돌아서 덮인다', (tester) async {
      final c = MemoryMatchController(
        previewDurationFor: noPreview,
        startStage: 2,
      );
      await _open(tester, c);
      final first = c.cards[0].emoji;
      final other = c.cards.indexWhere((x) => x.emoji != first);

      await _tapCard(tester, 0);
      await _tapCard(tester, other);
      await tester.pump(MemoryCardTile.flipDuration);
      expect(find.text(first), findsOneWidget);

      await tester.pump(MemoryMatchRules.mismatchDelay);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text(first), findsOneWidget, reason: '덮이는 중 (반 바퀴 전)');
      await tester.pumpAndSettle();
      expect(find.text(first), findsNothing);
      await _close(tester, c);
    });
  });

  group('특수 카드 피드백 (Phase 3)', () {
    for (final (kind, flashKey, labelKey, popupTitle) in [
      (SpecialCardKind.star, 'special_flash_star', 'special_label_star', '찬스!'),
      (SpecialCardKind.bomb, 'special_flash_bomb', 'special_label_bomb', '꽝!'),
    ]) {
      testWidgets('${kind.name}: 팝업 전에 카드 글자와 화면 번쩍임으로 먼저 알려 준다', (
        tester,
      ) async {
        final c = MemoryMatchController(
          previewDurationFor: noPreview,
          startStage: 7,
          pickSpecialCard: (_) => kind,
        );
        await _open(tester, c);

        await _tapCard(tester, c.cards.indexWhere((x) => x.isSpecial));
        await tester.pump(MemoryCardTile.flipDuration);

        // 피드백 중: 카드에 '찬스!'/'꽝!' 글자, 화면 가운데 큰 글자, 팝업은 아직
        expect(find.byKey(ValueKey(labelKey)), findsOneWidget);
        expect(find.byKey(ValueKey(flashKey)), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(c.isTimerRunning, isFalse, reason: '그동안 시간은 멈춰 있다');
        expect(c.acceptsInput, isFalse);

        await tester.pump(MemoryMatchScreen.specialFeedbackDuration);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(Dialog), findsOneWidget);
        expect(_inDialog(find.textContaining(popupTitle)), findsOneWidget);
        expect(find.byKey(ValueKey(flashKey)), findsNothing, reason: '번쩍임 끝');
        // 카드 글자는 계속 남는다
        expect(find.byKey(ValueKey(labelKey)), findsOneWidget);
        await _close(tester, c);
      });
    }
  });

  group('시작 미리 보기', () {
    for (final (stage, seconds) in [(1, 3), (4, 3), (5, 5)]) {
      testWidgets('Stage $stage 시작 팝업에서 $seconds초 미리 보기를 알려 준다', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = MemoryMatchController(startStage: stage);
        await _open(tester, c, start: false);

        expect(
          _inDialog(find.textContaining('카드를 $seconds초 동안 모두 보여 줘요')),
          findsOneWidget,
        );
        expect(_inDialog(find.text('👀 미리 보기')), findsOneWidget);
        expect(_inDialog(find.text('$seconds초')), findsOneWidget);
        await _close(tester, c);
      });
    }

    testWidgets('시작을 누르면 카드를 모두 보여 주고, 시간이 지나면 덮고 시작한다', (tester) async {
      final c = MemoryMatchController(decideEvenGridSpecials: (_) => false);
      await _open(tester, c, start: false);
      await tester.tap(find.text('시작!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(c.isPreviewing, isTrue);
      expect(find.byKey(const ValueKey('peek_timer_bar')), findsOneWidget);
      for (final card in c.cards) {
        expect(find.text(card.emoji), findsWidgets);
      }
      final limit = c.remainingSeconds;

      await tester.pump(c.previewDuration);
      await tester.pumpAndSettle();
      expect(c.isPreviewing, isFalse);
      expect(find.byKey(const ValueKey('peek_timer_bar')), findsNothing);
      expect(c.remainingSeconds, limit);
      await tester.pump(const Duration(seconds: 1));
      expect(c.remainingSeconds, limit - 1);
      await _close(tester, c);
    });

    testWidgets('작은 화면에서도 시작 팝업의 [시작!] 버튼이 화면 안에 보인다', (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = MemoryMatchController(startStage: 4, initialScore: 300);
      await _open(tester, c, start: false);

      final button = tester.getRect(find.text('시작!'));
      expect(button.bottom, lessThanOrEqualTo(360));
      expect(button.top, greaterThanOrEqualTo(0));
      await tester.tap(find.text('시작!'));
      await tester.pump();
      expect(c.isPreviewing, isTrue);
      await _close(tester, c);
    });
  });
}
