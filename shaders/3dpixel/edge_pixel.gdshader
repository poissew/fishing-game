shader_type spatial;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

float getLinearDepth(vec2 sUV, sampler2D depth_texture, mat4 invProjectionMat){
	float depth = texture(depth_texture, sUV).x;
	vec3 ndc = vec3(sUV * 2.0 - 1.0, depth);
	vec4 view = invProjectionMat * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void fragment() {
	vec2 texelSize = 1.0 / VIEWPORT_SIZE.xy;
	float depth = getLinearDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float depthLeft = getLinearDepth(SCREEN_UV + vec2(-1.0, 0.0) * texelSize, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float depthRight = getLinearDepth(SCREEN_UV + vec2(1.0, 0.0) * texelSize, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float depthUp = getLinearDepth(SCREEN_UV + vec2(0.0, -1.0) * texelSize, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float depthDown = getLinearDepth(SCREEN_UV + vec2(0.0, 1.0) * texelSize, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
}