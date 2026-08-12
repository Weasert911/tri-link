shader_type canvas_item;

// Short-lived transitional screen effect for big combat moments. Mounted as a
// permanent full-screen rect, but every uniform is driven to zero when no
// event is active, so the normal toon rendering stays clean.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic : hint_range(0.0, 0.03) = 0.0;
uniform float distortion : hint_range(0.0, 0.08) = 0.0;
uniform float ripple : hint_range(0.0, 0.04) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = distance(uv, center);
	vec2 dir = normalize(uv - center + vec2(1e-5));
	float edge = (1.0 - d);
	vec2 warped = uv
		+ dir * distortion * intensity * edge
		+ dir * sin(d * 40.0 - TIME * 16.0) * ripple * intensity * edge;
	vec3 col;
	col.r = texture(screen_tex, warped + vec2(chromatic * intensity, 0.0)).r;
	col.g = texture(screen_tex, warped).g;
	col.b = texture(screen_tex, warped - vec2(chromatic * intensity, 0.0)).b;
	col = mix(col, flash_color.rgb, intensity * 0.5);
	COLOR = vec4(col, intensity * 0.85);
}
