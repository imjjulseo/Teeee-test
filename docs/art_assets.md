# 디자인 이미지 넣기

모든 이미지 자리는 **비어 있으면 지금 그림(색·도형·글자)을 그대로 쓴다.** 이미지를 넣으면 그 자리만 바뀐다 (코드 수정 없음).
형식은 **PNG가 기본**(한 장 이미지, 투명 배경 가능). 애니메이션 시트는 아직 받지 않는다.
크기는 기준 해상도 **1080×1920**에서 1:1이다 (E31).

## 0. 공통 순서

1. 이미지 파일을 `assets/` 아래 종류별 폴더에 넣는다 (예: `assets/blocks/`, `assets/characters/`, `assets/effects/`, `assets/ui/`).
   Godot 에디터가 자동으로 가져온다 (`.import` 파일은 에디터가 만든다 — 직접 만들거나 고치지 않는다).
2. 아래 표의 **리소스 파일**을 에디터 파일시스템에서 더블클릭해 인스펙터를 연다.
3. 해당 칸에 이미지를 파일시스템에서 끌어다 놓는다 → 저장(Ctrl+S).
4. 게임을 실행해 확인한다.

## 1. 판 · 연출 — `resources/board_theme.tres` 의 **Art** 그룹

| 칸 | 넣을 이미지 | 크기 권장 | 쓰이는 곳 |
|---|---|---|---|
| `block_textures` | 블록 4장 (**문양까지 그린 완성 이미지**). 배열 순서 = 색 ID: **0 노랑 · 1 빨강 · 2 파랑 · 3 초록** | 정사각형 105px (판 칸 크기) | 판 칸, 족보 카드의 색 점 (캐릭터 카드 포함) |
| `seed_texture` | 씨앗(깨진 자리에서 자라는 칸) | 정사각형 | 가운데서 자람 진행도만큼 커진다 |
| `coin_texture` | 금화 | 정사각형 (칸 오른쪽 위 약 1/3 크기로 보임) | 금화가 붙은 블록 |
| `player_texture` | 기본 플레이어 | 정사각형 | 캐릭터 이미지가 없는 캐릭터의 판 위 모습 |
| `mark_textures` | 판 위 표시: "키 추가"로 종류 번호 → 이미지 | 칸 크기 비율 (구역은 3×3칸) | 아래 번호표 |
| `ability_flash_texture` | 능력 발동 섬광 (화면 전체) | 세로 화면 비율 | 캐릭터 색으로 물들어 잠깐 보였다 사라진다 |
| `effect_background_texture` | 능력 지속 효과 배경 (판 뒤 화면 전체) | 세로 화면 비율, 흰색 계열 | 효과 색으로 물들어 은은하게·끝날 때 깜빡임 |
| `chest_closed_texture` / `chest_open_texture` | 뽑기 상자 닫힘 / 열림 | 360×330 | 상점 뽑기. 열리는 순간 열림 이미지로 바뀐다 (뒤 빛은 그대로) |

`mark_textures` 종류 번호 (BoardMark.Kind):
`0` 깃발(갈 곳) · `1` 깃발(준비됨) · `2` 다음 깃발 · `3` 탐험 구역(3×3) · `5` 불 번짐 예고 ·
`6` 퍼즐 모을 블록 · `7` 목표 가운데 · `8` 목표 빈 자리 · `9` 목표 채운 자리 · `10` 먼저 설 칸 · `11` 당길 블록 ·
`12` 화살표(**오른쪽을 향한 이미지** — 방향에 맞춰 돌린다). `4`(수선사·사진사의 길)는 선이라 이미지를 쓰지 않는다.

**블록 이미지와 능력**: 이미지에 색이 칠해져 있으므로, 능력이 블록 색을 바꾸는 동안(색약 "뒤섞임", 뱀파이어 "피의 시간",
레트로 "흑백")에는 **모든 블록이 원래 그림(색 + 문양)으로** 그려지고 효과가 끝나면 이미지로 돌아온다.
(능력별 이미지가 필요하면 따로 자리를 만든다.)

## 2. 캐릭터 — `resources/characters/<id>.tres` 의 `portrait`

캐릭터마다 한 장 (정사각형 권장). 판 위 플레이어, 게임 화면 캐릭터 줄 아이콘, 아래 줄 블록, 메인 시작 칸, 캐릭터 정보, 뽑기 결과 카드, 상점 카드에 쓰인다 (블록 그림은 `CharacterBlockView` 하나).
이미지가 있으면 채움색 대신 이미지, 테두리(등급 색 등)는 그대로. 얻기 전 히든 캐릭터는 계속 가려진다.
id는 기획서 5.2장 표 (`clock` = 시계공 등).

## 3. 화면 공통 — `resources/ui_assets.tres`

| 칸 | 쓰이는 곳 |
|---|---|
| `logo` | 인트로 로고 (900×390 영역, 비율 유지) |
| `coin_icon` / `diamond_icon` | 위 줄 지갑, 게임 HUD의 코인 — "●" "◆" 글자 대신 (글자 크기 정사각형) |
| `shop_icon` · `achievements_icon` · `puzzle_icon` · `options_icon` | 아래 줄 버튼 그림, "상점" 등 글자 대신 (약 170×170) |
| `swipe_hint` | 메인의 밀어서 시작 안내 (가로로 넓게, 96 높이) |
| `back_icon` | 레벨 화면 뒤로가기 (180×132) |
| `left_arrow` · `right_arrow` | 캐릭터 화면 좌우 화살표 (66×180) |
| `lock_icon` | 잠긴 퍼즐 카드 자물쇠, "잠김" 글자 대신 (180×180) |
| `star_on` · `star_off` | 퍼즐 카드 별점, ★ ☆ 대신 (66×66, 둘 다 넣어야 바뀐다) |

씬에서는 `UiImage` 노드가 `slot` 이름으로 이 칸을 읽고, 이미지가 있으면 글자(`fallback`)를 숨긴다. 새 자리는 `UiAssets`에 칸 하나 + 씬에 `UiImage` 하나로 늘린다.

버튼·설명 문장 안의 ● ◆ (예: "열기 · ● 500", 결과의 "● +12")는 글자 그대로다.

## 4. 판넬 · 버튼 모양 — `resources/ui_theme_spec.tres` 의 styles

1. `styles` 목록에서 바꿀 모양을 연다 (이름: `CaptionPanel` 설명 상자, `CardPanel` 결과 카드, `SheetPanel` 캐릭터 시트,
   `BannerPanel` 능력 배너, `RevealCardPanel` 뽑기 결과 카드, `AchievementRowPanel` 목록 줄,
   `BarPanel` 퍼즐 막대, `CharacterRowPanel` · `CharacterIconPanel` 게임 화면 캐릭터 줄·아이콘,
   `TopBarPanel` · `BottomNavPanel` 위·아래 줄, `NavButton` · `NavButtonActive` 아래 줄 버튼(평소·지금 화면), `NotifyDot` 빨간 점, `BoostCellPanel` 경험치 2배 칸, `StartSlotPanel` 메인 시작 칸,
   `ShopCardPanel` 상점 카드, `RewardPreviewPanel` 업적 보상 미리보기, `LevelNodeButton` · `LevelBigNodeButton` 레벨 칸(보통·선택권), `LevelHudPanel` 레벨 아래 막대, `PuzzleCardButton` 퍼즐 카드,
   `Button` 기본 버튼, `HotButton` 주 행동, `AccentButton` 설명 칸, `PillButton` 알약, `SoftButton` · `GhostButton` · `WarnButton`,
   `ChipButton` · `ChoiceButton` · `TabButton` 선택된 버튼, `VolumeSlider` 볼륨 막대 …).
2. `texture`에 판넬 이미지, `texture_margins`에 **늘어나지 않는 가장자리 폭**(왼쪽·위·오른쪽·아래 px, 9분할)을 넣는다.
3. 테마를 다시 만든다:
   `godot --headless --path . -s tools/build_ui_theme.gd`
   (`resources/ui_theme.tres`는 이 도구가 만드는 파일이라 직접 고치지 않는다.)

이미지 판넬이 되면 그 모양의 토큰 색은 쓰지 않는다. 배너·뽑기 결과 카드·레벨 줄의 테두리 색(캐릭터·등급·상태 색)도 단색 모양일 때만 바뀐다.

## 5. 이미 있던 자리 (코드 수정 없음)

| 에셋 | 넣는 곳 |
|---|---|
| 효과음 | `scenes/sfx_player.tscn` → `sounds`에 ID별 오디오 |
| 폰트 | `resources/ui_theme_spec.tres`의 Default Font → 테마 다시 만들기 (`assets/fonts/README.md`) |
| 화면 색 | `resources/design_tokens.tres` → 테마 다시 만들기 |
| 앱 아이콘 | `icon.svg` 교체, 또는 `export_presets.cfg`(에디터 프로젝트 → 내보내기)의 Android·iOS 아이콘 칸 |

매치 파편은 지금 이미지 자리가 없다: `BurstEffect`가 HTML 파편을 코드로 그린다 (E32).

## 확인

`powershell -ExecutionPolicy Bypass -File tests/smoke/run_smoke.ps1 -Only smoke_art` — 모든 자리에 임시 이미지를 넣어
화면마다 찍는다 (`user://smoke_shots/smoke_art_*.png`). 실제 이미지를 넣은 뒤 전체 스모크로 배치가 깨지지 않는지 본다.
