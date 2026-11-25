#!/usr/bin/env bash
# Deja el laboratorio "en cero" antes de la demostración: sin alertas previas en Wazuh,
# sin webshells en el objetivo y sin la IP atacante bloqueada. Se corre desde el host:
#   ./infra/reset-demo.sh
# Conserva la configuración, las reglas y el inventario de vulnerabilidades (wazuh-states-*),
# que no son resultado de los ataques.
set -euo pipefail
LLAVE="${LLAVE:-$HOME/.ssh/minisoc_ed25519}"
ssh_vm() { ssh -i "$LLAVE" -o ConnectTimeout=5 "soc@10.10.10.$1" "sudo bash -s"; }

echo "[1/3] Objetivo: borra webshells y desbloquea a la atacante"
ssh_vm 20 <<'EOF'
find /srv/dvwa/uploads -type f \( -name '*.php' -o -name '*.phtml' -o -name '*.phar' \) -print -delete
for cadena in INPUT FORWARD; do
  while iptables -D "$cadena" -s 10.10.10.10 -j DROP 2>/dev/null; do :; done
done
EOF
sleep 10   # deja pasar el evento de FIM del borrado antes de limpiar el SIEM

echo "[2/3] SIEM: vacía alertas y archivos de eventos del manager"
ssh_vm 30 <<'EOF'
systemctl stop wazuh-manager
truncate -s 0 /var/ossec/logs/alerts/alerts.{json,log} /var/ossec/logs/archives/archives.log
rm -rf /var/ossec/logs/alerts/20* /var/ossec/logs/archives/20*
# La contraseña del indexer se lee en la VM y nunca sale de ella.
P=$(grep -A1 "User: admin" /root/wazuh-install.log | grep -oP "Password: \K\S+" | head -1)
curl -sfk -u "admin:$P" -X DELETE "https://127.0.0.1:9200/wazuh-alerts-*,wazuh-archives-*" >/dev/null
systemctl start wazuh-manager   # reinicia también los contadores de correlación (100101)
EOF

echo "[3/3] Comprobación"
ssh_vm 30 <<'EOF'
P=$(grep -A1 "User: admin" /root/wazuh-install.log | grep -oP "Password: \K\S+" | head -1)
echo "  alertas en el indexer: $(curl -sk -u "admin:$P" "https://127.0.0.1:9200/wazuh-alerts-*/_count" | grep -oP '"count":\K[0-9]+' || echo 0)"
echo "  wazuh-manager: $(systemctl is-active wazuh-manager)"
EOF
echo "Listo. Espere ~1 min a que el agente del objetivo reconecte antes de atacar."
