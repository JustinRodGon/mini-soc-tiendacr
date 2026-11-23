#!/usr/bin/env bash
# Ataque 1 - Reconocimiento (MITRE T1046/T1595). Debe disparar alertas de red en Suricata.
set -euo pipefail; source "$(dirname "$0")/lib.sh"
echo "[*] $(date '+%T') Escaneo de puertos SYN + servicios contra $OBJETIVO"
nmap -sS -sV -T4 -p- "$OBJETIVO"            # -sS = SYN (regla propia 1000001), -sV = servicios
echo "[*] $(date '+%T') Escaneo con scripts por defecto (dispara 'Nmap Scripting Engine')"
nmap -sC -p 22,80 "$OBJETIVO"
echo "[*] $(date '+%T') Fin del reconocimiento"
