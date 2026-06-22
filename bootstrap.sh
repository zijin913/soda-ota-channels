#!/usr/bin/env bash
# SODA — One-line bootstrap.
#
# Customer usage:
#   curl -fsSL https://zijin913.github.io/soda-ota-channels/bootstrap.sh | bash
#
# What this does:
#   1. Installs Docker if missing.
#   2. Adds the current user to the `docker` group if missing.
#   3. Re-executes itself under `sg docker` so the new group membership
#      takes effect WITHOUT requiring you to log out and back in.
#      (Logging out of a desktop session does NOT refresh group membership
#      in already-running terminals — this is a well-known and very confusing
#      issue on Ubuntu desktops. `sg docker -c` sidesteps it entirely.)
#   4. Resolves the current stable image version from the OTA channel.
#   5. Pulls that image (multi-arch — auto-selects amd64 / arm64).
#   6. Extracts install.sh from the image into /tmp.
#   7. Hands off to install.sh, which handles the rest interactively
#      (license, network, site config, OTA timer).
#
# Channel + image registry are configurable for vendor-internal use:
#   SODA_CHANNEL=dev      bash bootstrap.sh    # subscribe to dev instead of stable
#   SODA_CHANNEL_BASE=... bash bootstrap.sh    # mirror the channel locally
#   SODA_IMAGE=...        bash bootstrap.sh    # pin a specific image (bypasses channel)

set -euo pipefail

C_GRN=$'\033[32m'; C_RED=$'\033[31m'; C_YLW=$'\033[33m'; C_BLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
ok()   { printf '  %s✓%s %s\n'  "$C_GRN" "$C_RST" "$1"; }
todo() { printf '  %s→%s %s\n'  "$C_YLW" "$C_RST" "$1"; }
fail() { printf '  %s✗%s %s\n'  "$C_RED" "$C_RST" "$1" >&2; exit 1; }
section() { printf '\n%s═════%s %s%s%s %s═════%s\n' "$C_DIM" "$C_RST" "$C_BLD" "$1" "$C_RST" "$C_DIM" "$C_RST"; }

CHANNEL="${SODA_CHANNEL:-stable}"
CHANNEL_BASE="${SODA_CHANNEL_BASE:-https://zijin913.github.io/soda-ota-channels}"
REGISTRY_DEFAULT="ghcr.io/zijin913"
RUN_USER="${SUDO_USER:-$USER}"

section "SODA Bootstrap"
printf '  Channel: %s%s%s\n' "$C_BLD" "$CHANNEL" "$C_RST"

# ──────────────────────────────────────────────────────────────────────
# Phase 1 — Docker installed + reachable
# ──────────────────────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  todo "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh || fail "Docker install failed"
  ok "Docker installed"
fi

if ! docker ps >/dev/null 2>&1; then
  if ! id -nG "$RUN_USER" 2>/dev/null | grep -qw docker; then
    todo "Adding $RUN_USER to docker group (sudo)..."
    sudo usermod -aG docker "$RUN_USER" \
      || fail "Could not add $RUN_USER to docker group"
    ok "Added to docker group"
  fi

  # Re-exec under sg docker. This is the magic: even though the current shell
  # was started before docker group was added (so it doesn't see docker in its
  # groups), sg spawns a fresh process WITH the docker group active, with no
  # logout required. The customer never sees the chicken-and-egg confusion.
  todo "Activating docker group membership and continuing..."
  exec sg docker -c "bash '$0' $*" \
    || fail "Could not activate docker group. Log out + back in (or reboot), then re-run this command."
fi

ok "Docker reachable: $(docker --version | awk '{print $3}' | tr -d ,)"

# ──────────────────────────────────────────────────────────────────────
# Phase 2 — Resolve image from channel
# ──────────────────────────────────────────────────────────────────────
if [[ -n "${SODA_IMAGE:-}" ]]; then
  IMAGE="$SODA_IMAGE"
  ok "Image override: $IMAGE"
else
  todo "Resolving version from channel $CHANNEL..."
  VERSION="$(curl -fsSL -4 --max-time 10 "$CHANNEL_BASE/$CHANNEL.txt" | tr -d '[:space:]')"
  [[ -n "$VERSION" ]] || fail "Could not reach $CHANNEL_BASE/$CHANNEL.txt — check network"
  IMAGE="$REGISTRY_DEFAULT/robot-app:$VERSION"
  ok "Channel says: $VERSION  →  $IMAGE"
fi

# ──────────────────────────────────────────────────────────────────────
# Phase 3 — Pull image + extract install.sh
# ──────────────────────────────────────────────────────────────────────
todo "Pulling $IMAGE (multi-arch; auto-selects $(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'))..."
docker pull "$IMAGE" || fail "docker pull failed"
ok "Image pulled"

todo "Extracting install.sh from image..."
TMP=$(docker create "$IMAGE")
docker cp "$TMP:/opt/app/compose-overlay/install.sh" /tmp/install.sh
docker rm "$TMP" >/dev/null
ok "install.sh ready at /tmp/install.sh"

# ──────────────────────────────────────────────────────────────────────
# Phase 4 — Hand off to install.sh
# ──────────────────────────────────────────────────────────────────────
section "Handing off to install.sh"
exec bash /tmp/install.sh
