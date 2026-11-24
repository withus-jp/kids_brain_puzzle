import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/game_record.dart';
import 'score_repository.dart';

/// `shared_preferences`에 기록을 JSON 문자열 목록으로 저장하는 구현체.
///
/// 앱에서 `shared_preferences`를 쓰는 곳은 이 파일 하나뿐이다.
class LocalScoreRepository implements ScoreRepository {
  LocalScoreRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'game_records';

  final SharedPreferencesAsync _preferences;

  @override
  Future<void> saveRecord(GameRecord record) async {
    final stored = await _preferences.getStringList(_storageKey) ?? [];
    await _preferences.setStringList(
      _storageKey,
      [...stored, jsonEncode(record.toJson())],
    );
  }

  @override
  Future<List<GameRecord>> getRecords({String? gameId}) async {
    final stored = await _preferences.getStringList(_storageKey) ?? [];
    final records = <GameRecord>[];
    for (final item in stored) {
      try {
        records.add(
          GameRecord.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
      } on Object {
        // 형식이 깨진 항목은 건너뛴다.
      }
    }
    return records
        .where((r) => gameId == null || r.gameId == gameId)
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  @override
  Future<List<GameRecord>> getBestRecords() async {
    final best = <String, GameRecord>{};
    for (final record in await getRecords()) {
      final key = '${record.gameId}/${record.difficulty}';
      final current = best[key];
      if (current == null || record.isBetterThan(current)) {
        best[key] = record;
      }
    }
    return best.values.toList()
      ..sort((a, b) {
        final byGame = a.gameId.compareTo(b.gameId);
        return byGame != 0 ? byGame : a.difficulty.compareTo(b.difficulty);
      });
  }

  @override
  Future<GameRecord?> getBestRecord({
    required String gameId,
    required String difficulty,
  }) async {
    GameRecord? best;
    for (final record in await getRecords(gameId: gameId)) {
      if (record.difficulty != difficulty) continue;
      if (best == null || record.isBetterThan(best)) best = record;
    }
    return best;
  }

  @override
  Future<void> clearAll() => _preferences.remove(_storageKey);
}
