# Dumps and loads Firefox's add-ons and the settings of the ones that have a
# script here, like dump-dconf.sh and bootstrap.sh do for GNOME.
#
#   dump  writes .config/firefox: extensions.txt, from the profile, and
#         settings/<name>.json for each installed add-on with a dump. Reads a
#         copy of the profile, so Firefox can stay open.
#   load  applies each settings/<name>.json to the profile; Firefox must be
#         closed. Add-ons in extensions.txt are installed by policy (see
#         nix/firefox.nix), on this run too.
#
# Each add-on's script (see SCRIPTED) runs in one of its pages and defines
# load(settings), and dump() unless its settings are only written by hand.
#
# Dark Reader is disabled on the sites Stylus styles, so Catppuccin's
# userstyles aren't darkened again: load adds them to Dark Reader's
# disabledFor and dump leaves them out, so darkreader.json only holds the
# sites added by hand.

import configparser
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from marionette import Firefox

HERE = Path(__file__).resolve().parent
CONFIG = HERE.parent / ".config/firefox"
EXTENSIONS = CONFIG / "extensions.txt"
SETTINGS = CONFIG / "settings"
PROFILES = Path.home() / ".mozilla/firefox"

STYLUS = {"name": "stylus", "id": "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}", "page": "manage.html", "dumps": False}
DARK_READER = {"name": "darkreader", "id": "addon@darkreader.org", "page": "ui/popup/index.html", "dumps": True}
FIREFOX_COLOR = {"name": "firefoxcolor", "id": "FirefoxColor@mozilla.com", "page": "_generated_background_page.html", "dumps": True}
# In load order: Dark Reader's settings depend on Stylus's styles.
SCRIPTED = [STYLUS, DARK_READER, FIREFOX_COLOR]

# What a dump copies leaves out: site data, history, caches and the session,
# which would otherwise reopen its tabs.
UNCOPIED = {
    "lock", ".parentlock", "cache2", "startupCache", "crashes", "minidumps",
    "datareporting", "saved-telemetry-pings", "sessionstore-backups", "security_state",
}
UNCOPIED_PREFIXES = ("places.", "favicons.", "cookies.", "suggest.", "sessionstore")


def default_profile():
    ini = configparser.ConfigParser()
    if not ini.read(PROFILES / "profiles.ini"):
        return None
    # The [Install...] section names the profile this firefox build launches;
    # older profiles.ini files only mark it with Default=1.
    for section in ini.sections():
        if section.startswith("Install"):
            return PROFILES / ini[section]["Default"]
    for section in ini.sections():
        if ini[section].get("Default") == "1":
            return PROFILES / ini[section]["Path"]
    return None


def is_running(profile):
    # The lock links to "<ip>:+<pid>" while Firefox has the profile open.
    try:
        pid = int(os.readlink(profile / "lock").rsplit("+", 1)[1])
        os.kill(pid, 0)
        return True
    except (OSError, IndexError, ValueError):
        return False


def installed_extensions(profile):
    with open(profile / "extensions.json") as f:
        addons = json.load(f)["addons"]
    # app-profile is what the user installed; builtins and system add-ons live elsewhere.
    return sorted({a["id"] for a in addons if a["location"] == "app-profile"})


def declared_extensions():
    return [line for line in EXTENSIONS.read_text().splitlines() if line]


def call(firefox, extension, function, *args):
    firefox.open_extension(extension["id"], extension["page"])
    script = (HERE / f"{extension['name']}.js").read_text()
    return firefox.marionette.execute(f"{script}\nreturn await {function}(...args);", *args)


def copy_profile(profile, into):
    def ignore(directory, names):
        ignored = {n for n in names if n in UNCOPIED or n.startswith(UNCOPIED_PREFIXES)}
        if Path(directory) == profile / "storage/default":
            # Websites' storage; add-ons' is under moz-extension+++.
            ignored |= {n for n in names if n.startswith(("http", "file"))}
        return ignored

    shutil.copytree(profile, into, ignore=ignore, symlinks=True)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def dump():
    profile = default_profile()
    if not profile:
        sys.exit("No Firefox profile to dump")

    extensions = installed_extensions(profile)
    print(f"Dumping firefox extensions to {EXTENSIONS}")
    EXTENSIONS.parent.mkdir(parents=True, exist_ok=True)
    EXTENSIONS.write_text("".join(f"{id}\n" for id in extensions))

    dumped = [e for e in SCRIPTED if e["dumps"] and e["id"] in extensions]
    if not dumped:
        return
    with tempfile.TemporaryDirectory() as temp:
        copy = Path(temp) / "profile"
        copy_profile(profile, copy)
        with Firefox(copy) as firefox:
            for extension in dumped:
                settings = call(firefox, extension, "dump")
                if extension is DARK_READER and STYLUS["id"] in extensions:
                    styled = set(call(firefox, STYLUS, "sites"))
                    settings["disabledFor"] = [s for s in settings["disabledFor"] if s not in styled]
                path = SETTINGS / f"{extension['name']}.json"
                print(f"Dumping {extension['name']} settings to {path}")
                write_json(path, settings)


def load():
    profile = default_profile()
    if profile and is_running(profile):
        sys.exit("Close Firefox first: its profile can only be open once")

    extensions = declared_extensions()
    # Without a profile, Firefox makes the one it would have on first launch.
    with Firefox(profile) as firefox:
        for extension in SCRIPTED:
            path = SETTINGS / f"{extension['name']}.json"
            if not path.exists():
                continue
            print(f"Loading {extension['name']} settings from {path}")
            settings = json.loads(path.read_text())
            if extension is DARK_READER and STYLUS["id"] in extensions:
                styled = call(firefox, STYLUS, "sites")
                settings["disabledFor"] += [s for s in styled if s not in settings["disabledFor"]]
            call(firefox, extension, "load", settings)


if __name__ == "__main__":
    commands = {"dump": dump, "load": load}
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        sys.exit("usage: settings.py dump|load")
    commands[sys.argv[1]]()
