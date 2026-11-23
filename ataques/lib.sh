# Funciones comunes. OBJETIVO por defecto es el servidor de TiendaCR.
OBJETIVO="${OBJETIVO:-10.10.10.20}"
BASE="http://$OBJETIVO"
COOKIE="$(mktemp)"
trap 'rm -f "$COOKIE"' EXIT

# token CSRF de una página de DVWA (campo user_token)
token() { curl -s -c "$COOKIE" -b "$COOKIE" "$1" | grep -oP "name='user_token' value='\K[0-9a-f]+"; }

# Inicia sesión en DVWA (admin/password) y pone el nivel de seguridad en "low"
dvwa_login() {
  curl -s -c "$COOKIE" -b "$COOKIE" --data "username=admin&password=password&Login=Login&user_token=$(token $BASE/login.php)" "$BASE/login.php" >/dev/null
  curl -s -c "$COOKIE" -b "$COOKIE" --data "security=low&seclev_submit=Submit&user_token=$(token $BASE/security.php)" "$BASE/security.php" >/dev/null
  echo "[*] Sesión DVWA abierta, nivel de seguridad: low"
}
