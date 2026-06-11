{ nixpkgs, nixpkgs-custom-glibc }:
function:
nixpkgs.lib.genAttrs
  [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ]
  (
    system:
    function {
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          # Backport NixOS/nixpkgs@3244b07e: disable conan's
          # `test_qbsprofile_rcflags`, which requires gcc and so fails when
          # conan is built from source on Darwin. Drop this once the fix
          # reaches the nixos-unstable channel and the lock is bumped.
          (final: prev: {
            conan = prev.conan.overridePythonAttrs (old: {
              disabledTests = (old.disabledTests or [ ]) ++ [ "test_qbsprofile_rcflags" ];
            });
          })
        ];
      };
      # glibc 2.31 — matches the system libc on Ubuntu 20.04 LTS. Sourced
      # from the nixpkgs snapshot pinned via the `nixpkgs-custom-glibc`
      # flake input, so the build uses the compiler from that snapshot
      # (gcc 9.3.0) along with the matching patches, configure flags, and
      # hardening defaults.
      customGlibc = (import nixpkgs-custom-glibc { inherit system; }).glibc;
    }
  )
