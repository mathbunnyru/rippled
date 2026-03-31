ARG BASE_IMAGE=ubuntu:20.04
FROM ${BASE_IMAGE}

# Use Bash as the default shell for RUN commands, using the options
# `set -o errexit -o pipefail`, and as the entrypoint.
SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]
ENTRYPOINT ["/bin/bash"]

# Ensure any packages installed directly or indirectly via dpkg do not require manual interaction.
ARG DEBIAN_FRONTEND=noninteractive

RUN <<EOF
pkgs=()
pkgs+=(ca-certificates) # Enable TLS verification for HTTPS connections by providing trusted root certificates.
pkgs+=(curl)            # Required to install nix
pkgs+=(xz-utils)        # Required to install nix
apt-get update
apt-get install -y --no-install-recommends "${pkgs[@]}"
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

# Install nix
RUN sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon --yes

# Add nix to PATH and set NIX environment variables so nix is available in all
# shells including non-interactive shells (e.g., GitHub Actions).
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
ENV NIX_PROFILES="/nix/var/nix/profiles/default"
ENV NIX_SSL_CERT_FILE="/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"

RUN <<EOF
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
EOF

COPY nix/ /tmp/nix/
COPY flake.nix /tmp/
COPY flake.lock /tmp/

WORKDIR /tmp

RUN nix develop
