// LD_PRELOADed into every session process; it must stay inert outside GTK
// applications. It loads the hook built for the process's GTK once GTK is
// initialized, from whichever of two entry points comes first:
//
// - GApplication's startup signal. Applications written in JavaScript or
//   Python call GLib through GObject introspection, which looks functions up
//   in GLib's own library and so never sees an interposed function. GTK
//   itself is C, though: when it registers GtkApplication it calls
//   g_application_get_type through the dynamic linker, which lands here, and
//   that first call adds an emission hook to startup.
// - gtk_init and gtk_init_check, for processes without a GApplication, such as
//   the desktop portal that shows file pickers. libadwaita's adw_init calls
//   gtk_init the same way.
//
// GLib and GTK are only looked up at runtime, never linked.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <glib-object.h>

typedef GType (*GetTypeFn)(void);
typedef gpointer (*ClassRefFn)(GType type);
typedef guint (*SignalLookupFn)(const char *name, GType type);
typedef gulong (*AddEmissionHookFn)(guint signal_id, GQuark detail,
                                    GSignalEmissionHook hook, gpointer data,
                                    GDestroyNotify destroy);
typedef void (*AttachFn)(void);
// GTK 4's take no arguments, GTK 3's take (int *argc, char ***argv); passing
// two through is harmless for GTK 4.
typedef void (*InitFn)(void *argc, void *argv);
typedef gboolean (*InitCheckFn)(void *argc, void *argv);

// The function the process would have called without this library. A library
// loaded privately (as Qt loads GTK for its platform theme) still has its calls
// land here, but isn't in the global scope RTLD_NEXT searches, so it is found
// by name among the loaded libraries instead.
static void *real_function(const char *name, const char *const *libraries)
{
    void *real = dlsym(RTLD_NEXT, name);
    for (const char *const *library = libraries; !real && *library; library++) {
        void *handle = dlopen(*library, RTLD_LAZY | RTLD_NOLOAD);
        if (handle) {
            real = dlsym(handle, name);
            dlclose(handle);
        }
    }
    return real;
}

static const char *const gio_libraries[] = {"libgio-2.0.so.0", NULL};
static const char *const gtk_libraries[] = {"libgtk-4.so.1", "libgtk-3.so.0", NULL};

static void attach(void)
{
    // GTK 4 has gtk_widget_add_css_class; GTK 3 has gtk_style_context_add_class.
    const char *path = dlsym(RTLD_DEFAULT, "gtk_widget_add_css_class") ? HOOK_GTK4_PATH
        : dlsym(RTLD_DEFAULT, "gtk_style_context_add_class") ? HOOK_GTK3_PATH : NULL;
    void *hook = path ? dlopen(path, RTLD_NOW | RTLD_LOCAL) : NULL;
    AttachFn attach_hook = hook ? (AttachFn)dlsym(hook, "workspace_theme_attach") : NULL;
    if (attach_hook)
        attach_hook();
}

static gboolean on_startup(GSignalInvocationHint *hint, guint n_params,
                           const GValue *params, gpointer data)
{
    attach();
    return TRUE;
}

GType g_application_get_type(void)
{
    static GetTypeFn real;
    static gboolean hooked;
    if (!real)
        real = (GetTypeFn)real_function("g_application_get_type", gio_libraries);
    GType type = real();

    if (!hooked) {
        // Set first: initializing the class asks for the type again.
        hooked = TRUE;
        ClassRefFn class_ref = (ClassRefFn)dlsym(RTLD_DEFAULT, "g_type_class_ref");
        SignalLookupFn lookup = (SignalLookupFn)dlsym(RTLD_DEFAULT, "g_signal_lookup");
        AddEmissionHookFn add_hook =
            (AddEmissionHookFn)dlsym(RTLD_DEFAULT, "g_signal_add_emission_hook");
        if (class_ref && lookup && add_hook) {
            class_ref(type);
            add_hook(lookup("startup", type), 0, on_startup, NULL, NULL);
        }
    }
    return type;
}

void gtk_init(void *argc, void *argv)
{
    static InitFn real;
    if (!real)
        real = (InitFn)real_function("gtk_init", gtk_libraries);
    real(argc, argv);
    attach();
}

gboolean gtk_init_check(void *argc, void *argv)
{
    static InitCheckFn real;
    if (!real)
        real = (InitCheckFn)real_function("gtk_init_check", gtk_libraries);
    gboolean ok = real(argc, argv);
    if (ok)
        attach();
    return ok;
}
