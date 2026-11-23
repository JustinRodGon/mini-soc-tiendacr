#cloud-config
# Plantilla común: crear-vms.sh reemplaza __HOST__ y __KEY__
hostname: __HOST__
users:
  - name: soc
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true            # sin contraseña: solo llave
    ssh_authorized_keys: ["__KEY__"]
disable_root: true
ssh_pwauth: false
write_files:
  - path: /etc/ssh/sshd_config.d/10-endurecido.conf
    content: |
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      PubkeyAuthentication yes
      MaxAuthTries 3
runcmd:
  - systemctl restart ssh || systemctl restart sshd
