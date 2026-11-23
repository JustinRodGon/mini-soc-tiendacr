#!/usr/bin/env bash
# Crea la red soc-net y las 3 VM (kali, objetivo, siem) en KVM/libvirt.
# Uso: infra/crear-vms.sh   (requiere libvirtd activo y el usuario en el grupo libvirt)
set -euo pipefail
cd "$(dirname "$0")/.."
export LIBVIRT_DEFAULT_URI=qemu:///system
KEY=$(cat "${SSH_PUB:-$HOME/.ssh/minisoc_ed25519.pub}")
VM=$PWD/vm

virsh net-info soc-net >/dev/null 2>&1 || { virsh net-define infra/red-soc.xml; virsh net-autostart soc-net; }
virsh net-start soc-net 2>/dev/null || true

# nombre  ram(MB) vcpu disco  mac-final  imagen-base  os-variant
crear() {
  local n=$1 ram=$2 cpu=$3 disk=$4 mac=$5 base=$6 os=$7
  virsh dominfo "$n" >/dev/null 2>&1 && { echo "$n ya existe"; return; }
  qemu-img create -q -f qcow2 -F qcow2 -b "$VM/$base" "$VM/$n.qcow2" "$disk"
  sed "s|__HOST__|$n|; s|__KEY__|$KEY|" infra/cloud-init/user-data.tpl > "$VM/$n-user-data"
  virt-install -q --name "$n" --memory "$ram" --vcpus "$cpu" --os-variant "$os" \
    --disk "$VM/$n.qcow2" --import --network network=soc-net,mac=52:54:00:50:c0:$mac \
    --cloud-init user-data="$VM/$n-user-data" --graphics none --noautoconsole
  echo "$n creada"
}
[ -f "$VM/noble.qcow2" ] || qemu-img convert -O qcow2 "$VM/noble-server-cloudimg-amd64.img" "$VM/noble.qcow2"
# Kali: base Ubuntu + contenedor kalilinux/kali-rolling (ver kali/setup.sh)

crear siem     5120 4 40G 30 noble.qcow2      ubuntu24.04
crear objetivo 2048 2 20G 20 noble.qcow2      ubuntu24.04
crear kali     2048 2 25G 10 noble.qcow2      ubuntu24.04
