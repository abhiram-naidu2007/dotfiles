#version 330 core
// Shared by every scene file in this folder. A scene is one function:
//     vec3 scene(vec2 uv, vec2 q, float t)
// uv: 0..1 across the screen (y up). q: centred, y from -1 to 1, x from -aspect to aspect.
// t: seconds (it only runs while the wallpaper is in view). px: the size of one pixel in q units.
// Colours of the desktop palette (sRGB): u_bg u_deep u_fg u_a u_b (accents) and the six named ones.
// u_light is 1 on a light mood (day, paper), 0 at night.
// Directives, as comments on the first lines of a scene file:
//     // scale 0.66      draw at two thirds of the screen size (soft pictures, less GPU work)
//     // own-colours     the scene has colours of its own; `rice` then reads the desktop palette from it
uniform float u_time;
uniform vec2 u_res;
uniform float u_light;
uniform vec3 u_bg, u_deep, u_fg, u_a, u_b, u_red, u_green, u_yellow, u_blue, u_magenta, u_cyan;
out vec4 frag;

const float PI = 3.14159265, TAU = 6.2831853;
float px;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + 17.3; a *= 0.5; }
    return v;
}
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// distances: negative inside
float sdSeg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a, ba = b - a; return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)); }
float sdTri(vec2 p, vec2 a, vec2 b, vec2 c) {
    vec2 e0 = b - a, e1 = c - b, e2 = a - c, v0 = p - a, v1 = p - b, v2 = p - c;
    vec2 q0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 q1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 q2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(q0, q0), s * (v0.x * e0.y - v0.y * e0.x)), vec2(dot(q1, q1), s * (v1.x * e1.y - v1.y * e1.x))),
                 vec2(dot(q2, q2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}
// coverage of a filled shape / of a stroke of half-width w, one pixel of soft edge
float fill(float d) { return smoothstep(px, -px, d); }
float stroke(float d, float w) { return smoothstep(w + px, w - px, abs(d)); }
