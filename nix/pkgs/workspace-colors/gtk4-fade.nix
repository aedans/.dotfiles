# GTK 4's transitions for theme changes (faded, a transition-property list) on
# the nodes libadwaita's stylesheet gives a text color (see scope-css.py), in
# fade.css. The themes recolor GTK 4 through libadwaita's variables, so only
# its stylesheet counts; GTK's own, which it replaces, colors nodes it leaves
# to inherit. It's compiled into the library.
{ runCommand, glib, python3, libadwaita, faded }:
runCommand "workspace-themes-gtk4-fade" {
  nativeBuildInputs = [ glib.dev (python3.withPackages (p: [ p.tinycss2 ])) ];
} ''
  gresource extract ${libadwaita}/lib/libadwaita-1.so /org/gnome/Adwaita/styles/gtk.css > adwaita.css
  # A moved stylesheet would leave nothing to fade.
  grep -q 'color:' adwaita.css
  mkdir $out
  python3 ${./scope-css.py} fade ws-animating '${faded}' < adwaita.css > $out/fade.css
''
