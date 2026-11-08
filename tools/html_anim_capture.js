// HTML 프로토타입(docs/reference/swap_match_html_1106.html)의 판 연출을 시각별로 찍는다 (애니메이션 이식 비교용, E32).
// Godot 쪽은 tests/smoke/smoke_anim.gd가 같은 장면을 같은 시각(ms)에 찍는다 → tools/anim_compare.py로 나란히 붙인다.
//
// 사용: node tools/html_anim_capture.js <장면> <저장 폴더>
//   장면: match (매치 + 족보 완성 + 금화) · pop (블록 번쩍임) · stamp (퍼즐 깔기) · wall (벽 튕김)
//
// 방법: 가짜 시계(page.clock)로 타이머·rAF(파편)를 멈춰 두고, 모든 CSS·Web Animations를 멈춘 뒤 각 애니메이션이 생긴 시각부터
// 잰 시간으로 직접 넘긴다. 그래서 스크린샷이 느려도 정확히 그 시각의 장면이 찍힌다. 창은 405×720 (Godot 스모크 창과 같음).
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const FRAMES = [0, 30, 60, 90, 120, 160, 200, 260, 320, 400, 500, 650, 800];
const STEP = 5; // ms: 새로 생긴 애니메이션의 시작 시각을 이 단위로 잡는다

const SCENES = {
  // 플레이어 위 칸을 가운데로 십자를 빨강(1)으로 칠하고, 족보 0을 [빨강, 빨강] 진행 1로(완성), 족보 1을 [빨강, 노랑, 파랑](진행),
  // 십자 왼쪽 칸에 금화를 붙인 뒤 위로 한 칸.
  match: {
    setup: () => {
      const col = 1, pr = player.r, pc = player.c;
      for (const [r, c] of [[pr - 1, pc], [pr - 2, pc], [pr - 1, pc - 1], [pr - 1, pc + 1]]) {
        const b = blkAt(r, c); b.color = col; b.el.dataset.c = col; b.el.classList.remove('seedling');
      }
      const coin = blkAt(pr - 1, pc - 1);
      coin.coinUntil = gclock + 15; const ce = document.createElement('div'); ce.className = 'coin'; coin.el.appendChild(ce);
      slots[0] = { seq: [col, col], p: 1, b: 0, d: difficulty([col, col]), pts: recipePts([col, col]) };
      slots[1] = { seq: [col, 0, 2], p: 0, b: 0, d: difficulty([col, 0, 2]), pts: recipePts([col, 0, 2]) };
      syncCards();
    },
    trigger: () => doStep(-1, 0),
  },
  // 플레이어 오른쪽 세 칸이 번쩍 (씨앗이 다 자랄 때 HTML mature → retrigger pop).
  pop: {
    setup: () => {},
    trigger: () => {
      for (let k = 1; k <= 3; k++) { const b = blkAt(player.r, player.c + k); if (b) retrigger(b.el, 'pop'); }
    },
  },
  // 첫 튜토리얼 퍼즐 모양(0a)을 내 주변 5×5에 깐다 (HTML pzStamp → flipIn).
  stamp: {
    setup: () => {},
    trigger: () => { pzStamp(PZ_LV[0].boards[0], 1); },
  },
  // 왼쪽 벽으로 밀었을 때 튕김 (HTML nudge).
  wall: {
    setup: () => {},
    trigger: () => nudge(0, -1),
  },
};

(async () => {
  const scene = process.argv[2] || 'match';
  const out = process.argv[3] || 'html_shots';
  if (!SCENES[scene]) throw new Error('unknown scene ' + scene);
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 405, height: 720 }, deviceScaleFactor: 1 });
  // 튜토리얼을 끝낸 저장 (Lv5: 본 게임 보드 4색·족보 3장), 스와이프, 효과 켬.
  await page.addInitScript(() => {
    localStorage.setItem('swapmatch.meta.v4', JSON.stringify({ lv: 5, gt: 3, ach: { tut: true }, bupSeen: 3,
      seen: { _ach: true, _ach2: true, _pz: true, _coin: true, _xp: true, _multi: true, _multi2: true, _dual2: true, _pts2: true, _dup: true, _lv: true, _chr: true } }));
    localStorage.setItem('swapmatch.settings', JSON.stringify({ input: 'swipe', sound: false, reduce: false }));
  });
  await page.clock.install();
  await page.goto('file://' + path.resolve(__dirname, '../docs/reference/swap_match_html_1106.html'));
  await page.clock.runFor(300);
  await page.evaluate(() => startGame());
  await page.clock.runFor(500);
  await page.waitForTimeout(600); // 카드 등장(CSS, 실제 시간)이 끝나게
  // 여기부터는 가짜 시계를 멈춰 runFor로만 흐르게 한다 (실제 시간·스크린샷 시간이 섞이지 않게).
  const now = await page.evaluate(() => Date.now());
  await page.clock.pauseAt(now + 50);
  await page.evaluate(SCENES[scene].setup);
  await page.clock.runFor(100);
  await page.waitForTimeout(600);
  await page.evaluate(() => { spotClear && spotClear(); });
  // 기준 시각 0: 지금 있는 애니메이션은 모두 끝난 것으로 둔다.
  await page.evaluate(() => {
    window.__born = new Map();
    for (const a of document.getAnimations()) a.finish();
  });
  await page.evaluate(`(${SCENES[scene].trigger})(); window.__t0 = performance.now();`);
  const sync = () => page.evaluate(() => {
    const now = performance.now();
    for (const a of document.getAnimations()) {
      if (!window.__born.has(a)) window.__born.set(a, now);
      a.pause();
      a.currentTime = Math.max(0, now - window.__born.get(a));
    }
    return now - window.__t0;
  });
  await sync();
  let t = 0;
  for (const frame of FRAMES) {
    while (t < frame) { await page.clock.runFor(STEP); t += STEP; await sync(); }
    await page.screenshot({ path: path.join(out, `${scene}_${String(frame).padStart(3, '0')}.png`) });
  }
  await browser.close();
  console.log(`html ${scene}: ${FRAMES.length} frames → ${out}`);
})().catch((e) => { console.error(e); process.exit(1); });
