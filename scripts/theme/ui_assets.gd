class_name UiAssets
extends Resource
## 화면 공통 디자인 이미지 자리 (한 장 이미지, PNG 기본, resources/ui_assets.tres). 비어 있으면 지금처럼 글자·도형으로 그린다.
## 넣는 방법과 권장 크기는 docs/art_assets.md 3장.

@export_group("Common")
## 인트로·메인 화면 로고 ("Swap match" 글자 대신).
@export var logo: Texture2D
## 지갑(위 줄)과 판 HUD 코인 앞의 "●" "◆" 대신 (버튼·문장 안의 ● ◆는 글자 그대로 둔다).
@export var coin_icon: Texture2D
@export var diamond_icon: Texture2D

@export_group("Bottom Nav")
## 아래 줄 버튼 그림 ("상점" 같은 글자 대신).
@export var shop_icon: Texture2D
@export var achievements_icon: Texture2D
@export var puzzle_icon: Texture2D
@export var options_icon: Texture2D

@export_group("Main")
## 게임 시작 스와이프 안내 (위쪽 화살표, "▲" 대신).
@export var swipe_hint: Texture2D

@export_group("Screens")
## 레벨 화면 뒤로가기 ("‹" 대신).
@export var back_icon: Texture2D
## 캐릭터 화면 좌우 화살표 ("‹" "›" 대신).
@export var left_arrow: Texture2D
@export var right_arrow: Texture2D
## 잠긴 퍼즐 판 자물쇠 ("잠김" 글자 대신).
@export var lock_icon: Texture2D
## 별점의 채운 별 · 빈 별 ("★" "☆" 대신).
@export var star_on: Texture2D
@export var star_off: Texture2D
