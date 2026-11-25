import 'package:flutter/material.dart';

import '../core/models/game_record.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../games/game_registry.dart';
import '../repositories/score_repository.dart';

/// 저장된 판 기록을 도달 Stage가 높은 순(같으면 최신순)으로 보여 주는 화면.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.scoreRepository});

  final ScoreRepository scoreRepository;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  late final Future<List<GameRecord>> _records = widget.scoreRepository
      .getRecords();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏆 내 기록')),
      body: SafeArea(
        child: FutureBuilder<List<GameRecord>>(
          future: _records,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const _Message(emoji: '😢', text: '기록을 불러오지 못했어요.');
            }
            final records = snapshot.data ?? const [];
            if (records.isEmpty) {
              return const _Message(
                emoji: '🌱',
                text: '아직 기록이 없어요.\n게임을 하고 첫 기록을 만들어 보세요!',
              );
            }

            // 게임마다 최고 기록 하나에 🏆를 단다.
            final bestByGame = <String, GameRecord>{};
            for (final r in records) {
              final best = bestByGame[r.gameId];
              if (best == null || r.isBetterThan(best)) {
                bestByGame[r.gameId] = r;
              }
            }
            final bestIds = {for (final r in bestByGame.values) r.id};

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return _Summary(
                        count: records.length,
                        best: bestByGame.values.isEmpty
                            ? null
                            : bestByGame.values.first,
                      );
                    }
                    final record = records[index - 1];
                    return _RecordTile(
                      key: ValueKey('record_${record.id}'),
                      rank: index,
                      record: record,
                      isBest: bestIds.contains(record.id),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 맨 위 요약: 판 수와 최고 기록
class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.best});

  final int count;
  final GameRecord? best;

  @override
  Widget build(BuildContext context) {
    final best = this.best;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.pastelLemon,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('최고 기록', style: textTheme.bodyMedium),
                Text(
                  best == null
                      ? '-'
                      : best.cleared
                      ? '모두 클리어! · ${best.score}점'
                      : 'Stage ${best.stage} · ${best.score}점',
                  key: const ValueKey('records_best'),
                  style: textTheme.titleLarge,
                ),
              ],
            ),
          ),
          Text('$count판', style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    super.key,
    required this.rank,
    required this.record,
    required this.isBest,
  });

  final int rank;
  final GameRecord record;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final game = findGame(record.gameId);
    final detail = game?.stageDetail?.call(record.stage);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      decoration: BoxDecoration(
        color: game?.color ?? AppColors.pastelLavender,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: isBest
            ? Border.all(color: const Color(0xFFF5B800), width: 3)
            : null,
      ),
      child: Row(
        children: [
          // 순위
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  isBest ? '🏆' : (game?.emoji ?? '🎮'),
                  style: const TextStyle(fontSize: 28),
                ),
                Text(
                  '$rank위',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('Stage ${record.stage}', style: textTheme.titleLarge),
                    if (detail != null)
                      Text(detail, style: textTheme.bodyMedium),
                    if (record.cleared) const _Tag(text: '🎉 모두 클리어'),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text('⭐ ${record.score}점', style: textTheme.bodyLarge),
                    Text(
                      '⏱️ ${formatDuration(record.elapsedSeconds)}',
                      style: textTheme.bodyLarge,
                    ),
                    Text('🔁 ${record.moves}번', style: textTheme.bodyLarge),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '📅 ${formatDateTime(record.playedAt)}',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
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
