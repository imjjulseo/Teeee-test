# Swap match (가제)

N×N 그리드 위에서 플레이어 블록을 한 칸씩 움직여 색 블록과 자리를 바꾸고, 플레이어 상·하·좌·우 4칸을 같은 색으로 맞춰 깨서 시간을 얻고, 족보를 완성해 점수를 모으는 1인 시간제 스코어어택 퍼즐. 캐릭터마다 능력이 플레이를 바꾸고, 계정 레벨·뽑기·업적으로 캐릭터를 모은다.

- 엔진: Godot 4.7.2 / GDScript
- **게임 규칙의 기준은 기획서다**: @docs/game_design.md (v1.0). 수치·규칙·캐릭터·예외 처리는 기획서를 따르고, 규칙을 바꾸면 기획서(해당 장 + 별첨 A 결정 기록 + 별첨 C 업데이트 내역)도 함께 고친다.
- 코드 주석의 `E5`, `B14` 같은 번호는 기획서 (별첨 A) 결정 기록의 번호다.
- 이 파일은 **작업 규칙과 구현 구조**만 다룬다.

## HTML 프로토타입 이식 진행 중

- 기획서 v1.0은 팀 HTML 프로토타입 "Swap match"(10/20) 기준이다. **코드는 단계별로 v0.9.3에서 v1.0으로 바뀌는 중**이며 단계와 상태는 기획서 13장에 적는다. 단계를 끝낼 때마다 13장 상태를 고친다.
- 0~9단계 완료 (8단계 = 팀 결정 11/04 반영: 선택권·합성 5:1·뽑기 500·경험치 공식·퍼즐 분리, 9단계 = HTML 11/06: 메뉴 > 퍼즐·튜토리얼 레벨제 없앰·웹 배포) (7c 모바일은 빌드 준비까지 — Android APK는 템플릿·SDK·JDK 설치 뒤, iOS는 Mac + Xcode에서, `docs/mobile_build.md`). 로스터는 기본 + 31명 전원(기획서 5.2장 표 순서, 등급 `CharacterData.grade`). 처음에는 기본 캐릭터만 해금. v0.9.3 보관본(`docs/archive/game_design_v0.9.3.md`)은 참고용.
- 색 ID는 **0 노랑 · 1 빨강 · 2 파랑 · 3 초록**(E16). 캐릭터 id는 HTML id(`clock`, `fever` 등).
- 효과음 합성은 이식하지 않는다(E18). 소리는 `SfxPlayer` 자리만.
- `tests/test_design_doc_sync.gd`: 설정은 10장 표, 로스터 캐릭터는 5.2장 표(`| 이름 | id | 등급 | 족보 | 능력 |`의 족보·능력 칸)와 비교한다. 캐릭터를 추가하면 `ability_description`을 표의 "능력" 칸과 똑같이 쓴다.

## 객체 지향 설계 원칙 (이식 작업에서 반드시 지킨다)

- **한 클래스 = 한 책임.** 규칙 하나가 커지면(리필, 족보 생성, 금화, 시간 획득 등) 세션에 코드를 쌓지 말고 자기 클래스로 뺀다. `GameSession`은 순서를 조율할 뿐 세부 규칙을 직접 계산하지 않는다.
- **캐릭터별 분기를 핵심 로직에 쓰지 않는다.** `if character.id == ...`를 세션·보드·족보 코드에 넣지 말고, `Ability` 하위 클래스가 훅을 덮어써서 동작을 바꾼다(전략 패턴). 새 캐릭터 = 하위 클래스 1개 + 리소스 1개로 끝나야 한다.
- **확장 지점은 이름 있는 훅·인터페이스로.** 여러 캐릭터가 같은 방식으로 바꾸는 규칙(매치 판정, 얻는 시간, 리필 속도, 족보 진행, 점수 배율, 입력 가로채기)은 훅으로 열어 둔다. 훅이 늘어나면 기획서 5.2장 표와 맞는지 확인한다.
- **시간에 따라 일어나는 일은 공통 시간표로.** `TimedSystem`을 상속해(시계 선택 + `time_to_next_event` + `advance`) `GameSession._timed_systems`에 등록하면 세션 이벤트 루프가 한 곳에서 사건 시각을 맞춘다. 세션에 시간 계산을 직접 쓰지 않는다.
- **수치는 데이터로.** 게임 규칙은 `GameConfig`, 캐릭터 수치는 캐릭터·능력 리소스, 진행·재화 수치는 별도 리소스. 밸런스·경제 수치를 코드 상수로 두지 않는다 (방향·인덱스 같은 구조 상수는 괜찮다).
- **가독성:** 함수는 한 가지 일을 하고 이름이 그 일을 말한다. 긴 조건식은 이름 있는 함수로 뺀다. 공개 API에는 `##` 문서 주석을 단다. 상속은 "is-a"일 때만, 나머지는 구성(composition).

## 폴더 구조

```
scenes/                    # .tscn 씬 (Main, Board, HUD, Result, 메뉴 등)
scripts/                   # 씬에 붙는 View/Controller 스크립트 (Node 의존)
scripts/channels/          # View 종류별 이벤트 채널 (BoardChannel / HudChannel / FlowChannel)
scripts/logic/             # 순수 게임 로직 (Grid, 이동/매치 판정, 족보, 타이머). 씬·렌더링 의존 금지
scripts/logic/abilities/   # 캐릭터 능력 (Ability 하위 클래스, 능력 1개 = 파일 1개)
scripts/theme/             # 디자인 토큰·테마 만들기 (DesignTokens, UiThemeSpec, UiThemeBuilder, TokenRect)
scripts/tutorial/          # 튜토리얼 진행(TutorialDirector)과 단계 종류(TutorialStep 하위 클래스, 단계 1종 = 파일 1개)
resources/                 # 설정 리소스 (.tres): game_config, board_theme, ui_theme, character_roster, characters/
assets/                    # 디자인 이미지·폰트 (종류별 폴더, 넣는 곳은 docs/art_assets.md). assets/fonts/ = UI 폰트 자리
tools/                     # 개발 도구 (build_ui_theme.gd: 토큰 → ui_theme.tres, playtest_summary.gd: 플레이 기록 요약, build_android.ps1: APK, build_ios.sh: Mac에서 iOS)
tests/                     # 로직 단위 테스트. test_*.gd의 test_* 메서드를 자동 실행 (하위 폴더 제외)
tests/framework/           # 테스트 기반(test_case.gd), 스크립트 오류 감지 로거
tests/smoke/               # 실제 창 스모크 테스트 (run_smoke.ps1)
docs/                      # 기획서 (docs/archive/ = 이전 판 보관)
.github/workflows/         # CI 초안 (헤드리스 단위 테스트)
```

## GDScript 4 규칙

- 모든 변수, 매개변수, 반환값에 **정적 타입**을 명시한다. (`var score: int = 0`, `func move(dir: Vector2i) -> bool:`)
- 이름은 **snake_case** (변수·함수·파일), 클래스는 PascalCase `class_name`, 상수·enum 값은 UPPER_SNAKE_CASE.
- 노드 간 통신은 **signal 우선**. 자식이 부모를 직접 호출하거나 `get_parent()`/절대 경로 `get_node()`에 의존하지 않는다.
- 게임 상태는 bool 여러 개가 아닌 `GameState` enum과 명시적 전환 함수로 관리한다.
- 검증은 `assert`에만 두지 않는다 — 배포 빌드에서 사라진다. 설정은 `GameConfig.ensure_valid()`(오류 기록 + 기본값), 씬 연결 누락은 `push_error` 후 안전하게 멈춘다.

## 핵심 설계 원칙

- **논리 Grid가 Source of Truth다.** 셀 상태와 플레이어 좌표는 `scripts/logic/`의 `Board`가 결정한다.
- **View는 Grid 상태를 따라가기만 한다.** 채널로 받은 이벤트를 애니메이션으로 표현할 뿐, 게임 상태를 판단하거나 변경하지 않는다. 화면 좌표로 판정하지 않는다.
- 이동은 입력 즉시 그리드에 반영되고 매치도 바로 판정한다 (E4). 이동 애니메이션은 View의 표현일 뿐 로직은 기다리지 않는다.
- 난수는 판의 seed에서 만든 RNG로만 생성한다. 전역 `randi()` / `randf()` 금지.
  - `GameRng.derive(seed, Stream)`로 **보드 / 리필 / 족보 / 능력 / 금화** RNG를 따로 만든다. 새 기능이 난수를 쓰면 새 `Stream`을 추가하고 기존 번호는 바꾸지 않는다 (같은 seed의 결과가 바뀜).
- 시간 로직은 프레임레이트와 무관해야 한다.
  - `GameSession.advance(delta)`는 한 프레임을 **사건 시각에서 끊어** 처리한다: 0초 도달(`TimeKeeper`), 등록된 `TimedSystem`(씨앗 단계 `RefillSystem`, 금화 수명 `CoinSystem`)의 다음 사건, 능력 타이머(`Ability.time_to_next_event`). 시계는 `PLAY`(판 경과)와 `REFILL`(능력이 배속·정지 가능) 두 가지.
  - 시계는 첫 이동(또는 `GameSession.start()`)부터 흐른다. 그 전 `advance`는 아무것도 하지 않는다.
  - 시간에 따라 일어나는 일을 추가하면 `TimedSystem`으로 등록한다. `tests/test_event_order.gd`가 프레임 크기와 무관한지 검사한다.
  - 실제 게임 루프(`GameController`)만 한 프레임 반영 시간을 `max_frame_delta`로 자른다. 로직은 자르지 않는다 (테스트가 큰 delta를 쓴다).

## 씬 구성 규칙

- 고정 구조는 **스크립트(`add_child`, `new()`)로 만들지 않고 `.tscn`에 자식 씬을 인스턴스로 배치**해 관계가 씬 트리에 보이게 한다.
- 노드 간 signal 연결은 `.tscn`의 `[connection]`으로 정의한다. 코드 `connect()`는 다음 경우에만: RefCounted 로직 객체(세션·흐름) 연결, 데이터로 개수가 정해지는 반복 노드(셀, 캐릭터 카드), 뷰포트·자기 자신의 `resized` 같은 엔진 신호.
- 데이터로 개수가 정해지는 반복 노드는 `PackedScene`을 export 받아 코드에서 인스턴스화한다.
- 공유 리소스(`GameConfig`, `BoardTheme`, `CharacterRoster`)는 각 노드의 `@export`로 씬에서 지정한다.
- **게임 화면 이벤트는 View 종류별 채널로 나눈다** (main.tscn에서 `GameController`의 자식):
  - `BoardChannel` → BoardView(, SfxPlayer) / `HudChannel` → Hud(, SfxPlayer, EffectBackground) / `FlowChannel` → 오버레이·입력·방향키·씬 전환.
  - 세션 → 채널 전달은 각 채널의 `bind(session, character)`. View는 `GameController`를 직접 구독하지 않는다.
  - 새 이벤트는 받는 View의 채널에 signal을 추가하고 `.tscn`에 연결한다. `tests/test_channels.gd`가 구조를 검사한다.
- `GameController`는 `process_priority = -1` — 같은 프레임에서 시간 진행이 입력 처리보다 먼저 실행되어야 0초 프레임의 입력이 거절된다.
- 씬 전환은 `SceneNavigator` 노드(대상 경로 export)에 버튼 signal을 연결한다. 씬끼리 PackedScene으로 서로 참조하지 않는다 (순환 로드).
- 버튼은 `focus_mode = 0` — 방향키가 GUI 포커스 이동에 먹히지 않게.
- **화면 비율·안전 영역**: 기준 720×1280, `stretch/aspect = expand`. 좌표를 고정하지 말 것.
  - 가장자리에 붙는 UI는 `SafeArea`(노치 여백) → `Content`(Control) → 실제 노드(앵커) 구조. HUD, 가상 방향키, 메뉴, 레벨 보상, 캐릭터 화면, 옵션이 이 구조다.
  - 보드는 `LayoutLayer/GameLayout/SafeArea/Column/BoardArea` 가운데에 배치·축소된다. `HudSpace`(300)는 HUD 영역, `DpadSpace`(`ControlModeSpace`: 패드 360 · 스와이프 200, `FlowChannel.control_mode_ready`)는 방향키·설명 칸 영역과 맞춘다. 게임 화면 바탕은 프로젝트 기본 배경색(`#0C1F26`).
  - Control을 Node2D 아래에 두면 앵커가 화면 크기로 잡히지 않는다 → 레이아웃용 Control은 CanvasLayer 아래에.
  - 노치 확인: `SafeArea.debug_insets = Vector4(0, 90, 0, 40)`. 데스크톱은 여백 0.
- **디자인 토큰** (7.3장, E14, 7a): 화면 색은 `DesignTokens`(`resources/design_tokens.tres`, 용도 이름 → 색)에만 둔다. 프로젝트 테마 `resources/ui_theme.tres`는 **생성 파일** — `UiThemeSpec`(`resources/ui_theme_spec.tres`: 라벨 글자색 변형 → 토큰, 판넬·버튼·슬라이더 변형 = 모양 `StyleBoxFlat` + 토큰 이름, 기본 폰트)과 토큰으로 `UiThemeBuilder`가 만든다: `godot --headless --path . -s tools/build_ui_theme.gd`. 직접 고치지 않는다. 씬은 색을 직접 적지 않고 `theme_type_variation`(`MutedLabel` · `DimLabel` · `AccentLabel` · `InfoLabel` · `CaptionPanel` …)을 쓰고, 단색 사각형(배경·진행 막대)은 `TokenRect`(`token` 이름). 스크립트가 토큰을 읽을 때는 `get_theme_color(이름, DesignTokens.THEME_TYPE)`. `test_design_tokens.gd`가 테마가 최신인지·씬에 팔레트 색이 남지 않았는지 검사한다 (예외: 판 칸·상자 그림·투명 시작값·검은 외곽선). 판 색은 `BoardTheme`. 라이트/다크는 토큰 리소스를 하나 더 만들어 테마를 다시 만들면 된다.
- 폰트: `resources/ui_theme_spec.tres`의 Default Font에 지정하고 테마를 다시 만들면 전체 적용 (`assets/fonts/README.md`).
- **HTML 화면 디자인 (E30)**: `UiStyle`의 `name`이 `base_type`과 같으면(예: `Button`) 그 타입 전체의 기본 모양, `font_token`이면 글자색까지. 버튼 변형: 기본(패널 + 선) · `HotButton`(주황, 주 행동) · `AccentButton`(노랑, 설명 칸) · `PillButton`(알약) · `SoftButton`(설명 칸 안 작은 버튼) · `GhostButton`. 지금 누를 버튼은 `GlowRing`(화면을 덮는 투명 Control, `follow(버튼)`). 스포트라이트는 셰이더로 부드러운 구멍(여백·모서리·흐림은 `SpotlightOverlay` export, 색은 토큰 `spotlight_dim`), 설명 칸 = `CaptionIcon`(ㅗ·족보 점·금화·시계·씨앗) · `SegmentBar`(진행) · 글 · `Foot`(= `TutorialPuzzleBar`, 퍼즐 조작 설명에만) · `TapRing` 또는 노란 버튼, 건너뛰기 알약은 칸 위. 판 위 퍼즐 안내 빛·화살표 깜빡임은 `BoardMarksView`(수치는 `BoardTheme` Puzzle 그룹), 목표 자리·설 칸·퍼즐 창은 그리지 않는다(`PuzzleRunner.show_window` 기본 false). 족보 카드 틴트·점 밝기는 `BoardTheme` Recipe 그룹.
- **디자인 이미지 자리** (한 장 이미지, `docs/art_assets.md`): **비어 있으면 지금 그림**, 있으면 이미지. 판·연출은 `BoardTheme`의 Art 그룹(블록 4장 — 문양 포함이라 능력이 색을 바꾸는 동안(`DisplayStyle`의 `color_alias`·`monochrome`)은 `block_art`가 null → 그림, 씨앗·금화·플레이어·판 위 표시 `mark_textures`(Kind → 이미지, 화살표는 오른쪽 이미지를 돌림)·발동 섬광·배경 효과·뽑기 상자 닫힘/열림), 캐릭터는 `CharacterData.portrait`(판 위·카드·시트·뽑기 결과·상점 줄·뽑기 목록, `PortraitRect`), 화면 공통은 `UiAssets`(`resources/ui_assets.tres`: 로고·코인·다이아 아이콘 — 지갑 `WalletView`·HUD 코인), 판넬·버튼은 `UiStyle.texture` + `texture_margins`(9분할 `StyleBoxTexture`, 테마 다시 만들기). 테두리 색을 바꾸는 코드(배너·뽑기 결과·레벨 줄)는 `StyleBoxFlat`일 때만 바꾼다. `smoke_art`가 모든 자리에 임시 이미지를 넣어 확인한다.

## 구현 메모

- **입력** (E8): Input Map `move_up/down/left/right`(방향키 + WASD, physical keycode, 키 반복 허용), `pause`(ESC). `InputRouter`가 입력을 **즉시** `move_requested(dir, hand)`로 보낸다 (모으지 않음). 손: 0 = WASD·화면 왼쪽 절반·패드, 1 = 방향키·오른쪽 절반 (양손잡이만 구분해 씀). 누르고 있기는 `hold_started(dir, hand)`/`hold_released`(키를 누른 채, 스와이프한 손가락을 뗀 채, 패드 버튼), 꾹 누르기는 `long_pressed`(움직이지 않고 `long_press_time`초 또는 스페이스, 그 터치는 탭이 아님). 시간은 `InputRouter.tick(delta)`(테스트가 직접 부름). 스와이프 판정은 `SwipeGesture`(순수 로직): 손을 떼기 전 `swipe_threshold`(22px)를 넘는 순간 1칸, 한 터치 1칸. 움직이지 않은 탭은 `tap_requested` → `BoardView.cell_at`이 칸으로 바꿔 `cell_tapped` → `GameFlow.request_move_toward`(옆 칸이면 이동). 패드(`VirtualDpad`)는 누르는 순간 1칸, `RepeatTimer`로 0.17초 뒤 0.06초마다 반복. 스와이프는 `_unhandled_input`이라 버튼을 누른 터치로는 이동하지 않는다. 데스크톱은 `emulate_touch_from_mouse=true`.
- **캐릭터 능력**: 능력 1개 = `Ability` 하위 클래스 1개, 캐릭터 .tres가 하위 리소스로 품는다. 세션은 판마다 `duplicate()`한 인스턴스를 쓰므로 실행 중 상태는 **export하지 않은 멤버**에 둔다. 새 능력 = 하위 클래스 1개 + 캐릭터 .tres 1개 (캐릭터 색 `accent_color` = HTML `color`).
  - 세션 훅: `recipe_lengths` / `setup` / `match_rule` / `intercept_move` / `on_hold` / `on_release` / `on_long_press` / `refill_colors` / `locks_input` / `canonical_color` / `pass_through_wall` / `condition_frozen` / `on_move` / `after_move` / `trigger`(결과 문구 반환) / `modify_match_time` / `on_match` / `override_clear` / `modify_outcome` / `clock_rate(Clock)` / `advance` / `time_to_next_event` / `on_game_end` / `prefers_hint`(캐릭터 튜토리얼 힌트). 표시: `status_text`(캐릭터 카드 둘째 줄) / `effect_remaining` + `effect_block_color` + `effect_blink_window`(배경 효과) / `board_marks`(판 위 깃발·구역, 바뀌면 `session.notify_marks_changed()`) / `display_style`(색 합치기·흑백 `DisplayStyle`, 바뀌면 `session.notify_display_changed()`, View는 `BoardTheme.display_color`로 칠함). 목록과 부르는 때는 `ability.gd` 머리 주석.
  - 시간을 멈추거나 빠르게 하는 능력은 `clock_rate`로 (`TIMER` 0 = 시간 정지, `REFILL` ×2 = 리필 가속). 배속이 바뀌는 순간은 `time_to_next_event`로 알린다 — 세션은 구간 시작 때 배속을 정한다.
  - 족보 밖 점수(피버 정산 등)는 `GameSession.add_bonus_score(points, label)`. 판이 결과로 끝나면 `GameFlow`가 `session.finish()` → `on_game_end` (메뉴로 나간 판은 정산하지 않음).
  - 발동형 = `condition_colors`가 있는 캐릭터(`has_recipe`), 상시형 = 능력만 있고 족보 없음(카드에 상태만). 매치 규칙은 `MatchRule`(판 밖 이웃 허용 수, 상속해 바꿈), 판 끝 연결은 `Board.wraps_edges`(`step_from`). 능력 문구가 메시지 줄로 가는 길: 발동 = `trigger` 반환값, 그 밖 = `session.announce`. 매치 밖 시간 = `session.add_time`. 매치 밖 블록 폭파 = `session.blast_cell`, 매치 밖 족보 진행 = `RecipeSet.advance_slot` + `session.apply_recipe_outcome`, 순간이동 = `session.teleport_player`(`MoveResult.is_jump()`면 View가 바로 옮김). 매치 밖 매치 1회의 시간 = `session.award_match_time`, 판을 통째로 바꿈 = `Board.mirror` + `session.notify_board_rearranged`. 족보 칸 상태는 `Recipe.filled`/`is_step_done`/`next_index`로 읽는다 (거울세계는 뒤에서 채움, `progress`만 보지 않는다).
  - 이동: 플레이어 입력은 `session.request_move(dir, hand)`(잠금 → 가로채기 → `perform_move`). 능력의 자동 이동은 `perform_move`(판정 포함), 판정 없는 이동은 `shift_player`(마탄). 플레이어 둘(양손잡이)은 `Board.add_player` / `select_player` / `player_position`, 서로의 칸은 `BLOCKED_BY_PLAYER`.
  - 함정: 조건식 안의 배열 리터럴(`[x] if a else []`)은 `Array[T]` 반환형이어도 타입이 붙지 않아 타입 있는 signal 처리 함수가 받지 못한다 → 타입 있는 변수에 담아 돌려준다. 훅을 추가하면 `ability.gd` 목록과 이 줄을 고친다.
- **저장**: `user://save.cfg` 하나. 파일 입출력은 **`SaveData`만** 한다 (`[meta] version`, 현재 4 — version 3 이하 저장은 처음 읽을 때 설정(`[options]`)만 남기고 초기화, 팀 결정 11/04 E26). `BestScoreStore` / `CharacterStore` / `OptionsStore`는 SaveData로 값만 읽고 쓴다. 형식을 바꾸면 `CURRENT_VERSION`을 올리고 `SaveData._migrate()`에 단계를 추가한다. 경로를 주지 않으면 `SaveData.path_override` → 기본 경로 순.
- **진행·재화** (8장): 수치는 `ProgressionConfig`(`resources/progression.tres`: 경험치 지급 `exp_per_game + exp_per_point × 점수`, 필요 경험치 `curve_from_level` 전 직선 `linear_base/step` · 그 뒤 포물선 `curve_base/step/square` — 임시값이라 리소스만 고치면 바뀜, 레벨업 보상(매 레벨 같음)·선택권 레벨(Lv10·20·30)·보드 단계 `BoardStage`·부활 비용). 저장은 `ProgressStore`(`[progress]`: 레벨·경험치·코인·다이아·등급별 선택권·해금 캐릭터). 판 끝 정산은 순수 계산 `RunRewards.compute` → `ProgressStore.apply_rewards`(RESULT일 때만, 메뉴로 나간 판·다시 시작은 없음). 보드 단계는 `GameController._stage_config`가 판마다 `GameConfig` 사본에 덮어쓴다 (`GameFlow.set_config`). 부활은 `DiamondRevivePolicy`(판당 1번) + `RevivePanel`(REVIVE 상태). 설정의 `DebugPanel`은 개발 빌드만 보인다.
- **뽑기·상점** (8.5장): 수치는 `GachaConfig`(`resources/gacha.tres`, `ProgressionConfig.gacha`로 참조 — 1회 가격 `price`(● 500 고정), 뽑기 머신 단계 `GachaTier`(레벨·등급 확률 — 레벨 마일스톤에 업그레이드), 다이아 상점 가격·개방 레벨, 합성 장수, 광고 보상). 뽑기·합성·광고는 `CharacterShop`(난수는 자기 RNG, 테스트는 seed 주입), 선택권·다이아 해금과 카드 상태 문구(`status_text`, 시트용 `offer_for`)는 `CharacterCollection`. 화면은 `shop.tscn`(`ShopScreen`, 상자 `GachaChest` → 결과 카드 `GachaReveal`, 연출 시간·등급 색은 `BoardTheme`의 Collection 그룹, 효과 줄이기면 바로). 광고는 자리만(E18): 누르면 다이아를 준다. 튜토리얼 흐름의 첫 뽑기 고정은 6단계.
- **업적** (8.6 · 8.7장, 별첨 B): 목록·목표·보상은 `AchievementBook`(`resources/achievements.tres`: `CommonAchievement` · `CharacterAchievementChain` · `HiddenAchievement`). 판 지표는 `GameSession.metrics`(`RunMetrics`): 능력은 자기 `METRIC_*` 상수 이름으로 `add`(누적)/`record_max`(한 번에), "효과 한 번 동안" 지표는 `EffectWindowMetrics` 부품. 판 공통(점수·매치·족보)과 이동 습관(히든)은 `RunMetrics`가 채운다. 평가는 판이 RESULT일 때 `GameController`가 `AchievementTracker.record_game` 한 번(체험·메뉴로 나간 판 없음, E21) → `FlowChannel.achievements_ready` → 결과 보상 목록. 진행·달성·누적 통계 저장은 `AchievementStore`(`[achievements]`, `[stats]`). 업적을 추가하면 지표 이름이 실제로 남는지 `test_achievements.gd`가 검사한다. 히든 업적은 진행만 기록(달성 판정 없음).
- **블럭 모으기 퍼즐** (8.8장): 판·문구·규칙 수치는 `PuzzleBook`(`resources/puzzles.tres`: `PuzzleLevel` · `PuzzleDef`(5줄 문자열 T/P/.) · `PuzzleDifficulty`). 한 판은 `BlockPuzzle`(순수 로직: Board 위 창에 깔고, 모을 블록은 칸 객체로 추적, 수 판정·힌트·되돌리기·별점·정답 다시 보기), 최소 수는 `PuzzleSolver`(너비 우선, 창 둘레 한 칸 안에서만 탐색 — GDScript 속도), 무작위 문제 생성 `PuzzleGenerator`·`PuzzleDifficulty`는 남아 있지만 11/06부터 화면에서 쓰지 않는다(E28). 판 위 안내는 `PuzzleMarks` → `BoardMark`(TARGET·GOAL_*·STAND·PULL·ARROW). 화면은 메인 메뉴의 퍼즐 → `puzzle_menu.tscn`(`PuzzleMenuScreen`: 번호 붙은 판 버튼 `PuzzleBoardButton`, 첫 방문 안내 `SEEN_PUZZLES`) → `puzzle_play.tscn`(BoardView를 BoardChannel 이벤트로 재사용, 무엇을 풀지는 `PuzzleRequest`, 결과의 "다음 퍼즐"로 다음 판을 같은 화면에서). 기록은 `PuzzleStore`(`[puzzle]`, 첫 클리어 보상 받은 판 `rewarded`). 메뉴 판 목록은 `PuzzleMenu`(`PuzzleLevel.in_menu` 단계의 판을 단계 구분 없이 1번부터, 모두 열림, 첫 클리어 코인 `PuzzleBook.menu_clear_coins` 한 번) — 목록·풀이 화면이 이 결과를 보여 준다. 한 수는 반대 수로 되돌릴 수 있어 최소 수가 많아야 1 늘어난다 — "모양이 깨졌어요"는 풀이기가 한도 안에서 못 풀 때만 (HTML과 같음).
- **규칙 튜토리얼** (8.8장, E29 — HTML runRuleTut와 같게): 단계 목록·판 규칙·흐름 수치는 `TutorialScript`(`resources/tutorial.tres`, 단계 = `TutorialStep` 하위 리소스: Say · Move · PuzzleLevel · CoinPuzzle · Board · Match · Time · Wait, 캐릭터 튜토리얼은 CharacterTrigger · CharacterLesson). 시작 판은 `TutorialStartBoard`(고정 시드 `start_seed`, HTML mulberry32 = `HtmlRng` — node로 돌린 HTML 결과와 같은지 `test_tutorial.gd`가 검사), 그 난수를 튜토리얼 내내 이어 쓴다(`TutorialDirector._pick`). 규칙 튜토리얼 퍼즐은 `start_rule_puzzle` → `BlockPuzzle.stamp`(판은 그대로, 내 주변 5×5만, 회전·뒤집기 `sym_rows`, `keep_board`, 목표 점선 없음 `show_goal`), 첫 판 손가락 안내 `BoardMark.Kind.SWIPE`(`BoardMarksView`가 애니메이션, 수치는 `BoardTheme`), 첫 매치 멈춤 설명 `hold_text`. 자유 매치 힌트는 `TutorialPlanner`(HTML tutPlans·bestPlan·tutEnsure·tutAssist·makeShape: 배운 모양 = 내가 옮긴 블럭 수 built ≤ 단계, 옮긴 기록은 칸 객체별), 칭찬은 `PuzzleRunner.CHEER_WORDS`. 튜토리얼 중 금화는 생기지 않는다(`CoinSystem.enabled`). 새 단계 종류 = `scripts/tutorial/`에 하위 클래스 1개. 진행은 main.tscn의 `Tutorial`(`TutorialDirector`): 튜토리얼 판은 본게임 세션 그대로(`GameSession.frozen_clocks`로 남은 시간 정지, 퍼즐이 풀리면 `resolve_player_match`), 퍼즐은 `PuzzleRunner`(연습 화면과 공유), 자유 매치 힌트는 `MatchPlanner`, 설명은 `SpotlightOverlay`(TAP = 판 멈춤, ACT = 직접 조작, 구멍 자리는 `Hud.target_rects`·`BoardView.cells_rect`). `GameController`가 튜토리얼 전이면 튜토리얼 판으로 열고(`_setup_tutorial`), 설명 중엔 판을 멈추고, 퍼즐 중엔 이동을 넘긴다. 끝/건너뛰기 → 기록·업적(`complete_tutorial`) → `FlowChannel.tutorial_finished`로 main.tscn을 다시 연다(실전 판, 첫 판 안내 `show_intro`).
- **캐릭터 튜토리얼** (8.8장, 6c): 데이터는 `CharacterTutorialBook`(`resources/character_tutorials.tres`: 캐릭터별 `CharacterTutorial` = 소개·`TutorialMoment`(처음 보는 순간)·활용 연습 `CharacterLessonStep`, 공통 문구·발동 퍼즐 모양). `steps_for`가 단계 목록(소개 → 발동형은 족보 설명 + `CharacterTriggerStep` → 활용 → 준비 끝)을 만들고 `TutorialDirector.begin_lesson`이 규칙 튜토리얼과 같은 도구로 돌린다. **목표·순간은 사건 이름**: 능력 지표(`RunMetrics.changed`, 능력의 `METRIC_*`) · 능력의 순간(`session.notify_moment(MOMENT_*)`, 피버 끝 등) · `TutorialMoment.ABILITY`(발동) · `CharacterLessonStep.RECIPE`(족보 완성). 새 캐릭터 튜토리얼 = 그 능력이 지표·순간을 남기고 `.tres`에 항목 하나 (`test_character_tutorial.gd`가 목표 이름이 그 능력의 상수인지 검사). 발동 연습은 `session.prime_ability_condition`(족보 마지막 칸), 연습 판 다시 켜기는 `session.trigger_ability`. 처음 일어난 순간은 `CharacterMomentGuide`가 고르고 튜토리얼 뒤 실전 판에도 이어진다(`watch_moments`). 판 위 안내 표시는 능력 표시에 덧붙여 보낸다(`TutorialDirector._emit_marks`). 진입: 첫 뽑기 캐릭터로 처음 시작(흐름 FIRST_CHARACTER의 `want_character`) = 바로, 처음 쓰는 캐릭터 = `offer_lesson`(스포트라이트 두 버튼, 처음 사용 기록은 `TutorialStore`의 `character:<id>`, 튜토리얼을 끝낸 저장은 `all_characters`라 묻지 않음), 캐릭터 상세 "튜토리얼 다시 하기" = `TrialRequest.with_lesson`(체험 판). `GameController`: 튜토리얼 판은 보상·기록 없음, 다시 시작은 튜토리얼부터, 끝나면(`lesson_finished`) 같은 캐릭터로 새 판(`_flow.start_new_game`).
- **처음 볼 때 안내** (8.8장, 6d): 문구는 `FirstViewTips`(`resources/first_view_tips.tres`), 본 기록은 `TutorialStore.seen`(`SEEN_MULTI_RECIPES` · `SEEN_EXPERIENCE` · `SEEN_ACHIEVEMENTS` · `SEEN_HIDDEN_ACHIEVEMENTS` · `SEEN_CHARACTERS`, `finish_all`이 모두 본 것으로). 화면 안내는 `GuideQueue`(안 본 것만 줄 세워 스포트라이트 TAP으로 하나씩, 띄우는 순간 본 것으로, 밝힐 곳은 띄울 때 Callable로 잼)를 화면이 갖고 그 화면의 `Spotlight`(씬 인스턴스) `tapped`에 `next`. 결과 화면(`ResultPanel`, 층 10이라 자기 스포트라이트 층 11) = 경험치, 업적 화면 = 업적 → 히든 업적, 캐릭터 화면 = 카드 줄. 판 중 "족보 동시 진행"은 `TutorialDirector.watch_multi_recipes`(`RecipeSet.slots_waiting_same_color`, 카드 한 장 구멍 `card:<i>`)가 `show_notice`로 (순간 설명과 같은 장치, 판을 멈춤). 체험 판·튜토리얼 중에는 없음.
- **튜토리얼 흐름**: 저장은 `TutorialStore`(`[tutorial]`: done·flow·seen·want_character, 칸이 없는데 진행 기록이 있으면 끝낸 것으로). 메뉴 단계 판단은 `TutorialFlow`(순수 규칙: 열린 버튼 수·빛나는 버튼·첫 뽑기 유도·결과에서 메뉴로). 화면별 연결: 메뉴(잠금·빛남·시작 → 상점), 결과(`result_guided`), 레벨 보상(안내 + seen), 상점(1회분 코인·첫 뽑기 `CharacterShop.pull(forced)`·장착), 캐릭터·업적 화면(seen). **스모크 기반은 튜토리얼을 끝낸 저장으로 시작한다** (튜토리얼 스모크는 `_setup`에서 `TutorialStore`를 다시 정함). 디버그 패널에 튜토리얼 처음부터·끝냄·첫 뽑기 직전·첫 캐릭터 받음.
- **메뉴·캐릭터 화면** (8.1장): 실행 씬은 `intro.tscn` → `main_menu.tscn`(레벨 버튼 → `level_rewards.tscn`, 상점 → `shop.tscn`, 업적 → `achievements.tscn`). 메뉴 버튼 단계 잠금은 `MenuUnlocks`(시작 → 레벨 → 상점 → 캐릭터 → 업적 → 퍼즐, 설정은 늘 열림). 캐릭터 규칙(카드 상태·등급순·선택권 해금·장착)은 `CharacterCollection`만 정하고, 장착은 **해금한 캐릭터만** 적용된다 (`equipped_character`, 아니면 기본) — 스모크·테스트에서 캐릭터를 쓰려면 `ProgressStore.unlock`도 한다. 상세 시트(`CharacterSheet`)는 signal로만 알린다. 상세 문구는 `CharacterData.detail_effect/when/tip`, 캐릭터 업적은 `AchievementTracker.chain_status`(없으면 "준비 중").
- **체험 판**: 캐릭터 화면이 `TrialRequest.character_id`를 적고 게임 씬으로 → `GameController`가 `take()`해 체험 판(부활·보상·경험치·최고 기록·플레이 기록 없음). 결과의 메뉴·일시정지의 메뉴·다시 시작은 `FlowChannel.back_to_characters` → 캐릭터 화면, 결과 표시는 `trial_result_ready`. 러너는 `TrialRequest`를 되돌리지 않으면 실패로 센다.
- **오디오**: 버스 `default_bus_layout.tres` (Master ← SFX, BGM). `SfxPlayer`는 효과음 ID마다 전용 `AudioStreamPlayer`(SFX 버스, `polyphony_per_sound`)를 처음 재생할 때 만든다 → 다른 효과음끼리 끊기지 않는다.
- **볼륨**: 마스터 볼륨 0~100은 `OptionsStore.master_volume`(`[options] master_volume`) → `OptionsStore.apply_master_volume`이 Master 버스 dB(볼륨² 곡선, 0 = 음소거)로 반영. 저장값은 `AudioOptionsLoader` 노드(intro.tscn, main_menu.tscn, main.tscn)가 씬이 열릴 때 반영한다. 버스별 볼륨을 추가하면 같은 방식으로.
- **플레이 기록**: `GameSession.stats`(`SessionStats`)가 판 통계를 세고, 판이 RESULT/ABANDONED가 되면 `GameController`가 `PlaytestLog`로 `user://playtest_log.csv`에 한 줄 추가 (개발 빌드 + `playtest_logging`). 열 추가는 `PlaytestLog.COLUMNS` **끝에만** (헤더가 바뀌면 옛 파일은 `_old_<시각>`으로 옮기고 새로 시작). 매치당 이동 수는 `SessionStats.count_move` / `record_match_moves`(플레이어 자리 매치만), 판 밖 값(계정 레벨·보드 단계·조작)은 `PlaytestLog.Context`. 요약은 `PlaytestSummary`(`tools/playtest_summary.gd [-- <csv>]`).
- **HUD** (7.1): 위 줄(일시정지·점수·코인·시간) + 시간 막대 + 족보 카드 + 아래 안내 줄(`MessageLabel`). 점수는 `_process`에서 부드럽게 차오르고, 매치 시간·금화는 `FloatingText`로 떠오른다. `HudChannel.publish_frame`은 매 프레임 불리지만 표시 값이 바뀔 때만 signal을 보낸다.
- **능력 표시** (5.2장): 캐릭터 카드(`AbilityView`) 둘째 줄 = `status_text`, 비어 있으면 능력 이름. 발동하면 캐릭터 색 섬광(`Flash`) + 배너(`Banner`) + 메시지 줄에 `trigger` 문구. 배경 효과는 `EffectBackground`(main.tscn, 판 뒤 CanvasLayer -2)가 `effect_updated`를 따라 칠하고 끝나기 3초 전(능력이 바꿀 수 있음, 현상금 2초)부터 깜빡인다. 블록 색으로 칠할 때(현상금)는 색 ID만 받고 색은 `BoardTheme`에서 찾는다. 판 위 깃발·구역은 `BoardView/Marks`(`BoardMarksView`)가 `BoardChannel.marks_changed`를 따라 그린다. 항해사의 판 끝 넘기(`MoveResult.wrapped`)는 미끄러지지 않고 바로 옮긴다. 연출 수치는 `BoardTheme`의 Ability 그룹.
- **연출·효과 줄이기**: 매치 = 칸마다 `BurstEffect`(CPUParticles2D) + 판 흔들림 (`BoardTheme` 수치). 설정의 효과 줄이기(`OptionsStore.reduce_motion`)는 판 시작 때 `FlowChannel.reduce_motion_ready`로 BoardView·Hud에 전달되어 흔들림·파편·떠오르는 숫자·시간 펄스를 끈다.
- **일시정지·결과**: 일시정지 = 계속 / 다시 시작(`GameFlow.restart`, 점수 미기록) / 메뉴. 결과 = 점수, 최고 기록, 최고점, 판 코인·보유 재화, 경험치 바, 레벨업 보상 목록, 다시 하기 / 메뉴 (체험 판은 점수만, 메뉴 → 캐릭터 화면). 설정 화면은 탭 없이 한 페이지.
- **판 구성 요소** (`scripts/logic/`): `Board`(칸 = `BoardCell` 객체, 교환 시 칸째로 이동 → 씨앗·금화가 따라감), `TimeKeeper`(남은 시간), `RefillSystem` + `RefillColorPicker`(씨앗·색 분산), `CoinSystem`(금화), `RecipeSet` + `RecipeGenerator` + `RecipeScoring`(족보), `RevivePolicy`(부활 제안 여부, 기본 없음 — 5단계에서 다이아 규칙). `GameFlow`: WAITING → PLAYING ⇄ PAUSED → (REVIVE) → RESULT, PAUSED → ABANDONED / restart.
- **표시**: 씨앗은 자랄 색을 숨기고 자람 진행도(`Board.get_grow_progress`, 대기 중 0)만큼 중앙에서 차오른다. 금화는 칸 오른쪽 위 원(`CellView.show_coin`). 색별 문양은 `BoardTheme.block_glyphs`. 효과음은 `SfxPlayer.sounds`(ID → AudioStream)에 지정된 것만 재생한다 (음원 없음).

## 밸런스 값

- 게임 수치(판 크기, 시간, 매치 시간, 리필, 족보 점수, 금화, 부활 시간, 애니메이션, 스와이프 기준, seed, 최대 프레임 시간 등)는 **코드에 하드코딩하지 않는다.** `GameConfig`(`resources/game_config.tres`)와 캐릭터·능력 리소스에 두고, 로직은 주입받아 쓴다. 현재 값은 기획서 10장.
- 색상 팔레트·문양·연출 값은 `BoardTheme`(`resources/board_theme.tres`)에 둔다.

## 수정 금지

- `.godot/` 디렉터리, `*.import`, `*.uid` 파일은 직접 수정하거나 생성하지 않는다 (에디터가 관리).
- `.tscn`·`.tres`를 고칠 때는 에디터가 넣은 `uid=` / `unique_id=`를 지우지 않는다 (파일 전체를 다시 쓰지 말고 필요한 부분만 편집).

## 검증

Godot 실행 파일은 PATH에 없다. 스크립트는 `-Godot <경로>` 인자 → 환경 변수 `GODOT_BIN` → 기본값(`C:\Users\JP\Desktop\Godot\Godot_v4.7.2-stable_win64_console.exe`) 순으로 찾는다.

- **단위 테스트** (로직을 바꿨으면 필수): `powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1`
  - 클래스 캐시 갱신(`--import`) 후 `tests/run_tests.gd`를 실행한다. 실패 시 exit code 1.
  - 러너는 테스트마다 `before_each` → 테스트 → `after_each`를 부르고, **테스트 도중 스크립트 오류**(엔진 `Logger`로 감지), **만들고 `free()`하지 않은 노드**(트리 안 + 고아 노드 수 비교)와 **되돌리지 않은 전역 상태**(`SaveData.path_override`, `PlaytestLog.path_override`, `SafeArea.debug_insets`, Master 버스 볼륨·음소거)를 실패로 센 뒤 초기화한다.
  - 러너는 트리가 돌기 전(`_initialize`)에 실행된다: `_ready`는 `notification(NOTIFICATION_READY)`로 부르고, `Range`(슬라이더)는 트리 밖에서 `value_changed`를 보내지 않으므로 signal을 직접 보낸다. 트리 밖 Control에 `NOTIFICATION_EXIT_TREE`를 보내면 엔진이 죽는다 → 그런 동작은 스모크로.
  - **테스트는 `_`로 시작하는 비공개 멤버를 부르지 않는다.** 로직은 공개 API로(예: `GameSession.apply_clear_to_recipes`, `InputRouter.handle_input`/`flush`), 엔진 콜백은 `notification()`으로, 씬에서 연결된 처리 함수는 `tests/framework/scene_wiring.gd`로 **main.tscn 연결을 그대로 이어 원래 signal을 보내서** 확인한다 (보내는 쪽으로만 쓰는 대역 노드는 `targets`로 제외).
  - 일부러 잘못된 설정을 넣는 테스트(`test_validation.gd`)는 `ERROR: ... using defaults` 로그를 내는 것이 정상이다.
  - signal 람다가 그 signal의 주인(session 등)을 캡처하면 순환 참조로 누수된다 → `weakref`로 읽는다.
- **실제 창 스모크** (화면·입력·씬을 바꿨으면): `powershell -ExecutionPolicy Bypass -File tests/smoke/run_smoke.ps1` (`-Only <이름>`으로 일부만, 약 3분)
  - `tests/smoke/smoke_base.gd`를 상속한다. 게임 전체를 스모크 전용 저장 파일·플레이 기록 파일로 돌리고, 사용자 파일이 한 바이트라도 바뀌면 실패.
  - 실제 클릭(`click_control`)은 누름·뗌을 같은 프레임에 넣는다. 누른 채 프레임이 지나면 실행 중 사용자의 진짜 마우스 이동이 끼어들어 클릭이 취소된다 (누르고 있기 검사는 `press_control`/`release_mouse`, 스와이프는 `touch` → `drag` → `touch`, 좌표는 뷰포트 기준).
  - 스모크 저장 파일은 Lv1이므로 기반이 보드 단계 표(`progression.stages`)를 메모리에서 비워 본 게임 보드로 돌린다. 단계를 검사하는 스모크만 `keep_stages = true`.
  - 설정값을 메모리에서 바꿀 때는 기반의 `config` 멤버를 쓴다 (참조를 쥐고 있어야 게임 씬이 같은 인스턴스를 쓴다). 스크린샷은 `user://smoke_shots/`.
- **프로젝트 로드**: `godot --headless --path . --quit` 가 오류 없이 끝나야 한다.
- `class_name`을 추가하거나 바꿨다면 `godot --headless --path . --import`로 전역 클래스 캐시를 갱신한다 (run_tests.ps1은 자동).
- **모바일** (7c): 프리셋 `export_presets.cfg`의 `Android`(`com.swapmatch.game`, arm64, 디버그 서명)와 `iOS`(같은 번들 ID, arm64, iPhone·iPad, Team ID는 각자 설정), 둘 다 `tests/`·`tools/`·`docs/` 제외. Android 빌드: `powershell -ExecutionPolicy Bypass -File tools/build_android.ps1`(`-CheckOnly` 설치 점검, `-Install` adb 설치·실행). iOS 빌드는 Mac에서만: `bash tools/build_ios.sh`(`--check`, `--team <ID>`, `--open` Xcode). 설치·실행 방법·기기 확인 목록은 `docs/mobile_build.md`. 안드로이드에 필요한 프로젝트 설정(세로·뒤로 가기는 일시정지·ETC2/ASTC)은 `test_android_export.gd`가 지킨다. 서명 비밀번호는 `export_credentials.cfg`(git 제외)에만.
- CI: `.github/workflows/tests.yml` (Linux 헤드리스 단위 테스트).
- **웹 빌드·배포**: 프리셋 `Web`(단일 스레드 `variant/thread_support=false` — GitHub Pages는 COOP/COEP 헤더를 못 붙인다, `tests/`·`tools/`·`docs/` 제외, `build/web/index.html`). `main`에 push하면 `.github/workflows/pages.yml`이 Godot·웹 템플릿을 받아 내보내고 GitHub Pages에 올린다 (저장소 Settings → Pages → Source = GitHub Actions 한 번). 로컬: `godot --headless --path . --export-release "Web" build/web/index.html` 뒤 `build/web`을 HTTP로 띄워 연다(파일 직접 열기는 안 됨). 웹에는 시스템 폰트 폴백이 없어 UI 폰트(`assets/fonts/Pretendard-SemiBold.otf`)에 없는 글자는 네모로 보인다 — 지금 없는 글자는 제우스 상태 줄의 ⚡ 하나.
- **스모크를 Linux에서**: `xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/smoke/<스크립트> -- <모드>` (run_smoke.ps1과 같은 인자).
