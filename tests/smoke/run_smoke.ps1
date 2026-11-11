# Runs every smoke test in a real (rendering) window and prints a summary.
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File tests/smoke/run_smoke.ps1
#   powershell -ExecutionPolicy Bypass -File tests/smoke/run_smoke.ps1 -Godot "C:\path\to\Godot_console.exe"
# Godot binary lookup order: -Godot argument > GODOT_BIN environment variable > default path below.
# Each smoke script redirects the game to its own save file and fails if the user save file changes.
# Exit code: 0 = all passed, 1 = at least one failed.

param(
    [string]$Godot = "",
    [string]$Only = ""
)

$DefaultGodot = "C:\Users\JP\Desktop\Godot\Godot_v4.7.2-stable_win64_console.exe"
if ($Godot -eq "") { $Godot = $env:GODOT_BIN }
if ([string]::IsNullOrEmpty($Godot)) { $Godot = $DefaultGodot }
if (-not (Test-Path $Godot)) {
    "Godot binary not found: $Godot"
    "Pass -Godot <path> or set the GODOT_BIN environment variable."
    exit 2
}
"Using Godot: $Godot"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$runs = @(
    @{ Script = "smoke_flow.gd"; Args = @("result") },
    @{ Script = "smoke_flow.gd"; Args = @("abandon") },
    @{ Script = "smoke_input.gd"; Args = @("dpad") },
    @{ Script = "smoke_input.gd"; Args = @("swipe") },
    @{ Script = "smoke_swipe_soak.gd"; Args = @("run") },
    @{ Script = "smoke_debug.gd"; Args = @("replay") },
    @{ Script = "smoke_debug.gd"; Args = @("unlock") },
    @{ Script = "smoke_debug.gd"; Args = @("short") },
    @{ Script = "smoke_feedback.gd"; Args = @("run") },
    @{ Script = "smoke_feedback.gd"; Args = @("audio") },
    @{ Script = "smoke_anim.gd"; Args = @("match") },
    @{ Script = "smoke_anim.gd"; Args = @("pop") },
    @{ Script = "smoke_anim.gd"; Args = @("stamp") },
    @{ Script = "smoke_anim.gd"; Args = @("wall") },
    @{ Script = "smoke_anim.gd"; Args = @("reduce") },
    @{ Script = "smoke_characters.gd"; Args = @("select") },
    @{ Script = "smoke_characters.gd"; Args = @("basic") },
    @{ Script = "smoke_characters.gd"; Args = @("gardener") },
    @{ Script = "smoke_characters.gd"; Args = @("clock") },
    @{ Script = "smoke_characters.gd"; Args = @("gambler") },
    @{ Script = "smoke_characters.gd"; Args = @("fever") },
    @{ Script = "smoke_characters.gd"; Args = @("joker") },
    @{ Script = "smoke_characters.gd"; Args = @("painter") },
    @{ Script = "smoke_characters.gd"; Args = @("twins") },
    @{ Script = "smoke_characters.gd"; Args = @("artisan") },
    @{ Script = "smoke_characters.gd"; Args = @("wall") },
    @{ Script = "smoke_characters.gd"; Args = @("marathon") },
    @{ Script = "smoke_characters.gd"; Args = @("bounty") },
    @{ Script = "smoke_characters.gd"; Args = @("navigator") },
    @{ Script = "smoke_characters.gd"; Args = @("explorer") },
    @{ Script = "smoke_characters.gd"; Args = @("bomber") },
    @{ Script = "smoke_characters.gd"; Args = @("poseidon") },
    @{ Script = "smoke_characters.gd"; Args = @("colorblind") },
    @{ Script = "smoke_characters.gd"; Args = @("retro") },
    @{ Script = "smoke_characters.gd"; Args = @("architect") },
    @{ Script = "smoke_characters.gd"; Args = @("wanderer") },
    @{ Script = "smoke_characters.gd"; Args = @("runner") },
    @{ Script = "smoke_characters.gd"; Args = @("mirror") },
    @{ Script = "smoke_characters.gd"; Args = @("seer") },
    @{ Script = "smoke_characters.gd"; Args = @("sewer") },
    @{ Script = "smoke_characters.gd"; Args = @("vampire") },
    @{ Script = "smoke_characters.gd"; Args = @("zeus") },
    @{ Script = "smoke_characters.gd"; Args = @("photo") },
    @{ Script = "smoke_characters.gd"; Args = @("arson") },
    @{ Script = "smoke_characters.gd"; Args = @("madan") },
    @{ Script = "smoke_characters.gd"; Args = @("racer") },
    @{ Script = "smoke_characters.gd"; Args = @("pachy") },
    @{ Script = "smoke_characters.gd"; Args = @("ambi") },
    @{ Script = "smoke_progress.gd"; Args = @("stage") },
    @{ Script = "smoke_progress.gd"; Args = @("revive") },
    @{ Script = "smoke_progress.gd"; Args = @("decline") },
    @{ Script = "smoke_progress.gd"; Args = @("timeout") },
    @{ Script = "smoke_progress.gd"; Args = @("claim") },
    @{ Script = "smoke_shop.gd"; Args = @("trial_back") },
    @{ Script = "smoke_scroll.gd"; Args = @("level") },
    @{ Script = "smoke_scroll.gd"; Args = @("characters") },
    @{ Script = "smoke_scroll.gd"; Args = @("flick") },
    @{ Script = "smoke_scroll.gd"; Args = @("shop") },
    @{ Script = "smoke_scroll.gd"; Args = @("puzzle") },
    @{ Script = "smoke_scroll.gd"; Args = @("options") },
    @{ Script = "smoke_scroll.gd"; Args = @("achievements") },
    @{ Script = "smoke_scroll.gd"; Args = @("tap") },
    @{ Script = "smoke_scroll.gd"; Args = @("pause_swipe") },
    @{ Script = "smoke_scroll.gd"; Args = @("pause_tap") },
    @{ Script = "smoke_progress.gd"; Args = @("debug") },
    @{ Script = "smoke_menu.gd"; Args = @("intro") },
    @{ Script = "smoke_menu.gd"; Args = @("swipe") },
    @{ Script = "smoke_menu.gd"; Args = @("tap") },
    @{ Script = "smoke_menu.gd"; Args = @("sheet") },
    @{ Script = "smoke_menu.gd"; Args = @("trial_quit") },
    @{ Script = "smoke_shop.gd"; Args = @("gacha") },
    @{ Script = "smoke_shop.gd"; Args = @("store") },
    @{ Script = "smoke_shop.gd"; Args = @("reduce") },
    @{ Script = "smoke_achievements.gd"; Args = @("result") },
    @{ Script = "smoke_achievements.gd"; Args = @("sheet") },
    @{ Script = "smoke_achievements.gd"; Args = @("trial") },
    @{ Script = "smoke_puzzle.gd"; Args = @("menu") },
    @{ Script = "smoke_puzzle.gd"; Args = @("board") },
    @{ Script = "smoke_tutorial.gd"; Args = @("rule") },
    @{ Script = "smoke_tutorial.gd"; Args = @("skip") },
    @{ Script = "smoke_tutorial.gd"; Args = @("flow") },
    @{ Script = "smoke_lesson.gd"; Args = @("first") },
    @{ Script = "smoke_lesson.gd"; Args = @("wall") },
    @{ Script = "smoke_lesson.gd"; Args = @("offer") },
    @{ Script = "smoke_lesson.gd"; Args = @("accept") },
    @{ Script = "smoke_lesson.gd"; Args = @("redo") },
    @{ Script = "smoke_first_view.gd"; Args = @("multi") },
    @{ Script = "smoke_first_view.gd"; Args = @("result") },
    @{ Script = "smoke_first_view.gd"; Args = @("screens") },
    @{ Script = "smoke_art.gd"; Args = @("all") },
    @{ Script = "smoke_fps.gd"; Args = @("run"); Extra = @("--max-fps", "30") },
    @{ Script = "smoke_fps.gd"; Args = @("run"); Extra = @("--max-fps", "60") },
    @{ Script = "smoke_fps.gd"; Args = @("run"); Extra = @("--max-fps", "120") },
    @{ Script = "smoke_fps.gd"; Args = @("hitch") },
    @{ Script = "smoke_save_restart.gd"; Args = @("write"); Extra = @("--headless") },
    @{ Script = "smoke_save_restart.gd"; Args = @("read"); Extra = @("--headless") }
)
foreach ($res in @("405x720", "360x780", "540x1200", "600x800")) {
    foreach ($m in @("plain", "notch")) {
        $runs += @{ Script = "smoke_layout.gd"; Args = @($m); Extra = @("--resolution", $res) }
    }
}

$failed = 0
$count = 0
foreach ($run in $runs) {
    if ($Only -ne "" -and $run.Script -notlike "*$Only*") { continue }
    $count++
    $extra = @()
    if ($run.ContainsKey("Extra")) { $extra = $run.Extra }
    $godotArgs = @("--path", $root) + $extra + @("-s", "tests/smoke/$($run.Script)", "--") + $run.Args
    $output = & $Godot @godotArgs 2>&1
    $code = $LASTEXITCODE
    foreach ($line in $output) {
        $text = "$line"
        if ($text -match "SMOKE\[" -or $text -match "FAIL" -or $text -match "SCRIPT ERROR") { $text }
    }
    if ($code -ne 0) {
        $failed++
        "  -> exit code $code ($($run.Script) $($run.Args -join ' ') $($extra -join ' '))"
    }
}

""
"$count smoke runs, $($count - $failed) passed, $failed failed"
if ($failed -gt 0) { exit 1 } else { exit 0 }
