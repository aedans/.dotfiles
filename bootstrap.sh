#!/bin/bash

ln -sf "$(pwd)/etc/nixos/configuration.nix" /etc/nixos/configuration.nix

nixos-rebuild switch
