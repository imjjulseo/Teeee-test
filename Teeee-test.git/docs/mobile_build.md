# 모바일 빌드와 실행 (Android · iOS)

기획서 13장 7단계. 내보내기 프리셋 두 개(`export_presets.cfg`의 `Android`, `iOS`)와 빌드 스크립트가 준비되어 있다.
아래 설치를 한 번 마치면 스크립트 하나로 빌드하고 폰에서 실행할 수 있다.

| | Android | iOS |
|---|---|---|
| 빌드할 수 있는 PC | Windows · macOS · Linux | **macOS + Xcode만** (Apple 정책) |
| 빌드 스크립트 | `tools/build_android.ps1` (Windows PowerShell) | `tools/build_ios.sh` (Mac 터미널) |
| 결과 | `build/android/swap_match.apk` | `build/ios/swap_match.xcodeproj` (+ 서명되면 `.ipa`) |
| 앱 이름 / 식별자 | Swap match / `com.swapmatch.game` | Swap match / `com.swapmatch.game` |
| 버전 | 1.0 (코드 1) | 1.0 (빌드 1) |
| 아키텍처 | arm64-v8a | arm64 |
| 서명 | 디버그 키 | Apple 개발 인증서 (Team ID 필요) |
| 기기 | 폰·태블릿 | iPhone · iPad |
| 권한 | 없음 | 없음 |

공통: 세로 고정, 노치·펀치홀은 `SafeArea`가 피함, 텍스처 압축 ETC2/ASTC, `tests/`·`tools/`·`docs/`는 앱에 넣지 않음,
빌드 결과 폴더 `build/`는 git에서 제외. 디버그 빌드라 플레이 기록(`user://playtest_log.csv`)이 쌓인다.

---

## 1. Android

### 1-1. 설치 (한 번, Windows 기준)

1. **내보내기 템플릿**: Godot 에디터 → 편집기(Editor) → 내보내기 템플릿 관리 → 다운로드 및 설치.
   `%APPDATA%\Godot\export_templates\4.7.2.stable\android_debug.apk`가 생기면 된다 (iOS 템플릿도 같이 받아진다).
2. **JDK 17**: OpenJDK 17 (예: Eclipse Temurin 17) 설치.
3. **Android SDK**: Android Studio를 설치하거나 명령줄 도구만 설치한 뒤 SDK Manager로 받는다.
   - Android SDK Platform-Tools (adb) · Android SDK Build-Tools (apksigner) · Android SDK Command-line Tools
   - Android SDK Platform (Godot 4.7이 요구하는 대상 API — 모자라면 에디터 내보내기 창 오류 문구가 알려 준다)
   - 기본 위치는 `%LOCALAPPDATA%\Android\Sdk`.
4. **에디터 설정** (편집기 → 편집기 설정 → 내보내기 → Android):
   - Java SDK Path = JDK 17 폴더
   - Android SDK Path = 위 SDK 폴더 (지금 `C:\Users\JP\AppData\Local/Android/Sdk`로 되어 있음)
   - Debug Keystore: JDK를 지정하면 에디터가 `%APPDATA%\Godot\keystores\debug.keystore`를 만든다. 안 생기면:
     `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12`
5. 에디터에서 프로젝트를 한 번 열어 텍스처를 다시 가져오게 한다 (ETC2/ASTC 설정).

설치 확인: `powershell -ExecutionPolicy Bypass -File tools/build_android.ps1 -CheckOnly`

### 1-2. 폰 준비

설정 → 휴대전화 정보 → 소프트웨어 정보 → **빌드 번호를 7번 탭**(개발자 옵션 켜짐) → 설정 → 개발자 옵션 → **USB 디버깅 켜기**.
USB로 PC에 연결하고 폰에 뜨는 "USB 디버깅 허용"을 누른다. `adb devices`에 기기가 보이면 준비 끝
(`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe devices`).

### 1-3. 실행 방법 (넷 중 하나)

**A. 스크립트로 빌드 + 설치 + 실행 (추천)**

```
powershell -ExecutionPolicy Bypass -File tools/build_android.ps1 -Install
```

APK를 만들고 연결된 폰에 설치한 뒤 바로 실행한다. 다시 빌드할 때도 같은 명령 (`-r`로 덮어 설치, 저장은 유지).

**B. Godot 에디터 원클릭 배포 (로그·디버거를 보면서)**

폰을 연결한 채 에디터를 열면 오른쪽 위 실행 버튼 옆에 **Android 아이콘**이 생긴다. 누르면 빌드·설치·실행하고,
에디터 아래 출력 창에 `print`·오류가 그대로 보이며 원격 디버거(중단점)가 붙는다.
(프리셋의 Runnable이 켜져 있어서 가능. 디버그 → "원격 디버그로 배포"가 켜져 있어야 디버거가 붙는다.)

**C. APK 파일을 폰에 옮겨 설치 (케이블·adb 없이, 팀원에게 전달)**

`tools/build_android.ps1`로 만든 `build/android/swap_match.apk`를 메신저·구글 드라이브 등으로 폰에 보내 연다.
처음엔 "출처를 알 수 없는 앱 설치 허용"을 그 앱(파일 관리자·메신저)에 켜야 한다.

**D. 에뮬레이터 (폰이 없을 때)**

Android Studio → Device Manager → 가상 기기 만들기(**arm64 이미지** 또는 x86_64 이미지 — 지금 프리셋은 arm64만 넣으므로
x86_64 에뮬레이터를 쓰려면 프리셋에서 `architectures/x86_64`를 켠다) → 실행 후 A 또는 B와 같이.
터치 대신 마우스라 스와이프 감각은 실제 폰과 다르다.

### 1-4. 로그·기록 꺼내기

- 실시간 로그: `adb logcat -s godot` (또는 B 방법의 에디터 출력 창)
- 플레이 기록: `adb shell run-as com.swapmatch.game cat files/playtest_log.csv > playtest_log.csv`
  → `godot --headless --path . -s tools/playtest_summary.gd -- playtest_log.csv`

---

## 2. iOS

### 2-1. 준비물

- **Mac + Xcode** (App Store에서 설치 후 한 번 실행해 추가 구성 요소 설치). Windows에서는 iOS 앱을 빌드할 수 없다.
- **Godot 4.7.2 macOS 버전**과 **내보내기 템플릿** (에디터 → 내보내기 템플릿 관리 → 다운로드. `ios.zip`이 들어 있다).
- **Apple ID / Apple Developer 계정**:
  - 무료 Apple ID: 내 iPhone에 개발용으로 설치 가능. 대신 **7일마다 다시 설치**해야 하고 동시에 앱 3개까지.
  - 유료 Apple Developer Program(연 $99): 1년 유효, 팀원 기기 등록, **TestFlight로 팀 배포**, 앱 스토어 출시.
- Xcode → Settings → Accounts에서 Apple ID 로그인. 계정의 **Team ID**(영문·숫자 10자리)를 확인한다
  (developer.apple.com → Membership, 무료 계정은 Xcode 서명 화면의 Team 목록 / 키체인의 개발 인증서 OU 값).
- 프로젝트를 Mac으로 가져온다 (git clone). 에디터에서 한 번 열어 가져오기(import)를 마친다.

### 2-2. 빌드

```
bash tools/build_ios.sh --check                  # 설치 점검
bash tools/build_ios.sh --team ABCDE12345 --open # Team ID를 프리셋에 적고 빌드, Xcode 프로젝트 열기
bash tools/build_ios.sh --open                   # 다음부터 (Team ID는 프리셋에 남는다)
```

Team ID는 에디터의 프로젝트 → 내보내기 → iOS → App Store Team ID에 직접 넣어도 된다 (`export_presets.cfg`에 저장).
팀이 유료 계정 하나를 같이 쓰면 그 Team ID를 커밋해 두면 되고, 각자 무료 Apple ID를 쓰면 커밋하지 않는다.
번들 ID `com.swapmatch.game`이 다른 계정에서 이미 쓰이고 있다고 나오면 프리셋의 Bundle Identifier를 바꾼다
(예: `com.<이름>.swapmatch`).

### 2-3. 폰 준비

1. iPhone을 USB로 Mac에 연결하고 "이 컴퓨터를 신뢰" → 암호.
2. **개발자 모드 켜기** (iOS 16 이상): 설정 → 개인정보 보호 및 보안 → 개발자 모드 → 켜기 → 재시동.
   (한 번 Xcode에서 실행을 시도해야 메뉴가 보이는 경우가 있다.)
3. 무료 Apple ID로 처음 설치하면 앱이 안 열리고 "신뢰하지 않는 개발자"가 뜬다:
   설정 → 일반 → VPN 및 기기 관리 → 개발자 앱의 내 Apple ID → **신뢰**.

### 2-4. 실행 방법 (셋 중 하나)

**A. Xcode에서 실행 (추천)**

`--open`으로 열린 `build/ios/swap_match.xcodeproj`에서:
1. 왼쪽 프로젝트 → TARGETS → Signing & Capabilities → **Team**이 내 계정인지 확인 ("Automatically manage signing" 켜기).
2. 위쪽 실행 대상에서 연결된 **내 iPhone**을 고른다.
3. **▶ (⌘R)**. 빌드·설치·실행되고 Xcode 아래 콘솔에 로그가 보인다.

**B. Godot 에디터 원클릭 배포 (Mac에서)**

iPhone을 연결한 채 Mac의 Godot 에디터를 열면 오른쪽 위에 **iOS 아이콘**이 생긴다. 누르면 내보내기·설치·실행까지 한 번에
(서명이 Xcode에서 한 번 성공해 있어야 한다).

**C. 시뮬레이터 (폰이 없을 때)**

Xcode 실행 대상에서 iPhone 시뮬레이터(예: iPhone 15)를 골라 ▶. 서명이 필요 없다.
Godot 템플릿에 시뮬레이터 라이브러리가 없어 빌드가 실패하면 실제 기기로 확인한다. 마우스라 스와이프 감각은 다르다.

**팀원에게 배포 (유료 계정)**: Xcode → Product → Archive → Distribute App → TestFlight → 팀원은 TestFlight 앱으로 설치.

### 2-5. 로그·기록 꺼내기

- 실시간 로그: Xcode 콘솔 (A 방법) 또는 Mac의 콘솔 앱에서 기기 선택
- 플레이 기록: Xcode → Window → Devices and Simulators → 내 iPhone → 설치된 앱의 Swap match → ⋯ → **Download Container**
  → 받은 컨테이너의 `AppData/Documents/` 아래 `playtest_log.csv` → `tools/playtest_summary.gd`로 요약

---

## 3. 폰에서 확인할 것 (기획서 12장 QA 중 기기 항목, 두 플랫폼 공통)

- [ ] 첫 실행: 인트로 → 규칙 튜토리얼이 열리고 끝까지 진행된다
- [ ] 화면 비율·노치: HUD·판·방향키·메뉴가 가려지거나 겹치지 않는다 (19.5:9 · 20:9, 펀치홀 · 다이내믹 아일랜드, iPad 4:3)
- [ ] 스와이프 22px·옆 칸 탭·패드 반복이 의도대로, 누르고 있기(파키)·꾹 누르기(방화광)
- [ ] Android 뒤로 가기: 판에서는 일시정지/계속 (앱이 꺼지지 않는다)
- [ ] 홈으로 나갔다 오기·알림창·전화: 자동 일시정지
- [ ] 저장: 앱을 완전히 끄고 다시 켜도 레벨·재화·캐릭터·설정·튜토리얼 진행이 남는다
- [ ] 볼륨 0이면 무음 (효과음은 아직 자리만)
- [ ] 프레임: 매치·파편·연쇄 폭파·사진 실행 중 끊김 없음 (효과 줄이기 켜고/끄고)

## 4. 아직 안 한 것

- 출시용 서명(Android 릴리스 keystore, iOS 배포 인증서·프로비저닝), 릴리스 빌드, Play 스토어용 AAB(Gradle 빌드)
- 앱 아이콘(지금은 `icon.svg`)·Android 적응형 아이콘·iOS 아이콘 세트, iOS 실행 화면
- 메뉴 화면에서 Android 뒤로 가기 동작 (지금은 아무 일도 하지 않음)
