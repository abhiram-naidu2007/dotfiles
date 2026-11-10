// own-colours
// A temple town across its tank. The gateway tower is a gopuram as the Dravida style builds it:
// a stone base with the doorway, receding storeys each with its own eave and its row of little
// domed shrines (they give the tower its toothed outline), a barrel-vaulted roof laid across
// the top and a row of pot finials (kalasha) on its ridge. Behind it: smaller towers, coconut
// palms and hills, each layer paler with distance and each sliding at its own speed as the
// view drifts or the pointer moves. Everything stands again in the water. On a dark mood it
// is dusk, with oil lamps on every storey and lamps afloat; on a light mood it is dawn, with
// mist, sun and birds.
const float YW = -0.40;                                     // the water line
const int STOREYS = 7;

float sdBox(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
float storeyWidth(float j, float W) { return W * (0.93 - 0.58 * pow(j / float(STOREYS), 0.85)); }

// distance to a gopuram standing on y = 0: half-width W at the foot, height H
float gopuram(vec2 p, float W, float H) {
    float hb = 0.20 * H, th = 0.60 * H / float(STOREYS);
    p.x = abs(p.x);
    float out_x = p.x - W * 1.12, out_y = max(p.y - H, -p.y - 0.02);
    if (out_x > 0.0 || out_y > 0.0) return max(out_x, out_y) + 0.004;       // well outside: no need for the storeys
    float d = sdBox(p - vec2(0.0, hb * 0.5), vec2(W, hb * 0.5));            // the stone base
    d = min(d, sdBox(p - vec2(0.0, hb * 0.05), vec2(W * 1.05, hb * 0.05)));  // its plinth
    d = min(d, sdBox(p - vec2(0.0, hb), vec2(W * 1.05, 0.010 * H)));         // and cornice
    float near = clamp(floor((p.y - hb) / th), 0.0, float(STOREYS - 1));    // only the storeys at this height matter
    for (float j = max(near - 1.0, 0.0); j <= min(near + 1.0, float(STOREYS - 1)); j += 1.0) {
        float w = storeyWidth(j, W), y0 = hb + j * th;
        d = min(d, sdBox(p - vec2(0.0, y0 + th * 0.5), vec2(w, th * 0.5)));
        d = min(d, sdBox(p - vec2(0.0, y0 + th * 0.84), vec2(w + 0.035 * W, th * 0.09)));       // the eave
        float sp = th * 0.40, bx = p.x - sp * (floor(p.x / sp) + 0.5);                         // little shrines along it
        if (p.x < w) d = min(d, length(vec2(bx, p.y - y0 - th * 0.95)) - th * 0.14);
        d = min(d, length(p - vec2(w + 0.012 * W, y0 + th * 0.99)) - th * 0.19);               // a larger one on the corner
    }
    float yt = hb + float(STOREYS) * th, wr = W * 0.46, hr = 0.105 * H, r = hr * 0.46;
    d = min(d, sdBox(p - vec2(0.0, yt + 0.010 * H), vec2(W * 0.37, 0.010 * H)));               // neck
    yt += 0.016 * H;
    d = min(d, sdBox(p - vec2(0.0, yt + hr * 0.5), vec2(wr - r, hr * 0.5 - r)) - r);            // barrel vault
    d = min(d, length(p - vec2(wr - r * 0.75, yt + hr * 0.56)) - r * 1.12);                    // its horseshoe gable
    for (int k = 0; k < 3; k++) {                                                              // finials
        vec2 c = vec2(wr * 0.36 * float(k), yt + hr);
        d = min(d, length(p - c - vec2(0.0, 0.010 * H)) - 0.011 * H);
        d = min(d, sdSeg(p, c, c + vec2(0.0, 0.040 * H)) - 0.0028 * H);
    }
    return d;
}
// oil lamps along the eaves of each storey (summed light)
float lamps(vec2 p, float W, float H, float t) {
    float hb = 0.20 * H, th = 0.60 * H / float(STOREYS);
    float j = floor((p.y - hb) / th - 0.34);
    if (j < 0.0 || j >= float(STOREYS) || abs(p.x) > W) return 0.0;
    float w = storeyWidth(j, W), sp = W * 0.105, id = floor(p.x / sp + 0.5);
    vec2 c = vec2(id * sp, hb + j * th + th * 0.84);
    if (abs(c.x) > w) return 0.0;
    float flick = 0.75 + 0.25 * sin(t * (5.0 + 4.0 * hash1(id + j * 13.0)) + id * 7.0 + j);
    return flick * exp(-dot(p - c, p - c) / (W * W * 0.0013));
}
// the opening in the middle of each storey, smaller with height
float openings(vec2 p, float W, float H) {
    float hb = 0.20 * H, th = 0.60 * H / float(STOREYS);
    float j = clamp(floor((p.y - hb) / th), 0.0, float(STOREYS - 1));
    return sdBox(p - vec2(0.0, hb + j * th + th * 0.36), vec2(storeyWidth(j, W) * 0.050, th * 0.20)) - th * 0.07;
}
// one frond of a palm: a bent spine a-b-c, fat in the middle, pointed at the tip, toothed with leaflets
float frond(vec2 p, vec2 a, vec2 b, vec2 c, float w) {
    vec2 pa = p - a, ba = b - a, pb = p - b, cb = c - b;
    float h1 = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0), h2 = clamp(dot(pb, cb) / dot(cb, cb), 0.0, 1.0);
    float d1 = length(pa - ba * h1), d2 = length(pb - cb * h2);
    float u = d1 < d2 ? h1 * 0.5 : 0.5 + h2 * 0.5;
    return min(d1, d2) - w * pow(sin(PI * clamp(u, 0.03, 1.0)), 0.55) * (0.50 + 0.50 * step(0.45, fract(u * 11.0)));
}
// a coconut palm: leaning trunk and a crown of fronds that arch out and hang
float palm(vec2 p, vec2 foot, float h, float lean, float t) {
    if (abs(p.x - foot.x - lean * 0.6) > h * 0.60 || p.y > foot.y + h * 1.30 || p.y < foot.y - 0.01) return 1.0;
    vec2 mid = foot + vec2(lean * 0.25, h * 0.55), top = foot + vec2(lean, h);
    float d = min(sdSeg(p, foot, mid), sdSeg(p, mid, top)) - h * 0.016;
    d = min(d, length(p - top) - h * 0.035);                                // the knot of the crown
    if (p.y < foot.y + h * 0.55) return d;
    float sway = 0.045 * sin(t * 0.6 + foot.x * 9.0);
    for (int k = 0; k < 9; k++) {
        float a = -0.50 + float(k) * 0.52 + sway * (1.0 + 0.3 * float(k)), L = h * (0.40 + 0.06 * sin(float(k) * 2.3 + foot.x * 5.0));
        vec2 dir = vec2(cos(a), sin(a));
        vec2 b = top + L * 0.55 * vec2(dir.x, dir.y * 0.85 + 0.12);
        vec2 c = b + L * 0.55 * vec2(dir.x * 0.80, dir.y * 0.25 - 0.62);
        d = min(d, frond(p, top, b, c, h * 0.030));
    }
    return d;
}
// thin cloud: three octaves are enough for long soft streaks
float streaks(vec2 p) { return 0.57 * noise(p) + 0.29 * noise(p * 2.03 + 17.3) + 0.14 * noise(p * 4.1 + 31.0); }

// everything above the water line
vec3 above(vec2 p, float t) {
    float day = u_light, y = (p.y - YW) / (1.0 - YW), pan = 0.10 * sin(t * 0.021);
    vec3 top = mix(vec3(0.035, 0.035, 0.125), vec3(0.500, 0.660, 0.880), day);
    vec3 mid = mix(vec3(0.250, 0.115, 0.310), vec3(0.960, 0.800, 0.780), day);
    vec3 low = mix(vec3(0.930, 0.450, 0.220), vec3(1.000, 0.880, 0.680), day);
    vec3 col = mix(low, mid, smoothstep(0.0, 0.36, y));
    col = mix(col, top, smoothstep(0.22, 0.95, y));
    vec2 orb = vec2(-0.62 - pan * 0.05, YW + mix(0.86, 0.34, day));
    float od = length(p - orb);
    if (day > 0.5) {                                        // the sun, just up
        col += vec3(1.0, 0.80, 0.50) * 0.50 * exp(-od * 2.6);
        col = mix(col, vec3(1.0, 0.965, 0.86), smoothstep(0.105, 0.098, od));
    } else if (y > 0.25) {                                  // stars, a thin moon, now and then a meteor
        vec2 g = (p + vec2(pan * 0.05, 0.0)) * 46.0, id = floor(g);
        float s = hash(id);
        if (s > 0.90) col += vec3(0.85, 0.85, 1.0) * smoothstep(0.30, 0.0, length(fract(g) - 0.5 - 0.3 * (vec2(hash(id + 1.7), hash(id + 5.1)) - 0.5)))
                             * (s - 0.90) * 9.0 * (0.55 + 0.45 * sin(t * (0.8 + s * 2.0) + s * 80.0)) * smoothstep(0.30, 0.75, y);
        float moon = smoothstep(0.060, 0.057, od) * smoothstep(0.052, 0.055, length(p - orb - vec2(0.024, 0.012)));
        col = mix(col, vec3(0.98, 0.93, 0.80), moon);
        col += vec3(0.30, 0.22, 0.30) * exp(-od * 6.0) * 0.5;
        float turn = floor(t / 41.0), ph = fract(t / 41.0) * 41.0;          // one meteor every 41 seconds, 0.9 s long
        if (ph < 0.9) {
            vec2 m0 = vec2(mix(-1.2, 1.2, hash1(turn * 3.7)), 0.55 + 0.35 * hash1(turn * 5.1)), dir = normalize(vec2(-0.8, -0.38));
            vec2 head = m0 + dir * ph * 0.9, rel = p - head;
            float along = dot(rel, -dir);
            col += vec3(0.9, 0.9, 1.0) * 0.8 * smoothstep(0.9, 0.0, ph) * smoothstep(0.0, 0.3, ph)
                   * smoothstep(0.0035, 0.0, length(rel + dir * clamp(along, 0.0, 0.16))) * smoothstep(0.16, 0.0, along);
        }
    }
    // long thin clouds, lit from below by the horizon
    if (y > 0.10) {
        float c = smoothstep(0.50, 0.78, streaks(vec2(p.x * 0.8 + t * 0.006, p.y * 7.0 + 3.0))) * smoothstep(0.10, 0.40, y) * smoothstep(1.0, 0.6, y);
        col = mix(col, mix(mix(vec3(0.980, 0.520, 0.330), vec3(1.0, 0.960, 0.920), day), mid, smoothstep(0.2, 0.8, y)), c * 0.55);
    }
    if (y > 0.86) return col;                               // above every roof and palm: only sky

    vec3 farc  = mix(vec3(0.420, 0.200, 0.300), vec3(0.840, 0.740, 0.780), day);
    vec3 midc  = mix(vec3(0.170, 0.080, 0.200), vec3(0.640, 0.560, 0.680), day);
    vec3 nearc = mix(vec3(0.050, 0.030, 0.085), vec3(0.400, 0.330, 0.470), day);
    vec3 stone = mix(vec3(0.085, 0.050, 0.120), vec3(0.480, 0.400, 0.520), day);
    vec3 flame = vec3(1.0, 0.72, 0.30);
    float g0 = YW;
    // far: hills and two small towers
    vec2 pf = p + vec2(pan * 0.35, 0.0);
    if (pf.y < g0 + 0.56) {
        float hills = pf.y < g0 + 0.24 ? pf.y - g0 - 0.10 - 0.085 * noise(vec2(pf.x * 1.7 + 4.0, 2.0)) - 0.03 * noise(vec2(pf.x * 5.1, 6.0)) : 1.0;
        hills = min(hills, gopuram(pf - vec2(-1.22, g0 + 0.10), 0.085, 0.42));
        hills = min(hills, gopuram(pf - vec2(1.36, g0 + 0.09), 0.065, 0.33));
        col = mix(col, farc, fill(hills));
    }
    // middle: a line of trees with palms above it
    vec2 pm = p + vec2(pan * 0.65, 0.0);
    if (pm.y < g0 + 0.66) {
        float tr = pm.y < g0 + 0.20 ? pm.y - g0 - 0.085 - 0.075 * noise(vec2(pm.x * 7.0, 5.0)) - 0.02 * noise(vec2(pm.x * 31.0, 9.0)) : 1.0;
        tr = min(tr, palm(pm, vec2(-1.02, g0 + 0.08), 0.38, 0.06, t));
        tr = min(tr, palm(pm, vec2(-0.80, g0 + 0.08), 0.28, -0.05, t));
        tr = min(tr, palm(pm, vec2(1.02, g0 + 0.08), 0.42, -0.07, t));
        tr = min(tr, palm(pm, vec2(1.62, g0 + 0.08), 0.31, 0.06, t));
        tr = min(tr, palm(pm, vec2(-1.58, g0 + 0.08), 0.34, 0.05, t));
        col = mix(col, midc, fill(tr));
    }
    // mist lying between the trees and the temple
    if (y < 0.26) {
        float mist = smoothstep(0.26, 0.0, y) * (0.35 + 0.65 * noise(vec2(p.x * 2.2 - t * 0.012, y * 7.0)));
        col = mix(col, mix(low, vec3(1.0, 0.93, 0.84), day), mist * mix(0.30, 0.55, day));
    }
    // near: the wall, a gate tower each side, and the great gopuram
    vec2 pn = p + vec2(pan, 0.0);
    vec2 pg = pn - vec2(0.30, g0);
    float wall = sdBox(pn - vec2(0.30, g0 + 0.045), vec2(1.30, 0.045));
    wall = min(wall, sdBox(pn - vec2(0.30, g0 + 0.094), vec2(1.31, 0.005)));                 // coping
    float d = min(wall, gopuram(pg, 0.30, 1.16));
    d = min(d, gopuram(pn - vec2(-0.78, g0), 0.105, 0.44));
    d = min(d, gopuram(pn - vec2(1.42, g0), 0.105, 0.44));
    if (d < 0.02) {
        vec3 body = stone * (0.96 + 0.06 * smoothstep(0.25, 0.75, abs(fract(pn.x * 52.0) - 0.5) * 2.0));   // rows of carved figures
        body = mix(body, mix(stone, low, 0.32), smoothstep(-0.010, 0.0, d) * 0.8);          // edges catch the sky
        // the wall of a temple is striped red and white
        if (wall < 0.0 && d == wall) body = mix(stone, mix(vec3(0.300, 0.110, 0.130), vec3(0.900, 0.800, 0.800), day), step(0.5, fract(pn.x * 22.0)) * 0.50);
        col = mix(col, body, fill(d));
        float open = min(openings(pg, 0.30, 1.16), sdBox(pg - vec2(0.0, 0.080), vec2(0.046, 0.080)) - 0.008);
        if (day < 0.5) {
            // doorway and the openings above it: light from inside, and its glow on the stone
            col = mix(col, mix(vec3(0.95, 0.52, 0.20), vec3(1.0, 0.84, 0.48), smoothstep(0.30, 0.0, pg.y)), fill(open));
            col += flame * 0.22 * exp(-max(open, 0.0) * 22.0) * fill(d);
        } else col = mix(col, stone * 0.55, fill(open));
    }
    if (day < 0.5) {
        float l = lamps(pg, 0.30, 1.16, t) + 0.8 * lamps(pn - vec2(-0.78, g0), 0.105, 0.44, t) + 0.8 * lamps(pn - vec2(1.42, g0), 0.105, 0.44, t);
        vec2 wl = vec2((fract(pn.x / 0.085) - 0.5) * 0.085, pn.y - g0 - 0.106);            // lamps along the wall
        l += 0.8 * exp(-dot(wl, wl) / 0.00010) * step(abs(pn.x - 0.30), 1.30) * (0.8 + 0.2 * sin(t * 6.0 + floor(pn.x / 0.085) * 5.0));
        col += flame * l * 0.95;
        col += flame * 0.10 * exp(-length(pg - vec2(0.0, 0.5)) * 2.4);                      // lamp haze around the tower
    } else {
        for (int k = 0; k < 5; k++) {                       // birds
            float fk = float(k), ph = fract(t * (0.012 + 0.004 * hash1(fk + 2.0)) + hash1(fk));
            vec2 b = p - vec2(ph * 4.4 - 2.2, 0.30 + 0.40 * hash1(fk + 7.0) + 0.03 * sin(t * 0.5 + fk));
            float flap = 0.35 * sin(t * 6.0 + fk * 2.0), s = 0.022;
            float bd = min(sdSeg(b, vec2(0.0), s * vec2(-1.0, 0.45 + flap)), sdSeg(b, vec2(0.0), s * vec2(1.0, 0.45 + flap)));
            col = mix(col, nearc, stroke(bd, 0.0022));
        }
    }
    return col;
}

vec3 scene(vec2 uv, vec2 q, float t) {
    float day = u_light;
    vec3 col;
    if (q.y >= YW) col = above(q, t);
    else {
        // the tank: the same view upside down, shaken by ripples that grow towards the viewer
        float depth = YW - q.y;
        vec2 r = vec2(q.x, YW + depth);
        float rip = noise(vec2(q.x * 9.0 + t * 0.15, depth * 70.0 - t * 0.9)) - 0.5;
        r.x += rip * 0.035 * (0.25 + depth * 2.2);
        r.y += rip * 0.020 * (0.25 + depth * 2.2);
        col = above(r, t);
        vec3 water = mix(vec3(0.040, 0.030, 0.100), vec3(0.560, 0.560, 0.700), day);
        col = mix(col, water, 0.22 + 0.45 * smoothstep(0.0, 0.6, depth));
        col += mix(0.04, 0.07, day) * smoothstep(0.62, 0.9, noise(vec2(q.x * 6.0 - t * 0.1, depth * 150.0)));   // glints
        // stone steps down to the water
        float pan = 0.10 * sin(t * 0.021);
        vec3 stair = mix(vec3(0.120, 0.075, 0.150), vec3(0.560, 0.490, 0.580), day);
        col = mix(col, stair * (0.80 + 0.20 * step(0.5, fract(depth / 0.015))), smoothstep(0.045, 0.042, depth) * step(abs(q.x - 0.30 + pan), 1.30));
        if (day < 0.5) {                                    // lamps set afloat
            for (int k = 0; k < 9; k++) {
                float fk = float(k), dz = 0.10 + 0.50 * hash1(fk * 3.1 + 1.0);
                vec2 c = vec2(mod(hash1(fk * 7.7) * 4.0 + t * 0.010 * (1.0 + fk * 0.2), 4.0) - 2.0 - pan * (1.0 + dz), YW - dz + 0.004 * sin(t * 1.3 + fk));
                float size = 0.5 + dz * 1.6, flick = 0.8 + 0.2 * sin(t * 7.0 + fk * 4.0);
                vec2 e = q - c;
                if (abs(e.x) > 0.25) continue;
                col += vec3(1.0, 0.72, 0.30) * flick * (exp(-dot(e, e) / (0.00016 * size * size))
                       + 0.30 * exp(-abs(e.x) / (0.006 * size)) * exp(-max(-e.y, 0.0) / (0.05 * size)) * step(e.y, 0.0)
                       + 0.10 * exp(-length(e) / (0.03 * size)));
            }
        }
    }
    return col * (1.0 - 0.20 * smoothstep(0.9, 2.1, length(q)));           // the corners fall off a little
}
