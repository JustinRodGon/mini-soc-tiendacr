#!/usr/bin/env bash
# Copia la carpeta de cada VM y ejecuta su setup.sh. Uso: infra/provisionar.sh siem|objetivo
set -euo pipefail
cd "$(dirname "$0")/.."
declare -A IP=([kali]=10.10.10.10 [objetivo]=10.10.10.20 [siem]=10.10.10.30)
vm=$1; ip=${IP[$vm]}
SSH="ssh -i $HOME/.ssh/minisoc_ed25519 -o StrictHostKeyChecking=accept-new soc@$ip"
tar -C "$vm" -cz . | $SSH "rm -rf ~/$vm && mkdir ~/$vm && tar -C ~/$vm -xz"
$SSH "sudo bash ~/$vm/setup.sh"
