# moving-puzzle

Swap match (가제) — Godot 4.7.2 퍼즐 게임. 규칙은 `docs/game_design.md`, 작업 규칙은 `CLAUDE.md`.

## 웹에서 하기 (GitHub Pages)

`main`에 push하면 `.github/workflows/pages.yml`이 웹 빌드를 만들어 GitHub Pages에 올린다.

- 주소: `https://<owner>.github.io/<repo>/` (Actions의 `deploy-web` 실행 결과에도 나온다)
- 처음 한 번만: 저장소 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 바꾼다.
- 수동 배포: Actions → `deploy-web` → Run workflow.

로컬에서 웹 빌드 확인:

```sh
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8000   # http://localhost:8000
```
