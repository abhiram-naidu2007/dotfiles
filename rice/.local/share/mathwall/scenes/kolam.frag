// Sikku kolam: one dot per tile, and a line that goes round every dot. Where two neighbouring
// dots are "linked" the lines cross between them; where they are not, the line turns back
// around its dot. Any such choice with no loose ends is a kolam (the square-tile model of
// arXiv:2304.14134). Here the links are chosen with four-fold symmetry and a few of them change
// every twenty seconds: a crossing eases open into two turns, or two turns close into a crossing.
// Rice flour is the desktop's text colour, the ground its background, the dots its accent.
const float N = 5.0;                                        // dots from the centre to a tip of the diamond

float inside(vec2 c) { return step(abs(c.x) + abs(c.y), N + 0.01); }
// 1 = the line turns back at the edge between tiles a and b, 0 = it crosses there
float gate(vec2 a, vec2 b, float t) {
    if (inside(a) * inside(b) < 0.5) return 1.0;            // the rim: always turned back, no loose ends
    vec2 m = abs((a + b) * 0.5);
    m = vec2(max(m.x, m.y), min(m.x, m.y));                 // the same choice in all eight mirror images
    float epoch = floor(t / 20.0), f = smoothstep(0.80, 1.0, fract(t / 20.0));
    float now = step(0.66, hash(m * 7.31 + epoch * 1.37)), next = step(0.66, hash(m * 7.31 + (epoch + 1.0) * 1.37));
    return mix(now, next, f);
}
// a square with a different radius on each corner (Inigo Quilez)
float roundBox(vec2 p, float b, vec4 r) {
    r.xy = p.x > 0.0 ? r.xy : r.zw;
    r.x = p.y > 0.0 ? r.x : r.y;
    vec2 d = abs(p) - b + r.x;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r.x;
}
vec3 scene(vec2 uv, vec2 q, float t) {
    float cell = 0.80 / (N + 0.5);                          // the whole diamond fits the height of the screen
    vec2 g = q / cell, c = floor(g + 0.5), p = g - c;       // c: which dot, p: position inside its tile
    vec3 ground = mix(u_bg, u_deep, smoothstep(0.4, 1.9, length(q))) * (0.955 + 0.05 * noise(q * 3.0));
    float grain = 0.80 + 0.20 * noise(q * 260.0);           // powder, not paint
    // the border: two lines of red ochre (kaavi) round the whole drawing, and a row of dots between them
    float rim = (abs(q.x) + abs(q.y)) * 0.70710678 - (N + 1.15) * cell * 0.70710678;
    ground = mix(ground, u_a, 0.55 * grain * (stroke(rim, 0.0035) + stroke(rim - 0.034, 0.0022)));
    vec2 along = vec2(abs(q.x) - abs(q.y), 0.0) * 0.70710678;
    ground = mix(ground, u_fg, 0.60 * grain * fill(length(vec2(mod(along.x + 0.017, 0.034) - 0.017, rim - 0.017)) - 0.0042));
    if (inside(c) < 0.5) return ground;
    // The line round a dot is a diamond through the middles of the tile's edges; turned 45 degrees
    // it is a square, and a turned-back edge is that square's corner rounded off.
    vec2 r = vec2(p.x + p.y, p.y - p.x) * 0.70710678;
    float s = 0.35355339, R = 0.30;
    vec4 radii = R * vec4(gate(c, c + vec2(0, 1), t), gate(c, c + vec2(1, 0), t), gate(c, c + vec2(-1, 0), t), gate(c, c + vec2(0, -1), t));
    float d = roundBox(r, s, radii) * cell;
    vec3 col = ground;
    col += u_fg * 0.05 * exp(-abs(d) * 55.0);               // a little light off the white line
    col = mix(col, u_fg, 0.92 * grain * stroke(d, 0.0046));
    col = mix(col, u_a, fill(length(p) * cell - 0.010));
    return col;
}
