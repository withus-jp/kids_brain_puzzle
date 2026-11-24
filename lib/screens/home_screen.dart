import 'package:flutter/material.dart';

import '../core/models/game_info.dart';
import '../games/game_registry.dart';
import '../repositories/score_repository.dart';
import 'records_screen.dart';
import 'widgets/game_card.dart';

/// 메인 게임 허브 화면.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.scoreRepository});

  final ScoreRepository scoreRepository;

  static const _maxContentWidth = 960.0;
  static const _cardSpacing = 20.0;

  void _openGame(BuildContext context, GameInfo game) {
    final builder = game.screenBuilder;
    if (builder == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  void _openRecords(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordsScreen(scoreRepository: scoreRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                children: [
                  const Text('🧠', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  Text(
                    '두뇌 퍼즐 놀이터',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '하고 싶은 게임을 골라 보세요!',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 840
                          ? 3
                          : width >= 520
                          ? 2
                          : 1;
                      final cardWidth =
                          (width - _cardSpacing * (columns - 1)) / columns;

                      return Wrap(
                        alignment: WrapAlignment.center,
                        spacing: _cardSpacing,
                        runSpacing: _cardSpacing,
                        children: [
                          for (final game in gameRegistry)
                            SizedBox(
                              width: cardWidth,
                              child: GameCard(
                                game: game,
                                onTap: game.isComingSoon
                                    ? null
                                    : () => _openGame(context, game),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => _openRecords(context),
                    icon: const Text('🏆', style: TextStyle(fontSize: 22)),
                    label: const Text('내 기록 보기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
