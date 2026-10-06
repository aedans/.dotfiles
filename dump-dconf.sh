#!/usr/bin/env bash

cd "$(dirname "$0")"

# Turn dconf-ignore.txt globs into one anchored regex over full key paths.
ignore=$(grep -vE '^\s*(#|$)' dconf-ignore.txt \
    | sed -e 's/[.[\^$+?(){}|]/\\&/g' -e 's/\*/[^\/]*/g' \
    | paste -sd '|')

for in in /org/gnome/shell/ /org/gnome/desktop/ /org/gnome/mutter/; do
    out=.config/dconf/${in////-}.txt
    echo Dumping $in to $out
    dconf dump $in | awk -v root="${in%/}" -v ignore="^(${ignore})\$" '
        # Buffer each section so ones left empty by the filter are dropped.
        function flush() {
            if (body != "") printf "%s%s\n%s", sep, header, body, sep = "\n"
            body = ""
        }
        /^\[.*\]$/ {
            flush()
            header = $0
            section = substr($0, 2, length($0) - 2)
            prefix = section == "/" ? root "/" : root "/" section "/"
            next
        }
        /^$/ { next }
        {
            key = substr($0, 1, index($0, "=") - 1)
            if ((prefix key) !~ ignore) body = body $0 "\n"
        }
        END { flush() }
    ' > $out
done
