shader_type spatial;
render_mode ambient_light_disabled;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture;

uniform float lightIntensity = 1.25;
uniform float lineAlpha = 0.7;
uniform bool useLighting = true;
uniform float lineHighlight = 0.2;
uniform float lineShadow = 0.55;

varying vec2 screen_uv;
varying float lineMask;

/* ---------------- Utilities ---------------- */

float get_depth(vec2 uv, float mask) {
	return texture(DEPTH_TEXTURE, uv).r * mask;
}

vec3 get_normal(vec2 uv, float mask) {
	return (texture(NORMAL_TEXTURE, uv).rgb * 2.0 - 1.0) * mask;
}

float normal_edge_indicator(
	vec3 bias,
	vec3 n,
	vec3 n2,
	float depth_diff
) {
	float normal_diff = dot(n - n2, bias);
	float normal_indicator = smoothstep(-0.01, 0.01, normal_diff);
	float depth_indicator = step(0.0, depth_diff + 0.001);
	return (1.0 - dot(n, n2)) * normal_indicator * depth_indicator;
}

/* ---------------- Vertex ---------------- */

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

/* ---------------- Fragment ---------------- */

void fragment() {
	screen_uv = SCREEN_UV;
	vec2 texel = 1.0 / VIEWPORT_SIZE.xy;

	vec2 offsets[4] = {
		screen_uv + vec2(0.0, -1.0) * texel,
		screen_uv + vec2(0.0,  1.0) * texel,
		screen_uv + vec2(1.0,  0.0) * texel,
		screen_uv + vec2(-1.0, 0.0) * texel
	};

	/* Roughness mask (alpha of normal texture) */
	float outlineMask = ceil(texture(NORMAL_TEXTURE, screen_uv).a);

	/* -------- Depth edge detection -------- */

	float depth = get_depth(screen_uv, outlineMask);
	float depthDiff = 0.0;
	float invDepth = 0.5;

	for (int i = 0; i < 4; i++) {
		float d = get_depth(offsets[i], outlineMask);
		depthDiff += clamp(d - depth, 0.0, 1.0);
		invDepth += depth - d;
	}

	invDepth = clamp(invDepth, 0.0, 1.0);
	invDepth = smoothstep(0.98, 1.0, invDepth);
	depthDiff = smoothstep(0.001, 0.003, depthDiff);

	/* -------- Normal edge detection -------- */

	vec3 normal = get_normal(screen_uv, outlineMask);
	vec3 bias = vec3(1.0);
	float normalDiff = 0.0;

	for (int i = 0; i < 4; i++) {
		vec3 n = get_normal(offsets[i], outlineMask);
		normalDiff += normal_edge_indicator(bias, normal, n, depthDiff);
	}

	normalDiff = smoothstep(0.15, 0.3, normalDiff);
	normalDiff = clamp(normalDiff - invDepth, 0.0, 1.0);

	/* -------- Final color -------- */

	ALBEDO = texture(SCREEN_TEXTURE, screen_uv).rgb;
	lineMask = clamp(depthDiff + normalDiff * 5.0, 0.0, lineAlpha);

	if (!useLighting) {
		ALBEDO += normalDiff * lineHighlight;
		ALBEDO -= ALBEDO * depthDiff * lineShadow;
	}
}

/* ---------------- Lighting ---------------- */

void light() {
	if (!useLighting) {
		DIFFUSE_LIGHT = vec3(1.0);
	}

	vec3 normal = texture(NORMAL_TEXTURE, screen_uv).rgb * 2.0 - 1.0;
	float nl = max(dot(normal, LIGHT), 0.0);
	nl = pow(nl, 2.5);

	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += mix(
			vec3(1.0),
			nl * LIGHT_COLOR * lightIntensity,
			lineMask
		);
	}
}
