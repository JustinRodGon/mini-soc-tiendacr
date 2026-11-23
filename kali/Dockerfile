# Kali Linux oficial (kali-rolling) con las herramientas del laboratorio.
FROM docker.io/kalilinux/kali-rolling
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      nmap hydra sqlmap curl jq wordlists openssh-client iputils-ping ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /ataques
