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
