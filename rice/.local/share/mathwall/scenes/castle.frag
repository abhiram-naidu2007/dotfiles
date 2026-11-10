// picture ghibli/howl011.jpg
// fps 60
// The moving castle on the moor (a still from Howl's Moving Castle, which Studio Ghibli gives
// away for personal use; it is fetched by `rice ghibli`, not kept in this repository).
// The painting is left as painted; what moves is what would move:
//   - the storm clouds roll behind the castle, and the steam cloud beside it billows upward
//   - steam keeps coming out of the three stacks
//   - the castle itself heaves a little, the way a machine on legs stands
//   - the grass in front bends in gusts
float plume(vec2 p, vec2 from, float t) {
    const vec2 AXIS = vec2(0.545, 0.838);                   // steam leaves up and to the right
    vec2 r = p - from;
    float along = dot(r, AXIS), side = dot(r, vec2(AXIS.y, -AXIS.x));
    if (along < 0.0 || along > 0.20 || abs(side) > 0.07) return 0.0;
    float width = 0.006 + along * 0.26;
    float n = 0.6 * noise(vec2(along * 34.0 - t * 1.0, side * 46.0 + from.x * 50.0)) + 0.4 * noise(vec2(along * 80.0 - t * 1.9, side * 100.0));
    return smoothstep(width, 0.0, abs(side) + (n - 0.5) * width) * smoothstep(0.20, 0.04, along) * smoothstep(0.0, 0.010, along) * (0.35 + 0.65 * n);
}

vec3 scene(vec2 uv, vec2 q, float t) {
    vec2 x = uv;
    // the castle stands inside this box; the sky is what lies above the moor outside it
    float body = inbox(x, vec2(0.13, 0.10), vec2(0.63, 1.10), 0.03);
    vec2 heave = vec2(0.0006 * sin(t * 0.7), 0.0020 * sin(t * 1.15) + 0.0008 * sin(t * 2.9 + 1.0));
    vec2 p = x - heave * body * wake();
    // the sky rolls to the left; the steam cloud right of the stacks climbs
    float sky = (1.0 - body) * smoothstep(0.28, 0.36, x.y);
    float steam = inbox(x, vec2(0.60, 0.50), vec2(0.90, 0.98), 0.05) * sky;
    float pace = 0.5 + 1.0 * noise(x * vec2(2.6, 4.0) + 7.0);
    vec2 vel = wake() * sky * (vec2(-0.0017, 0.0002 * sin(x.x * 7.0)) * pace + steam * vec2(0.0022, 0.0030) * (0.4 + noise(x * 9.0 + t * 0.05)));
    // grass in front, bottom right: the tips go with the gusts
    float grass = inbox(x, vec2(0.52, -0.1), vec2(1.1, 0.105), 0.03);
    float gust = 0.5 + 0.5 * sin(t * 0.5 + x.x * 6.0);
    p.x += wake() * grass * 0.0022 * gust * sin(t * 2.1 + x.x * 90.0 + 4.0 * noise(x * 60.0));
    vec3 col = flowed(p, vel, t, 9.0);
    // fresh steam from the stacks (they heave with the castle)
    float s = plume(p, vec2(0.505, 0.893), t) + plume(p, vec2(0.545, 0.916), t + 3.0) + plume(p, vec2(0.592, 0.886), t + 7.0);
    col = mix(col, vec3(0.78, 0.80, 0.80), clamp(s, 0.0, 1.0) * 0.62 * wake());
    return col;
}
