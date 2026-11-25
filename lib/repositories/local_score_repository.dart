import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/game_record.dart';
import 'score_repository.dart';

/// `shared_preferences`에 기록을 JSON 문자열 목록으로 저장하는 구현체.
///
/// 앱에서 `shared_preferences`를 쓰는 곳은 이 파일 하나뿐이다.
/// 모바일은 기기 저장소, 웹은 브라우저 localStorage에 남으므로 앱을 다시 켜거나
/// 새로고침해도 기록이 유지된다.
class LocalScoreRepository implements ScoreRepository {
  LocalScoreRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// 저장 키. 형식이 바뀐 Phase 3부터 새 키를 쓴다.
  static const _storageKey = 'game_records_v2';

  final SharedPreferencesAsync _preferences;

  Future<List<GameRecord>> _load() async {
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
    return records;
  }

  Future<void> _store(List<GameRecord> records) => _preferences.setStringList(
    _storageKey,
    [for (final r in records) jsonEncode(r.toJson())],
  );

  @override
  Future<void> saveRecord(GameRecord record) async {
    final records = await _load()
      ..removeWhere((r) => r.id == record.id);
    await _store([...records, record]);
  }

  @override
  Future<List<GameRecord>> getRecords({String? gameId}) async {
    final records = await _load();
    return records.where((r) => gameId == null || r.gameId == gameId).toList()
      ..sort(GameRecord.compareByStageThenRecent);
  }

  @override
  Future<GameRecord?> getBestRecord({
    required String gameId,
    String? excludeId,
  }) async {
    GameRecord? best;
    for (final record in await getRecords(gameId: gameId)) {
      if (record.id == excludeId) continue;
      if (best == null || record.isBetterThan(best)) best = record;
    }
    return best;
  }

  @override
  Future<void> clearAll() => _preferences.remove(_storageKey);
}
