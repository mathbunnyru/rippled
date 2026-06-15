# Troubleshooting Nix problems

Common issues encountered when using the [Nix development shell](./nix.md), and
how to resolve them.

## Git worktrees

If `nix develop` fails with an error like:

```
error:
       … while fetching the input 'git+file:///path/to/rippled'

       error: opening Git repository "/path/to/rippled": unsupported extension name extensions.relativeworktrees (libgit2 error code = 6)
```

then your Nix is linked against a libgit2 older than **1.9.4**. Git 2.48+ writes
the `extensions.relativeWorktrees` config entry when a worktree is created with
relative paths (`git worktree add --relative-paths`, or with
`worktree.useRelativePaths=true`), and older libgit2 versions refuse to open a
repository that uses it. Nix uses libgit2 to read the flake, so evaluation
fails.

> [!IMPORTANT]
> This entry is written to the **shared** repository config, so once any
> relative worktree exists, `nix develop` fails in the main checkout too — not
> just inside the worktree.

The fix is in [libgit2 1.9.4](https://github.com/libgit2/libgit2/releases/tag/v1.9.4).
Check which version your Nix links against:

```bash
nix-store -qR "$(readlink -f "$(command -v nix)")" | grep libgit2
```

If it reports a version below `1.9.4`, upgrade Nix (nixpkgs already ships the
fixed libgit2):

```bash
sudo -i nix upgrade-nix
```

Until Nix is upgraded, you can work around it by either:

- bypassing libgit2 with a `path:` flakeref: `nix develop "path:$PWD"`
  (note: this copies the working tree to the store and ignores `.gitignore`); or
- creating worktrees with absolute paths (omit `--relative-paths`); or
- clearing the extension if you don't need relative worktrees:
  `git config --unset extensions.relativeWorktrees`.
