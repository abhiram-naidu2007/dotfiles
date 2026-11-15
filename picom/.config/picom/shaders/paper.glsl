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
const float SAT_INK = 0.35;
const float GAP = 0.48;
const float TEXT_ON = 0.72;

const ivec2 RING[8] = ivec2[8](
    ivec2(2, 0), ivec2(-2, 0), ivec2(0, 2), ivec2(0, -2),
    ivec2(3, 3), ivec2(-3, -3), ivec2(3, -3), ivec2(-3, 3));

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

float tone(vec3 rgb) {
    float top = max(rgb.r, max(rgb.g, rgb.b));
    float sat = top - min(rgb.r, min(rgb.g, rgb.b));
    return lstar(luma(rgb * (1.0 - SAT_INK * sat * top)));
}

float tone_at(ivec2 p) {
    vec4 c = texelFetch(tex, clamp(p, ivec2(0), textureSize(tex, 0) - 1), 0);
    return c.a > 0.0 ? tone(c.rgb / c.a) : 1.0;
}

vec4 window_shader() {
    ivec2 p = ivec2(texcoord);
    vec4 c = texelFetch(tex, p, 0);
    if (c.a <= 0.0) return default_post_processing(c);
    vec3 rgb = c.rgb / c.a;

    float l = tone(rgb);
    float hi = l, sum = 0.0;
    for (int i = 0; i < 8; i++) {
        float t = tone_at(p + RING[i]);
        hi = max(hi, t);
        sum += t;
    }
    float d = hi - l;
    if (hi > TEXT_ON && hi - sum / 8.0 < 0.5 * d + 0.05 && d > 0.02 && d < GAP)
        l = hi - mix(d, GAP, clamp((d - 0.02) / 0.06, 0.0, 1.0));

    float n = min(min(tone_at(p + ivec2(1, 0)), tone_at(p - ivec2(1, 0))),
                  min(tone_at(p + ivec2(0, 1)), tone_at(p - ivec2(0, 1))));
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
