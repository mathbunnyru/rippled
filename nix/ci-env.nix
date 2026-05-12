{
  pkgs,
  system,
  nixpkgs-glibc231,
  ...
}:
let
  inherit (import ./packages.nix { inherit pkgs; }) commonPackages;

  # glibc 2.31 — matches the system libc on Ubuntu 20.04 LTS. Sourced from
  # the nixpkgs snapshot pinned via the `nixpkgs-glibc231` flake input, so
  # the build uses the compiler from that snapshot (gcc 9.3.0) along with
  # the matching patches, configure flags, and hardening defaults.
  glibc231 = (import nixpkgs-glibc231 { inherit system; }).glibc;

  # binutils wrapped to emit binaries that reference glibc 2.31 (dynamic
  # linker path, library search path, RPATH).
  binutils231 = pkgs.wrapBintoolsWith {
    bintools = pkgs.binutils-unwrapped;
    libc = glibc231;
  };

  # A stdenv that uses the existing gcc 15 binary but with glibc 2.31 as its
  # libc. We only need this as a *build* environment — its job is to compile
  # a fresh gcc 15 whose libstdc++/libgcc target glibc 2.31.
  bootstrapGcc15WithGlibc231 = pkgs.wrapCCWith {
    cc = pkgs.gcc15.cc;
    libc = glibc231;
    bintools = binutils231;
  };
  glibc231Stdenv = pkgs.stdenvAdapters.overrideCC pkgs.stdenv bootstrapGcc15WithGlibc231;

  # Rebuild gcc 15 (specifically libstdc++ / libgcc_s) against glibc 2.31.
  # Using gcc15.cc.override { stdenv = ...; } reruns the bootstrap with the
  # glibc-2.31-flavoured stdenv, so the resulting compiler ships runtime
  # libraries that only reference symbols available in glibc 2.31.
  gcc15CcWithGlibc231 = pkgs.gcc15.cc.override {
    stdenv = glibc231Stdenv;
  };

  # cc-wrapper around the rebuilt compiler, pointing at glibc 2.31 headers
  # and libraries. This is what we actually expose to users.
  gcc15WithGlibc231 = pkgs.wrapCCWith {
    cc = gcc15CcWithGlibc231;
    libc = glibc231;
    bintools = binutils231;
  };

  env = pkgs.buildEnv {
    name = "xrpld-ci-env";
    paths = commonPackages ++ [
      gcc15WithGlibc231
      binutils231
    ];
    pathsToLink = [
      "/bin"
      "/lib"
      "/include"
      "/share"
    ];
    ignoreCollisions = false;
  };
in
{
  default = env;
}
