#!/usr/bin/env bash

dconf reset -f /

set -e

if [[ $# -eq 0 ]] ; then
  echo 'usage: bash bootstrap.sh <config>'
  exit 0
fi

nix-shell -p sassc --command "bash ./Colloid-gtk-theme/install.sh --tweaks nord -l -c dark"
bash ./Colloid-icon-theme/install.sh --scheme nord
(cd Future-cursors; bash install.sh)

sudo nixos-rebuild switch --flake .#$1 --impure

nix-shell -p stow --command "stow . --no-folding"

while read in; do
  echo Installing vscode extension $in
  code --install-extension $in
done < /home/hans/.dotfiles/.config/Code/User/extensions.txt
