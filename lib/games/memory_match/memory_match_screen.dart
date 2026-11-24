import 'package:flutter/material.dart';

/// 기억력 카드 짝 맞추기 게임 화면 (임시).
///
/// 실제 게임 로직은 Phase 2에서 구현한다.
class MemoryMatchScreen extends StatelessWidget {
  const MemoryMatchScreen({super.key});

  static const gameId = 'memory_match';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기억력 짝 맞추기')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '기억력 짝 맞추기 게임 화면 (Phase 2에서 구현 예정)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
