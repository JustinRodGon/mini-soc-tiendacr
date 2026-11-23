#!/usr/bin/env bash
# Máquina atacante: Ubuntu 24.04 (los kernels de Debian/Kali se reinician en este KVM)
# con Kali oficial en contenedor. Se usa con el comando `kali` (red del host = 10.10.10.10).
set -euo pipefail
cd "$(dirname "$0")"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -yq docker.io ufw
docker build -t kali-tiendacr .
cat > /usr/local/bin/kali <<'EOS'
#!/bin/sh
exec docker run --rm -it --network host -v "$HOME/ataques:/ataques" kali-tiendacr "${@:-bash}"
EOS
chmod +x /usr/local/bin/kali
usermod -aG docker soc
install -d -o soc -g soc /home/soc/ataques
ufw --force reset; ufw default deny incoming; ufw default allow outgoing
ufw allow in proto tcp from 10.10.10.1 to any port 22 comment 'K1 SSH admin desde la laptop'
ufw --force enable
