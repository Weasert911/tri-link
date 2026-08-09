shader_type canvas_item;

// Combined retro-comic treatment over the 3D scene, below the HUD layer.
// Adds ink edges, halftone shadows, print offset, palette reduction and grain.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 2.0) = 1.08;
uniform float contrast : hint_range(0.5, 1.5) = 1.04;
uniform float exposure : hint_range(0.0, 2.0) = 1.0;
uniform vec3 tint : source_color = vec3(1.01, 1.0, 0.97);
uniform float vignette : hint_range(0.0, 1.0) = 0.12;
uniform int posterize_steps : hint_range(0, 16) = 0;
uniform float ink_strength : hint_range(0.0, 1.0) = 0.3;
uniform float ink_threshold : hint_range(0.0, 0.5) = 0.12;
uniform vec3 ink_color : source_color = vec3(0.018, 0.012, 0.045);
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.06;
uniform float halftone_scale : hint_range(2.0, 12.0) = 5.0;
uniform float print_offset : hint_range(0.0, 3.0) = 0.15;

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(screen_tex, 0));
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec3 shifted_left = texture(screen_tex, SCREEN_UV - vec2(texel.x * print_offset, 0.0)).rgb;
	vec3 shifted_right = texture(screen_tex, SCREEN_UV + vec2(texel.x * print_offset, 0.0)).rgb;
	col.r = shifted_left.r;
	col.b = shifted_right.b;
	col *= exposure;
	float lum = luminance(col);
	col = mix(vec3(lum), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col *= tint;
	if (posterize_steps > 1) {
		float steps = float(posterize_steps);
		col = floor(col * steps + 0.5) / steps;
	}

	float left_lum = luminance(texture(screen_tex, SCREEN_UV - vec2(texel.x, 0.0)).rgb);
	float right_lum = luminance(texture(screen_tex, SCREEN_UV + vec2(texel.x, 0.0)).rgb);
	float up_lum = luminance(texture(screen_tex, SCREEN_UV - vec2(0.0, texel.y)).rgb);
	float down_lum = luminance(texture(screen_tex, SCREEN_UV + vec2(0.0, texel.y)).rgb);
	float edge = abs(right_lum - left_lum) + abs(down_lum - up_lum);
	float ink = smoothstep(ink_threshold, ink_threshold * 2.6, edge) * ink_strength;
	col = mix(col, ink_color, ink);

	vec2 dot_cell = floor(FRAGCOORD.xy / halftone_scale) * halftone_scale;
	vec2 dot_uv = mod(FRAGCOORD.xy, halftone_scale) / halftone_scale - 0.5;
	float dot_mask = 1.0 - smoothstep(0.18, 0.38, length(dot_uv));
	float shadow_mask = smoothstep(0.72, 0.15, lum);
	col = mix(col, col * 0.62, dot_mask * shadow_mask * halftone_strength);
	col += (fract(sin(dot(dot_cell, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.012;

	float d = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - vignette * smoothstep(0.45, 0.85, d);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
