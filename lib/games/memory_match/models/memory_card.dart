/// 홀수 그리드의 남는 칸에 놓이는 특수 카드 종류.
enum SpecialCardKind {
  /// 찬스: 짝을 못 찾은 카드를 잠깐 모두 보여 준다.
  star('⭐'),

  /// 꽝: 제한 시간이나 남은 기회를 뺏는다.
  bomb('💣');

  const SpecialCardKind(this.emoji);

  final String emoji;
}

/// 게임판 위 카드 한 장.
class MemoryCard {
  const MemoryCard({
    required this.emoji,
    this.special,
    this.isFaceUp = false,
    this.isMatched = false,
  });

  /// 특수 카드를 만든다.
  MemoryCard.special(SpecialCardKind kind)
    : this(emoji: kind.emoji, special: kind);

  /// 카드 앞면 그림. 일반 카드는 같은 이모지 두 장이 한 쌍이다.
  final String emoji;

  /// 특수 카드이면 그 종류, 일반 카드이면 `null`
  final SpecialCardKind? special;

  /// 지금 앞면이 보이는지 여부
  final bool isFaceUp;

  /// 짝을 찾았거나(일반 카드) 이미 사용했는지(특수 카드) 여부.
  /// 이런 카드는 계속 앞면으로 둔다.
  final bool isMatched;

  bool get isSpecial => special != null;

  /// 앞면이 화면에 보여야 하는지 여부
  bool get isRevealed => isFaceUp || isMatched;

  MemoryCard copyWith({bool? isFaceUp, bool? isMatched}) => MemoryCard(
    emoji: emoji,
    special: special,
    isFaceUp: isFaceUp ?? this.isFaceUp,
    isMatched: isMatched ?? this.isMatched,
  );
}
