class_name DrawnIcons
extends RefCounted
## 코드로 그리는 조작 부품 그림 (슬라이더 손잡이, 켜고 끄는 스위치). 엔진 기본 그림은 1080×1920 화면에서 너무 작다.
## 색은 부르는 쪽이 디자인 토큰에서 읽어 넘긴다. 같은 모양·색은 한 번만 만든다.

static var _cache: Dictionary[String, ImageTexture] = {}


## 지름 diameter px의 둥근 손잡이.
static func disc(diameter: int, color: Color) -> ImageTexture:
	return capsule(Vector2i(diameter, diameter), color)


## size 크기의 알약 모양 (높이가 지름).
static func capsule(size: Vector2i, color: Color) -> ImageTexture:
	var key: String = "capsule:%s:%s" % [size, color.to_html()]
	if not _cache.has(key):
		var image: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		_fill_capsule(image, Rect2i(Vector2i.ZERO, size), color)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## 스위치: 알약 바탕(track) 위에 둥근 손잡이(knob). on이면 손잡이가 오른쪽.
static func switch(size: Vector2i, on: bool, track: Color, knob: Color, inset: int = 9) -> ImageTexture:
	var key: String = "switch:%s:%s:%s:%s:%d" % [size, on, track.to_html(), knob.to_html(), inset]
	if not _cache.has(key):
		var image: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		_fill_capsule(image, Rect2i(Vector2i.ZERO, size), track)
		var knob_size: int = size.y - inset * 2
		var knob_x: int = size.x - inset - knob_size if on else inset
		_fill_capsule(image, Rect2i(knob_x, inset, knob_size, knob_size), knob)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## rect 안에 알약을 칠한다 (가장자리는 한 픽셀 폭으로 부드럽게, 이미 칠한 색 위에 덮어 그린다).
static func _fill_capsule(image: Image, rect: Rect2i, color: Color) -> void:
	var radius: float = rect.size.y / 2.0
	var left: float = rect.position.x + radius
	var right: float = rect.position.x + rect.size.x - radius
	var center_y: float = rect.position.y + radius
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			var point: Vector2 = Vector2(x + 0.5, y + 0.5)
			var nearest: Vector2 = Vector2(clampf(point.x, left, right), center_y)
			var cover: float = clampf(radius - point.distance_to(nearest) + 0.5, 0.0, 1.0)
			if cover > 0.0:
				image.set_pixel(x, y, image.get_pixel(x, y).blend(Color(color, color.a * cover)))
