// LD_PRELOAD library for limusic (Tauri/WebKitGTK): adds a user stylesheet to every
// webview and swaps it when the file changes. Rules apply only where the page is
// limusic's own (html[data-rice]), never to the Google sign-in page.
//   LIMUSIC_RICE_CSS   stylesheet path (default ~/.config/limusic-rice/rice.css)
//   LIMUSIC_RICE_DUMP  file to write limusic's DOM, CSS variables and rules to
#define _GNU_SOURCE
#include <dlfcn.h>
#include <gio/gio.h>

typedef void Manager;
typedef void Sheet;
typedef void Script;

enum { ALL_FRAMES = 0, TOP_FRAME = 1, AT_START = 0, AT_END = 1, LEVEL_AUTHOR = 1 };

static struct {
    Manager *(*manager_new)(void);
    void (*add_sheet)(Manager *, Sheet *);
    void (*remove_sheets)(Manager *);
    Sheet *(*sheet_new)(const char *, int, int, const char *const *, const char *const *);
    void (*sheet_unref)(Sheet *);
    void (*add_script)(Manager *, Script *);
    Script *(*script_new)(const char *, int, int, const char *const *, const char *const *);
    void (*script_unref)(Script *);
    gboolean (*register_handler)(Manager *, const char *);
    void *(*result_value)(void *);
    char *(*value_to_string)(void *);
} wk;

static GPtrArray *managers;
static char *css_path;
static GFileMonitor *monitor;

static const char MARK[] =
    "if (location.protocol === 'tauri:' || location.hostname === 'tauri.localhost')"
    " document.documentElement.setAttribute('data-rice', '');";

static const char DUMP[] =
    "setTimeout(() => {"
    " if (!document.documentElement.hasAttribute('data-rice')) return;"
    " const rules = [], vars = {};"
    " for (const s of document.styleSheets) { try { for (const r of s.cssRules) rules.push(r.cssText); } catch (e) {} }"
    " const cs = getComputedStyle(document.documentElement);"
    " for (const r of rules) for (const m of r.matchAll(/(--[\\w-]+)\\s*:/g)) vars[m[1]] = cs.getPropertyValue(m[1]).trim();"
    " window.webkit.messageHandlers.riceDump.postMessage(JSON.stringify({vars, html: document.body.outerHTML, rules}));"
    "}, 4000);";

static void apply(Manager *m) {
    char *css = NULL;
    wk.remove_sheets(m);
    if (g_file_get_contents(css_path, &css, NULL, NULL)) {
        Sheet *s = wk.sheet_new(css, ALL_FRAMES, LEVEL_AUTHOR, NULL, NULL);
        wk.add_sheet(m, s);
        wk.sheet_unref(s);
        g_free(css);
    }
}

static void apply_each(gpointer m, gpointer data) {
    (void)data;
    apply(m);
}

static void forget(gpointer list, GObject *gone) {
    g_ptr_array_remove(list, gone);
}

static void on_change(GFileMonitor *mon, GFile *f, GFile *other, GFileMonitorEvent ev, gpointer data) {
    (void)mon, (void)f, (void)other, (void)data;
    if (ev == G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT || ev == G_FILE_MONITOR_EVENT_CREATED || ev == G_FILE_MONITOR_EVENT_DELETED)
        g_ptr_array_foreach(managers, apply_each, NULL);
}

static void on_dump(Manager *m, void *result, gpointer path) {
    (void)m;
    char *json = wk.value_to_string(wk.result_value(result));
    g_file_set_contents(path, json, -1, NULL);
    g_free(json);
}

static void add_script(Manager *m, const char *src, int when) {
    Script *s = wk.script_new(src, TOP_FRAME, when, NULL, NULL);
    wk.add_script(m, s);
    wk.script_unref(s);
}

static gboolean bind(void) {
    void *h = RTLD_DEFAULT;
    wk.manager_new = dlsym(RTLD_NEXT, "webkit_user_content_manager_new");
    wk.add_sheet = dlsym(h, "webkit_user_content_manager_add_style_sheet");
    wk.remove_sheets = dlsym(h, "webkit_user_content_manager_remove_all_style_sheets");
    wk.sheet_new = dlsym(h, "webkit_user_style_sheet_new");
    wk.sheet_unref = dlsym(h, "webkit_user_style_sheet_unref");
    wk.add_script = dlsym(h, "webkit_user_content_manager_add_script");
    wk.script_new = dlsym(h, "webkit_user_script_new");
    wk.script_unref = dlsym(h, "webkit_user_script_unref");
    wk.register_handler = dlsym(h, "webkit_user_content_manager_register_script_message_handler");
    wk.result_value = dlsym(h, "webkit_javascript_result_get_js_value");
    wk.value_to_string = dlsym(h, "jsc_value_to_string");
    return wk.manager_new && wk.add_sheet && wk.remove_sheets && wk.sheet_new && wk.sheet_unref && wk.add_script &&
           wk.script_new && wk.script_unref;
}

Manager *webkit_user_content_manager_new(void) {
    static int ready = -1;
    if (ready < 0) {
        ready = bind();
        if (ready) {
            const char *env = g_getenv("LIMUSIC_RICE_CSS");
            css_path = env ? g_strdup(env) : g_build_filename(g_get_user_config_dir(), "limusic-rice", "rice.css", NULL);
            managers = g_ptr_array_new();
            GFile *f = g_file_new_for_path(css_path);
            monitor = g_file_monitor_file(f, G_FILE_MONITOR_NONE, NULL, NULL);
            g_object_unref(f);
            if (monitor) g_signal_connect(monitor, "changed", G_CALLBACK(on_change), NULL);
        }
    }
    if (!wk.manager_new) wk.manager_new = dlsym(RTLD_NEXT, "webkit_user_content_manager_new");
    Manager *m = wk.manager_new();
    if (ready != 1 || !m) return m;
    g_ptr_array_add(managers, m);
    g_object_weak_ref(m, forget, managers);
    add_script(m, MARK, AT_START);
    apply(m);
    const char *dump = g_getenv("LIMUSIC_RICE_DUMP");
    if (dump && wk.register_handler && wk.result_value && wk.value_to_string && wk.register_handler(m, "riceDump")) {
        g_signal_connect(m, "script-message-received::riceDump", G_CALLBACK(on_dump), g_strdup(dump));
        add_script(m, DUMP, AT_END);
    }
    return m;
}
