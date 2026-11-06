class_name UiAssets
extends Resource
## 화면 공통 디자인 이미지 자리 (한 장 이미지, resources/ui_assets.tres). 비어 있으면 지금처럼 글자로 그린다.
## - logo: 인트로 로고 ("Swap match" 글자 대신)
## - coin_icon · diamond_icon: 지갑(메뉴·상점·캐릭터·업적 화면 위)과 판 HUD 코인 앞의 "●" "◆" 대신
##   (버튼·문장 안의 ● ◆는 글자 그대로 둔다)

@export var logo: Texture2D
@export var coin_icon: Texture2D
@export var diamond_icon: Texture2D
