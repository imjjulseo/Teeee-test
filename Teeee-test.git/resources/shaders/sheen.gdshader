shader_type canvas_item;
// 카드 위를 비스듬히 지나가는 빛 띠 (HTML .rc.chr::after sheen: linear-gradient(105deg, transparent 42%, 색 50%, transparent 58%)).
// offset은 띠의 가로 위치 (-0.45 ~ 0.45, 스크립트가 움직인다). 색은 modulate가 아니라 band_color.

uniform vec4 band_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform float offset = -0.45;
uniform float aspect = 4.0;

void fragment() {
	// 105도 기울기: 위로 갈수록 오른쪽으로.
	vec2 uv = UV - vec2(0.5);
	float along = uv.x + (uv.y / aspect) * 0.27 - offset * 1.8;
	float d = abs(along);
	float a = 1.0 - smoothstep(0.0, 0.08 * 1.8, d);
	COLOR = vec4(band_color.rgb, band_color.a * a);
}
