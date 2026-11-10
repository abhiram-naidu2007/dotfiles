#version 330
// E-ink for `rice mode paper`: every window is redrawn as ink on warm paper.
// Brightness decides how much ink a pixel gets; a little of the original colour
// is kept so links, syntax and pictures stay tellable apart; static grain gives
// the sheet some tooth. Loaded through ~/.config/picom/mode.conf.
in vec2 texcoord;
uniform sampler2D tex;
vec4 default_post_processing(vec4 c);

const vec3 PAPER = vec3(0.945, 0.906, 0.824);   // #f1e7d2, the paper palette's background
const vec3 INK   = vec3(0.169, 0.149, 0.106);   // #2b261b, its text colour
const float KEEP_COLOUR = 0.30;
const float GRAIN = 0.022;

float grain(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

vec4 window_shader() {
    vec4 c = texelFetch(tex, ivec2(texcoord), 0);
    if (c.a <= 0.0) {
        return default_post_processing(c);
    }
    vec3 rgb = c.rgb / c.a;                                   // textures are premultiplied
    float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
    vec3 tone = mix(vec3(luma), rgb, KEEP_COLOUR);
    tone = smoothstep(0.0, 0.92, tone);                       // paper white is reached a little early
    vec3 page = INK + (PAPER - INK) * tone + grain(floor(texcoord)) * GRAIN;
    return default_post_processing(vec4(clamp(page, 0.0, 1.0) * c.a, c.a));
}
