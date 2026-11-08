#!/bin/bash
# Linux용 스모크 실행기 (tests/smoke/run_smoke.ps1과 같은 목록, Xvfb + opengl3).
# 사용: GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/run_smoke.sh [이름 필터]
set -u
G="${GODOT_BIN:?GODOT_BIN을 Godot 실행 파일 경로로 지정하세요}"
cd "$(dirname "$0")/.."
runs=$(python3 - <<'PY'
import re
s=open('tests/smoke/run_smoke.ps1',encoding='utf8').read()
for m in re.finditer(r'@\{ Script = "(\S+)"; Args = @\("([^"]+)"\)(?:; Extra = @\(([^)]*)\))? \}',s):
    extra=' '.join(x.strip().strip('"') for x in (m.group(3) or '').split(',') if x.strip())
    print(f'{m.group(1)}|{m.group(2)}|{extra}')
for res in ["405x720","360x780","540x1200","600x800"]:
    for mm in ["plain","notch"]:
        print(f'smoke_layout.gd|{mm}|--resolution {res}')
PY
)
fail=0; n=0
while IFS='|' read -r script arg extra; do
  [[ -n "${1:-}" && "$script" != *"$1"* ]] && continue
  n=$((n+1))
  out=$(timeout 300 xvfb-run -a -s "-screen 0 1400x1400x24" "$G" --path . --rendering-driver opengl3 $extra -s tests/smoke/$script -- $arg 2>&1)
  line=$(echo "$out" | grep "^SMOKE\[" | tail -1)
  if [[ "$line" != *PASS* ]]; then fail=$((fail+1)); echo "FAILED $script $arg $extra"; echo "$out" | grep -E "FAIL|SCRIPT ERROR|^SMOKE" | head -15; else echo "$line"; fi
done <<< "$runs"
echo "smoke: $n runs, $fail failed"
[[ $fail -eq 0 ]]
