#!/usr/bin/env bash
# Prepara el servidor objetivo: Docker + DVWA, Suricata, agente Wazuh y UFW.
# Se ejecuta en la VM "objetivo" como root (lo copia y corre infra/provisionar.sh).
set -euo pipefail
cd "$(dirname "$0")"
WAZUH_VER=4.14.10-1
SIEM=10.10.10.30
IFACE=$(ip -o -4 route show to default | awk '{print $5}')
export DEBIAN_FRONTEND=noninteractive

# 1. Paquetes
curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor --yes -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
apt-get update -q
apt-get install -yq docker.io docker-compose-v2 suricata jq ufw
WAZUH_MANAGER=$SIEM WAZUH_AGENT_NAME=objetivo apt-get install -yq wazuh-agent=$WAZUH_VER
apt-mark hold wazuh-agent

# 2. DVWA
install -d /var/log/dvwa /opt/tiendacr
install -d -o 33 -g 33 /srv/dvwa/uploads
cp docker-compose.yml /opt/tiendacr/
[ -f /opt/tiendacr/.env ] || printf 'DB_PASSWORD=%s\nDVWA_NIVEL=low\n' "$(openssl rand -hex 16)" > /opt/tiendacr/.env
chmod 600 /opt/tiendacr/.env
docker compose -f /opt/tiendacr/docker-compose.yml --env-file /opt/tiendacr/.env up -d

# 3. Suricata: IDS en la interfaz del servidor, HOME_NET = solo este servidor
sed -i "s|^\(\s*HOME_NET:\).*|\1 \"[10.10.10.20/32]\"|; s|^\(\s*EXTERNAL_NET:\).*|\1 \"any\"|" /etc/suricata/suricata.yaml
sed -i "0,/- interface: .*/s//- interface: $IFACE/" /etc/suricata/suricata.yaml
cp suricata/tiendacr.rules /etc/suricata/rules/tiendacr.rules
grep -q tiendacr.rules /etc/suricata/suricata.yaml || \
  sed -i "/^rule-files:/a\  - /etc/suricata/rules/tiendacr.rules" /etc/suricata/suricata.yaml
sed -i "s|^#\?\s*default-rule-path:.*|default-rule-path: /var/lib/suricata/rules|" /etc/suricata/suricata.yaml
suricata-update -q || true          # reglas ET Open
suricata -T -c /etc/suricata/suricata.yaml >/dev/null
systemctl enable --now suricata && systemctl restart suricata

# 4. Agente Wazuh: registros web, eve.json de Suricata e integridad de archivos
cp ossec-agente.xml /tmp/ossec-agente.xml
grep -q TIENDACR /var/ossec/etc/ossec.conf || cat /tmp/ossec-agente.xml >> /var/ossec/etc/ossec.conf
systemctl enable --now wazuh-agent && systemctl restart wazuh-agent

# 5. Cortafuegos al final (si falla algo antes, no nos deja fuera)
bash ufw.sh
