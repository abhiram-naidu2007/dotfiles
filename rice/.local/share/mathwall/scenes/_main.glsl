
void main() {
    vec2 uv = gl_FragCoord.xy / u_res;
    vec2 q = (gl_FragCoord.xy * 2.0 - u_res) / u_res.y;
    px = 2.0 / u_res.y;
    vec3 c = scene(uv, q, u_time);
    c += (hash(gl_FragCoord.xy + 0.37) - 0.5) / 255.0;      // one grey level of noise: no banding in gradients
    frag = vec4(c, 1.0);
}
