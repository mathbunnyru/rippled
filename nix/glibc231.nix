# glibc 2.31 — matches Ubuntu 20.04 LTS.
#
# Sourced from the upstream nixpkgs snapshot that shipped glibc 2.31 as the
# primary version (2020-06-30), so the build uses the compiler from that
# snapshot (gcc 9.3.0) along with the matching patches, configure flags, and
# hardening defaults. builtins.fetchTarball is a build-time fetch, so this
# does not appear in flake.lock.
{ pkgs }:

let
  nixpkgsRev = "9cd98386a38891d1074fc18036b842dc4416f562";

  oldNixpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsRev}.tar.gz";
    sha256 = "0zanfgvsnvca39c44svfzy6v0p4vl3k38kq94vyv541vcbxmcdpr";
  }) { inherit (pkgs.stdenv.hostPlatform) system; };
in
oldNixpkgs.glibc
