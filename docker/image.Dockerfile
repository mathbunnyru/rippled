# Final image
FROM ubuntu:20.04

# Use Bash as the default shell for RUN commands, using the options
# `set -o errexit -o pipefail`, and as the entrypoint.
SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]
ENTRYPOINT ["/bin/bash"]

# Copy /nix/store and the env symlink tree
COPY --from=builder /tmp/nix-store-closure /nix/store
COPY --from=builder /tmp/build/result /nix/ci-env

ENV PATH="/nix/ci-env/bin:$PATH"
