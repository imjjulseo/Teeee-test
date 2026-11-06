# Builds the Android debug APK from the "Android" export preset (export_presets.cfg).
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File tools/build_android.ps1
#   powershell -ExecutionPolicy Bypass -File tools/build_android.ps1 -Install        # also installs on a USB-connected phone (adb)
#   powershell -ExecutionPolicy Bypass -File tools/build_android.ps1 -CheckOnly      # only checks the setup
# Godot binary lookup order: -Godot argument > GODOT_BIN environment variable > default path below.
# Setup steps (export templates, Android SDK, JDK, editor settings): docs/mobile_build.md
# Exit code: 0 = built (and installed), 1 = setup missing or build failed.

param(
    [string]$Godot = "",
    [switch]$Install,
    [switch]$CheckOnly
)

$DefaultGodot = "C:\Users\JP\Desktop\Godot\Godot_v4.7.2-stable_win64_console.exe"
$TemplateVersion = "4.7.2.stable"
$Preset = "Android"
$Output = "build/android/swap_match.apk"
$Package = "com.swapmatch.game"

if ($Godot -eq "") { $Godot = $env:GODOT_BIN }
if ([string]::IsNullOrEmpty($Godot)) { $Godot = $DefaultGodot }
$root = Split-Path -Parent $PSScriptRoot
$problems = @()

function Get-EditorSetting([string]$key) {
    $file = Get-ChildItem "$env:APPDATA\Godot" -Filter "editor_settings-4*.tres" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if ($null -eq $file) { return "" }
    $line = Select-String -Path $file.FullName -Pattern "^$([regex]::Escape($key)) = `"(.*)`"" | Select-Object -First 1
    if ($null -eq $line) { return "" }
    return $line.Matches[0].Groups[1].Value.Replace("\\", "\")
}

"Checking Android export setup"
if (Test-Path $Godot) { "  ok   Godot: $Godot" } else { $problems += "Godot binary not found: $Godot (pass -Godot or set GODOT_BIN)" }

$templates = Join-Path $env:APPDATA "Godot\export_templates\$TemplateVersion"
if (Test-Path (Join-Path $templates "android_debug.apk")) { "  ok   export templates: $templates" }
else { $problems += "Android export templates missing: $templates (editor: Editor > Manage Export Templates > Download and Install)" }

$sdk = Get-EditorSetting "export/android/android_sdk_path"
if ($sdk -ne "" -and (Test-Path (Join-Path $sdk "platform-tools")) -and (Test-Path (Join-Path $sdk "build-tools"))) { "  ok   Android SDK: $sdk" }
else { $problems += "Android SDK (platform-tools + build-tools) not found at '$sdk' (install it, then Editor Settings > Export > Android > Android SDK Path)" }

$java = Get-EditorSetting "export/android/java_sdk_path"
if ($java -ne "" -and (Test-Path (Join-Path $java "bin\java.exe"))) { "  ok   JDK: $java" }
else { $problems += "JDK not set (install JDK 17, then Editor Settings > Export > Android > Java SDK Path): '$java'" }

$keystore = Get-EditorSetting "export/android/debug_keystore"
if ($keystore -ne "" -and (Test-Path $keystore)) { "  ok   debug keystore: $keystore" }
else { $problems += "Debug keystore missing: '$keystore' (the editor creates it when the JDK is set; or see docs/mobile_build.md)" }

if ($problems.Count -gt 0) {
    ""
    "Setup is not complete:"
    foreach ($p in $problems) { "  - $p" }
    "See docs/mobile_build.md"
    exit 1
}
if ($CheckOnly) { ""; "Setup OK"; exit 0 }

New-Item -ItemType Directory -Force (Join-Path $root "build/android") | Out-Null
""
"Exporting '$Preset' (debug) -> $Output"
& $Godot --headless --path $root --export-debug $Preset $Output
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $root $Output))) {
    "Export failed (exit code $LASTEXITCODE)"
    exit 1
}
"Built: $(Join-Path $root $Output)"

if ($Install) {
    $adb = Join-Path $sdk "platform-tools\adb.exe"
    & $adb install -r (Join-Path $root $Output)
    if ($LASTEXITCODE -ne 0) { "adb install failed (is USB debugging on and the phone authorized? 'adb devices')"; exit 1 }
    & $adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 | Out-Null
    "Installed and launched $Package"
}
exit 0
