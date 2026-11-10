// Chladni figures: sand on a vibrating plate gathers where the plate stands still.
// The plate's mode numbers drift, so the figure keeps reorganising itself.
vec3 scene(vec2 uv, vec2 q, float t) {
    float n = 3.0 + 2.0 * sin(t * 0.043), m = 5.0 + 2.4 * cos(t * 0.031);
    vec2 p = q * 0.5 * PI;
    float f = cos(n * p.x) * cos(m * p.y) - cos(m * p.x) * cos(n * p.y);     // nodal lines: f = 0
    float sand = exp(-abs(f) * 11.0);
    sand *= 0.55 + 0.45 * hash(floor(gl_FragCoord.xy));                       // grains
    vec3 grain = mix(u_a, u_b, 0.5 + 0.5 * sin(atan(q.y, q.x) * 2.0 + t * 0.05));
    vec3 back = mix(u_bg, u_deep, smoothstep(0.3, 1.9, length(q)));
    return mix(back, mix(grain, u_fg, 0.25), sand * (u_light > 0.5 ? 0.85 : 0.95));
}
