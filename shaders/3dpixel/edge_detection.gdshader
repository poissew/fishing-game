shader_type spatial;

/*
 * Screen-space outline pass, drawn on a full-screen quad parented to the camera.
 *
 * It draws ONLY the lines, as a transparent overlay. Everything underneath —
 * including the alpha-scissor Sprite3Ds of the hands viewmodel — reaches the
 * screen untouched. The previous version re-blitted hint_screen_texture into
 * ALBEDO and overrode DIFFUSE_LIGHT for the whole screen, which is what made
 * held sprites render wrong.
 *
 * Two constraints from the GL Compatibility renderer shape this shader:
 *   - hint_normal_roughness_texture is Forward+ only and will not compile here,
 *     so edges are derived from depth alone.
 *   - the depth buffer is only wired up for reads made directly inside
 *     fragment(), so every texture(DEPTH_TEXTURE, ...) call lives there.
 */

render_mode unshaded, blend_mix, cull_disabled,
	depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 line_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float line_alpha : hint_range(0.0, 1.0) = 0.7;
/* Line width, in screen pixels */
uniform float thickness : hint_range(1.0, 4.0) = 1.0;
/* Silhouette sensitivity: a depth step this large relative to the pixel's own
   distance from the camera counts as an edge */
uniform float silhouette_threshold : hint_range(0.001, 0.5) = 0.02;
/* Interior-crease sensitivity, same units */
uniform float crease_threshold : hint_range(0.001, 0.5) = 0.05;
/* Outlines fade out between these distances so far-off terrain does not turn
   into noise. The sky sits past the far end, so it never gets lines. */
uniform float fade_start = 40.0;
uniform float fade_end = 70.0;

/* ---------------- Utilities ---------------- */

/* View-space distance from a raw depth sample. Takes the already-sampled value
   so the depth texture itself is only ever read inside fragment(). */
float linear_depth(float raw, vec2 uv, mat4 inv_projection) {
	vec4 view = inv_projection * vec4(vec3(uv * 2.0 - 1.0, raw), 1.0);
	return -view.z / view.w;
}

/* ---------------- Vertex ---------------- */

void vertex() {
	/* Cover the whole screen no matter where the quad actually sits */
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

/* ---------------- Fragment ---------------- */

void fragment() {
	vec2 texel = thickness / VIEWPORT_SIZE;
	vec2 uv_l = SCREEN_UV - vec2(texel.x, 0.0);
	vec2 uv_r = SCREEN_UV + vec2(texel.x, 0.0);
	vec2 uv_u = SCREEN_UV - vec2(0.0, texel.y);
	vec2 uv_d = SCREEN_UV + vec2(0.0, texel.y);

	float d_c = linear_depth(texture(DEPTH_TEXTURE, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX);
	float d_l = linear_depth(texture(DEPTH_TEXTURE, uv_l).r, uv_l, INV_PROJECTION_MATRIX);
	float d_r = linear_depth(texture(DEPTH_TEXTURE, uv_r).r, uv_r, INV_PROJECTION_MATRIX);
	float d_u = linear_depth(texture(DEPTH_TEXTURE, uv_u).r, uv_u, INV_PROJECTION_MATRIX);
	float d_d = linear_depth(texture(DEPTH_TEXTURE, uv_d).r, uv_d, INV_PROJECTION_MATRIX);

	/* Thresholds scale with distance, so a line is the same width in world
	   terms whether the object is at arm's length or across the lake */
	float scale = max(d_c, 0.05);

	/* -------- Silhouettes -------- */

	/* Only fires where a neighbour is FARTHER away, so the line lands on the
	   near object rather than doubling up on both sides of the step */
	float step_out = max(
		max(d_l - d_c, d_r - d_c),
		max(d_u - d_c, d_d - d_c)
	) / scale;
	float silhouette = smoothstep(
		silhouette_threshold,
		silhouette_threshold * 2.0,
		step_out
	);

	/* -------- Interior creases -------- */

	/* Second derivative of INVERSE depth. Under a perspective projection 1/z is
	   exactly linear across any flat surface, so a floor seen at a grazing
	   angle curves by zero and picks up no false lines; only an actual change
	   of surface angle registers. */
	float i_c = 1.0 / scale;
	float i_l = 1.0 / max(d_l, 0.05);
	float i_r = 1.0 / max(d_r, 0.05);
	float i_u = 1.0 / max(d_u, 0.05);
	float i_d = 1.0 / max(d_d, 0.05);
	float curvature = abs((i_l + i_r + i_u + i_d) - 4.0 * i_c) * scale;
	float crease = smoothstep(
		crease_threshold,
		crease_threshold * 2.0,
		curvature
	);

	/* -------- Output -------- */

	float fade = 1.0 - smoothstep(fade_start, fade_end, d_c);
	float edge = max(silhouette, crease) * fade;

	ALBEDO = line_color.rgb;
	ALPHA = clamp(edge * line_alpha * line_color.a, 0.0, 1.0);
}
