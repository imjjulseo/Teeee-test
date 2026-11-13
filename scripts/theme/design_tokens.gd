class_name DesignTokens
extends Resource
## 디자인 토큰 (기획서 7.3장, E14): 화면 색을 용도 이름으로 모은다. 화면은 값이 아니라 이 이름을 쓴다 —
## 라벨·판넬은 프로젝트 테마(ui_theme.tres, UiThemeBuilder가 이 값으로 만든다)의 변형으로, 단색 사각형은 TokenRect로.
## 라이트/다크를 정하면(베타 뒤) 이 리소스를 하나 더 만들어 테마를 다시 만들면 된다. 판 색(블록·문양·연출)은 BoardTheme.
## 테마에는 토큰이 THEME_TYPE 형식의 색으로도 들어가 Control이 get_theme_color(이름, THEME_TYPE)로 읽는다.

const THEME_TYPE: StringName = &"Tokens"

@export_group("Background")
## 화면 바탕.
@export var background: Color = Color(0.0470588, 0.121569, 0.14902, 1)
## 설정 화면 바탕.
@export var background_settings: Color = Color(0.113725, 0.121569, 0.14902, 1)
## 판을 가리는 화면 (일시정지) / 비치는 화면 (결과·부활).
@export var overlay: Color = Color(0.08, 0.085, 0.1, 1)
@export var overlay_glass: Color = Color(0.08, 0.085, 0.1, 0.92)
## 뒤를 어둡게 덮는 막 (시트·결과 카드 / 뽑기 결과).
@export var scrim: Color = Color(0, 0, 0, 0.6)
@export var scrim_strong: Color = Color(0, 0, 0, 0.7)

@export_group("Surface")
## 카드·시트·설명 상자.
@export var surface: Color = Color(0.0862745, 0.180392, 0.215686, 1)
## 판 위에 뜨는 설명 상자·막대.
@export var surface_glass: Color = Color(0.0862745, 0.180392, 0.215686, 0.96)
## 버튼·카드 바탕 (HTML --panel #132D36) / 한 단계 밝은 바탕 (--panel-2 #1A3A45, 누른 버튼·보조 버튼).
@export var panel: Color = Color(0.0745098, 0.176471, 0.211765, 1)
@export var panel_raised: Color = Color(0.101961, 0.227451, 0.270588, 1)
## 버튼·카드 테두리 (HTML --line #27505C).
@export var line: Color = Color(0.152941, 0.313726, 0.360784, 1)
## 튜토리얼 설명 칸 (HTML #tspCap: --panel-2 92%).
@export var caption: Color = Color(0.101961, 0.227451, 0.270588, 0.92)
## 설명 칸 위 건너뛰기 알약 (HTML rgba(19,45,54,.9)).
@export var pill: Color = Color(0.0745098, 0.176471, 0.211765, 0.9)
## 스포트라이트가 덮는 어두운 막 (HTML #tsp .dim rgba(4,12,16,.45)).
@export var spotlight_dim: Color = Color(0.0156863, 0.0470588, 0.0627451, 0.45)
## 능력 배너.
@export var banner: Color = Color(0.0392157, 0.101961, 0.12549, 0.86)
## 목록 한 줄 바탕 / 테두리.
@export var row: Color = Color(1, 1, 1, 0.05)
@export var row_border: Color = Color(1, 1, 1, 0.1)
## 진행 막대 바탕.
@export var track: Color = Color(1, 1, 1, 0.12)
## 슬라이더 바탕.
@export var control_track: Color = Color(0.3, 0.3, 0.34, 1)
## 선택한 버튼·탭.
@export var selected: Color = Color(0.184314, 0.435294, 0.839216, 1)
## 흰 테두리.
@export var outline: Color = Color(1, 1, 1, 1)

@export_group("Text")
## 보조 문구 (회청색).
@export var text_muted: Color = Color(0.560784, 0.666667, 0.698039, 1)
## 설명·주석 (회색).
@export var text_dim: Color = Color(0.7, 0.7, 0.7, 1)
## 강조 바탕 위의 글자.
@export var text_on_accent: Color = Color(0.0470588, 0.121569, 0.14902, 1)

@export_group("Accent")
## 강조 (재화·제목·별).
@export var accent: Color = Color(1, 0.823529, 0.247059, 1)
## 따뜻한 강조 (최고 기록·떠오르는 점수).
@export var accent_warm: Color = Color(0.96, 0.78, 0.26, 1)
## 강조 테두리 (설명 상자).
@export var accent_line: Color = Color(1, 0.823529, 0.247059, 0.8)
## 주 행동 버튼 (게임 시작·결과의 다음, HTML --hot #F27B50).
@export var hot: Color = Color(0.94902, 0.482353, 0.313726, 1)
## 정보 (진행 막대 채움·소제목·상태).
@export var info: Color = Color(0.560784, 0.890196, 1, 1)
## 다이아 (코인의 강조색과 구분).
@export var diamond: Color = Color(0.45, 0.82, 1, 1)
## 되돌릴 수 없는 행동의 글자 (설정의 진행 초기화, HTML .sbtn.warn = --c1).
@export var warn: Color = Color(0.886275, 0.333333, 0.431373, 1)


## 토큰 이름 목록 (이 리소스의 색 속성).
func names() -> Array[StringName]:
	var list: Array[StringName] = []
	for property: Dictionary in get_property_list():
		if property["type"] == TYPE_COLOR and (property["usage"] & PROPERTY_USAGE_STORAGE) != 0:
			list.append(StringName(property["name"]))
	return list


func has_token(token: StringName) -> bool:
	return names().has(token)


## 토큰 색 (없는 이름이면 오류를 남기고 분홍).
func color_of(token: StringName) -> Color:
	if not has_token(token):
		push_error("DesignTokens: unknown token %s" % token)
		return Color.MAGENTA
	return get(token)
