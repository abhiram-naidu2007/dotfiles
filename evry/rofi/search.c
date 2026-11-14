#include <gio/gio.h>
#include <gmodule.h>
#include <string.h>

#include <rofi/helper.h>
#include <rofi/mode.h>
#include <rofi/mode-private.h>
#include <rofi/rofi-icon-fetcher.h>

#define ROW_MARKUP 8

typedef struct RofiViewState RofiViewState;
extern RofiViewState *rofi_view_get_active(void);
extern const char *rofi_view_get_user_input(const RofiViewState *state);

G_MODULE_EXPORT Mode mode;

typedef struct {
    char *input;
} Priv;

typedef struct {
    const char *key, *name, *icon;
} Engine;

static const Engine ENGINES[] = {
    {"g", "Google", "web-browser"},           {"ddg", "DuckDuckGo", "web-browser"},
    {"yt", "YouTube", "youtube"},             {"gh", "GitHub", "github"},
    {"w", "Wikipedia", "wikipedia"},          {"te", "Telugu Wikipedia", "wikipedia"},
    {"aw", "the Arch Wiki", "archlinux"},     {"pkg", "Ubuntu packages", "system-software-install"},
    {"maps", "Maps", "maps"},                 {"tr", "Translate", "accessories-dictionary"},
    {"mal", "MyAnimeList", "web-browser"},    {"dex", "Bulbapedia", "web-browser"},
    {"ai", "Claude", "web-browser"},
};

static const Engine *engine_of(const char *in, const char **rest) {
    const char *sp = strchr(in, ' ');
    if (sp && sp[1]) {
        size_t n = sp - in;
        for (size_t i = 0; i < G_N_ELEMENTS(ENGINES); i++)
            if (strlen(ENGINES[i].key) == n && strncmp(in, ENGINES[i].key, n) == 0) {
                *rest = sp + 1;
                return &ENGINES[i];
            }
    }
    *rest = in;
    return NULL;
}

static gboolean looks_like_url(const char *s) {
    if (strchr(s, ' ')) return FALSE;
    if (g_str_has_prefix(s, "http://") || g_str_has_prefix(s, "https://") || g_str_has_prefix(s, "localhost")) return TRUE;
    const char *dot = strrchr(s, '.');
    if (!dot || dot == s) return FALSE;
    const char *tld = dot + 1;
    size_t n = strcspn(tld, "/:");
    if (n < 2 || n > 6) return FALSE;
    for (size_t i = 0; i < n; i++)
        if (!g_ascii_isalpha(tld[i])) return FALSE;
    return TRUE;
}

static int s_init(Mode *sw) {
    if (mode_get_private_data(sw) == NULL) mode_set_private_data(sw, g_new0(Priv, 1));
    return TRUE;
}

static unsigned int s_num(G_GNUC_UNUSED const Mode *sw) { return 1; }

static void s_destroy(Mode *sw) {
    Priv *p = mode_get_private_data(sw);
    if (p) {
        g_free(p->input);
        g_free(p);
        mode_set_private_data(sw, NULL);
    }
}

static char *s_pre(Mode *sw, const char *input) {
    Priv *p = mode_get_private_data(sw);
    g_free(p->input);
    p->input = g_strstrip(g_strdup(input ? input : ""));
    return g_strdup(input);
}

static void sync_input(const Mode *sw) {
    Priv *p = mode_get_private_data(sw);
    RofiViewState *v = rofi_view_get_active();
    const char *in = v ? rofi_view_get_user_input(v) : NULL;
    if (!p || !in) return;
    if (!p->input || strcmp(p->input, in) != 0) {
        g_free(p->input);
        p->input = g_strstrip(g_strdup(in));
    }
}

static int s_match(const Mode *sw, G_GNUC_UNUSED rofi_int_matcher **tokens, G_GNUC_UNUSED unsigned int index) {
    sync_input(sw);
    Priv *p = mode_get_private_data(sw);
    return p && p->input && strlen(p->input) >= 2;
}

static char *s_display(const Mode *sw, G_GNUC_UNUSED unsigned int index, int *state, G_GNUC_UNUSED GList **attrs, int get_entry) {
    *state |= ROW_MARKUP;
    if (!get_entry) return NULL;
    sync_input(sw);
    Priv *p = mode_get_private_data(sw);
    const char *in = p && p->input ? p->input : "";
    const char *rest;
    const Engine *e = engine_of(in, &rest);
    char *q = g_markup_escape_text(rest, -1);
    if (!e && !looks_like_url(in)) {
        GString *g = g_string_new(NULL);
        for (const char *c = q; *c; c = g_utf8_next_char(c)) {
            g_string_append_len(g, c, g_utf8_next_char(c) - c);
            if (*g_utf8_next_char(c)) g_string_append(g, "\u2060\u2060\u2060");
        }
        g_free(q);
        q = g_string_free(g, FALSE);
    }
    char *out;
    if (e)
        out = g_strdup_printf("%s\n<span size='small' alpha='62%%'>search %s  ·  Enter</span>", q, e->name);
    else if (looks_like_url(in))
        out = g_strdup_printf("%s\n<span size='small' alpha='62%%'>open this address  ·  Enter</span>", q);
    else
        out = g_strdup_printf("Search the web for “%s”\n<span size='small' alpha='62%%'>Enter  ·  Ctrl+Enter searches from any row  ·  yt gh w te aw pkg maps tr mal dex ai</span>", q);
    g_free(q);
    return out;
}

static cairo_surface_t *s_icon(const Mode *sw, G_GNUC_UNUSED unsigned int index, unsigned int height) {
    Priv *p = mode_get_private_data(sw);
    const char *rest;
    const Engine *e = engine_of(p && p->input ? p->input : "", &rest);
    static uint32_t uid[G_N_ELEMENTS(ENGINES) + 1];
    static gboolean asked[G_N_ELEMENTS(ENGINES) + 1];
    size_t i = e ? (size_t)(e - ENGINES) : G_N_ELEMENTS(ENGINES);
    if (!asked[i]) {
        uid[i] = rofi_icon_fetcher_query(e ? e->icon : "web-browser", height);
        asked[i] = TRUE;
    }
    cairo_surface_t *s = rofi_icon_fetcher_get(uid[i]);
    if (!s && e) {
        static uint32_t fb;
        if (!fb) fb = rofi_icon_fetcher_query("web-browser", height);
        s = rofi_icon_fetcher_get(fb);
    }
    return s;
}

static ModeMode s_result(Mode *sw, int retv, char **input, G_GNUC_UNUSED unsigned int selected) {
    if (retv & (MENU_NEXT | MENU_PREVIOUS | MENU_QUICK_SWITCH | MENU_CANCEL)) {
        if (retv & MENU_NEXT) return NEXT_DIALOG;
        if (retv & MENU_PREVIOUS) return PREVIOUS_DIALOG;
        if (retv & MENU_QUICK_SWITCH) return retv & MENU_LOWER_MASK;
        return MODE_EXIT;
    }
    Priv *p = mode_get_private_data(sw);
    const char *q = (input && *input && **input) ? *input : (p ? p->input : NULL);
    if (q && *q) {
        char *script = g_build_filename(g_get_home_dir(), ".config/rofi/scripts/websearch.sh", NULL);
        const char *argv[] = {script, q, NULL};
        g_spawn_async(NULL, (char **)argv, NULL, G_SPAWN_DEFAULT, NULL, NULL, NULL, NULL);
        g_free(script);
    }
    return MODE_EXIT;
}

Mode mode = {
    .abi_version = ABI_VERSION,
    .name = "search",
    .type = MODE_TYPE_SWITCHER,
    .cfg_name_key = "display-search",
    ._init = s_init,
    ._get_num_entries = s_num,
    ._result = s_result,
    ._destroy = s_destroy,
    ._token_match = s_match,
    ._get_display_value = s_display,
    ._get_icon = s_icon,
    ._preprocess_input = s_pre,
    .private_data = NULL,
    .free = NULL,
};
