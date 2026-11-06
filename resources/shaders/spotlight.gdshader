// 스포트라이트: 화면을 어둡게 하고 holes(캔버스 좌표 사각형) 자리만 둥글게 비운다.
shader_type canvas_item;

uniform vec4 holes[8];
uniform int hole_count = 0;
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 0.62);
uniform float radius = 14.0;
uniform float pad = 6.0;

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
		vec2 half_size = h.zw * 0.5 + vec2(pad);
		float d = rounded_box(p, h.xy + h.zw * 0.5, half_size, radius);
		alpha = min(alpha, dim_color.a * smoothstep(-1.5, 1.5, d));
	}
	COLOR = vec4(dim_color.rgb, alpha);
}
