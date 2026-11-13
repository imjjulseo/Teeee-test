// 스포트라이트 (HTML #tsp): 화면을 dim_color로 덮고 holes(캔버스 좌표 사각형) 자리만 비운다.
// 구멍은 pad만큼 넓힌 둥근 사각형, 가장자리는 feather 폭으로 부드럽게 (HTML 마스크의 가우시안 흐림), 너무 작으면 min_size로 키운다.
shader_type canvas_item;

uniform vec4 holes[8];
uniform int hole_count = 0;
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec4 dim_color : source_color = vec4(0.0157, 0.047, 0.063, 0.45);
uniform float radius = 50.0;
uniform float pad = 28.0;
uniform float feather = 45.0;
uniform float min_size = 71.0;

float rounded_box(vec2 p, vec2 center, vec2 half_size, float r) {
	vec2 q = abs(p - center) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	float alpha = dim_color.a;
	for (int i = 0; i < 8; i++) {
		if (i >= hole_count) {
			break;
		}
		vec4 h = holes[i];
		vec2 half_size = max(h.zw, vec2(min_size)) * 0.5 + vec2(pad);
		float r = min(radius, min(half_size.x, half_size.y));
		float d = rounded_box(p, h.xy + h.zw * 0.5, half_size, r);
		alpha = min(alpha, dim_color.a * smoothstep(-feather, feather, d));
	}
	COLOR = vec4(dim_color.rgb, alpha);
}
