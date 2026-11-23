#!/usr/bin/env bash
# Cortafuegos del servidor objetivo: denegación por defecto en ambos sentidos
# y solo lo estrictamente necesario. Las reglas están justificadas en docs/reglas-acceso.md.
set -euo pipefail
ADMIN=10.10.10.1    # laptop del equipo (host KVM)
KALI=10.10.10.10    # máquina atacante del equipo
SIEM=10.10.10.30

ufw --force reset
ufw default deny incoming
ufw default deny outgoing
ufw default deny routed
# Entrada
ufw allow in proto tcp from $ADMIN to any port 22 comment 'R1 SSH admin desde la laptop'
ufw allow in proto tcp from $KALI  to any port 22 comment 'R2 SSH desde Kali (prueba de fuerza bruta)'
ufw allow in proto tcp from $ADMIN to any port 80 comment 'R3 Web TiendaCR desde la laptop'
ufw allow in proto tcp from $KALI  to any port 80 comment 'R4 Web TiendaCR desde Kali (ataques)'
# Salida
ufw allow out proto tcp to $SIEM port 1514,1515 comment 'R5 Agente Wazuh hacia el SIEM'
ufw allow out to $ADMIN port 53 comment 'R6 DNS del laboratorio'
ufw allow out proto tcp to any port 80,443 comment 'R7 Actualizaciones apt y Docker'
ufw allow out proto udp to any port 123 comment 'R8 Hora NTP (marcas de tiempo de las alertas)'
ufw allow out to 172.16.0.0/12 comment 'R9 DVWA hacia su base de datos en Docker'
ufw --force enable
ufw status numbered
