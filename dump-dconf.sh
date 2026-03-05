#!/usr/bin/env bash

for in in /org/gnome/shell/ /org/gnome/desktop/ /org/gnome/mutter/; do
    echo Dumping $in to /home/hans/.dotfiles/nix/de/dconf/${in////-}.nix
    nix-shell -p dconf2nix --command "dconf dump $in | dconf2nix --root $in > /home/hans/.dotfiles/home/dconf/${in////-}.nix"
done
