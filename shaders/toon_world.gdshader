shader_type spatial;
render_mode specular_disabled;

// 3-band toon lighting for arena world geometry. Applied as a runtime
// surface override by scripts/toon_renderer.gd; the arena scenes on disk
// are never modified.

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear;
uniform vec3 shadow_color : source_color = vec3(0.18, 0.22, 0.38);
uniform vec3 mid_color : source_color = vec3(0.62, 0.72, 0.86);
uniform vec3 light_color : source_color = vec3(0.92, 1.0, 1.0);
uniform int band_count : hint_range(3, 4) = 3;

uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float light_threshold : hint_range(0.0, 1.0) = 0.62;
uniform float band_softness : hint_range(0.0, 0.3) = 0.015;

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.18;
uniform float mid_strength : hint_range(0.0, 1.0) = 0.62;
uniform float light_strength : hint_range(0.0, 1.0) = 1.0;
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.2;

uniform float saturation : hint_range(0.0, 2.0) = 1.22;
uniform float contrast : hint_range(0.5, 1.5) = 1.12;
uniform vec3 tint : source_color = vec3(1.0);

uniform float rim_strength : hint_range(0.0, 2.0) = 0.0;
uniform float rim_width : hint_range(0.0, 10.0) = 3.0;
uniform vec3 rim_color : source_color = vec3(1.0);

uniform float specular_strength : hint_range(0.0, 1.0) = 0.12;
uniform float specular_shininess : hint_range(1.0, 128.0) = 28.0;
uniform float light_response : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	vec3 base = albedo * texture(albedo_texture, UV).rgb;
	base = mix(vec3(0.34, 0.42, 0.58), base, 0.88);
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722));
	base = mix(vec3(lum), base, saturation);
	base = (base - 0.5) * contrast + 0.5;
	base *= tint;
	ALBEDO = clamp(base, vec3(0.0), vec3(1.0));
	EMISSION = ALBEDO * ambient_strength * 0.35;
}

void light() {
	float n = max(dot(NORMAL, LIGHT), 0.0);
	float s = band_softness;
	float mid = smoothstep(shadow_threshold - s, shadow_threshold + s, n);
	float lit = smoothstep(light_threshold - s, light_threshold + s, n);
	float band = mix(shadow_strength, mid_strength, mid);
	band = mix(band, light_strength, lit);
	vec3 band_color = mix(shadow_color, mid_color, mid);
	band_color = mix(band_color, light_color, lit);
	vec3 palette_tint = mix(vec3(1.0), band_color, 0.32);
	vec3 col = ALBEDO * band * palette_tint * LIGHT_COLOR * ATTENUATION * light_response;

	vec3 h = normalize(LIGHT + VIEW);
	float spec = pow(max(dot(NORMAL, h), 0.0), specular_shininess);
	col += ALBEDO * specular_strength * spec * band * LIGHT_COLOR * ATTENUATION * light_response;

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_width);
	col += rim_color * rim_strength * fres * band;

	DIFFUSE_LIGHT += col;
}
