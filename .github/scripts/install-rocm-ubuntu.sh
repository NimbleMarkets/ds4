#!/usr/bin/env bash
set -euo pipefail

ROCM_VERSION="${ROCM_VERSION:-7.2.4}"
UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"

# Slim ROCm set DS4 needs; the full `rocm` metapackage overflows the runner disk.
ROCM_PACKAGES="${ROCM_PACKAGES:-rocm-hip-runtime-dev hipblas-dev hipblaslt-dev hipcub-dev rocwmma-dev}"

arch="$(dpkg --print-architecture)"
if [ "$arch" != "amd64" ]; then
  echo "ROCm CI install supports amd64 only; got $arch"
  exit 1
fi

if [ -z "$UBUNTU_CODENAME" ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
fi

if [ -z "$UBUNTU_CODENAME" ]; then
  echo "Unable to determine Ubuntu codename"
  exit 1
fi

# Reclaim space on the root volume before the ROCm install. GitHub-hosted
# runners ship ~25-30 GB of preinstalled toolchains we never use; removing them
# keeps the slim ROCm set comfortably within disk even as it grows.
echo "Disk usage before cleanup:"
df -h /
sudo rm -rf \
  /usr/share/dotnet \
  /usr/local/lib/android \
  /opt/ghc \
  /usr/local/.ghcup \
  /opt/hostedtoolcache/CodeQL || true
echo "Disk usage after cleanup:"
df -h /

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  wget \
  ca-certificates \
  gnupg

sudo mkdir -p -m 0755 /etc/apt/keyrings
wget -qO- https://repo.radeon.com/rocm/rocm.gpg.key | \
  gpg --dearmor | \
  sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

{
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${UBUNTU_CODENAME} main"
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/${ROCM_VERSION}/ubuntu ${UBUNTU_CODENAME} main"
} | sudo tee /etc/apt/sources.list.d/rocm.list > /dev/null

{
  echo "Package: *"
  echo "Pin: release o=repo.radeon.com"
  echo "Pin-Priority: 600"
} | sudo tee /etc/apt/preferences.d/rocm-pin-600 > /dev/null

sudo apt-get update
# shellcheck disable=SC2086
sudo apt-get install -y --no-install-recommends $ROCM_PACKAGES

echo "Disk usage after ROCm install:"
df -h /
