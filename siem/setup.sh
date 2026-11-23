#!/usr/bin/env bash
# Instala Wazuh todo en uno (indexer + manager + dashboard) en la VM "siem".
set -euo pipefail
cd "$(dirname "$0")"
export DEBIAN_FRONTEND=noninteractive
if [ ! -d /var/ossec ]; then
  # El instalador deja wazuh-install-files.tar (contraseñas y certificados) en /root, fuera del repo
  (cd /root && curl -fsSLO https://packages.wazuh.com/4.14/wazuh-install.sh
  # -i ignora el chequeo de hardware (el laboratorio tiene 5 GB de RAM, Wazuh recomienda 8)
  bash wazuh-install.sh -a -i | tee /root/wazuh-install.log)
fi
cp local_rules.xml /var/ossec/etc/rules/local_rules.xml
chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml
grep -q TIENDACR /var/ossec/etc/ossec.conf || cat ossec-manager.xml >> /var/ossec/etc/ossec.conf
/var/ossec/bin/wazuh-analysisd -t
systemctl restart wazuh-manager

apt-get install -yq ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow in proto tcp from 10.10.10.1  to any port 22   comment 'S1 SSH admin desde la laptop'
ufw allow in proto tcp from 10.10.10.1  to any port 443  comment 'S2 Panel Wazuh desde la laptop'
ufw allow in proto tcp from 10.10.10.20 to any port 1514 comment 'S3 Eventos del agente objetivo'
ufw allow in proto tcp from 10.10.10.20 to any port 1515 comment 'S4 Registro del agente objetivo'
ufw --force enable
ufw status numbered
echo "Contraseña del panel (usuario admin): sudo tar -xOf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt"
