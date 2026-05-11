{ pkgs, ... }:
let
  inherit (import ./packages.nix { inherit pkgs; }) commonPackages;

  # glibc 2.31 — matches the system libc on Ubuntu 20.04 LTS.
  # Produced by overriding the current nixpkgs glibc; no extra flake input required.
  glibc231 = import ./glibc231.nix { inherit pkgs; };

  # binutils wrapped so that the linker emits binaries that reference glibc 2.31
  # (dynamic linker path, library search path, RPATH).
  binutils231 = pkgs.wrapBintoolsWith {
    bintools = pkgs.binutils-unwrapped;
    libc = glibc231;
  };

  # GCC 15 re-wrapped to compile and link against glibc 2.31 headers/libraries.
  # pkgs.gcc15.cc is the raw (unwrapped) GCC 15 compiler binary; we give it a
  # fresh cc-wrapper that substitutes glibc 2.31 for the default sysroot.
  gcc15WithGlibc231 = pkgs.wrapCCWith {
    cc = pkgs.gcc15.cc;
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
