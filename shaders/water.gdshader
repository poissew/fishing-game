shader_type spatial;
// Same switches the hand-made pond material had: no ambient, no specular, no fog, no shadows.
render_mode specular_disabled, ambient_light_disabled, fog_disabled, shadows_disabled;

// Laid out in world space rather than by the mesh's own UVs, so a CSG box and a
// TrenchBroom brush tile the texture identically and neighbouring pieces line up.
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
// Texture repeats per world unit.
uniform float uv_scale = 2.08;
// Texture repeats per second the whole surface drifts.
uniform vec2 scroll_speed = vec2(0.05, 0.025);
// How far, in texture space, the waves push the texture around.
uniform float wave_strength = 0.02;
// How many wave crests per texture repeat.
uniform float wave_frequency = 6.0;
uniform float wave_speed = 1.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * uv_scale + scroll_speed * TIME;
	// Two sines crossing each other: the surface wobbles instead of sliding in one direction.
	// Done on the texture and not on the vertices because a water brush is a handful of
	// triangles, with nothing in the middle of it to move.
	uv += wave_strength * vec2(
		sin(uv.y * wave_frequency + TIME * wave_speed),
		cos(uv.x * wave_frequency + TIME * wave_speed * 0.8));
	ALBEDO = texture(albedo_texture, uv).rgb * albedo_color.rgb;
}
