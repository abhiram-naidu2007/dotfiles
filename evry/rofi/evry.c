// rofi modes that answer while you type.
//   files.so  "files": live file search over the whole disk (evry), like voidtools' Everything.
//             "=2^10" is a calculation, "?words" a web search.
//   calc.so   "calc":  every keystroke is evaluated by qalc; Enter copies the result.
// Rofi's own modes get a fixed list once. Here each change of the input starts
// the helper in the background; when it answers, the list is replaced.
// Build: make -C ~/dotfiles/evry        Run: rofi/launcher.sh
#include <gio/gio.h>
#include <gmodule.h>
#include <string.h>

#include <rofi/helper.h>
#include <rofi/mode.h>
#include <rofi/mode-private.h>
#include <rofi/rofi-icon-fetcher.h>

#ifdef EVRY_CALC
#define MODE_NAME "calc"
#else
#define MODE_NAME "files"
#endif
#define ROW_MARKUP 8          // rofi's TextBoxFontType MARKUP (not in the public headers)
#define THUMB_MAX (12 << 20)  // image files up to this size are their own icon
#define SMALL "<span size='small' alpha='62%%'>"

// Not in the public headers, exported by the rofi binary.
typedef struct RofiViewState RofiViewState;
extern void rofi_view_reload(void);
extern RofiViewState *rofi_view_get_active(void);
extern const char *rofi_view_get_user_input(const RofiViewState *state);

G_MODULE_EXPORT Mode mode;

typedef enum { ROW_FILE, ROW_CALC, ROW_WEB, ROW_NOTE } RowKind;

typedef struct {
    RowKind kind;
    char *arg;   // file path (raw bytes), calculation result, or web query
    char *text;  // pango markup shown in the list
    char *icon;  // icon name or image path
    char *fallback;
    uint32_t uid, fallback_uid;
    int uid_size;
} Row;

typedef struct {
    GPtrArray *rows;
    char *query;  // input the last request was made for
    GCancellable *cancel;
    GSubprocess *proc;
    guint poll;
} Priv;

typedef struct {
    Mode *sw;
    RowKind kind;
    char *expr;
} Request;

static void row_free(gpointer p) {
    Row *r = p;
    g_free(r->arg);
    g_free(r->text);
    g_free(r->icon);
    g_free(r->fallback);
    g_free(r);
}

static Row *row_new(RowKind kind, const char *arg, char *text, const char *icon, const char *fallback) {
    Row *r = g_new0(Row, 1);
    r->kind = kind;
    r->arg = g_strdup(arg);
    r->text = text;
    r->icon = g_strdup(icon);
    r->fallback = g_strdup(fallback);
    return r;
}

static char *escape(const char *raw) {
    char *valid = g_utf8_make_valid(raw, -1);
    char *out = g_markup_escape_text(valid, -1);
    g_free(valid);
    return out;
}

static char *state_file(const char *name) {
    return g_build_filename(g_get_user_state_dir(), "rice", name, NULL);
}

// One line of "evry --tsv": kind \t path \t size \t age \t bytes
static Row *file_row(char *line) {
    char **f = g_strsplit(line, "\t", 5);
    if (g_strv_length(f) < 4) {
        g_strfreev(f);
        return NULL;
    }
    const char *path = f[1];
    gboolean is_dir = f[0][0] == 'd';
    const char *slash = strrchr(path, '/');
    const char *name = slash && slash[1] ? slash + 1 : path;
    char *dir = slash && slash != path ? g_strndup(path, slash - path) : g_strdup("/");
    const char *home = g_get_home_dir();
    if (g_str_has_prefix(dir, home) && (dir[strlen(home)] == '/' || dir[strlen(home)] == '\0')) {
        char *tilde = g_strconcat("~", dir + strlen(home), NULL);
        g_free(dir);
        dir = tilde;
    }
    char *ename = escape(name), *edir = escape(dir);
    char *text = is_dir ? g_strdup_printf("<b>%s</b>\n" SMALL "%s  ·  folder  ·  %s</span>", ename, edir, f[3])
                        : g_strdup_printf("%s\n" SMALL "%s  ·  %s  ·  %s</span>", ename, edir, f[2], f[3]);

    char *icon = NULL, *fallback = NULL;
    if (is_dir) {
        icon = g_strdup("folder");
    } else {
        char *type = g_content_type_guess(name, NULL, 0, NULL);
        fallback = g_content_type_get_generic_icon_name(type);
        gint64 bytes = f[4] ? g_ascii_strtoll(f[4], NULL, 10) : 0;
        if (g_str_has_prefix(type, "image/") && bytes > 0 && bytes <= THUMB_MAX) {
            icon = g_strdup(path);
        } else {
            GIcon *gicon = g_content_type_get_icon(type);
            if (G_IS_THEMED_ICON(gicon)) {
                icon = g_strdup(g_themed_icon_get_names(G_THEMED_ICON(gicon))[0]);
            }
            g_object_unref(gicon);
        }
        g_free(type);
    }
    Row *r = row_new(ROW_FILE, path, text, icon, fallback ? fallback : "text-x-generic");
    g_free(icon);
    g_free(fallback);
    g_free(ename);
    g_free(edir);
    g_free(dir);
    g_strfreev(f);
    return r;
}

// Earlier results (newest first), written by scripts/act.sh as "expression = result".
static void add_calc_history(GPtrArray *rows) {
    char *file = state_file("calc-history"), *data = NULL;
    if (g_file_get_contents(file, &data, NULL, NULL)) {
        char **lines = g_strsplit(data, "\n", -1);
        guint n = g_strv_length(lines), shown = 0;
        for (guint i = n; i-- > 0 && shown < 12;) {
            char *eq = g_strrstr(lines[i], " = ");
            if (!eq) {
                continue;
            }
            char *expr = g_strndup(lines[i], eq - lines[i]);
            char *ee = escape(expr), *er = escape(eq + 3);
            g_ptr_array_add(rows, row_new(ROW_CALC, eq + 3, g_strdup_printf("%s\n" SMALL "%s</span>", er, ee), "accessories-calculator", NULL));
            g_free(expr);
            g_free(ee);
            g_free(er);
            shown++;
        }
        g_strfreev(lines);
    }
    g_free(data);
    g_free(file);
}

static void set_rows(Mode *sw, GPtrArray *rows) {
    Priv *pd = mode_get_private_data(sw);
    g_ptr_array_unref(pd->rows);
    pd->rows = rows;
    rofi_view_reload();
}

static void on_reply(GObject *source, GAsyncResult *res, gpointer data) {
    Request *req = data;
    GBytes *out = NULL;
    // On failure (also: cancelled because the mode is gone) nothing of the mode is touched.
    if (g_subprocess_communicate_finish(G_SUBPROCESS(source), res, &out, NULL, NULL) && out) {
        gsize len = 0;
        const char *raw = g_bytes_get_data(out, &len);
        char *text = g_strndup(raw ? raw : "", len);
        GPtrArray *rows = g_ptr_array_new_with_free_func(row_free);
        if (req->kind == ROW_CALC) {
            g_strstrip(text);
            char *last = strrchr(text, '\n');  // warnings come first, the result last
            const char *result = last ? last + 1 : text;
            if (*result) {
                char *er = escape(result), *ee = escape(req->expr);
                char *entry = g_strconcat(req->expr, " = ", result, NULL);
                g_ptr_array_add(rows, row_new(ROW_CALC, entry, g_strdup_printf("<b>%s</b>\n" SMALL "= %s</span>", er, ee),
                                              "accessories-calculator", NULL));
                g_free(entry);
                g_free(er);
                g_free(ee);
            }
            add_calc_history(rows);
        } else {
            char **lines = g_strsplit(text, "\n", -1);
            for (char **l = lines; *l; l++) {
                Row *r = **l ? file_row(*l) : NULL;
                if (r) {
                    g_ptr_array_add(rows, r);
                }
            }
            g_strfreev(lines);
        }
        g_free(text);
        g_bytes_unref(out);
        set_rows(req->sw, rows);
    }
    g_free(req->expr);
    g_free(req);
}

static void request(Mode *sw, const char *input) {
    Priv *pd = mode_get_private_data(sw);
    g_free(pd->query);
    pd->query = g_strdup(input);
    if (pd->proc) {
        g_cancellable_cancel(pd->cancel);
        g_subprocess_force_exit(pd->proc);
        g_clear_object(&pd->proc);
        g_clear_object(&pd->cancel);
    }

    const char *text = input;
    while (*text == ' ') {
        text++;
    }
    RowKind kind = ROW_FILE;
#ifdef EVRY_CALC
    kind = ROW_CALC;
    if (*text == '=') {                 // the "=" that starts a calculation in the other tabs is not part of it here
        text++;
        while (*text == ' ') text++;
    }
#else
    if (*text == '=') {
        kind = ROW_CALC;
        text++;
    } else if (*text == '?') {
        char *eq = escape(text + 1);
        GPtrArray *rows = g_ptr_array_new_with_free_func(row_free);
        g_ptr_array_add(rows, row_new(ROW_WEB, text + 1, g_strdup_printf("Search the web\n" SMALL "%s</span>", eq), "web-browser", NULL));
        g_free(eq);
        set_rows(sw, rows);
        return;
    }
#endif
    if (kind == ROW_CALC && !*text) {
        GPtrArray *rows = g_ptr_array_new_with_free_func(row_free);
        add_calc_history(rows);
        set_rows(sw, rows);
        return;
    }

    const char *argv_calc[] = {"qalc", "-t", "--", text, NULL};
    const char *argv_files[] = {"evry", "q", "--tsv", "-l", "60", "--", text, NULL};
    GError *error = NULL;
    pd->proc = g_subprocess_newv(kind == ROW_CALC ? argv_calc : argv_files,
                                 G_SUBPROCESS_FLAGS_STDOUT_PIPE | G_SUBPROCESS_FLAGS_STDERR_SILENCE, &error);
    if (!pd->proc) {
        GPtrArray *rows = g_ptr_array_new_with_free_func(row_free);
        char *why = escape(error->message);
        g_ptr_array_add(rows, row_new(ROW_NOTE, NULL, g_strdup_printf("helper did not start\n" SMALL "%s</span>", why), "dialog-warning", NULL));
        g_free(why);
        g_error_free(error);
        set_rows(sw, rows);
        return;
    }
    Request *req = g_new0(Request, 1);
    req->sw = sw;
    req->kind = kind;
    req->expr = g_strdup(text);
    pd->cancel = g_cancellable_new();
    g_subprocess_communicate_async(pd->proc, NULL, pd->cancel, on_reply, req);
}

// Rofi skips preprocess_input when the input is empty, so emptying it is seen here.
static gboolean poll_input(gpointer data) {
    Mode *sw = data;
    Priv *pd = mode_get_private_data(sw);
    RofiViewState *view = rofi_view_get_active();
    const char *input = view ? rofi_view_get_user_input(view) : NULL;
    if (input && !*input && pd->query && *pd->query) {
        request(sw, "");
    }
    return G_SOURCE_CONTINUE;
}

static int evry_init(Mode *sw) {
    if (mode_get_private_data(sw) == NULL) {
        Priv *pd = g_new0(Priv, 1);
        pd->rows = g_ptr_array_new_with_free_func(row_free);
        mode_set_private_data(sw, pd);
        request(sw, "");
        pd->poll = g_timeout_add(120, poll_input, sw);
    }
    return TRUE;
}

static void evry_destroy(Mode *sw) {
    Priv *pd = mode_get_private_data(sw);
    if (pd == NULL) {
        return;
    }
    g_source_remove(pd->poll);
    if (pd->proc) {
        g_cancellable_cancel(pd->cancel);
        g_subprocess_force_exit(pd->proc);
        g_clear_object(&pd->proc);
        g_clear_object(&pd->cancel);
    }
    g_ptr_array_unref(pd->rows);
    g_free(pd->query);
    g_free(pd);
    mode_set_private_data(sw, NULL);
}

static unsigned int evry_num_entries(const Mode *sw) {
    const Priv *pd = mode_get_private_data(sw);
    return pd->rows->len;
}

static char *evry_preprocess(Mode *sw, const char *input) {
    Priv *pd = mode_get_private_data(sw);
    if (g_strcmp0(input, pd->query) != 0) {
        request(sw, input);
    }
    return g_strdup(input);
}

// The helper already chose and ordered the rows; rofi must not filter them again.
static int evry_token_match(const Mode *sw, G_GNUC_UNUSED rofi_int_matcher **tokens, unsigned int index) {
    const Priv *pd = mode_get_private_data(sw);
    return index < pd->rows->len;
}

static char *evry_display(const Mode *sw, unsigned int index, int *state, G_GNUC_UNUSED GList **attrs, int get_entry) {
    const Priv *pd = mode_get_private_data(sw);
    if (index >= pd->rows->len) {
        return get_entry ? g_strdup("") : NULL;
    }
    *state |= ROW_MARKUP;
    return get_entry ? g_strdup(((Row *)g_ptr_array_index(pd->rows, index))->text) : NULL;
}

static cairo_surface_t *evry_icon(const Mode *sw, unsigned int index, unsigned int height) {
    const Priv *pd = mode_get_private_data(sw);
    if (index >= pd->rows->len) {
        return NULL;
    }
    Row *r = g_ptr_array_index(pd->rows, index);
    if (r->uid_size != (int)height) {
        r->uid = r->icon ? rofi_icon_fetcher_query(r->icon, height) : 0;
        r->fallback_uid = r->fallback ? rofi_icon_fetcher_query(r->fallback, height) : 0;
        r->uid_size = height;
    }
    cairo_surface_t *icon = r->uid ? rofi_icon_fetcher_get(r->uid) : NULL;
    return icon || !r->fallback_uid ? icon : rofi_icon_fetcher_get(r->fallback_uid);
}

static char *evry_message(G_GNUC_UNUSED const Mode *sw) {
#ifdef EVRY_CALC
    return g_strdup("<b>⏎</b> copy result     sqrt(2)   20!   solve(x^2 = 2)   diff(sin(x)/x)   5 km to mi");
#else
    return g_strdup("<b>⏎</b> open   <b>⇧⏎</b> folder   <b>^Y</b> copy path   <b>^T</b> terminal   <b>^O</b> edit"
                    "     pdf: img: dir: ext:rs notes/   =2^10   ?web");
#endif
}

static ModeMode evry_result(Mode *sw, int retv, G_GNUC_UNUSED char **input, unsigned int selected) {
    Priv *pd = mode_get_private_data(sw);
    if (retv & MENU_NEXT) {
        return NEXT_DIALOG;
    }
    if (retv & MENU_PREVIOUS) {
        return PREVIOUS_DIALOG;
    }
    if (retv & MENU_QUICK_SWITCH) {
        return retv & MENU_LOWER_MASK;
    }
    if (retv & MENU_ENTRY_DELETE) {
        return RELOAD_DIALOG;
    }
    Row *r = NULL;
    if ((retv & (MENU_OK | MENU_CUSTOM_COMMAND)) && selected < pd->rows->len) {
        r = g_ptr_array_index(pd->rows, selected);
    } else if ((retv & MENU_CUSTOM_INPUT) && pd->rows->len > 0) {
        r = g_ptr_array_index(pd->rows, 0);  // Enter with nothing selected: the best match
    }
    if (r == NULL || r->kind == ROW_NOTE) {
        return MODE_EXIT;
    }
    const char *action = "open";
    if (r->kind == ROW_CALC) {
        action = "calc";
    } else if (r->kind == ROW_WEB) {
        action = "web";
    } else if (retv & MENU_CUSTOM_COMMAND) {
        static const char *const custom[] = {"copy", "term", "edit"};
        unsigned int k = retv & MENU_LOWER_MASK;
        action = k < G_N_ELEMENTS(custom) ? custom[k] : "open";
    } else if (retv & MENU_CUSTOM_ACTION) {
        action = "reveal";
    }
    const char *env = g_getenv("EVRY_ACT");
    char *script = env ? g_strdup(env) : g_build_filename(g_get_user_config_dir(), "rofi", "scripts", "act.sh", NULL);
    char *argv[] = {script, (char *)action, r->arg, NULL};
    GError *error = NULL;
    if (!g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL, &error)) {
        g_warning("evry: %s", error->message);
        g_error_free(error);
    }
    g_free(script);
    return MODE_EXIT;
}

Mode mode = {
    .abi_version = ABI_VERSION,
    .name = MODE_NAME,
    .cfg_name_key = "display-" MODE_NAME,
    ._init = evry_init,
    ._destroy = evry_destroy,
    ._get_num_entries = evry_num_entries,
    ._result = evry_result,
    ._token_match = evry_token_match,
    ._get_display_value = evry_display,
    ._get_icon = evry_icon,
    ._get_message = evry_message,
    ._preprocess_input = evry_preprocess,
    .type = MODE_TYPE_SWITCHER,
};
