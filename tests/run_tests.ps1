# Runs the headless unit tests (tests/run_tests.gd) after refreshing the global class cache.
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1
#   powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1 -Godot "C:\path\to\Godot_console.exe"
# Godot binary lookup order: -Godot argument > GODOT_BIN environment variable > default path below.
# Exit code: 0 = all passed, 1 = at least one failed, 2 = Godot not found.

param(
    [string]$Godot = ""
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

$root = Split-Path -Parent $PSScriptRoot
& $Godot --headless --path $root --import 2>&1 | Out-Null
& $Godot --headless --path $root -s tests/run_tests.gd 2>&1 | ForEach-Object { "$_" }
exit $LASTEXITCODE
