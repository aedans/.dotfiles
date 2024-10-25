#!/usr/bin/env bash

for in in /org/gnome/shell/ /org/gnome/desktop/ /org/gnome/mutter/; do
    echo Dumping $in to /home/hans/.dotfiles/nix/de/dconf/${in////-}.nix
    nix-shell -p dconf2nix --command "dconf dump $in | dconf2nix --root $in > /home/hans/.dotfiles/nix/de/dconf/${in////-}.nix"
done

echo Dumping vscode extensions
code --list-extensions | tr '[:upper:]' '[:lower:]' > /home/hans/.dotfiles/.config/Code/User/extensions.txt
