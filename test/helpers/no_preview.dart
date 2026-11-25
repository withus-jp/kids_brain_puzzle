/// Stage 시작 미리 보기를 건너뛴다. 미리 보기와 상관없는 기존 테스트에서
/// [MemoryMatchController]의 `previewDurationFor`로 넘긴다.
Duration noPreview(int stage) => Duration.zero;
