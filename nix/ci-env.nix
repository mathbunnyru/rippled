{ pkgs, ... }:
let
  devshell = import ./devshell.nix { inherit pkgs; };
  # Extract the packages list from the default shell's inputs
  env = pkgs.buildEnv {
    name = "xrpld-ci-env";
    paths =
      devshell.default.nativeBuildInputs
      ++ devshell.default.buildInputs
      ++ (devshell.default.propagatedBuildInputs or [ ])
      ++ [ devshell.default.stdenv.cc ];
    pathsToLink = [
      "/bin"
      "/lib"
      "/include"
      "/share"
    ];
    ignoreCollisions = true;
  };
in
{
  default = env;
}
