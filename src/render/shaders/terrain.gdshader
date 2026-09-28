shader_type canvas_item;
// Terrain + territory in one pass. Each fragment finds its tile, samples the
// procedural tile atlas, then layers shading, shoreline, borders and overlays.
// data_tex:  R biome index | G variant(2) veg band(2)<<2 wood band(2)<<4 | B hillshade
// owner_tex: R,G owner city id (lo, hi byte) | B color index + 1 (0 = unowned)

uniform sampler2D data_tex : filter_nearest;
uniform sampler2D owner_tex : filter_nearest;
uniform sampler2D atlas : filter_nearest;
uniform sampler2D city_palette : filter_nearest;
uniform sampler2D overlay_tex : filter_nearest;
uniform vec2 world_size = vec2(256.0, 256.0);
uniform int farmland_index = 14;
uniform int forest_index = 6;
uniform int grass_index = 5;
uniform int max_water_index = 2;
uniform bool show_territory = true;
uniform float territory_fill = 0.16;
uniform float overlay_alpha = 0.0;
uniform bool show_chunks = false;
uniform float chunk_size = 16.0;
uniform float anim_time = 0.0;

const float TILE_PX = 8.0;
const vec3 DRY = vec3(0.62, 0.58, 0.30);

ivec4 texel_i(sampler2D t, ivec2 p) {
	ivec2 sz = ivec2(world_size);
	return ivec4(texelFetch(t, clamp(p, ivec2(0), sz - 1), 0) * 255.0 + 0.5);
}

bool is_water(int b) { return b <= max_water_index; }

int owner_id(ivec2 p) {
	ivec4 o = texel_i(owner_tex, p);
	return o.b == 0 ? -1 : o.r + o.g * 256;
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 wp = UV * world_size;
	// Derivatives must be taken in uniform control flow.
	vec2 tiles_per_screen_px = fwidth(wp);
	vec2 chunk_fw = fwidth(wp / chunk_size);
	ivec2 t = ivec2(floor(wp));
	vec2 f = fract(wp);
	ivec2 px = ivec2(floor(f * TILE_PX));
	ivec4 d = texel_i(data_tex, t);
	int b = d.r;
	int variant = d.g & 3;
	int veg = (d.g >> 2) & 3;
	int wood = (d.g >> 4) & 3;
	int col = variant;
	if (b == farmland_index) {
		col = 4 + veg;
	} else if (b == forest_index && wood < 2) {
		col = 4 + wood;
	}
	// Dithered biome transitions: pixels in the outer two rows of a land tile may
	// take the art of a different neighbouring land biome, breaking stair-step edges.
	if (!is_water(b) && b != farmland_index) {
		float hsh = hash12(vec2(t) * 8.0 + vec2(px));
		ivec2 nb_dir = ivec2(0);
		float edge = 0.0;
		if (px.x <= 1) { nb_dir = ivec2(-1, 0); edge = float(2 - px.x); }
		else if (px.x >= 6) { nb_dir = ivec2(1, 0); edge = float(px.x - 5); }
		if (px.y <= 1 && float(2 - px.y) > edge) { nb_dir = ivec2(0, -1); edge = float(2 - px.y); }
		else if (px.y >= 6 && float(px.y - 5) > edge) { nb_dir = ivec2(0, 1); edge = float(px.y - 5); }
		if (edge > 0.0) {
			ivec4 nd = texel_i(data_tex, t + nb_dir);
			int nb = nd.r;
			if (nb != b && !is_water(nb) && nb != farmland_index && hsh < 0.22 * edge) {
				b = nb;
				col = nd.g & 3;
			}
		}
	}
	vec4 c = texelFetch(atlas, ivec2(col * 8 + px.x, b * 8 + px.y), 0);

	if (b == grass_index && veg < 2) {
		c.rgb = mix(c.rgb, DRY * c.rgb * 1.6, float(2 - veg) * 0.28);
	}

	float hs = float(d.b) / 255.0;
	c.rgb *= 0.80 + 0.40 * hs;

	if (is_water(b)) {
		float ph = hash12(vec2(t)) * 6.2831;
		float s = sin(anim_time * 1.6 + ph + float(px.y) * 0.9);
		if (s > 0.93 && (px.x + px.y + int(ph)) % 3 == 0) {
			c.rgb += vec3(0.10, 0.12, 0.14);
		}
		// Foam on water pixels touching land.
		bool shore = false;
		if (px.x == 0 && !is_water(texel_i(data_tex, t + ivec2(-1, 0)).r)) shore = true;
		if (px.x == 7 && !is_water(texel_i(data_tex, t + ivec2(1, 0)).r)) shore = true;
		if (px.y == 0 && !is_water(texel_i(data_tex, t + ivec2(0, -1)).r)) shore = true;
		if (px.y == 7 && !is_water(texel_i(data_tex, t + ivec2(0, 1)).r)) shore = true;
		if (shore) {
			float foam = 0.55 + 0.25 * sin(anim_time * 2.0 + float(t.x + t.y));
			c.rgb = mix(c.rgb, vec3(0.86, 0.93, 0.96), foam);
		}
	} else {
		// Darken the land lip facing water to read as a small bank.
		if (px.y == 7 && is_water(texel_i(data_tex, t + ivec2(0, 1)).r)) c.rgb *= 0.62;
		if (px.x == 0 && is_water(texel_i(data_tex, t + ivec2(-1, 0)).r)) c.rgb *= 0.8;
		if (px.x == 7 && is_water(texel_i(data_tex, t + ivec2(1, 0)).r)) c.rgb *= 0.8;
	}

	if (show_territory) {
		int me = owner_id(t);
		if (me >= 0) {
			int ci = texel_i(owner_tex, t).b - 1;
			vec3 cc = texelFetch(city_palette, ivec2(ci, 0), 0).rgb;
			c.rgb = mix(c.rgb, cc, territory_fill);
			// Border thickness: one art pixel, never thinner than ~1.5 screen pixels.
			float thick = max(1.0 / TILE_PX, 1.5 * max(tiles_per_screen_px.x, tiles_per_screen_px.y));
			bool edge = false;
			if (f.x < thick && owner_id(t + ivec2(-1, 0)) != me) edge = true;
			if (f.x > 1.0 - thick && owner_id(t + ivec2(1, 0)) != me) edge = true;
			if (f.y < thick && owner_id(t + ivec2(0, -1)) != me) edge = true;
			if (f.y > 1.0 - thick && owner_id(t + ivec2(0, 1)) != me) edge = true;
			if (edge) {
				c.rgb = mix(cc * 1.15, vec3(1.0), 0.12);
			}
		}
	}

	if (overlay_alpha > 0.0) {
		vec4 o = texelFetch(overlay_tex, t, 0);
		c.rgb = mix(c.rgb, o.rgb, o.a * overlay_alpha);
	}

	if (show_chunks) {
		vec2 cf = fract(wp / chunk_size);
		vec2 g = chunk_fw * 1.5;
		if (cf.x < g.x || cf.y < g.y) c.rgb = mix(c.rgb, vec3(1.0, 0.2, 0.8), 0.7);
	}
	COLOR = vec4(c.rgb, 1.0);
}
