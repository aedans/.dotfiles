# Steam with Millennium, from unstable's recipes but built against this
# system's packages. The Steam client runs in a pressure-vessel container that
# takes libstdc++ from the host's graphics drivers, so an unstable-built
# Millennium (GCC 16) fails to dlopen next to 26.05's GCC 15 libstdc++.
{ pkgs, pkgs-unstable }:
let
  byName = name: "${pkgs-unstable.path}/pkgs/by-name/${builtins.substring 0 2 name}/${name}/package.nix";
  millennium = pkgs.callPackage (byName "millennium") { };
in
pkgs.callPackage (byName "steamWithMillennium") { inherit millennium; }
