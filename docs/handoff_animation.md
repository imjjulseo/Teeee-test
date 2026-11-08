# 다음 작업 인계: 애니메이션 (HTML 연출 이식)

새 대화창에서 이 파일 하나만 읽으면 이어서 작업할 수 있게 정리했다. 맨 아래 **붙여 넣을 프롬프트**를 그대로 쓰면 된다.

## 1. 지금까지 끝난 것 (2026-11-08 기준, `main`)

- Godot 4.7.2 프로젝트 "Swap match" — HTML 프로토타입(`docs/reference/swap_match_html_1106.html`, 팀 11/06 판)을 옮기는 중. 규칙·구조는 `CLAUDE.md`, 기획은 `docs/game_design.md`.
- 9단계까지 완료: 메뉴 > 퍼즐(11판), 튜토리얼 레벨제 없앰, 규칙 튜토리얼 = HTML `runRuleTut` 그대로(E29: 고정 시드 8907, 5×5 스탬프, 배운 모양 힌트), 화면 디자인 HTML 따르기(E30: 버튼·설명 칸·족보 카드·스포트라이트·블럭 빛남·버튼 노란 고리), **기준 해상도 1080×1920**(E31: 모든 픽셀 값 1.5배, 디자인 이미지는 1080 기준 1:1).
- 웹 배포: `main`에 push하면 `.github/workflows/pages.yml`이 GitHub Pages에 올린다 (저장소 Settings → Pages → Source = GitHub Actions가 켜져 있어야 함).
- 사용자(팀)의 결정: **UI·기본 디자인을 다듬은 뒤 애니메이션** — 이제 애니메이션 차례.

## 2. 작업 환경 (클라우드 세션은 매번 새로 받아야 함)

```bash
# Godot (Linux) — 스크래치 폴더에
curl -fsSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -q godot.zip && export GODOT_BIN=$PWD/Godot_v4.7.2-stable_linux.x86_64
# 웹 빌드를 로컬에서 확인하려면 템플릿 중 web_* 만
curl -fsSL -o t.tpz https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.7.2.stable && unzip -qj t.tpz 'templates/web_*' 'templates/version.txt' -d ~/.local/share/godot/export_templates/4.7.2.stable
```

- 클래스 캐시: `$GODOT_BIN --headless --path . --import`
- 단위 테스트(463개): `$GODOT_BIN --headless --path . -s tests/run_tests.gd`
- 실제 창 스모크(81개, Xvfb): `GODOT_BIN=... tools/run_smoke.sh [필터]` — 스크린샷은 `~/.local/share/godot/app_userdata/Moving_Puzzle/smoke_shots/`
- 테마를 바꾸면: `$GODOT_BIN --headless --path . -s tools/build_ui_theme.gd`
- HTML 화면 비교: Playwright(사전 설치)로 `docs/reference/swap_match_html_1106.html`을 405×720으로 열어 찍는다. 인트로는 화면 탭, 메뉴 `#mStart`, 튜토리얼은 새 저장에서 자동. 게임 전역 함수(`tut`, `slots`, `tutFinish()` 등)를 `page.evaluate`로 부를 수 있다. Godot 스모크와 같은 405×720 창이라 나란히 비교된다.

## 3. 애니메이션 목록 (HTML → Godot, 우선순위 순)

HTML 위치는 `docs/reference/swap_match_html_1106.html`의 줄 번호(대략). HTML CSS px는 폰 폭 405 기준이라 Godot 1080 기준으로는 × 2.67. 판 안 크기는 칸 크기 비율로 옮긴다.

### A. 판 기본 손맛 (가장 먼저)
| HTML | 무엇 | Godot에 붙일 곳 |
|---|---|---|
| `@keyframes pop`(125), `retrigger(b.el,'pop')` | 블럭 색이 바뀌거나(능력·힌트 보정) 생길 때 밝게 번쩍 → 원래 색 | `BoardView._refresh_with_pop` / `CellView` |
| `@keyframes grown`(736) + 다 자랄 때 | 씨앗이 다 자라는 순간 초록 고리 + 밝아짐 → 사라짐 ("블록이 톡 튀어나옴", 기획 7.2) | `BoardView._on_cells_refilled` |
| `flipIn`(퍼즐 깔기, `pzStamp`) | 퍼즐을 깔 때 내 칸에서 가까운 칸부터 0.2→1 크기로 튀어나옴 (280ms, 칸마다 55ms 지연) | `TutorialDirector.start_rule_puzzle` 뒤 → `BoardChannel`에 새 signal(예: `cells_stamped(cells, origin)`) |
| `boardSwap`(2950) | 판 전체가 바뀔 때 위로 빠지고(220ms) 아래에서 올라옴(280ms) | `notify_board_rearranged` / `board_created` |
| `@keyframes dotHit`(63) | 족보 칸이 채워질 때 그 점이 1.7배·밝게 → 원래 | `RecipeView.show_recipe` (진행된 칸만) |
| `cardBreak`(51)·`cardOut`(54)·`cardIn`(49) | 족보 완성: 커지며 밝아짐 → 아래로 빠짐 → 새 카드가 위에서 내려옴 | `RecipeView.play_complete` (지금은 커졌다 돌아오기만) |
| `@keyframes bump`(27) | 점수·시간 숫자가 바뀔 때 1.22배 → 원래 | `Hud._on_score_changed`, 시간 얻을 때 |
| `@keyframes fly`(205) | 금화 "+10"이 판에서 HUD 코인으로 날아감 | `Hud._on_coins_updated` + `FloatingText` |
| `@keyframes rise`(202) | 떠오르는 숫자(+2.5초 등) — 지금 `FloatingText.rise`가 비슷, HTML 곡선에 맞추기 | `FloatingText` |
| `tutCheer` (Good/Great!/Awesome! 떠오르기 + 파편) | 튜토리얼 칭찬 — 지금은 메시지 줄. 플레이어 위로 떠오르게 | `TutorialDirector.cheer` → Hud 떠오르는 글자 |
| `@keyframes shake`/`shakeBig`(101) | 매치·벽 흔들림 — 이미 있음, HTML 진폭·곡선과 비교 | `BoardView._shake_board` |

### B. 튜토리얼·UI
| `capIn`(930) | 설명 칸이 10px 아래에서 올라오며 나타남 (400ms) | `SpotlightOverlay.open` |
| `tnudge`(925) | 판 멈춘 상태에서 손대면 고리가 살짝 커짐 | `SpotlightOverlay` |
| `ovgIn`(440) | 결과·일시정지 카드 등장 (0.85 → 1) | `ResultPanel`, `PauseOverlay`, `PuzzleResultPanel` |
| `gcIn`(723), `mPop`(823), `miniUp`(812), `freshB`(837) | 뽑기 결과 카드·보드 업그레이드 연출·새 족보 칸 빛남 | `GachaReveal`, 결과 화면 미니 판, `Hud` |
| `glow`(957) | 이미 `GlowRing`으로 옮김 | — |
| `lockGlint`(597), `chestBob`(595), `chestShake`(600), `rays`(604) | 상자 반짝·흔들림·빛줄기 — 일부 있음 | `GachaChest` |

### C. 캐릭터 능력 연출 (마지막)
`chrBurst`(93, 캐릭터 카드 발동), `ctPulse`(877), `bloodPulse`(491, 뱀파이어), `emberWarn`(872)·`flicker`(870, 방화광), `thread`(518)·`stitchP`(523, 수선사), `wpPulse`(512, 마라토너 깃발), `dvPulse`(478), `slam`(197, 배너), `zoneIn`(732, 탐험가 구역), `mslIn`(817), `sheen`(72, 캐릭터 카드 광택), `breathe`·`bob`(343).

## 4. 지켜야 할 것 (CLAUDE.md 요약)

- **로직은 연출을 기다리지 않는다** (E4). 애니메이션은 View(채널 signal을 받는 쪽)에만. 새 이벤트가 필요하면 채널에 signal을 추가하고 `.tscn`에 연결 (`tests/test_channels.gd`가 검사).
- 수치(시간·크기·색)는 `BoardTheme`(판·연출) 또는 디자인 토큰. 코드 상수 금지.
- **효과 줄이기**(`reduce_motion`)가 켜지면 큰 움직임(흔들림·튀어나옴·날아감)을 끈다 — 새 연출도 모두 따를 것.
- 기준 해상도 1080×1920. 판 안 연출은 칸 크기(`BoardTheme.cell_size` = 105) 비율로.
- 튜토리얼·퍼즐 스모크는 타이밍에 민감: 새 연출이 입력을 막거나 지연시키면 `tools/run_smoke.sh smoke_tutorial`, `smoke_puzzle`로 확인.
- 커밋 메시지 끝에 Co-Authored-By 등 세션 지침을 따른다. 기획 7.2장·별첨 A(새 결정 번호 E32~)·별첨 C도 함께 고친다.

## 5. 붙여 넣을 프롬프트

```
imjjulseo/Teeee-test 레포(Godot 4.7.2, Swap match)에서 이어서 작업하자.
먼저 docs/handoff_animation.md 와 CLAUDE.md 를 읽어. 지난 대화에서 UI·디자인을 HTML(docs/reference/swap_match_html_1106.html)에 맞췄고
기준 해상도를 1080×1920으로 바꿨어. 이번엔 애니메이션 작업이야.
handoff 문서 3장 목록의 A(판 기본 손맛)부터 HTML 연출과 똑같은 느낌으로 옮겨 줘.
HTML을 Playwright로 같은 장면을 찍어 Godot 스모크 스크린샷과 나란히 비교하면서 맞추고,
효과 줄이기 설정에서는 꺼지게 해. 단위 테스트·스모크 전부 통과시키고 main에 push한 뒤 보고해.
A가 끝나면 B, C 순서로 진행할지 물어봐.
```
