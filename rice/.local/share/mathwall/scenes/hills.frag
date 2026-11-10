// scale 0.5
// own-colours
// A slow flight over grass hills and lakes, painted like a film background. The land is a real
// height field and every pixel is a ray walked through it, so near slopes slide past faster
// than far ones and haze thickens with distance. The clouds overhead sit on a plane at a fixed
// height, throw their shadows on the grass below them and show in the water. By day: sun,
// cumulus, flowers. On a dark mood: moonlight, stars and fireflies.
const vec3 SUN = vec3(-0.591, 0.645, 0.484);
const vec3 MOON = vec3(0.262, 0.332, 0.906);
const float DECK = 14.0;                                    // height of the cloud plane
const float WATER = 0.66;                                   // level of the lakes

float broad(vec2 p) { return 1.7 * noise(p * 0.15); }
float woodAt(vec2 p) { return smoothstep(0.60, 0.68, noise(p * 0.21 + 40.0)); }
float land(vec2 p) {
    float h = broad(p) + 0.42 * noise(p * 0.41 + 11.7);
    float w = woodAt(p);
    if (w > 0.0) h += w * (0.16 + 0.12 * noise(p * 3.0));   // tree tops: a bumpy raised patch
    return h;
}
float ground(vec2 p) { return max(land(p), WATER); }
float deck(vec2 p, float t) { return fbm(p * 0.07 + vec2(t * 0.016, 0.0)); }
// round lobes with creases between them
float lobes(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * abs(2.0 * noise(p) - 1.0); p = p * 2.1 + 5.3; a *= 0.5; }
    return v;
}

vec3 sky(vec3 rd, vec3 ro, float t, float day) {
    float e = max(rd.y, 0.0), a = atan(rd.x, rd.z);
    vec3 zenith = mix(vec3(0.020, 0.045, 0.130), vec3(0.130, 0.400, 0.860), day);
    vec3 low    = mix(vec3(0.150, 0.210, 0.380), vec3(0.720, 0.870, 0.970), day);
    vec3 lit    = mix(vec3(0.520, 0.600, 0.780), vec3(1.000, 0.985, 0.950), day);
    vec3 shade  = mix(vec3(0.085, 0.120, 0.240), vec3(0.540, 0.660, 0.870), day);
    vec3 col = mix(low, zenith, pow(e, 0.55));
    if (day < 0.5) {                                        // stars and the moon
        vec2 g = vec2(a * 60.0, e * 90.0), id = floor(g);
        float s = hash(id);
        if (s > 0.93) col += vec3(0.8, 0.85, 1.0) * smoothstep(0.35, 0.0, length(fract(g) - 0.5)) * (s - 0.93) * 12.0
                             * (0.6 + 0.4 * sin(t * (1.0 + s * 3.0) + s * 90.0)) * smoothstep(0.02, 0.2, e);
        float m = acos(clamp(dot(rd, MOON), -1.0, 1.0));
        col += vec3(0.30, 0.36, 0.52) * exp(-m * 7.0);
        col = mix(col, vec3(0.96, 0.95, 0.88), smoothstep(0.040, 0.036, m));
    }
    // clouds overhead: a plane, so they shrink towards the horizon and drift with the wind
    if (rd.y > 0.03) {
        float tc = (DECK - ro.y) / rd.y;
        vec2 cp = ro.xz + rd.xz * tc;
        float d = deck(cp, t);
        float cover = smoothstep(0.55, 0.63, d) * exp(-tc * 0.010);
        float l = smoothstep(-0.02, 0.10, d - deck(cp + SUN.xz * 3.0, t));
        col = mix(col, mix(shade, lit, 0.30 + 0.70 * l), cover * 0.94);
    }
    // heaped clouds standing on the horizon
    float skyline = fbm(vec2(a * 1.9 + t * 0.003, 3.0));
    float top = 0.03 + (0.26 + 0.12 * noise(vec2(a * 6.0 + t * 0.004, 9.0))) * smoothstep(0.42, 0.58, skyline);
    float lb = lobes(vec2(a * 6.0 + t * 0.004, e * 11.0));
    float bank = smoothstep(0.0, 0.025, top + (lb - 0.35) * 0.16 - e);
    float up = clamp(e / max(top, 0.05), 0.0, 1.0);
    vec3 cc = mix(shade, lit, smoothstep(0.15, 0.95, up + (lb - 0.3) * 0.9));
    cc = mix(low, cc, smoothstep(0.0, 0.10, e));            // their feet dissolve in haze
    return mix(col, cc, bank);
}

vec3 scene(vec2 uv, vec2 q, float t) {
    float day = u_light;
    vec3 ro = vec3(1.5 * sin(t * 0.021), 0.0, t * 0.42);
    ro.y = max(broad(ro.xz), WATER) + 1.05;
    vec3 rd = normalize(vec3(q.x, q.y + 0.14, 1.65));
    rd.xz = rot(0.22 * sin(t * 0.017)) * rd.xz;
    vec3 haze = mix(vec3(0.150, 0.210, 0.380), vec3(0.720, 0.870, 0.970), day);
    vec3 col;

    float d = 0.25, hit = -1.0;
    for (int i = 0; i < 34; i++) {
        vec3 p = ro + rd * d;
        float gap = p.y - ground(p.xz);
        if (gap < 0.003 * d) { hit = d; break; }
        if (rd.y > 0.0 && p.y > 2.5) break;
        d += gap * 0.5 + 0.020 * d;
        if (rd.y <= 0.0) hit = d;                           // out of steps: the land is about here
    }
    if (hit < 0.0) {
        col = sky(rd, ro, t, day);
        // far mountains: two ridges, bluer the further
        float a = atan(rd.x, rd.z);
        float r1 = 0.030 + 0.085 * fbm(vec2(a * 3.0, 1.0)), r2 = 0.012 + 0.060 * fbm(vec2(a * 5.0 + 20.0, 7.0));
        vec3 far = mix(vec3(0.090, 0.130, 0.270), vec3(0.440, 0.600, 0.860), day);
        col = mix(col, mix(far, haze, 0.40), smoothstep(0.0, 0.004, r1 - rd.y));
        col = mix(col, mix(far * mix(1.0, 0.86, day), haze, 0.22), smoothstep(0.0, 0.004, r2 - rd.y));
    } else {
        vec3 p = ro + rd * hit;
        float e = 0.03 + 0.004 * hit, raw = land(p.xz), near = exp(-hit * 0.09);
        float sh = smoothstep(0.55, 0.63, deck(p.xz + SUN.xz * (DECK - p.y) / SUN.y, t));   // cloud shadow
        if (raw < WATER) {
            // a lake: the sky upside down, broken by ripples, darker where you look straight in
            vec2 rip = vec2(noise(p.xz * 5.0 + vec2(t * 0.5, 0.0)), noise(p.xz * 5.0 + vec2(13.0, -t * 0.4))) - 0.5;
            vec3 n = normalize(vec3(rip.x * 0.10 * near, 1.0, rip.y * 0.10 * near));
            vec3 r = reflect(rd, n);
            r.y = abs(r.y) + 0.02;
            float fres = 0.30 + 0.70 * pow(1.0 - clamp(dot(-rd, n), 0.0, 1.0), 3.0);
            vec3 deep = mix(vec3(0.020, 0.050, 0.110), vec3(0.090, 0.330, 0.520), day);
            col = mix(deep, sky(normalize(r), p, t, day), fres);
            col = mix(col, mix(vec3(0.30, 0.38, 0.50), vec3(0.93, 0.96, 0.90), day), smoothstep(0.035, 0.0, WATER - raw) * 0.7);   // shore
            col *= 1.0 - 0.25 * sh;
        } else {
            vec3 n = normalize(vec3(raw - land(p.xz + vec2(e, 0.0)), e, raw - land(p.xz + vec2(0.0, e))));
            float nl = clamp(dot(n, SUN), 0.0, 1.0), wood = woodAt(p.xz);
            vec3 lit   = mix(vec3(0.100, 0.230, 0.250), vec3(0.660, 0.820, 0.230), day);
            vec3 dark  = mix(vec3(0.020, 0.060, 0.100), vec3(0.130, 0.440, 0.260), day);
            vec3 tree  = mix(vec3(0.050, 0.130, 0.140), vec3(0.330, 0.600, 0.200), day);
            vec3 treed = mix(vec3(0.010, 0.030, 0.060), vec3(0.040, 0.220, 0.190), day);
            float patches = noise(p.xz * 0.8 + 3.0);
            col = mix(dark, lit, smoothstep(0.30, 0.86, nl + (patches - 0.5) * 0.25));
            col *= 0.90 + 0.20 * patches;
            // wind: pale bands running over the grass, and the grain of the blades close by
            float gust = smoothstep(0.55, 0.85, noise(vec2(p.x * 0.6 - t * 0.9, p.z * 1.9 + t * 0.3)));
            col += lit * 0.22 * gust * near;
            col *= 1.0 - 0.10 * near * noise(p.xz * vec2(9.0, 3.0) + vec2(t * 0.6, 0.0));
            if (wood > 0.0) {                               // tree crowns: lit tops, dark between them
                float crown = lobes(p.xz * 1.6);
                col = mix(col, mix(treed, tree, smoothstep(0.18, 0.55, crown) * (0.35 + 0.65 * nl)), wood);
            }
            // flowers, close to the camera only
            if (hit < 16.0 && wood < 0.1) {
                vec2 g = p.xz * 5.0, id = floor(g), f = fract(g) - 0.5;
                float r = hash(id);
                if (r > 0.70) {
                    vec2 o = (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.6;
                    float size = 0.10 + 0.09 * hash(id + 1.3);
                    vec3 fc = r > 0.90 ? vec3(1.0, 0.86, 0.25) : (r > 0.80 ? vec3(1.0, 0.98, 0.94) : vec3(0.98, 0.62, 0.72));
                    col = mix(col, fc * mix(0.16, 1.0, day), smoothstep(size, size * 0.45, length(f - o)) * smoothstep(16.0, 5.0, hit));
                }
            }
            col = mix(col, col * mix(vec3(0.55, 0.62, 0.80), vec3(0.50, 0.62, 0.78), day), sh * 0.85);
        }
        col = mix(haze, col, exp(-hit * 0.036));
    }
    if (day < 0.5) {                                        // fireflies: two depths of slow blinking lights
        for (int k = 0; k < 2; k++) {
            float z = 1.0 + float(k) * 0.8;
            vec2 g = (q + vec2(t * 0.012 * z, 0.0)) * (2.6 * z) + float(k) * 17.0, id = floor(g);
            vec2 o = 0.5 + 0.30 * vec2(sin(t * 0.31 + hash(id) * 40.0), cos(t * 0.23 + hash(id + 2.0) * 40.0));
            float blink = smoothstep(0.1, 1.0, sin(t * (0.5 + hash(id + 5.0)) + hash(id + 9.0) * 30.0));
            float on = step(0.62, hash(id + 4.0)) * smoothstep(0.05, -0.25, q.y);
            col += vec3(0.80, 0.95, 0.35) * blink * on * exp(-length(fract(g) - o) * 26.0 * z) * 0.9;
        }
    }
    return col;
}
