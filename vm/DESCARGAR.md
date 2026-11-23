# Imágenes base

Las imágenes de disco no se versionan (pesan cientos de MB). Descargue la base de Ubuntu aquí:

```bash
cd vm
curl -LO https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
# verificar:
curl -sL https://cloud-images.ubuntu.com/noble/current/SHA256SUMS | \
  grep 'noble-server-cloudimg-amd64.img$' | sha256sum -c
```

`crear-vms.sh` convierte esta imagen a `noble.qcow2` y la usa como base de las 3 VM
(objetivo, siem y kali). La máquina atacante corre Kali en contenedor sobre esa base Ubuntu
(ver `kali/`), porque la imagen cloud de Kali reinicia en bucle en este KVM.
