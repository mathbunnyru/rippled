{ pkgs, ... }:
let
  inherit (import ./packages.nix { inherit pkgs; }) commonPackages;
  env = pkgs.buildEnv {
    name = "xrpld-ci-env";
    paths = commonPackages ++ [ pkgs.gcc15Stdenv.cc ];
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
