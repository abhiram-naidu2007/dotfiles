// scale 0.8
// Manga night: screentone sky, a halftone moon, drawn clouds crossing it, a sea of wave scales
// (seigaiha), and petals in the one spot colour. Ink and paper are the desktop's own text and
// background colours, so the page inverts with the mood like a negative.
float tone(vec2 q, float freq, float level) {                  // dots on a 45 degree grid; level = how dark
    vec2 c = fract(rot(0.785398) * q * freq) - 0.5;
    float rad = sqrt(clamp(level, 0.0, 1.0)) * 0.56, soft = freq * px * 0.8;
    return smoothstep(rad + soft, rad - soft, length(c));
}
float cloudBank(vec2 q, float y, float speed, float seed, float t) {
    float x = q.x + t * speed + seed * 3.7, cell = floor(x / 1.5), d = 1e9;
    for (int k = -1; k <= 1; k++) {
        float id = cell + float(k), h = hash1(id * 7.3 + seed);
        vec2 c = vec2((id + 0.5) * 1.5 + (h - 0.5) * 0.5, y + (h - 0.5) * 0.10);
        vec2 p = vec2(x, q.y) - c;
        d = min(d, sdSeg(p, vec2(-0.34 - 0.14 * h, 0.0), vec2(0.34 + 0.10 * h, 0.0)) - 0.060);
        d = min(d, sdSeg(p, vec2(-0.16, 0.070), vec2(0.20 + 0.10 * h, 0.070)) - 0.048);
        d = min(d, sdSeg(p, vec2(-0.26 + 0.10 * h, -0.066), vec2(0.10, -0.066)) - 0.042);
    }
    return d;
}
vec3 scene(vec2 uv, vec2 q, float t) {
    vec3 paper = u_bg, ink = u_fg, spot = u_a;
    // sky: screentone, denser toward the top
    vec3 col = mix(paper, ink, 0.42 * tone(q, 46.0, 0.06 + 0.30 * smoothstep(-0.3, 1.0, q.y)));
    // moon: a disc of ink with craters in tone, and one clean outline
    vec2 mp = q - vec2(0.62, 0.26);
    float md = length(mp) - 0.42;
    vec3 moon = mix(ink, paper, 0.55 * tone(mp, 58.0, 0.55 * smoothstep(0.42, 0.62, fbm(mp * 3.2 + 4.0))));
    col = mix(col, moon, fill(md));
    col = mix(col, spot, stroke(md - 0.022, 0.004));
    // clouds: flat paper shapes with a double ink line
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float d = cloudBank(q, 0.50 - fi * 0.27, 0.010 + 0.006 * fi, fi + 1.0, t);
        col = mix(col, paper, fill(d));
        col = mix(col, ink, stroke(d, 0.0045));
        col = mix(col, ink, 0.6 * stroke(d + 0.020, 0.0022));
    }
    // sea: rows of overlapping scales, each a set of concentric arcs; nearer rows cover farther ones
    float top = -0.40 + 0.025 * sin(q.x * 2.2 + t * 0.35);
    if (q.y < top) {
        const float W = 0.26, R = 0.13, H = 0.065;
        float y = q.y + 1.10, row = floor(y / H);
        vec3 sea = paper;
        for (int k = 1; k >= 0; k--) {                          // the lower row first: it lies on top
            float j = row - float(k);
            float x = q.x + t * 0.012 * (mod(j, 2.0) < 1.0 ? 1.0 : -1.0) + mod(j, 2.0) * 0.5 * W;
            float cx = (floor(x / W) + 0.5) * W;
            float d = length(vec2(x - cx, y - j * H));
            if (d < R) {
                float arcs = max(max(stroke(d - R, 0.004), stroke(d - R * 0.74, 0.003)), max(stroke(d - R * 0.48, 0.003), stroke(d - R * 0.22, 0.003)));
                sea = mix(paper, ink, arcs);
                sea = mix(sea, ink, 0.30 * tone(q, 70.0, 0.25) * step(d, R * 0.22));
                break;
            }
        }
        col = sea;
        col = mix(col, ink, stroke(q.y - top, 0.005));
    }
    // petals on the wind
    for (int i = 0; i < 16; i++) {
        float fi = float(i), h = hash1(fi * 12.9);
        vec2 p = vec2(mod(h * 4.0 + t * (0.035 + 0.03 * h), 4.0) - 2.0, mod(1.1 - hash1(fi * 3.1) * 2.2 - t * (0.045 + 0.03 * h), 2.2) - 1.1);
        p.x += 0.05 * sin(t * 0.9 + fi);
        vec2 l = rot(t * (0.5 + h) + fi) * (q - p);
        col = mix(col, spot, fill((length(l / vec2(0.020, 0.011)) - 1.0) * 0.011));
    }
    return col;
}
