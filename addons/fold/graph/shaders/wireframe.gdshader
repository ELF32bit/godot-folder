shader_type spatial;

uniform vec3 albedo_color: source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D albedo_texture: hint_default_white;

uniform float wireframe_width_min = 10.0;
uniform float wireframe_width_max = 20.0;
uniform float wireframe_scale = 200.0;
uniform float wireframe_pow = 2.71;

uniform float B_scale = 4.0;
uniform vec4 B_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 M_color: source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 V_color: source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 F_color: source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 U_color: source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 C_color: source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 J_color: source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform float fade: hint_range(0.0, 1.0, 0.01) = 1.0;

varying vec3 bc; /* barycentric coordinates */
varying flat ivec3 ea; /* edges assignment */
varying flat ivec3 va; /* vertices edges assignments pair */
varying float fragment_distance; /* distance from camera to pixel */

const vec3 BC_TABLE[4] = {
	vec3(1.0, 1.0, 1.0),
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
};

const ivec2 VA_TABLE[32] = {
	ivec2(1, 1), ivec2(1, 2), ivec2(1, 3), ivec2(1, 4), ivec2(1, 5), ivec2(1, 6), ivec2(1, 7),
	ivec2(2, 2), ivec2(2, 3), ivec2(2, 4), ivec2(2, 5), ivec2(2, 6), ivec2(2, 7),
	ivec2(3, 3), ivec2(3, 4), ivec2(3, 5), ivec2(3, 6), ivec2(3, 7),
	ivec2(4, 4), ivec2(4, 5), ivec2(4, 6), ivec2(4, 7),
	ivec2(5, 5), ivec2(5, 6), ivec2(5, 7),
	ivec2(6, 6), ivec2(6, 7),
	ivec2(7, 7),
	ivec2(0, 0), ivec2(0, 0), ivec2(0, 0), ivec2(0, 0)
};

const bool VA_has_B_TABLE[32] = {
	false, false, false, false, false, false, true,
	false, false, false, false, false, true,
	false, false, false, false, true,
	false, false, false, true,
	false, false, true,
	false, true,
	true,
	false, false, false, false
};


void vertex() {
	ivec4 color = ivec4(COLOR * 255.0);                    /* 0 -> 255 */
	bc = BC_TABLE[(color.a >> 6)];                         /* 11000000 */
	ea.r = (color.r >> 5);                                 /* 11100000 */
	ea.g = (color.g >> 5);                                 /* 11100000 */
	ea.b = (color.b >> 5);                                 /* 11100000 */
	va.g = (color.r & 31);                                 /* 00011111 */
	va.b = (color.g & 31);                                 /* 00011111 */
	va.r = (color.b & 31);                                 /* 00011111 */
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fragment_distance = distance(CAMERA_POSITION_WORLD, world_position);
}


void fragment() {
	vec3 ibc = vec3(1.0) - bc.rgb;
	vec3 scale = fragment_distance / fwidth(bc);
	vec4 EA_TABLE[] = {vec4(1.0, 0.0, 1.0, 1.0),
		J_color, C_color, U_color, F_color, V_color, M_color, B_color};

	/* blending between absolute and relative wireframe width */
	float c = max(max(bc.r, bc.g), bc.b);
	float blend = pow(2.0 * clamp(c - 0.5, 0.0, 0.5), wireframe_pow);
	scale = mix(scale, vec3(wireframe_scale), blend);

	/* finding if vertices edges contain B crease */
	bvec3 va_has_B = bvec3(false);
	va_has_B.r = VA_has_B_TABLE[va.r];
	va_has_B.g = VA_has_B_TABLE[va.g];
	va_has_B.b = VA_has_B_TABLE[va.b];

	/* obtaining wireframe edges and vertices colors */
	vec4 r = EA_TABLE[ea.r]; vec4 g = EA_TABLE[ea.g]; vec4 b = EA_TABLE[ea.b];
	vec4 ir = (EA_TABLE[VA_TABLE[va.r].x] + EA_TABLE[VA_TABLE[va.r].y]) * 0.5;
	vec4 ig = (EA_TABLE[VA_TABLE[va.g].x] + EA_TABLE[VA_TABLE[va.g].y]) * 0.5;
	vec4 ib = (EA_TABLE[VA_TABLE[va.b].x] + EA_TABLE[VA_TABLE[va.b].y]) * 0.5;

	/* coloring intersections with B creases without averaging */
	if (va.r != 27 && va_has_B.r) { ir = EA_TABLE[7]; }
	if (va.g != 27 && va_has_B.g) { ig = EA_TABLE[7]; }
	if (va.b != 27 && va_has_B.b) { ib = EA_TABLE[7]; }

	/* alpha blending edges and vertices colors */
	r.rgb = mix(albedo_color, r.rgb, r.a);
	g.rgb = mix(albedo_color, g.rgb, g.a);
	b.rgb = mix(albedo_color, b.rgb, b.a);
	ir.rgb = mix(albedo_color, ir.rgb, ir.a);
	ig.rgb = mix(albedo_color, ig.rgb, ig.a);
	ib.rgb = mix(albedo_color, ib.rgb, ib.a);

	/* wireframe width based on crease type */
	vec3 width_min = vec3(wireframe_width_min);
	vec3 width_max = vec3(wireframe_width_max);
	if (ea.r == 7) { width_min.r *= B_scale; width_max.r *= B_scale; }
	if (ea.g == 7) { width_min.g *= B_scale; width_max.g *= B_scale; }
	if (ea.b == 7) { width_min.b *= B_scale; width_max.b *= B_scale; }

	vec3 iwidth_min = vec3(wireframe_width_min);
	vec3 iwidth_max = vec3(wireframe_width_max);
	if (va_has_B.r) { iwidth_min.r *= B_scale; iwidth_max.r *= B_scale; }
	if (va_has_B.g) { iwidth_min.g *= B_scale; iwidth_max.g *= B_scale; }
	if (va_has_B.b) { iwidth_min.b *= B_scale; iwidth_max.b *= B_scale; }

	/* wireframe edges mask */
	vec3 mask = width_max;
	mask.r = min(width_max.r, bc.r * scale.r);
	mask.g = min(width_max.g, bc.g * scale.g);
	mask.b = min(width_max.b, bc.b * scale.b);
	mask.r = smoothstep(width_min.r, width_max.r, mask.r);
	mask.g = smoothstep(width_min.g, width_max.g, mask.g);
	mask.b = smoothstep(width_min.b, width_max.b, mask.b);

	/* wireframe vertices mask */
	vec3 imask = iwidth_max;
	imask.r = min(iwidth_max.r, ibc.r * scale.r);
	imask.g = min(iwidth_max.g, ibc.g * scale.g);
	imask.b = min(iwidth_max.b, ibc.b * scale.b);
	imask.r = smoothstep(iwidth_min.r, iwidth_max.r, imask.r);
	imask.g = smoothstep(iwidth_min.g, iwidth_max.g, imask.g);
	imask.b = smoothstep(iwidth_min.b, iwidth_max.b, imask.b);

	/* drawing vertices */
	vec3 ialbedo = vec3(ALBEDO);
	ialbedo = mix(ir.rgb, ialbedo, imask.r);
	ialbedo = mix(ig.rgb, ialbedo, imask.g);
	ialbedo = mix(ib.rgb, ialbedo, imask.b);

	/* drawing wireframe edges in the best possible order */
	vec3 albedo = vec3(ALBEDO);
	if (ea.r >= ea.g && ea.g >= ea.b) {
		albedo = mix(b.rgb, albedo, mask.b);
		albedo = mix(g.rgb, albedo, mask.g);
		albedo = mix(r.rgb, albedo, mask.r);
	} else if (ea.r >= ea.b && ea.b >= ea.g) {
		albedo = mix(g.rgb, albedo, mask.g);
		albedo = mix(b.rgb, albedo, mask.b);
		albedo = mix(r.rgb, albedo, mask.r);
	} else if (ea.b >= ea.r && ea.r >= ea.g) {
		albedo = mix(g.rgb, albedo, mask.g);
		albedo = mix(r.rgb, albedo, mask.r);
		albedo = mix(b.rgb, albedo, mask.b);
	} else if (ea.b >= ea.g && ea.g >= ea.r) {
		albedo = mix(r.rgb, albedo, mask.r);
		albedo = mix(g.rgb, albedo, mask.g);
		albedo = mix(b.rgb, albedo, mask.b);
	} else if (ea.g >= ea.r && ea.r >= ea.b) {
		albedo = mix(b.rgb, albedo, mask.b);
		albedo = mix(r.rgb, albedo, mask.r);
		albedo = mix(g.rgb, albedo, mask.g);
	} else if (ea.g >= ea.b && ea.b >= ea.r) {
		albedo = mix(r.rgb, albedo, mask.r);
		albedo = mix(b.rgb, albedo, mask.b);
		albedo = mix(g.rgb, albedo, mask.g);
	}

	albedo = clamp(albedo - ALBEDO, -1.0, 1.0);
	ialbedo = clamp(ialbedo - ALBEDO, -1.0, 1.0);
	ALBEDO += clamp(albedo + ialbedo, -1.0, 1.0);
}