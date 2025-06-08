
default:
  @just --list

# For testing
build:
  set -x NIXPKGS_ALLOW_UNFREE 1
  nix develop --impure
