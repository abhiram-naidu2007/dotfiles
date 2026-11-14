#version 330
in vec2 texcoord;
uniform sampler2D tex;
vec4 default_post_processing(vec4 c);

const vec3 PAPER = vec3(0.890, 0.882, 0.863);
const vec3 INK = vec3(0.247, 0.243, 0.235);
const float LEVELS = 15.0;
const float COLOUR = 0.18;
const float SPREAD = 0.14;
const float FIBRE = 0.014;

const float BAYER[16] = float[16](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0);

vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
float luma(vec3 c) { return dot(lin(c), vec3(0.2126, 0.7152, 0.0722)); }
float lstar(float y) { return y > 0.008856 ? 1.16 * pow(y, 1.0 / 3.0) - 0.16 : y * 9.033; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 straight(ivec2 p) {
    vec4 c = texelFetch(tex, p, 0);
    return c.a > 0.0 ? c.rgb / c.a : vec3(1.0);
}

vec4 window_shader() {
    ivec2 p = ivec2(texcoord);
    vec4 c = texelFetch(tex, p, 0);
    if (c.a <= 0.0) return default_post_processing(c);
    vec3 rgb = c.rgb / c.a;

    float l = lstar(luma(rgb));
    float n = min(min(lstar(luma(straight(p + ivec2(1, 0)))), lstar(luma(straight(p - ivec2(1, 0))))),
                  min(lstar(luma(straight(p + ivec2(0, 1)))), lstar(luma(straight(p - ivec2(0, 1))))));
    l = mix(l, min(l, n), SPREAD);

    ivec2 s = ivec2(gl_FragCoord.xy) & 3;
    float threshold = (BAYER[s.y * 4 + s.x] + 0.5) / 16.0 - 0.5;
    float q = clamp(floor(clamp(l, 0.0, 1.0) * LEVELS + 0.5 + threshold * 0.9) / LEVELS, 0.0, 1.0);

    vec3 page = lin(INK) + (lin(PAPER) - lin(INK)) * q;
    vec3 tint = lin(rgb) / max(luma(rgb), 1e-3) * dot(page, vec3(0.2126, 0.7152, 0.0722));
    page = mix(page, tint, COLOUR * (1.0 - q * 0.6));

    vec2 g = gl_FragCoord.xy;
    float fibre = vnoise(g * vec2(0.9, 0.22)) * 0.6 + vnoise(g * 0.45) * 0.4 - 0.5;
    page *= 1.0 + fibre * FIBRE * q;

    vec3 outc = clamp(srgb(page), 0.0, 1.0);
    return default_post_processing(vec4(outc * c.a, c.a));
}
