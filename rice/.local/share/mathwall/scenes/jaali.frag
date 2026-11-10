// Jaali: the pierced stone screens of Mughal buildings. Three pointed arches, each filled with
// the oldest lattice of that tradition: eight-pointed stars (two squares, one turned 45 degrees)
// with crosses between them. The stone is the band along every edge of that tiling.
// A light moves slowly behind the wall. It shows the thickness of the stone, spills round the
// arches and throws the pattern on the floor, where it slides as the light moves. Far off,
// through the holes, stands a domed tomb. All colours are the desktop's.
const float FLOOR = -0.58, CELL = 0.20, BAND = 0.015;

float sdBox(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
// a pointed arch on the axis x = 0: straight sides up to `spring`, then two arcs that meet
float archD(vec2 p, float W, float spring) {
    float x = abs(p.x);
    return p.y < spring ? x - W : length(vec2(x + 0.6 * W, p.y - spring)) - 1.6 * W;
}
float arches(vec2 p) { return min(archD(p, 0.50, -0.02), archD(vec2(abs(p.x) - 1.20, p.y), 0.32, -0.14)); }
// distance to the edge between star tiles and cross tiles, for a lattice of spacing 1
float star(vec2 p) {
    p = abs(fract(p + 0.5) - 0.5);
    return min(max(p.x, p.y), (p.x + p.y) * 0.70710678) - 0.35355339;
}
// how open the wall is at p: 1 in a hole of the lattice inside an arch, 0 on stone
float opening(vec2 p, float soft) {
    float s = abs(star(p / CELL)) * CELL - BAND;
    return smoothstep(soft, -soft, arches(p) + 0.024) * smoothstep(-soft, soft, s) * step(FLOOR, p.y);
}

vec3 scene(vec2 uv, vec2 q, float t) {
    vec2 c = vec2(1.25 * sin(t * 0.045), 0.22 + 0.20 * sin(t * 0.031 + 1.0));      // the light behind the wall
    vec2 sway = vec2(sin(t * 0.11), cos(t * 0.083)) * 0.006;                        // the viewer shifts a little
    vec3 stone = mix(u_bg, u_fg, mix(0.10, 0.24, u_light));
    vec3 light = mix(u_a, vec3(1.0), mix(0.30, 0.55, u_light));
    float r2 = dot(q - c, q - c), g = exp(-r2 * 1.3), core = exp(-r2 * 18.0);
    vec3 col;
    float a = arches(q);
    if (q.y >= FLOOR && a < px) {
        // outside: the glow of the light, and the tomb against it
        vec3 sky = mix(u_deep * 0.6 + u_a * 0.75 * g + mix(u_b, vec3(1.0), 0.65) * 0.85 * core,
                       mix(mix(u_bg, vec3(1.0), 0.8), u_a, 0.38 * g) + 0.15 * core, u_light);
        vec2 m = q + sway * 4.0 - vec2(0.0, FLOOR);
        float tomb = length(m - vec2(0.0, 0.40)) - 0.17;                                        // the great dome
        tomb = min(tomb, sdTri(m, vec2(-0.05, 0.55), vec2(0.05, 0.55), vec2(0.0, 0.66)));       // its point
        tomb = min(tomb, sdBox(m - vec2(0.0, 0.16), vec2(0.30, 0.16)));                         // the body
        tomb = min(tomb, length(vec2(abs(m.x) - 0.215, m.y - 0.36)) - 0.06);                    // small domes
        tomb = min(tomb, sdBox(vec2(abs(m.x) - 0.43, m.y - 0.24), vec2(0.016, 0.24)));          // minarets
        tomb = min(tomb, length(vec2(abs(m.x) - 0.43, m.y - 0.49)) - 0.026);
        sky = mix(sky, mix(u_deep * 0.35, mix(u_bg, u_fg, 0.45), u_light), 0.62 * fill(tomb));

        // the screen: its back edge (seen a little smaller, being further away), then its face
        float s = star(q / CELL), front = abs(s) * CELL - BAND;
        float back = abs(star((q * 1.014 + sway) / CELL)) * CELL - BAND;
        vec2 e = vec2(px, 0.0) / CELL;
        vec2 gr = vec2(star(q / CELL + e.xy) - star(q / CELL - e.xy), star(q / CELL + e.yx) - star(q / CELL - e.yx));
        gr = normalize(gr + 1e-6) * sign(s);                                                   // pointing off the band
        float bevel = smoothstep(0.30, 1.0, abs(s) * CELL / BAND);
        vec3 face = stone * (1.0 + 0.34 * dot(gr, vec2(-0.5, 0.86)) * bevel);                  // lit from up and left
        vec3 inner = mix(stone * 0.55, light, 0.34 * g + 0.30 * core);                         // the thickness catches the light
        col = mix(sky, inner, fill(back));
        col = mix(col, face, fill(front));
        col = mix(col, stone * 0.86, smoothstep(-0.028, -0.022, a));                           // the rim of each panel
    }
    if (q.y >= FLOOR) {
        // the wall round the arches
        vec3 wall = stone * (0.93 + 0.10 * noise(q * 3.0));
        wall += light * 0.20 * exp(-max(a, 0.0) * 7.0) * (0.25 + 0.75 * g);                    // light spilling round the arch
        wall = mix(wall, stone * 1.22, 0.7 * stroke(a - 0.034, 0.0045));
        wall = mix(wall, u_a, 0.55 * stroke(a - 0.060, 0.0022));                               // an inlaid line
        col = a < -px ? col : mix(col, wall, smoothstep(-px, px, a));
        col = mix(col, stone * 0.70, smoothstep(FLOOR + 0.016, FLOOR + 0.012, q.y));           // skirting
    } else {
        // the floor, receding towards the wall, with the pattern the light throws on it
        float z = (FLOOR - q.y) / (FLOOR + 1.0);
        float X = q.x / (1.0 + 0.50 * z), Z = z * 0.80;
        vec2 w = vec2(X + c.x * 0.6 * Z, FLOOR + Z * (0.75 + 0.9 * c.y));
        float lit = opening(w, px * (1.5 + 12.0 * z));
        vec3 ground = stone * (0.80 - 0.10 * z) * (1.0 - 0.06 * step(0.5, fract(X / 0.40 + 0.5 * step(0.5, fract(Z / 0.28)))));
        col = mix(ground, mix(ground, light, mix(0.50, 0.60, u_light)), lit * (1.0 - 0.35 * z));
    }
    // dust in the light
    vec2 dg = q * 9.0 + vec2(t * 0.05, -t * 0.07), id = floor(dg);
    float h = hash(id);
    if (h > 0.78) col += light * (h - 0.78) * 2.2 * (1.0 - 0.75 * u_light) * exp(-r2 * 0.9) * (0.5 + 0.5 * sin(t * (0.5 + h) + h * 50.0))
                         * smoothstep(0.09, 0.0, length(fract(dg) - 0.5 - 0.3 * (vec2(hash(id + 1.0), hash(id + 2.0)) - 0.5)));
    return col * (1.0 - 0.18 * smoothstep(0.9, 2.0, length(q)));
}
