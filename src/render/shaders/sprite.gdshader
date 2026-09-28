shader_type canvas_item;
// Resolves AssetForge material maps into colors for MultiMesh instances.
// INSTANCE_CUSTOM: x = frame index, y = skin idx, z = hair/wool idx, w = flags
//   flags bit0 = flip horizontally, bit1 = selected highlight, bit2 = ghost (semi-transparent)
// Instance COLOR = tint for clothes / roofs / banners.

uniform sampler2D atlas : filter_nearest;
uniform vec2 frame_px = vec2(8.0, 8.0);
uniform float atlas_cols = 8.0;
uniform vec2 atlas_px = vec2(64.0, 16.0);
uniform vec4 skins[4];
uniform vec4 hairs[5];
uniform vec4 wools[3];
uniform vec4 mats[24];

varying flat vec4 v_custom;
varying flat vec4 v_tint;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_tint = COLOR;
}

void fragment() {
	int frame = int(v_custom.x + 0.5);
	int flags = int(v_custom.w + 0.5);
	vec2 uv = UV;
	if ((flags & 1) != 0) uv.x = 1.0 - uv.x;
	vec2 origin = vec2(float(frame % int(atlas_cols)), float(frame / int(atlas_cols))) * frame_px;
	ivec2 p = ivec2(origin + min(floor(uv * frame_px), frame_px - 1.0));
	vec4 m = texelFetch(atlas, p, 0);
	if (m.a < 0.5) discard;
	int id = int(m.r * 255.0 + 0.5);
	float shade = m.g * 255.0 / 128.0;
	vec3 base;
	if (id == 2) base = skins[int(v_custom.y + 0.5) % 4].rgb;
	else if (id == 3 || id == 18) base = v_tint.rgb;
	else if (id == 12 || id == 13) base = mix(v_tint.rgb, vec3(0.55, 0.42, 0.30), 0.55); // muted roofs keep people readable
	else if (id == 4) base = hairs[int(v_custom.z + 0.5) % 5].rgb;
	else if (id == 5) base = wools[int(v_custom.z + 0.5) % 3].rgb;
	else base = mats[id].rgb;
	vec3 c = base * shade;
	float a = ((flags & 4) != 0) ? 0.55 : 1.0;
	if (id == 1 && shade < 0.6) {
		// Soft shadow material.
		COLOR = vec4(0.0, 0.0, 0.0, 0.35);
	} else {
		if ((flags & 2) != 0) c = mix(c, vec3(1.0, 0.95, 0.6), 0.25);
		COLOR = vec4(c, a);
	}
}
