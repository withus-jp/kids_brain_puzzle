# Project: Kids Brain Puzzle Hub

## 1. Tech Stack & Environment
- Framework: Flutter (Web & Mobile Cross-platform)
- Language: Dart
- Local Storage: shared_preferences

## 2. Architecture & Folder Structure (Strict)
확장성을 위해 Feature-first 구조와 Repository 패턴을 엄격히 준수한다.
- `lib/core/`: 공통 모델(`GameRecord`), 테마, 유틸리티
- `lib/repositories/`: 데이터 저장소 추상 클래스(`ScoreRepository`) 및 구현체(`LocalScoreRepository`)
- `lib/screens/`: 메인 게임 허브(홈 화면), 기록/랭킹 화면
- `lib/games/`: 개별 게임 모듈 (각 게임은 독립된 폴더로 구성)
    - `lib/games/memory_match/`: 기억력 카드 짝 맞추기 게임

## 3. Coding & Vibe Coding Rules
- **UI와 데이터 계층 분리:** UI 위젯에서 `shared_preferences`를 직접 호출하지 않고 반드시 `ScoreRepository` 인터페이스를 통해 접근한다. (향후 온라인 랭킹 API 연동을 위함)
- **반응형 디자인:** 웹(가로 넓은 화면)과 모바일(세로 화면) 모두에서 카드가 잘리지 않고 중앙에 깔끔하게 배치되도록 `LayoutBuilder`나 `ConstrainedBox`를 활용한다.
- **아이 친화적 UI:** 둥근 모서리, 밝고 선명한 파스텔 톤 색상, 크고 명확한 이모지/아이콘을 사용한다.
- **작업 단위:** 한 번에 요청받은 Phase만 구현하고, 임의로 다음 Phase의 기능을 미리 만들지 않는다.