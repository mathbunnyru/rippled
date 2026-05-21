{
  pkgs,
  glibc231,
  ...
}:
let
  inherit (import ./packages.nix { inherit pkgs; }) commonPackages;

  # binutils wrapped to emit binaries that reference glibc 2.31 (dynamic
  # linker path, library search path, RPATH).
  binutils231 = pkgs.wrapBintoolsWith {
    bintools = pkgs.binutils-unwrapped;
    libc = glibc231;
  };

  # Rebuild gcc 15 (specifically libstdc++ / libgcc_s) against glibc 2.31.
  # The override swaps gcc15.cc's bootstrap stdenv for one that uses the
  # existing gcc 15 binary but links against glibc 2.31, so the resulting
  # compiler ships runtime libraries that only reference symbols available
  # in glibc 2.31.
  gcc15CcWithGlibc231 = pkgs.gcc15.cc.override {
    stdenv = pkgs.stdenvAdapters.overrideCC pkgs.stdenv (
      pkgs.wrapCCWith {
        cc = pkgs.gcc15.cc;
        libc = glibc231;
        bintools = binutils231;
      }
    );
  };

  # cc-wrapper around the rebuilt compiler, pointing at glibc 2.31 headers
  # and libraries. This is what we actually expose to users.
  gcc15WithGlibc231 = pkgs.wrapCCWith {
    cc = gcc15CcWithGlibc231;
    libc = glibc231;
    bintools = binutils231;
  };

  # cc-wrapper around clang 21, pointing at glibc 2.31 headers and libraries.
  # Reuses the rebuilt gcc 15 for libstdc++ / libgcc_s so that C++ binaries
  # produced by clang also only reference symbols available in glibc 2.31.
  # compiler-rt is wired into a resource-root so sanitizer runtimes
  # (libclang_rt.*.a) are found at link time; this mirrors what nixpkgs
  # does internally when building llvmPackages_21.clang.
  clang21WithGlibc231 = pkgs.wrapCCWith {
    cc = pkgs.llvmPackages_21.clang-unwrapped;
    libc = glibc231;
    bintools = binutils231;
    gccForLibs = gcc15CcWithGlibc231;
    extraPackages = [ pkgs.llvmPackages_21.compiler-rt ];
    extraBuildCommands = ''
      rsrc="$out/resource-root"
      mkdir "$rsrc"
      ln -s "${pkgs.llvmPackages_21.clang-unwrapped.lib}/lib/clang/21/include" "$rsrc/include"
      ln -s "${pkgs.llvmPackages_21.compiler-rt.out}/lib" "$rsrc/lib"
      ln -s "${pkgs.llvmPackages_21.compiler-rt.out}/share" "$rsrc/share" || true
      echo "-resource-dir=$rsrc" >> $out/nix-support/cc-cflags
    '';
  };

  # Strip the generic cc/c++/cpp symlinks from the clang wrapper so it can
  # coexist with the gcc wrapper in buildEnv. gcc remains the default
  # compiler (cc/c++/cpp); clang is invoked explicitly as clang/clang++.
  clang21ForCiEnv = pkgs.symlinkJoin {
    name = "clang-wrapper-21-for-ci-env";
    paths = [ clang21WithGlibc231 ];
    postBuild = ''
      rm -f $out/bin/cc $out/bin/c++ $out/bin/cpp
    '';
  };

in
{
  default = pkgs.buildEnv {
    name = "xrpld-ci-env";
    paths = commonPackages ++ [
      gcc15WithGlibc231
      clang21ForCiEnv
      binutils231
    ];
    pathsToLink = [
      "/bin"
      "/lib"
      "/include"
      "/share"
    ];
  };
}
