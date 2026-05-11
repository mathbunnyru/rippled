# glibc 2.31 — matches Ubuntu 20.04 LTS
#
# Built by overriding the current nixpkgs glibc derivation so that no extra nixpkgs input is needed in flake.lock.
# All patches are fetched directly from last commit that shipped glibc 2.31 as the primary version (2020-06-30).
# The ordering matches upstream exactly.
{ pkgs }:

let
  nixpkgsRev = "9cd98386a38891d1074fc18036b842dc4416f562";
  nixpkgsPatch =
    name: sha256:
    pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/NixOS/nixpkgs/${nixpkgsRev}/pkgs/development/libraries/glibc/${name}";
      inherit sha256;
    };
in

pkgs.glibc.overrideAttrs (_old: {
  version = "2.31";

  src = pkgs.fetchurl {
    url = "mirror://gnu/glibc/glibc-2.31.tar.xz";
    sha256 = "05zxkyz9bv3j9h0xyid1rhvh3klhsmrpkf3bcs6frvlgyr2gwilj";
  };

  # All patches applied by nixpkgs at the last glibc 2.31 commit, fetched
  # directly from that commit with pinned hashes.
  patches = [
    (nixpkgsPatch "rpcgen-path.patch" "10gfkgi7cjq76r6llwh4czswa6f70y81yj2554zaxc4qc2wmhzsg")
    (nixpkgsPatch "nix-locale-archive.patch" "1xn9pvd29h0x5nkkzkswr2cg2yfg40kvainmcklx3g1jvzi0fmvp")
    (nixpkgsPatch "dont-use-system-ld-so-cache.patch" "1d59171gszhgij6dbnavd6zf3fw4vz9kvi7klkkrdrf4i0v1s4cd")
    (nixpkgsPatch "dont-use-system-ld-so-preload.patch" "19jadm0zsl1hppvbfkp4ymcr25b8jwi0ldaxkx2qg7rpac7px2fy")
    (nixpkgsPatch "fix_path_attribute_in_getconf.patch" "0iw0ns5cvq160lxdw074q7yhbbsshiyh95rxjsyh3iw6ny2n45yp")
    (nixpkgsPatch "allow-kernel-2.6.32.patch" "1amzbvywixyg9j5cp4yzgk71b69a6b5fadwdjyrmbhnaw0ql253h")
    (pkgs.fetchurl {
      url = "https://git.savannah.gnu.org/cgit/guix.git/plain/gnu/packages/patches/glibc-reinstate-prlimit64-fallback.patch?id=eab07e78b691ae7866267fc04d31c7c3ad6b0eeb";
      sha256 = "091bk3kyrx1gc380gryrxjzgcmh1ajcj8s2rjhp2d2yzd5mpd5ps";
    })
    (pkgs.fetchurl {
      url = "https://salsa.debian.org/glibc-team/glibc/raw/49767c9f7de4828220b691b29de0baf60d8a54ec/debian/patches/localedata/locale-C.diff";
      sha256 = "0irj60hs2i91ilwg5w7sqrxb695c93xg0ik7yhhq9irprd7fidn4";
    })
    (nixpkgsPatch "fix-x64-abi.patch" "19w5wwfc180yvg3sv5zy26r1469w9q2cjpbxqgiz9ngqrxsm83sq")
    (nixpkgsPatch "2.30-cve-2020-1752.patch" "1viw8xlzdwiqdzdc4rn029w9kdn8dszvhkpjlyv25mrsj5iib4sw")
    (nixpkgsPatch "2.31-cve-2020-10029.patch" "113mmblc14hhsiphhk7g0zsk8zrln2jyzpdr0pp86fwi3lxk7dwx")
  ];

  # The inherited postPatch from the parent glibc derivation may run sed over
  # files introduced in glibc >= 2.33.  Stub them out so the sed doesn't fail.
  postPatch = ''
    touch nss/nss_files_fopen.c
    touch include/nss_files.h
  ''
  + _old.postPatch;

  # --enable-fortify-source was introduced in glibc >= 2.34; drop it here.
  # All other inherited flags are supported by glibc 2.31.
  configureFlags = builtins.filter (f: f != "--enable-fortify-source") _old.configureFlags;

  # Newer GCC introduced some new errors when building old glibc 2.31
  #
  # NIX_CFLAGS_COMPILE lives in the parent's `env` set, so we must merge
  # there rather than at the top level to avoid a "overlapping attributes" error.
  env = (_old.env or { }) // {
    NIX_CFLAGS_COMPILE =
      ((_old.env or { }).NIX_CFLAGS_COMPILE or "")
      + " -Wno-error=array-parameter -Wno-error=stringop-overflow -Wno-error=use-after-free -Wno-error=builtin-declaration-mismatch -Wno-error=stringop-overread";
  };
})
