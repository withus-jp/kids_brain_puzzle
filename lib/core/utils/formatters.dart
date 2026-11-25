/// 초를 `m:ss` 형식으로 바꾼다. (예: 75 → `1:15`)
String formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// 날짜를 `yyyy.MM.dd` 형식으로 바꾼다.
String formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}

/// 날짜와 시각을 `yyyy.MM.dd HH:mm` 형식으로 바꾼다.
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatDate(local)} $hour:$minute';
}
