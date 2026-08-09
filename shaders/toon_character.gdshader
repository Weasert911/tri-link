shader_type spatial;
render_mode specular_disabled, cull_disabled;

// 3-band toon lighting for the player mannequins with a stable identity
// accent. The separate toon_outline shader draws the silhouette.

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear;

uniform int band_count : hint_range(3, 4) = 4;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.22;
uniform float mid_threshold : hint_range(0.0, 1.0) = 0.48;
uniform float light_threshold : hint_range(0.0, 1.0) = 0.74;
uniform float band_softness : hint_range(0.0, 0.3) = 0.015;

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.12;
uniform float dark_mid_strength : hint_range(0.0, 1.0) = 0.36;
uniform float light_mid_strength : hint_range(0.0, 1.0) = 0.68;
uniform float light_strength : hint_range(0.0, 1.0) = 1.0;
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec3 shadow_color : source_color = vec3(0.1, 0.13, 0.28);
uniform vec3 dark_mid_color : source_color = vec3(0.32, 0.38, 0.58);
uniform vec3 light_mid_color : source_color = vec3(0.68, 0.74, 0.86);
uniform vec3 highlight_color : source_color = vec3(1.0, 0.96, 0.88);

uniform float saturation : hint_range(0.0, 2.0) = 1.2;
uniform float contrast : hint_range(0.5, 1.5) = 1.1;
uniform vec3 tint : source_color = vec3(1.0);

uniform vec3 player_color : source_color = vec3(1.0);
uniform float identity_accent_strength : hint_range(0.0, 1.0) = 0.24;
uniform float rgb_emission_strength : hint_range(0.0, 2.0) = 0.25;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.38;
uniform float rim_width : hint_range(0.0, 10.0) = 3.5;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.18;
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float specular_width : hint_range(0.0, 0.3) = 0.035;
uniform float lighting_floor : hint_range(0.0, 1.0) = 0.32;
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.4;

void fragment() {
	vec3 base = albedo * texture(albedo_texture, UV).rgb;
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722));
	base = mix(vec3(lum), base, saturation);
	base = (base - 0.5) * contrast + 0.5;
	base *= tint;
	ALBEDO = mix(base, vec3(0.48, 0.53, 0.66), 0.45);
	// Keep gameplay identity out of ALBEDO. Arena lighting may vary by facing,
	// but the player color must remain stable in both directions.
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), rim_width);
	EMISSION = player_color * (rgb_emission_strength + rim * rim_strength);
}

void light() {
	float n = abs(dot(NORMAL, LIGHT));
	float s = band_softness;
	float dark_mid = smoothstep(shadow_threshold - s, shadow_threshold + s, n);
	float light_mid = smoothstep(mid_threshold - s, mid_threshold + s, n);
	float highlight = smoothstep(light_threshold - s, light_threshold + s, n);
	float band = mix(shadow_strength, dark_mid_strength, dark_mid);
	band = mix(band, light_mid_strength, light_mid);
	band = mix(band, light_strength, highlight);
	band = max(band, lighting_floor);
	vec3 band_color = mix(shadow_color, dark_mid_color, dark_mid);
	band_color = mix(band_color, light_mid_color, light_mid);
	band_color = mix(band_color, highlight_color, highlight);
	vec3 palette_tint = mix(vec3(1.0), band_color, 0.28);
	vec3 col = ALBEDO * band * palette_tint * LIGHT_COLOR * ATTENUATION * 0.42;
	vec3 half_vector = normalize(LIGHT + VIEW);
	float specular = smoothstep(specular_threshold - specular_width, specular_threshold + specular_width, dot(NORMAL, half_vector));
	col += vec3(specular * specular_strength) * LIGHT_COLOR * ATTENUATION * 0.42;
	DIFFUSE_LIGHT += col;
}
