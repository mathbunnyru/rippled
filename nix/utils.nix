{
  nixpkgs,
  nixpkgs-glibc-2-31,
  nixpkgs-glibc-2-34,
  nixpkgs-glibc-2-35,
}:
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
      pkgs = import nixpkgs { inherit system; };
      # glibc 2.31 — matches Ubuntu 20.04 LTS. Sourced from a nixpkgs snapshot
      # that predates nixpkgs' own flake.nix (hence flake = false above).
      glibc-2-31 = (import nixpkgs-glibc-2-31 { inherit system; }).glibc;
      # glibc 2.34 — matches RHEL 9 / UBI 9.
      glibc-2-34 = (import nixpkgs-glibc-2-34 { inherit system; }).glibc;
      # glibc 2.35 — highest version available in nixpkgs that is below Debian
      # Bookworm's native glibc 2.36 (nixpkgs skipped 2.36 entirely).
      glibc-2-35 = (import nixpkgs-glibc-2-35 { inherit system; }).glibc;
    }
  )
