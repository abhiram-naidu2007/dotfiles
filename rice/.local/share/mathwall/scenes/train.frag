// picture ghibli/chihiro043.jpg
// fps 60
// The sea railway at dusk (a still from Spirited Away, which Studio Ghibli gives away for
// personal use; it is fetched by `rice ghibli`, not kept in this repository).
// The painting is left as painted; what moves is what would move:
//   - the clouds drift, each part at its own pace, and so do their images in the water
//   - the sea ripples, more towards the viewer, and glints along the horizon
//   - the windows of the train burn a little brighter and dimmer
// The train, its platform and the signal pole are held still.
const float HORIZON = 0.245;                                // height of the waterline in the picture

vec3 scene(vec2 uv, vec2 q, float t) {
    vec2 x = uv;
    float solid = max(inbox(x, vec2(0.140, 0.224), vec2(0.832, 0.332), 0.012),      // train and platform
                      inbox(x, vec2(0.785, 0.250), vec2(0.797, 0.430), 0.004));     // signal pole
    float water = smoothstep(HORIZON + 0.004, HORIZON - 0.004, x.y);
    float wd = clamp((HORIZON - x.y) / HORIZON, 0.0, 1.0);                          // 0 at the horizon, 1 at the viewer
    // ripples: fine and quick far away, broad and slow close by
    vec2 rip = vec2(noise(vec2(x.x * 16.0 + t * 0.22, x.y * 190.0 - t * 0.9)), noise(vec2(x.x * 11.0 - t * 0.17, x.y * 120.0 + t * 0.6 + 40.0))) - 0.5;
    vec2 p = x + rip * vec2(0.0075, 0.0030) * (0.25 + wd) * water * wake();
    // the clouds: to the right, slower low on the sky where they are far, uneven like weather
    float pace = 0.55 + 0.9 * noise(vec2(x.x * 2.3, abs(x.y - HORIZON) * 5.0) + 3.0);
    vec2 vel = vec2(0.0016, 0.00012 * sin(x.x * 9.0)) * pace * mix(0.35, 1.0, smoothstep(0.0, 0.5, abs(x.y - HORIZON))) * (1.0 - solid) * wake();
    vec3 col = flowed(p, vel, t, 9.0);
    // a few glints on the far water, coming and going
    float glint = smoothstep(0.80, 0.93, noise(vec2(x.x * 150.0, x.y * 900.0))) * smoothstep(0.55, 0.95, noise(vec2(x.x * 40.0 + t * 0.7, x.y * 300.0 - t * 0.5)))
                  * water * (1.0 - wd) * (1.0 - wd);
    col += vec3(1.0, 0.92, 0.80) * glint * 0.55 * dot(col, vec3(0.33)) * wake();
    // the lit windows
    float warm = smoothstep(0.16, 0.34, col.r - col.b) * step(0.62, col.r) * inbox(x, vec2(0.205, 0.258), vec2(0.752, 0.302), 0.004);
    col += vec3(1.0, 0.70, 0.30) * 0.13 * wake() * warm * (0.75 + 0.25 * sin(t * 1.3 + floor(x.x * 46.0) * 2.4) + 0.10 * sin(t * 7.0 + x.x * 300.0));
    return col;
}
