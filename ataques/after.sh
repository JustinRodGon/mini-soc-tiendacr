#!/usr/bin/env bash
# Remediación: repetir ataques 2 y 3 con el nivel IMPOSSIBLE (código corregido).
# Prueba SIEMPRE desde cero (--flush-session) para no reusar resultados cacheados.
set -euo pipefail
OBJETIVO=10.10.10.20; BASE="http://$OBJETIVO"; C=$(mktemp)
tok(){ curl -s -c "$C" -b "$C" "$1" | grep -oP "name='user_token' value='\K[0-9a-f]+"; }
curl -s -c "$C" -b "$C" --data "username=admin&password=password&Login=Login&user_token=$(tok $BASE/login.php)" "$BASE/login.php" >/dev/null
curl -s -c "$C" -b "$C" --data "security=impossible&seclev_submit=Submit&user_token=$(tok $BASE/security.php)" "$BASE/security.php" >/dev/null
echo "[*] Nivel de seguridad fijado: $(grep -o 'security.*' "$C" | awk '{print $2}' | tail -1)"

echo "--- Ataque 2 (fuerza bruta) contra impossible ---"
for p in 123456 password admin root toor; do
  r=$(curl -s -b "$C" "$BASE/vulnerabilities/brute/?username=admin&password=$p&Login=Login")
  if echo "$r" | grep -q 'Welcome to the password protected area'; then
    echo "  admin/$p -> ENTRÓ (!)"
  else
    echo "  admin/$p -> rechazado"
  fi
done

echo "--- Ataque 3 (inyección SQL) contra impossible ---"
PH=$(grep PHPSESSID "$C" | awk '{print $NF}')
OUT=$(sqlmap -u "$BASE/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=$PH; security=impossible" --batch --flush-session 2>&1 || true)
echo "$OUT" | grep -iE 'does not appear to be dynamic|might not be|not injectable|all tested parameters|does not seem' | head -8
echo
if echo "$OUT" | grep -qiE 'not injectable|do not appear to be injectable|might not be|does not appear to be dynamic'; then
  echo "[OK] RESULTADO: la inyección SQL YA NO FUNCIONA en nivel impossible (vulnerabilidad remediada)."
else
  echo "[!] Revisar: sqlmap no confirmó la protección."
fi
rm -f "$C"
