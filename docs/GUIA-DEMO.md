# Guía de la demostración — Mini SOC TiendaCR

Atacar desde **Kali** y ver la detección en **Wazuh**. Solo comandos y filtros.

## Máquinas

| Máquina | IP |
|---|---|
| Laptop (host) | 10.10.10.1 |
| Kali (atacante) | 10.10.10.10 |
| Objetivo (DVWA + Suricata + agente) | 10.10.10.20 |
| SIEM (panel Wazuh) | 10.10.10.30 |

---

## 1. Preparar

Dejar el SOC en cero (sin alertas viejas, sin webshell, sin bloqueos) y esperar 1 min:

```bash
./infra/reset-demo.sh
```

### Entrar a Kali (desde la laptop)

```bash
TERM=xterm-256color ssh -i ~/.ssh/minisoc_ed25519 soc@10.10.10.10
kali            # abre la shell de Kali (nmap/hydra/sqlmap)
cd /ataques
```

### Panel de Wazuh

1. Abrir `https://10.10.10.30` (aceptar el certificado). Usuario: **`admin`**.
2. Contraseña (desde la laptop):
   ```bash
   ssh -i ~/.ssh/minisoc_ed25519 soc@10.10.10.30 "sudo grep -A2 'User: admin' /root/wazuh-install.log"
   ```
3. Menú ☰ → **Threat Hunting** → pestaña **Events**.
4. Tiempo (arriba a la derecha) → **Last 24 hours**.
5. Pegar el filtro de cada ataque en la barra de búsqueda y pulsar **Refresh**.

---

## 2. Ataques

Correr el comando en Kali, pegar el filtro en Wazuh y pulsar Refresh.

### 1 — Reconocimiento
```bash
./01-recon.sh
```
Filtro: `rule.description:*SYN*`

### 2 — Fuerza bruta + bloqueo automático
```bash
./02-fuerza-bruta.sh
```
Filtro fuerza bruta: `rule.id:100101`
Filtro bloqueo/desbloqueo: `rule.id:651 or rule.id:652`

Probar el bloqueo (unos 15 s después, o cuando salga la regla 651), en Kali:
```bash
curl -m 5 -s -o /dev/null -w "%{http_code}\n" http://10.10.10.20
```
Durante el bloqueo da `000`. A los 180 s vuelve a responder (`302`).
**La IP de Kali queda bloqueada 180 s: los ataques 3 y 4 no funcionan hasta que se libere.**

### 3 — Inyección SQL
```bash
./03-sqli.sh
```
Filtro payload (manual): `rule.id:100110 and not rule.description:*sqlmap*`
Filtro herramienta: `rule.id:100110 and rule.description:*sqlmap*`

### 4 — Webshell
```bash
./04-webshell.sh
```
Filtro: `rule.id:100120`

### Cierre — Remediación
```bash
./after.sh
```
Resultado esperado: sqlmap reporta `all tested parameters do not appear to be injectable`.

---

## 3. Resumen

| # | Script | Filtro en Wazuh |
|---|--------|-----------------|
| 1 | `01-recon.sh` | `rule.description:*SYN*` |
| 2 | `02-fuerza-bruta.sh` | `rule.id:100101` |
| 2b | (bloqueo) | `rule.id:651 or rule.id:652` |
| 3 | `03-sqli.sh` | `rule.id:100110 and not rule.description:*sqlmap*` |
| 3b | (sqlmap) | `rule.id:100110 and rule.description:*sqlmap*` |
| 4 | `04-webshell.sh` | `rule.id:100120` |

Vista general: menú ☰ → **Threat Hunting → Dashboard** (gráfico MITRE y conteos).

---

## 4. Si algo falla

| Síntoma | Arreglo |
|---|---|
| `'xterm-ghostty': unknown terminal type` | Entrar con `TERM=xterm-256color ssh ...` |
| El recon tarda mucho | `sed -i 's/-p-/--top-ports 200/' /ataques/01-recon.sh` |
| No salen alertas | Tiempo en "Last 24 hours", filtro correcto, pulsar Refresh, estar en Threat Hunting → Events |
| Los ataques 3/4 no llegan | La IP de Kali está bloqueada; esperar 180 s o correr `./infra/reset-demo.sh` |

Capturas de referencia: carpeta `docs/capturas/`.
