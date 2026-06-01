{
  description = "Nix related things for xrpld";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    # Last nixpkgs commit with glibc 2.31 (2020-06-30) — matches Ubuntu 20.04 LTS.
    # Imported as flake = false because this revision predates nixpkgs' own flake.nix.
    nixpkgs-glibc-2-31 = {
      url = "github:NixOS/nixpkgs/9cd98386a38891d1074fc18036b842dc4416f562";
      flake = false;
    };

    # Last nixpkgs commit with glibc 2.34 (2022-07-26) — matches RHEL 9 / UBI 9.
    nixpkgs-glibc-2-34 = {
      url = "github:NixOS/nixpkgs/cd935b2d96037d2eee31529d27340c12098d9b07";
      flake = false;
    };

    # Last nixpkgs commit with glibc 2.35 (2023-04-10) — highest available in nixpkgs
    # below Debian Bookworm's native glibc 2.36 (nixpkgs skipped 2.36, going 2.35→2.37).
    nixpkgs-glibc-2-35 = {
      url = "github:NixOS/nixpkgs/f9c5b550c2ff7116bb39783f34820754a11c016b";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-glibc-2-31,
      nixpkgs-glibc-2-34,
      nixpkgs-glibc-2-35,
      ...
    }:
    let
      forEachSystem = import ./nix/utils.nix {
        inherit
          nixpkgs
          nixpkgs-glibc-2-31
          nixpkgs-glibc-2-34
          nixpkgs-glibc-2-35
          ;
      };
    in
    {
      devShells = forEachSystem (import ./nix/devshell.nix);
      packages = forEachSystem (import ./nix/ci-env.nix);
      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixfmt);
    };
}
