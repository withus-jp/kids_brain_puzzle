import 'package:flutter/material.dart';

import '../core/models/game_record.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../games/game_registry.dart';
import '../repositories/score_repository.dart';

/// 로컬에 저장된 게임·난이도별 최고 기록을 보여 주는 화면.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.scoreRepository});

  final ScoreRepository scoreRepository;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  late final Future<List<GameRecord>> _bestRecords =
      widget.scoreRepository.getBestRecords();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏆 내 기록')),
      body: SafeArea(
        child: FutureBuilder<List<GameRecord>>(
          future: _bestRecords,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const _Message(
                emoji: '😢',
                text: '기록을 불러오지 못했어요.',
              );
            }
            final records = snapshot.data ?? const [];
            if (records.isEmpty) {
              return const _Message(
                emoji: '🌱',
                text: '아직 기록이 없어요.\n게임을 하고 첫 기록을 만들어 보세요!',
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) =>
                      _RecordTile(record: records[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final game = findGame(record.gameId);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: game?.color ?? AppColors.pastelLavender,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Text(game?.emoji ?? '🎮', style: const TextStyle(fontSize: 44)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game?.title ?? record.gameId, style: textTheme.titleMedium),
                Text(
                  game?.difficultyLabel(record.difficulty) ??
                      record.difficulty,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text('🔁 ${record.moves}번', style: textTheme.bodyLarge),
                    Text(
                      '⏱️ ${formatDuration(record.elapsedSeconds)}',
                      style: textTheme.bodyLarge,
                    ),
                    Text(
                      '📅 ${formatDate(record.playedAt)}',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
