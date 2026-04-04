#!/usr/bin/env bash

for in in /org/gnome/shell/ /org/gnome/desktop/ /org/gnome/mutter/; do
    echo Dumping $in to /home/hans/.dotfiles/nix/de/dconf/${in////-}.nix
    dconf dump $in > .config/dconf/${in////-}.txt
done
