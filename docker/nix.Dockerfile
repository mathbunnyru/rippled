ARG BASE_IMAGE=ubuntu:20.04

# Nix builder
FROM nixos/nix:latest AS builder

# Copy our source and setup our working dir.
COPY nix/ /tmp/build/nix/
COPY flake.nix /tmp/build/
COPY flake.lock /tmp/build/
WORKDIR /tmp/build

# Build our Nix CI environment (all build tools in a single store path)
RUN nix \
    --extra-experimental-features "nix-command flakes" \
    --option filter-syscalls false \
    build

# Copy the Nix store closure into a directory. The Nix store closure is the
# entire set of Nix store values that we need for our build.
RUN mkdir /tmp/nix-store-closure && \
    cp -R $(nix-store -qR result/) /tmp/nix-store-closure

# Final image
FROM ${BASE_IMAGE}

# Use Bash as the default shell for RUN commands, using the options
# `set -o errexit -o pipefail`, and as the entrypoint.
SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]
ENTRYPOINT ["/bin/bash"]

# Copy /nix/store and the env symlink tree
COPY --from=builder /tmp/nix-store-closure /nix/store
COPY --from=builder /tmp/build/result /nix/ci-env

ENV PATH="/nix/ci-env/bin:$PATH"

RUN <<EOF
ccache --version
cmake --version
conan --version
gcovr --version
git --version
make --version
clang-format --version
mold --version
ninja --version
perl --version
pkg-config --version
pre-commit --version
python3 --version
run-clang-tidy --help
EOF
