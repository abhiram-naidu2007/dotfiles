// mathwall: live wallpapers, drawn by the GPU and asleep whenever they are not in view.
//
// Three kinds of scene:
//   orbits   one long orbit of a chaotic system (Aizawa, Lorenz, Thomas, Halvorsen, Dadras),
//            240 000 points drawn as a single thin additive line that turns slowly; pulses of
//            light travel along it the way the system moves
//   curves   figures recomputed every frame: a harmonograph that keeps retuning itself, and a
//            sunflower spiral (phyllotaxis) breathing around the golden angle
//   shaders  every *.frag file in ~/.local/share/mathwall/scenes: one function that colours a
//            pixel (temple, chladni ...). Drop a new file there and it
//            is a new wallpaper; _common.glsl in that folder documents what a scene can use.
// Lines and points are summed into a floating-point buffer and tone-mapped, so crowded places
// glow instead of clipping. Colours are the desktop palette (~/.cache/theme/colors.sh); on a
// light mood lines are ink that darkens the paper.
//
// It is built to cost nothing while you work:
//   - it animates only while the current workspace is empty (the wallpaper is in full view);
//     with a window open it holds a still frame and sleeps
//   - it sleeps on battery and while the screen is off
//   - 30 frames a second
// Flags: --always (animate behind windows too)  --battery (also on battery)  --fps N
//        --scene NAME  --cycle SECONDS (move to the next scene; 0 = never; default 900)
//        --snapshot FILE.ppm [--size WxH] [--at SECONDS]
//                                           draw one frame into a file and exit (thumbnails);
//                                           --at picks the moment of the scene (default 40)
//        --list | --list-own                scene names | those with colours of their own
//        --bench N                          draw N frames off screen, print milliseconds per frame
//        --mood light|dark                  draw for that mood whatever the desktop's is (previews)
// A scene file may say `// fps N` (its own frame rate); see _common.glsl.
// Signals: USR1 reload the palette (and the painting), USR2 reload the palette and go to the next scene (or the one named in
//          $XDG_RUNTIME_DIR/mathwall.goto, if that file exists: a fade to a chosen scene), TERM quit.
// In $XDG_RUNTIME_DIR: mathwall.pid (this process), mathwall.scene (the scene on screen),
// mathwall.picture (the time stamp of the picture file it has loaded).
// `rice live ...` and the wallpaper picker drive it. Build: make -C ~/dotfiles/mathwall install
#define _GNU_SOURCE
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glx.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/dpms.h>
#include <X11/extensions/shape.h>
#include <dirent.h>
#include <glob.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define POINTS 240000          // an orbit; also the size of the vertex buffer
#define CURVE_POINTS 16000
#define DOT_POINTS 2600
#define FADE_SECONDS 0.6

typedef void (*Flow)(const double *p, double *d);

static void lorenz(const double *p, double *d) {
    d[0] = 10 * (p[1] - p[0]); d[1] = p[0] * (28 - p[2]) - p[1]; d[2] = p[0] * p[1] - 8.0 / 3 * p[2];
}
static void aizawa(const double *p, double *d) {
    double x = p[0], y = p[1], z = p[2];
    d[0] = (z - 0.7) * x - 3.5 * y; d[1] = 3.5 * x + (z - 0.7) * y;
    d[2] = 0.6 + 0.95 * z - z * z * z / 3 - (x * x + y * y) * (1 + 0.25 * z) + 0.1 * z * x * x * x;
}
static void thomas(const double *p, double *d) {
    const double b = 0.208186;
    d[0] = sin(p[1]) - b * p[0]; d[1] = sin(p[2]) - b * p[1]; d[2] = sin(p[0]) - b * p[2];
}
static void halvorsen(const double *p, double *d) {
    const double a = 1.4; double x = p[0], y = p[1], z = p[2];   // 1.89, often quoted, settles into a loop
    d[0] = -a * x - 4 * y - 4 * z - y * y; d[1] = -a * y - 4 * z - 4 * x - z * z; d[2] = -a * z - 4 * x - 4 * y - x * x;
}
static void dadras(const double *p, double *d) {
    double x = p[0], y = p[1], z = p[2];
    d[0] = y - 3 * x + 2.7 * y * z; d[1] = 1.7 * y - x * z + z; d[2] = 2 * x * y - 9 * z;
}

enum { ORBIT, CURVE, DOTS, SHADER };
typedef struct {
    char name[48];
    int kind;
    Flow flow; double dt, start[3];          // orbits
    char path[600]; float scale; int own;    // shader files: draw size relative to the screen, own colours
    GLuint prog; int tried;
    int fps;                                 // shader files: their own frame rate (0 = the default)
} Scene;
static Scene scenes[64] = {
    {"aizawa", ORBIT, aizawa, 0.012, {0.1, 0, 0}, "", 1, 0, 0, 0, 0},
    {"lorenz", ORBIT, lorenz, 0.006, {1, 1, 1}, "", 1, 0, 0, 0, 0},
    {"thomas", ORBIT, thomas, 0.06, {1.1, 1.1, -0.01}, "", 1, 0, 0, 0, 0},
    {"halvorsen", ORBIT, halvorsen, 0.006, {-5, 0, 0}, "", 1, 0, 0, 0, 0},
    {"dadras", ORBIT, dadras, 0.008, {1.1, 2.1, -2}, "", 1, 0, 0, 0, 0},
    {"harmonograph", CURVE, NULL, 0, {0, 0, 0}, "", 1, 0, 0, 0, 0},
    {"phyllotaxis", DOTS, NULL, 0, {0, 0, 0}, "", 1, 0, 0, 0, 0},
};
static int nscenes = 7;
static char scene_dir[512];

static volatile sig_atomic_t quit_flag, reload_flag, next_flag;
static void on_signal(int sig) {
    if (sig == SIGUSR1) reload_flag = 1;
    else if (sig == SIGUSR2) next_flag = 1;
    else quit_flag = 1;
}

static double now_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

// ---------------------------------------------------------------- scene files
static char *slurp(const char *dir, const char *name) {
    char path[1200];
    snprintf(path, sizeof path, "%s%s%s", dir, *dir ? "/" : "", name);
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    rewind(f);
    char *buf = malloc(n + 1);
    buf[fread(buf, 1, n, f)] = 0;
    fclose(f);
    return buf;
}

static int by_name(const void *a, const void *b) { return strcmp(((const Scene *)a)->name, ((const Scene *)b)->name); }

static void find_scene_files(void) {
    const char *env = getenv("MATHWALL_SCENES"), *data = getenv("XDG_DATA_HOME");
    if (env) snprintf(scene_dir, sizeof scene_dir, "%s", env);
    else if (data && *data) snprintf(scene_dir, sizeof scene_dir, "%s/mathwall/scenes", data);
    else snprintf(scene_dir, sizeof scene_dir, "%s/.local/share/mathwall/scenes", getenv("HOME"));
    DIR *d = opendir(scene_dir);
    if (!d) return;
    int first = nscenes;
    struct dirent *e;
    while ((e = readdir(d)) && nscenes < 64) {
        size_t len = strlen(e->d_name);
        if (e->d_name[0] == '_' || e->d_name[0] == '.' || len < 6 || len > 40 || strcmp(e->d_name + len - 5, ".frag")) continue;
        Scene *s = &scenes[nscenes++];
        memset(s, 0, sizeof *s);
        snprintf(s->name, sizeof s->name, "%.*s", (int)len - 5, e->d_name);
        snprintf(s->path, sizeof s->path, "%s", e->d_name);
        s->kind = SHADER;
        s->scale = 1;
        char *text = slurp(scene_dir, e->d_name);       // directives sit in the comments at the top
        if (text) {
            char *body = strstr(text, "\nvec"), *p;
            if (body) *body = 0;
            if ((p = strstr(text, "// scale "))) s->scale = strtof(p + 9, NULL);
            if (strstr(text, "// own-colours")) s->own = 1;
            if ((p = strstr(text, "// fps "))) s->fps = atoi(p + 7);
            if (s->scale < 0.25f || s->scale > 1) s->scale = 1;
            free(text);
        }
    }
    closedir(d);
    qsort(scenes + first, nscenes - first, sizeof(Scene), by_name);
}

// ---------------------------------------------------------------- vertices: x y z, t (0..1 along the figure), tint (0..1)
static float *verts;
static int nverts;

static int by_size(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

static void fill_orbit(const Scene *s) {
    Flow f = s->flow;
    double dt = s->dt, p[3], k1[3], k2[3], k3[3], k4[3], q[3];
    memcpy(p, s->start, sizeof p);
    double *raw = malloc(sizeof(double) * 4 * POINTS), mean[3] = {0, 0, 0}, top = 0, reach;
    for (int i = -12000; i < POINTS; i++) {     // the first 12000 steps only bring it onto the attractor
        f(p, k1);
        for (int j = 0; j < 3; j++) q[j] = p[j] + dt / 2 * k1[j];
        f(q, k2);
        for (int j = 0; j < 3; j++) q[j] = p[j] + dt / 2 * k2[j];
        f(q, k3);
        for (int j = 0; j < 3; j++) q[j] = p[j] + dt * k3[j];
        f(q, k4);
        for (int j = 0; j < 3; j++) p[j] += dt / 6 * (k1[j] + 2 * k2[j] + 2 * k3[j] + k4[j]);
        if (i < 0) continue;
        double speed = sqrt(k1[0] * k1[0] + k1[1] * k1[1] + k1[2] * k1[2]);
        memcpy(raw + 4 * i, p, sizeof p);
        raw[4 * i + 3] = speed;
        for (int j = 0; j < 3; j++) mean[j] += p[j] / POINTS;
        if (speed > top) top = speed;
    }
    // Fit to the screen by the distance that 99.5% of the points stay within: one rare
    // excursion must not shrink the whole figure, and a dense core must not push its wings off screen.
    double *r2 = malloc(sizeof(double) * POINTS);
    for (int i = 0; i < POINTS; i++) {
        r2[i] = 0;
        for (int j = 0; j < 3; j++) r2[i] += (raw[4 * i + j] - mean[j]) * (raw[4 * i + j] - mean[j]);
    }
    qsort(r2, POINTS, sizeof(double), by_size);
    reach = 1.04 * sqrt(r2[(int)(POINTS * 0.995)]);
    free(r2);
    for (int i = 0; i < POINTS; i++) {
        for (int j = 0; j < 3; j++) verts[5 * i + j] = (float)((raw[4 * i + j] - mean[j]) / reach);
        verts[5 * i + 3] = (float)i / POINTS;
        verts[5 * i + 4] = (float)sqrt(raw[4 * i + 3] / top);
    }
    free(raw);
    nverts = POINTS;
}

// Harmonograph: two damped pendulums per axis. Their frequencies sit near a small whole-number
// ratio, which gives a clean rosette; the ratio moves on to the next one every minute and the
// phases never stop drifting, so the figure is always becoming another.
static void fill_curve(double t) {
    static const double RATIO[6][2] = {{2, 3}, {3, 4}, {3, 5}, {4, 5}, {2, 5}, {5, 6}};
    double pos = t / 60.0, blend = pos - floor(pos);
    int k = (int)floor(pos) % 6;
    blend = blend < 0.85 ? 0 : (blend - 0.85) / 0.15;                 // hold, then glide to the next ratio
    blend = blend * blend * (3 - 2 * blend);
    double a = RATIO[k][0] + (RATIO[(k + 1) % 6][0] - RATIO[k][0]) * blend + 0.004 * sin(t * 0.021);
    double b = RATIO[k][1] + (RATIO[(k + 1) % 6][1] - RATIO[k][1]) * blend + 0.004 * cos(t * 0.017);
    for (int i = 0; i < CURVE_POINTS; i++) {
        double s = i * (190.0 / CURVE_POINTS), e1 = exp(-0.0075 * s), e2 = exp(-0.0055 * s);
        verts[5 * i] = (float)(0.60 * (sin(a * s + t * 0.050) * e1 + sin(b * s + t * 0.031) * e2));
        verts[5 * i + 1] = (float)(0.60 * (sin(a * s + 1.57 + t * 0.043) * e2 + sin(b * s + 0.8 + t * 0.027) * e1));
        verts[5 * i + 2] = (float)(0.10 * sin(0.5 * (a + b) * s) * e2);
        verts[5 * i + 3] = verts[5 * i + 4] = (float)i / CURVE_POINTS;
    }
    nverts = CURVE_POINTS;
}

// Phyllotaxis: seed n sits at angle n * g and radius sqrt(n). At the golden angle the seeds
// pack like a sunflower; g drifts a little around it and the spirals rearrange.
static void fill_dots(double t) {
    double g = 2.39996323 + 0.012 * sin(t * 0.05);
    for (int i = 0; i < DOT_POINTS; i++) {
        double r = 1.12 * sqrt((i + 0.5) / DOT_POINTS), a = i * g;
        verts[5 * i] = (float)(r * cos(a));
        verts[5 * i + 1] = (float)(r * sin(a));
        verts[5 * i + 2] = (float)(0.10 * sin(r * 7.0 - t * 0.5));
        verts[5 * i + 3] = (float)(i + 0.5) / DOT_POINTS;
        verts[5 * i + 4] = (float)(0.5 + 0.5 * sin(r * 9.0 - t * 0.35));
    }
    nverts = DOT_POINTS;
}

// ---------------------------------------------------------------- palette
enum { C_BG, C_DEEP, C_FG, C_A, C_B, C_RED, C_GREEN, C_YELLOW, C_BLUE, C_MAGENTA, C_CYAN, NCOL };
static const char *const COLOUR_KEYS[NCOL] = {"bg", "crust", "fg", "accent", "accent2", "red", "green", "yellow", "blue", "magenta", "cyan"};
static const char *const COLOUR_UNIFORMS[NCOL] = {"u_bg", "u_deep", "u_fg", "u_a", "u_b", "u_red", "u_green", "u_yellow", "u_blue", "u_magenta", "u_cyan"};
static float srgb[NCOL][3] = {{0.07f, 0.075f, 0.11f}, {0.03f, 0.04f, 0.07f}, {0.87f, 0.88f, 0.92f}, {0.64f, 0.74f, 1.0f}, {0.95f, 0.62f, 0.6f},
                              {0.96f, 0.6f, 0.62f}, {0.54f, 0.79f, 0.55f}, {0.84f, 0.7f, 0.38f}, {0.53f, 0.73f, 0.99f}, {0.84f, 0.63f, 0.89f}, {0.44f, 0.78f, 0.8f}};
static float linear[NCOL][3];
static int light_mood;

static void load_palette(void) {
    char path[512], line[256], key[64], val[128];
    snprintf(path, sizeof path, "%s/.cache/theme/colors.sh", getenv("HOME"));
    FILE *f = fopen(path, "r");
    while (f && fgets(line, sizeof line, f)) {
        if (sscanf(line, "%63[^=]='%127[^']'", key, val) != 2) continue;
        if (!strcmp(key, "variant")) light_mood = !strcmp(val, "light");
        for (int c = 0; c < NCOL; c++) {
            unsigned r, g, b;
            if (!strcmp(key, COLOUR_KEYS[c]) && sscanf(val, "#%2x%2x%2x", &r, &g, &b) == 3) {
                srgb[c][0] = r / 255.0f; srgb[c][1] = g / 255.0f; srgb[c][2] = b / 255.0f;
            }
        }
    }
    if (f) fclose(f);
    for (int c = 0; c < NCOL; c++)
        for (int k = 0; k < 3; k++) linear[c][k] = powf(srgb[c][k], 2.2f);
}

// ---------------------------------------------------------------- GL
static const char *POINT_VS =
    "#version 330 core\n"
    "layout(location=0) in vec4 a_pos; layout(location=1) in float a_tint;\n"
    "uniform mat4 u_mvp; uniform float u_time, u_size, u_light; uniform int u_mode; uniform vec3 u_a, u_b;\n"
    "out vec3 v_col;\n"
    "void main() {\n"
    "  gl_Position = u_mvp * vec4(a_pos.xyz, 1.0);\n"
    "  // six pulses run along the figure, the way the system itself moves\n"
    "  float pulse = pow(0.5 + 0.5 * cos(6.2831853 * (a_pos.w * 6.0 - u_time * 0.035)), 14.0);\n"
    "  vec3 c = mix(u_a, u_b, a_tint);\n"
    "  if (u_light > 0.5) c = vec3(1.0) - c;            // ink: what it removes from the paper\n"
    "  float near = clamp(1.6 - gl_Position.w * 0.3, 0.5, 1.4);\n"
    "  if (u_mode == 0) {                                // the whole figure as one thin line\n"
    "    v_col = c * (0.22 + 0.5 * pulse) * near;\n"
    "  } else if (u_mode == 1) {                         // soft points, only where a pulse is\n"
    "    v_col = c * 1.6 * pulse * near;\n"
    "    gl_PointSize = u_size * (0.8 + 1.4 * pulse) * near;\n"
    "    if (pulse < 0.04) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);\n"
    "  } else {                                          // every vertex a seed, larger toward the rim\n"
    "    v_col = c * (0.55 + 1.3 * pulse) * near;\n"
    "    gl_PointSize = u_size * (1.1 + 2.2 * a_pos.w) * near;\n"
    "  }\n"
    "}\n";
static const char *POINT_FS =
    "#version 330 core\n"
    "uniform int u_mode;\n"
    "in vec3 v_col; out vec4 frag;\n"
    "void main() {\n"
    "  float soft = 1.0;\n"
    "  if (u_mode != 0) { vec2 d = gl_PointCoord * 2.0 - 1.0; soft = exp(-dot(d, d) * 3.2); }\n"
    "  frag = vec4(v_col * soft, 1.0);\n"
    "}\n";
static const char *SCREEN_VS =
    "#version 330 core\n"
    "void main() { vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2); gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0); }\n";
static const char *TONE_FS =      // sum of light (or ink) -> picture
    "#version 330 core\n"
    "uniform sampler2D u_tex; uniform vec2 u_res; uniform vec3 u_bg, u_deep; uniform float u_light, u_fade, u_gain;\n"
    "out vec4 frag;\n"
    "void main() {\n"
    "  vec2 uv = gl_FragCoord.xy / u_res;\n"
    "  vec3 sum = texture(u_tex, uv).rgb * u_gain * u_fade;\n"
    "  vec3 back = mix(u_bg, u_deep, smoothstep(0.25, 0.95, length(uv - 0.5) * 1.25));\n"
    "  vec3 col = u_light > 0.5 ? back * exp(-sum) : back + (vec3(1.0) - exp(-sum)) * (vec3(1.0) - back);\n"
    "  col = pow(col, vec3(1.0 / 2.2));\n"
    "  col += (fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;  // no banding\n"
    "  frag = vec4(col, 1.0);\n"
    "}\n";
static const char *SHOW_FS =      // a finished picture, scaled to the screen and faded against the background
    "#version 330 core\n"
    "uniform sampler2D u_tex; uniform vec2 u_res; uniform vec3 u_bg; uniform float u_fade;\n"
    "out vec4 frag;\n"
    "void main() { frag = vec4(mix(u_bg, texture(u_tex, gl_FragCoord.xy / u_res).rgb, u_fade), 1.0); }\n";

static const char *PRESENT_FS =   // what reaches the screen: the frame just drawn, cross-faded from the one kept at the last change
    "#version 330 core\n"
    "uniform sampler2D u_new, u_old; uniform vec2 u_res; uniform float u_fade;\n"
    "out vec4 frag;\n"
    "void main() { vec2 uv = gl_FragCoord.xy / u_res; frag = vec4(mix(texture(u_old, uv).rgb, texture(u_new, uv).rgb, u_fade), 1.0); }\n";

static GLuint compile(GLenum type, const char *src, const char *what) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[2048];
        glGetShaderInfoLog(s, sizeof log, NULL, log);
        fprintf(stderr, "mathwall: %s does not compile:\n%s\n", what, log);
        glDeleteShader(s);
        return 0;
    }
    return s;
}
static GLuint program(const char *vs, const char *fs, const char *what) {
    GLuint v = compile(GL_VERTEX_SHADER, vs, what), f = compile(GL_FRAGMENT_SHADER, fs, what);
    if (!v || !f) return 0;
    GLuint p = glCreateProgram();
    glAttachShader(p, v);
    glAttachShader(p, f);
    glLinkProgram(p);
    GLint ok;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) { fprintf(stderr, "mathwall: %s does not link\n", what); return 0; }
    return p;
}

// A scene file becomes a program: shared header + the file + the shared main().
static GLuint scene_program(Scene *s) {
    if (s->tried) return s->prog;
    s->tried = 1;
    char *head = slurp(scene_dir, "_common.glsl"), *body = slurp(scene_dir, s->path), *tail = slurp(scene_dir, "_main.glsl");
    if (head && body && tail) {
        size_t n = strlen(head) + strlen(body) + strlen(tail) + 32;
        char *src = malloc(n);
        snprintf(src, n, "%s\n#line 1\n%s\n%s", head, body, tail);      // errors are reported with the file's own line numbers
        s->prog = program(SCREEN_VS, src, s->path);
        free(src);
    } else fprintf(stderr, "mathwall: %s: missing _common.glsl, _main.glsl or the scene itself in %s\n", s->name, scene_dir);
    free(head); free(body); free(tail);
    return s->prog;
}

// column-major 4x4: out = a * b
static void mul(const float *a, const float *b, float *out) {
    float r[16];
    for (int c = 0; c < 4; c++)
        for (int k = 0; k < 4; k++)
            r[c * 4 + k] = a[k] * b[c * 4] + a[4 + k] * b[c * 4 + 1] + a[8 + k] * b[c * 4 + 2] + a[12 + k] * b[c * 4 + 3];
    memcpy(out, r, sizeof r);
}

// ---------------------------------------------------------------- when to move
static Display *dpy;
static Window root;
static Atom A_CURRENT, A_CLIENTS, A_DESKTOP;

static long cardinal(Window w, Atom prop, long fallback) {
    Atom type; int format; unsigned long n, left; unsigned char *data = NULL;
    long value = fallback;
    if (XGetWindowProperty(dpy, w, prop, 0, 1, False, XA_CARDINAL, &type, &format, &n, &left, &data) == Success && data && n)
        value = *(long *)data;
    if (data) XFree(data);
    return value;
}

static int workspace_empty(void) {
    long current = cardinal(root, A_CURRENT, -1);
    Atom type; int format; unsigned long n, left; unsigned char *data = NULL;
    if (XGetWindowProperty(dpy, root, A_CLIENTS, 0, 4096, False, XA_WINDOW, &type, &format, &n, &left, &data) != Success || !data)
        return 1;
    int empty = 1;
    for (unsigned long i = 0; i < n && empty; i++) {
        long desk = cardinal(((Window *)data)[i], A_DESKTOP, -2);
        if (desk == current || desk == 0xFFFFFFFFL) empty = 0;    // here, or on every workspace
    }
    XFree(data);
    return empty;
}

static int on_mains(void) {
    glob_t g;
    int online = 1, seen = 0;
    if (glob("/sys/class/power_supply/*/online", 0, NULL, &g) == 0) {
        online = 0;
        for (size_t i = 0; i < g.gl_pathc; i++) {
            FILE *f = fopen(g.gl_pathv[i], "r");
            if (!f) continue;
            seen = 1;
            if (fgetc(f) == '1') online = 1;
            fclose(f);
        }
        globfree(&g);
    }
    return online || !seen;    // a desktop PC has no such file: always on mains
}

static int screen_on(void) {
    CARD16 level; BOOL enabled; int event, error;
    if (DPMSQueryExtension(dpy, &event, &error) && DPMSInfo(dpy, &level, &enabled) && enabled) return level == DPMSModeOn;
    return 1;
}

static int xerror(Display *d, XErrorEvent *e) { (void)d; (void)e; return 0; }   // a window may vanish while it is asked

// $XDG_RUNTIME_DIR/mathwall.pid: how `rice` finds the wallpaper of this session (and only this one).
static char pid_path[512];
static void forget_pid(void) { if (pid_path[0]) unlink(pid_path); }
static void remember_pid(void) {
    const char *dir = getenv("XDG_RUNTIME_DIR");
    snprintf(pid_path, sizeof pid_path, "%s/mathwall.pid", dir ? dir : "/tmp");
    FILE *f = fopen(pid_path, "w");
    if (f) { fprintf(f, "%d\n", (int)getpid()); fclose(f); atexit(forget_pid); }
    else pid_path[0] = 0;
}

static void remember_scene(int scene) {
    char path[512];
    const char *dir = getenv("XDG_RUNTIME_DIR");
    snprintf(path, sizeof path, "%s/mathwall.scene", dir ? dir : "/tmp");
    FILE *f = fopen(path, "w");
    if (f) { fprintf(f, "%s\n", scenes[scene].name); fclose(f); }
}

// The scene named in $XDG_RUNTIME_DIR/mathwall.goto (the file is used up), or -1.
static int wanted_scene(void) {
    char path[512], name[64] = "";
    const char *dir = getenv("XDG_RUNTIME_DIR");
    snprintf(path, sizeof path, "%s/mathwall.goto", dir ? dir : "/tmp");
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    if (!fgets(name, sizeof name, f)) name[0] = 0;
    fclose(f);
    unlink(path);
    name[strcspn(name, "\n")] = 0;
    for (int i = 0; i < nscenes; i++) if (!strcmp(scenes[i].name, name)) return i;
    return -1;
}

int main(int argc, char **argv) {
    int fps = 30, fps_given = 0, always = 0, battery = 0, scene = -1, snap_w = 0, snap_h = 0, bench = 0, list = 0, force_mood = -1;
    const char *snapshot = NULL, *wanted = NULL;
    double cycle = 900, at = 40;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--always")) always = 1;
        else if (!strcmp(argv[i], "--battery")) battery = 1;
        else if (!strcmp(argv[i], "--list")) list = 1;
        else if (!strcmp(argv[i], "--list-own")) list = 2;
        else if (!strcmp(argv[i], "--fps") && i + 1 < argc) { fps = atoi(argv[++i]); fps_given = 1; }
        else if (!strcmp(argv[i], "--cycle") && i + 1 < argc) cycle = atof(argv[++i]);
        else if (!strcmp(argv[i], "--at") && i + 1 < argc) at = atof(argv[++i]);
        else if (!strcmp(argv[i], "--bench") && i + 1 < argc) bench = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--snapshot") && i + 1 < argc) snapshot = argv[++i];
        else if (!strcmp(argv[i], "--size") && i + 1 < argc) sscanf(argv[++i], "%dx%d", &snap_w, &snap_h);
        else if (!strcmp(argv[i], "--scene") && i + 1 < argc) wanted = argv[++i];
        else if (!strcmp(argv[i], "--mood") && i + 1 < argc) force_mood = !strcmp(argv[++i], "light");
        else {
            fprintf(stderr, "usage: mathwall [--always] [--battery] [--fps N] [--cycle SECONDS] [--scene NAME]\n"
                            "                [--snapshot FILE.ppm [--size WxH]] [--bench N] [--list | --list-own]\n");
            return 2;
        }
    }
    find_scene_files();
    if (list) {
        for (int k = 0; k < nscenes; k++)
            if (list == 1 || scenes[k].own) puts(scenes[k].name);
        return 0;
    }
    for (int k = 0; wanted && k < nscenes; k++)
        if (!strcmp(wanted, scenes[k].name)) scene = k;
    if (wanted && scene < 0) { fprintf(stderr, "mathwall: no scene called %s (see --list)\n", wanted); return 2; }
    if (fps < 1) fps = 1;
    if (fps > 120) fps = 120;
    srand((unsigned)time(NULL));
    if (scene < 0) scene = rand() % nscenes;
    int offscreen = snapshot || bench;

    struct sigaction sa = {.sa_handler = on_signal};
    sigaction(SIGTERM, &sa, NULL); sigaction(SIGINT, &sa, NULL);
    sigaction(SIGUSR1, &sa, NULL); sigaction(SIGUSR2, &sa, NULL);

    if (!(dpy = XOpenDisplay(NULL))) { fprintf(stderr, "mathwall: no X display\n"); return 1; }
    XSetErrorHandler(xerror);
    int screen = DefaultScreen(dpy);
    root = RootWindow(dpy, screen);
    A_CURRENT = XInternAtom(dpy, "_NET_CURRENT_DESKTOP", False);
    A_CLIENTS = XInternAtom(dpy, "_NET_CLIENT_LIST", False);
    A_DESKTOP = XInternAtom(dpy, "_NET_WM_DESKTOP", False);
    int W = DisplayWidth(dpy, screen), H = DisplayHeight(dpy, screen);
    if (snapshot && snap_w > 0 && snap_h > 0) { W = snap_w; H = snap_h; }

    static const int want[] = {GLX_X_RENDERABLE, True, GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT, GLX_RENDER_TYPE, GLX_RGBA_BIT,
                               GLX_RED_SIZE, 8, GLX_GREEN_SIZE, 8, GLX_BLUE_SIZE, 8, GLX_DOUBLEBUFFER, True, None};
    int count;
    GLXFBConfig *configs = glXChooseFBConfig(dpy, screen, want, &count);
    if (!configs || !count) { fprintf(stderr, "mathwall: no GLX framebuffer config\n"); return 1; }
    GLXFBConfig config = configs[0];
    XVisualInfo *vi = glXGetVisualFromFBConfig(dpy, config);

    // A window under everything else: not managed by i3, typed as the desktop for picom,
    // and transparent to the mouse.
    XSetWindowAttributes attrs = {.override_redirect = True, .colormap = XCreateColormap(dpy, root, vi->visual, AllocNone),
                                  .background_pixel = 0, .border_pixel = 0, .event_mask = ExposureMask};
    Window win = XCreateWindow(dpy, root, 0, 0, W, H, 0, vi->depth, InputOutput, vi->visual,
                               CWOverrideRedirect | CWColormap | CWBackPixel | CWBorderPixel | CWEventMask, &attrs);
    XClassHint hint = {"mathwall", "mathwall"};
    XSetClassHint(dpy, win, &hint);
    XStoreName(dpy, win, "mathwall");
    Atom desktop = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DESKTOP", False);
    XChangeProperty(dpy, win, XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False), XA_ATOM, 32, PropModeReplace, (unsigned char *)&desktop, 1);
    XShapeCombineRectangles(dpy, win, ShapeInput, 0, 0, NULL, 0, ShapeSet, Unsorted);
    if (!offscreen) {
        XSelectInput(dpy, root, StructureNotifyMask);
        XLowerWindow(dpy, win);
        XMapWindow(dpy, win);
        XLowerWindow(dpy, win);
    }

    typedef GLXContext (*CreateContext)(Display *, GLXFBConfig, GLXContext, Bool, const int *);
    CreateContext create = (CreateContext)glXGetProcAddressARB((const GLubyte *)"glXCreateContextAttribsARB");
    static const int core[] = {GLX_CONTEXT_MAJOR_VERSION_ARB, 3, GLX_CONTEXT_MINOR_VERSION_ARB, 3,
                               GLX_CONTEXT_PROFILE_MASK_ARB, GLX_CONTEXT_CORE_PROFILE_BIT_ARB, None};
    GLXContext ctx = create ? create(dpy, config, NULL, True, core) : NULL;
    if (!ctx || !glXMakeCurrent(dpy, win, ctx)) { fprintf(stderr, "mathwall: OpenGL 3.3 is not available\n"); return 1; }
    typedef void (*SwapInterval)(Display *, GLXDrawable, int);
    SwapInterval swap_interval = (SwapInterval)glXGetProcAddressARB((const GLubyte *)"glXSwapIntervalEXT");
    if (swap_interval) swap_interval(dpy, win, 0);      // paced by the sleep below, not by the 144 Hz panel

    GLuint points = program(POINT_VS, POINT_FS, "figure shader"), tone = program(SCREEN_VS, TONE_FS, "tone shader"),
           show = program(SCREEN_VS, SHOW_FS, "show shader"), present = program(SCREEN_VS, PRESENT_FS, "present shader");
    if (!points || !tone || !show) return 1;
    GLuint vao, vbo, empty_vao, fbo, sum, art_fbo, art_tex, final_fbo, frames_tex[2], shot_fbo = 0, shot_tex = 0;
    verts = malloc(sizeof(float) * 5 * POINTS);
    glGenVertexArrays(1, &vao); glBindVertexArray(vao);
    glGenBuffers(1, &vbo); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 5 * POINTS, NULL, GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void *)0);
    glEnableVertexAttribArray(1); glVertexAttribPointer(1, 1, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void *)(4 * sizeof(float)));
    glGenVertexArrays(1, &empty_vao);
    // sum: where lines add up (floating point).  art: where a shader scene is painted, possibly smaller than the screen.
    glGenFramebuffers(1, &fbo); glGenTextures(1, &sum);
    glBindTexture(GL_TEXTURE_2D, sum);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, W, H, 0, GL_RGBA, GL_HALF_FLOAT, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, sum, 0);
    glGenFramebuffers(1, &art_fbo); glGenTextures(1, &art_tex);
    glBindTexture(GL_TEXTURE_2D, art_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindFramebuffer(GL_FRAMEBUFFER, art_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, art_tex, 0);
    // final: every scene ends up here.  kept: the frame that was on screen at the last change of
    // scene, picture or palette; the new one is cross-faded in from it.
    glGenFramebuffers(1, &final_fbo); glGenTextures(2, frames_tex);
    GLuint final_tex = frames_tex[0], kept_tex = frames_tex[1];
    for (int i = 0; i < 2; i++) {
        glBindTexture(GL_TEXTURE_2D, frames_tex[i]);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, final_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, final_tex, 0);
#define KEEP_FRAME() do { glBindFramebuffer(GL_READ_FRAMEBUFFER, final_fbo); glBindTexture(GL_TEXTURE_2D, kept_tex); \
                          glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 0, 0, W, H); } while (0)
    if (offscreen) {                                   // the finished frame goes into a texture, not the window
        glGenFramebuffers(1, &shot_fbo); glGenTextures(1, &shot_tex);
        glBindTexture(GL_TEXTURE_2D, shot_tex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glBindFramebuffer(GL_FRAMEBUFFER, shot_fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, shot_tex, 0);
    }
    glEnable(GL_PROGRAM_POINT_SIZE);
    load_palette();
    if (force_mood >= 0) light_mood = force_mood;
    glBindFramebuffer(GL_FRAMEBUFFER, final_fbo);      // the first scene fades in from the background colour
    glClearColor(srgb[C_BG][0], srgb[C_BG][1], srgb[C_BG][2], 1); glClear(GL_COLOR_BUFFER_BIT);
    KEEP_FRAME();

    // Every scene starts at the same moment as its still (--snapshot), fully shown: `rice` puts that
    // still on the root window, so the wallpaper starts to move without any jump.
    double clock = at, fade = 1, fade_dir = 1;
    if (!offscreen) remember_pid();
    double last = now_seconds(), checked = 0, scene_age = 0, bench_start = 0;
    int moving = 1, redraw = 1, pending = scene, art_w = 0, art_h = 0, frames = 0;
    scene = -1;
    while (!quit_flag) {
        // -- enter the pending scene (at start, and at the dark middle of a fade)
        if (pending >= 0) {
            int tries = 0;
            while (scenes[pending].kind == SHADER && !scene_program(&scenes[pending]) && tries++ < nscenes)
                pending = (pending + 1) % nscenes;          // a scene that does not compile is skipped
            scene = pending; pending = -1;
            last = now_seconds();                        // compiling the scene took a while: the fade starts now, not then
            remember_scene(scene);
            if (scenes[scene].kind == ORBIT) {
                fill_orbit(&scenes[scene]);
                glBindBuffer(GL_ARRAY_BUFFER, vbo);
                glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float) * 5 * nverts, verts);
            }
            if (scenes[scene].kind == SHADER) {
                int w = (int)(W * scenes[scene].scale), h = (int)(H * scenes[scene].scale);
                if (w != art_w || h != art_h) {
                    art_w = w; art_h = h;
                    glBindTexture(GL_TEXTURE_2D, art_tex);
                    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
                }
            }
            fade_dir = 1;
        }
        const Scene *s = &scenes[scene];

        while (!offscreen && XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);
            if (ev.type == Expose) redraw = 1;
            if (ev.type == ConfigureNotify && ev.xconfigure.window == root && (ev.xconfigure.width != W || ev.xconfigure.height != H)) {
                W = ev.xconfigure.width; H = ev.xconfigure.height;         // resolution changed
                XResizeWindow(dpy, win, W, H);
                glBindTexture(GL_TEXTURE_2D, sum);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, W, H, 0, GL_RGBA, GL_HALF_FLOAT, NULL);
                for (int i = 0; i < 2; i++) {
                    glBindTexture(GL_TEXTURE_2D, frames_tex[i]);
                    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
                }
                art_w = art_h = 0; pending = scene; fade = 0;               // rebuild the scene's own buffer
                redraw = 1;
            }
        }
        double t = now_seconds(), dt = t - last;
        last = t;
        if (!offscreen && t - checked > 1.0) {
            checked = t;
            moving = screen_on() && (battery || on_mains()) && (always || workspace_empty());
        }
        if (reload_flag) {
            float before[NCOL][3];
            int mood_before = light_mood;
            memcpy(before, srgb, sizeof before);
            reload_flag = 0; load_palette(); if (force_mood >= 0) light_mood = force_mood; redraw = 1;
            int recoloured = memcmp(before, srgb, sizeof before) || mood_before != light_mood;
            if (recoloured) { KEEP_FRAME(); fade = 0; fade_dir = 1; }                       // new colours: cross-fade
        }
        if (next_flag || (cycle > 0 && scene_age > cycle && moving)) {
            int to = next_flag ? wanted_scene() : -1;    // a scene asked for by name, else the next one
            if (next_flag) { load_palette(); if (force_mood >= 0) light_mood = force_mood; }   // one signal does both
            next_flag = 0; scene_age = 0;
            pending = to >= 0 ? to : (scene + 1) % nscenes;
            KEEP_FRAME(); fade = 0;                      // cross-fade from what is on screen now
        }
        int fading = (fade_dir > 0 && fade < 1) || fade_dir < 0;
        if (!moving && !fading && !redraw) {             // nothing to do: sleep until X or a signal wakes us
            struct pollfd fd = {ConnectionNumber(dpy), POLLIN, 0};
            poll(&fd, 1, 1000);
            last = now_seconds();
            continue;
        }
        if (dt > 0.25) dt = 0.25;
        if (bench) dt = 1.0 / 30;
        if (moving) { clock += dt; scene_age += dt; }
        if (!offscreen) fade += fade_dir * dt / FADE_SECONDS;
        if (fade > 1) fade = 1;
        if (fade < 0) fade = 0;
        float ease = (float)(fade * fade * (3 - 2 * fade));
        GLuint target = offscreen ? shot_fbo : 0;

        if (s->kind == SHADER) {
            glBindFramebuffer(GL_FRAMEBUFFER, art_fbo);
            glViewport(0, 0, art_w, art_h);
            glDisable(GL_BLEND);
            glUseProgram(s->prog);
            glUniform1f(glGetUniformLocation(s->prog, "u_time"), (float)clock);
            glUniform2f(glGetUniformLocation(s->prog, "u_res"), (float)art_w, (float)art_h);
            glUniform1f(glGetUniformLocation(s->prog, "u_light"), (float)light_mood);
            for (int c = 0; c < NCOL; c++) glUniform3fv(glGetUniformLocation(s->prog, COLOUR_UNIFORMS[c]), 1, srgb[c]);
            glBindVertexArray(empty_vao);
            glDrawArrays(GL_TRIANGLES, 0, 3);

            glBindFramebuffer(GL_FRAMEBUFFER, final_fbo);
            glViewport(0, 0, W, H);
            glUseProgram(show);
            glBindTexture(GL_TEXTURE_2D, art_tex);
            glUniform2f(glGetUniformLocation(show, "u_res"), (float)W, (float)H);
            glUniform3fv(glGetUniformLocation(show, "u_bg"), 1, srgb[C_BG]);
            glUniform1f(glGetUniformLocation(show, "u_fade"), 1.0f);
            glDrawArrays(GL_TRIANGLES, 0, 3);
        } else {
            // camera: orbits turn once in about three minutes with a gentle nod; flat figures
            // face the viewer and only sway (the seed head also spins in its own plane)
            float turn = (float)(clock * 0.035), nod = 0.35f + 0.18f * sinf((float)clock * 0.021f), spin = 0;
            if (s->kind == CURVE) { turn = 0.14f * sinf((float)clock * 0.05f); nod = 0.10f * sinf((float)clock * 0.037f); }
            if (s->kind == DOTS) { turn = 0.22f * sinf((float)clock * 0.04f); nod = 0.42f + 0.10f * sinf((float)clock * 0.03f); spin = (float)(clock * 0.02); }
            float aspect = (float)W / H, fl = 1.0f / tanf(0.34f), n = 0.1f, f = 10.0f;
            float proj[16] = {fl / aspect, 0, 0, 0, 0, fl, 0, 0, 0, 0, (f + n) / (n - f), -1, 0, 0, 2 * f * n / (n - f), 0};
            float back[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, -3.1f, 1};
            float ry[16] = {cosf(turn), 0, -sinf(turn), 0, 0, 1, 0, 0, sinf(turn), 0, cosf(turn), 0, 0, 0, 0, 1};
            float rx[16] = {1, 0, 0, 0, 0, cosf(nod), sinf(nod), 0, 0, -sinf(nod), cosf(nod), 0, 0, 0, 0, 1};
            float rz[16] = {cosf(spin), sinf(spin), 0, 0, -sinf(spin), cosf(spin), 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
            float mvp[16];
            mul(ry, rz, mvp); mul(rx, mvp, mvp); mul(back, mvp, mvp); mul(proj, mvp, mvp);

            glBindVertexArray(vao);
            if (s->kind != ORBIT) {
                if (s->kind == CURVE) fill_curve(clock); else fill_dots(clock);
                glBindBuffer(GL_ARRAY_BUFFER, vbo);
                glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float) * 5 * nverts, verts);
            }
            glBindFramebuffer(GL_FRAMEBUFFER, fbo);
            glViewport(0, 0, W, H);
            glClearColor(0, 0, 0, 0); glClear(GL_COLOR_BUFFER_BIT);
            glEnable(GL_BLEND); glBlendFunc(GL_ONE, GL_ONE);
            glUseProgram(points);
            glUniformMatrix4fv(glGetUniformLocation(points, "u_mvp"), 1, GL_FALSE, mvp);
            glUniform1f(glGetUniformLocation(points, "u_time"), (float)clock);
            glUniform1f(glGetUniformLocation(points, "u_size"), H / 1080.0f * 3.2f);
            glUniform3fv(glGetUniformLocation(points, "u_a"), 1, linear[C_A]);
            glUniform3fv(glGetUniformLocation(points, "u_b"), 1, linear[C_B]);
            glUniform1f(glGetUniformLocation(points, "u_light"), (float)light_mood);
            GLint mode = glGetUniformLocation(points, "u_mode");
            if (s->kind == DOTS) {
                glUniform1i(mode, 2); glDrawArrays(GL_POINTS, 0, nverts);
            } else {
                glUniform1i(mode, 0); glDrawArrays(GL_LINE_STRIP, 0, nverts);
                glUniform1i(mode, 1); glDrawArrays(GL_POINTS, 0, nverts);
            }

            glBindFramebuffer(GL_FRAMEBUFFER, final_fbo);
            glDisable(GL_BLEND);
            glUseProgram(tone);
            glBindTexture(GL_TEXTURE_2D, sum);
            glUniform2f(glGetUniformLocation(tone, "u_res"), (float)W, (float)H);
            glUniform3fv(glGetUniformLocation(tone, "u_bg"), 1, linear[C_BG]);
            glUniform3fv(glGetUniformLocation(tone, "u_deep"), 1, linear[C_DEEP]);
            glUniform1f(glGetUniformLocation(tone, "u_light"), (float)light_mood);
            glUniform1f(glGetUniformLocation(tone, "u_fade"), 1.0f);
            glUniform1f(glGetUniformLocation(tone, "u_gain"), (light_mood ? 0.55f : 0.85f) * (s->kind == DOTS ? 1.6f : 1.0f));
            glBindVertexArray(empty_vao);
            glDrawArrays(GL_TRIANGLES, 0, 3);
        }

        // to the screen: the new frame over the kept one
        glBindFramebuffer(GL_FRAMEBUFFER, target);
        glViewport(0, 0, W, H);
        glDisable(GL_BLEND);
        glUseProgram(present);
        glActiveTexture(GL_TEXTURE3); glBindTexture(GL_TEXTURE_2D, kept_tex);
        glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, final_tex);
        glUniform1i(glGetUniformLocation(present, "u_new"), 0);
        glUniform1i(glGetUniformLocation(present, "u_old"), 3);
        glUniform2f(glGetUniformLocation(present, "u_res"), (float)W, (float)H);
        glUniform1f(glGetUniformLocation(present, "u_fade"), ease);
        glBindVertexArray(empty_vao);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        if (bench) {
            glFinish();
            if (frames == 5) bench_start = now_seconds();          // the first frames pay for compiling
            if (++frames == bench + 5) {
                printf("%s: %.2f ms per frame at %dx%d\n", s->name, (now_seconds() - bench_start) * 1000 / bench, W, H);
                return 0;
            }
            continue;
        }
        if (snapshot) {
            unsigned char *px = malloc((size_t)W * H * 3);
            glPixelStorei(GL_PACK_ALIGNMENT, 1);
            glReadPixels(0, 0, W, H, GL_RGB, GL_UNSIGNED_BYTE, px);
            FILE *out = fopen(snapshot, "wb");
            if (!out) { fprintf(stderr, "mathwall: cannot write %s\n", snapshot); return 1; }
            fprintf(out, "P6\n%d %d\n255\n", W, H);
            for (int row = H - 1; row >= 0; row--) fwrite(px + (size_t)row * W * 3, 3, W, out);   // GL rows run bottom-up
            fclose(out);
            return 0;
        }
        glXSwapBuffers(dpy, win);
        redraw = 0;

        double spent = now_seconds() - t, frame = 1.0 / (s->fps > 0 && !fps_given ? s->fps : fps);
        if (spent < frame) {
            struct timespec nap = {0, (long)((frame - spent) * 1e9)};
            nanosleep(&nap, NULL);
        }
    }
    glXMakeCurrent(dpy, None, NULL);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
