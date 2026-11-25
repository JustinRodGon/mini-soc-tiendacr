# Guía de la demostración — Mini SOC TiendaCR

Paso a paso para la demo en vivo: **atacar desde Kali** y **ver la detección en Wazuh**.
La idea que se demuestra es el ciclo de un SOC: **prevenir → detectar → responder → recuperar**.

---

## 0. Quién es quién (las 3 máquinas)

| Máquina | IP | Rol |
|---|---|---|
| Laptop (host) | 10.10.10.1 | Desde aquí hace SSH y abre el panel |
| **Kali** (atacante) | 10.10.10.10 | Lanza los ataques (contenedor con nmap/hydra/sqlmap) |
| **Objetivo** | 10.10.10.20 | DVWA + Suricata + agente Wazuh + UFW |
| **SIEM** | 10.10.10.30 | Panel Wazuh (manager + indexer + dashboard) |

El flujo: Kali ataca al objetivo → Suricata/los logs ven el ataque → el agente Wazuh del
objetivo manda la alerta al SIEM → en el panel (`https://10.10.10.30`) aparece la detección.

---

## 1. Preparar las dos ventanas

**Antes de empezar**, desde la laptop deje el SOC en cero (sin alertas viejas, sin webshell y sin
la IP atacante bloqueada) y espere un minuto a que el agente reconecte:

```bash
./infra/reset-demo.sh
```

Trabaje con **dos ventanas a la vista** al mismo tiempo:

- **Ventana A — Terminal de Kali** (desde donde ataca).
- **Ventana B — Navegador con el panel de Wazuh** (donde ve las alertas).

### 1.A Entrar a Kali

```bash
# Desde la laptop. Si su terminal es Ghostty y da "unknown terminal type":
TERM=xterm-256color ssh -i ~/.ssh/minisoc_ed25519 soc@10.10.10.10

# Ya dentro de la VM, abrir la shell de Kali (lanza el contenedor con las herramientas):
kali
cd /ataques
```
Dentro del contenedor el prompt cambia a `root㉿kali` y la carpeta de ataques es `/ataques`.

### 1.B Entrar y preparar el panel de Wazuh

1. Abra `https://10.10.10.30` (acepte el aviso de certificado).
2. Login: usuario **`admin`**. La contraseña se obtiene así (desde la laptop):
   ```bash
   ssh -i ~/.ssh/minisoc_ed25519 soc@10.10.10.30 "sudo grep -A2 'User: admin' /root/wazuh-install.log"
   ```
3. Menú (☰ arriba a la izquierda) → **Threat Hunting**.
4. Pestaña **Events**.
5. Arriba a la derecha, selector de tiempo → **Last 24 hours**.
   - (Opcional) **Refresh every → 5 seconds → Start** para que se actualice sola.
6. Deje la **barra de búsqueda vacía** para ver todo; o pegue la búsqueda de cada ataque.

> **Regla de oro:** refrescar NO crea alertas. Si no sale nada, revise: (a) tiempo en "Last 24
> hours", (b) barra de búsqueda vacía, (c) pulsó Refresh, (d) está en Threat Hunting → Events.

---

## 2. El guion, ataque por ataque

Para cada paso: **corra el comando en Kali (Ventana A)** y luego **pegue la búsqueda en Wazuh
(Ventana B)** y pulse Refresh. Entre el ataque y la alerta suele pasar < 1 minuto.

### Ataque 1 — Reconocimiento (nmap) · MITRE T1046

**En Kali:**
```bash
./01-recon.sh
```
> Si tarda mucho: el `-p-` escanea los 65.535 puertos y el firewall descarta paquetes → es
> lento. Para la demo, acórtelo una vez: `sed -i 's/-p-/--top-ports 200/' /ataques/01-recon.sh`.
> La alerta se dispara aunque no termine; puede parar con Ctrl+C.

**En Wazuh, buscar:**
```
rule.description:*SYN*
```
**Qué aparece:** *"TIENDACR Escaneo de puertos SYN desde 10.10.10.10"* (nivel 10, Suricata).
**Qué decir:** *"El atacante hace reconocimiento de la red; Suricata lo detecta como escaneo."*

---

### Ataque 2 — Fuerza bruta + RESPUESTA AUTOMÁTICA · MITRE T1110

**En Kali:**
```bash
./02-fuerza-bruta.sh
```

**En Wazuh, buscar la fuerza bruta:**
```
rule.id:100101
```
**Qué aparece:** *"fuerza bruta contra el login de DVWA"* (nivel 12). Cada intento suelto es la
regla `100100`; al acumularse salta la `100101`.

**En Wazuh, buscar el bloqueo automático:**
```
rule.id:651 or rule.id:652
```
**Qué aparece:** *"Host Blocked by firewall-drop Active Response"* → *"Host Unblocked"* (~180 s
después). **Wazuh bloqueó la IP de Kali solo, sin intervención humana.**

**Demostrarlo en vivo** — unos 15 s después de la fuerza bruta (o cuando ya aparezca la regla 651), en Kali:
```bash
curl -m 5 -s -o /dev/null -w "%{http_code}\n" http://10.10.10.20
```
Durante el bloqueo **falla** (timeout / sin respuesta). A los 3 minutos vuelve a responder.
**Qué decir:** *"El SOC no solo detecta: responde solo, aísla al atacante y luego se recupera."*

---

### Ataque 3 — Inyección SQL · MITRE T1190

**En Kali:**
```bash
./03-sqli.sh
```
Roba la tabla `users` completa (los hashes de las contraseñas).

**En Wazuh, buscar el payload inyectado:**
```
rule.id:100110 and not rule.description:*sqlmap*
```
**Qué aparece:** *"Inyeccion SQL UNION SELECT"* y *"tautologia OR"* (Suricata detecta el contenido
malicioso, no solo la herramienta).

**En Wazuh, buscar la herramienta automática:**
```
rule.id:100110 and rule.description:*sqlmap*
```
**Qué aparece:** cientos de *"Herramienta sqlmap"*.
**Qué decir:** *"Detecto tanto la inyección manual como el uso de sqlmap."*

---

### Ataque 4 — Webshell · MITRE T1505.003

**En Kali:**
```bash
./04-webshell.sh
```
Sube un PHP malicioso a `/srv/dvwa/uploads/` para ejecutar comandos en el servidor.

**En Wazuh, buscar:**
```
rule.id:100120
```
**Qué aparece:** *"posible webshell creada en /srv/dvwa/uploads/tienda_shell.php"* (nivel 13).
Lo detecta el **FIM** (monitoreo de integridad de archivos) en el instante de la subida.
**Qué decir:** *"Cualquier archivo nuevo en la carpeta de subidas me genera alerta inmediata."*

---

### Cierre — Remediación · 2.8

**En Kali:**
```bash
./after.sh
```
Sube DVWA a nivel `impossible` (consultas parametrizadas) y repite la SQLi.
**Resultado:** sqlmap reporta *"all tested parameters do not appear to be injectable"*.
**Qué decir:** *"Identificada la falla, la remedio y verifico que el ataque ya no funciona."*

---

## 3. Tabla resumen (para tener a mano)

| # | Script | Ataque | Búsqueda en Wazuh | Regla | MITRE |
|---|--------|--------|-------------------|-------|-------|
| 1 | `01-recon.sh` | Reconocimiento | `rule.description:*SYN*` | Suricata (100110) | T1046 |
| 2 | `02-fuerza-bruta.sh` | Fuerza bruta | `rule.id:100101` | 100100→100101 | T1110 |
| 2b | — | Respuesta automática | `rule.id:651 or rule.id:652` | firewall-drop | — |
| 3 | `03-sqli.sh` | Inyección SQL | `rule.id:100110 and not rule.description:*sqlmap*` | Suricata propias | T1190 |
| 3b | — | sqlmap | `rule.id:100110 and rule.description:*sqlmap*` | Suricata (UA) | T1190 |
| 4 | `04-webshell.sh` | Webshell | `rule.id:100120` | FIM 100120 | T1505.003 |

Vista general del SOC: menú → **Threat Hunting → Dashboard** (gráfico MITRE y conteos).

---

## 4. Si algo no sale

| Síntoma | Causa / arreglo |
|---|---|
| `nmap: command not found` | Está en la VM, no en el contenedor. Use `kali bash /ataques/01-recon.sh` o entre con `kali`. |
| `'xterm-ghostty': unknown terminal type` | `export TERM=xterm-256color` antes de trabajar. |
| El recon tarda muchísimo | `-p-` escanea 65.535 puertos; use `--top-ports 200`. La alerta ya se disparó. |
| No salen alertas al refrescar | Tiempo en "Last 24 hours" + barra de búsqueda vacía + estar en Threat Hunting → Events. |
| Los ataques no llegan al objetivo | La IP de Kali quedó bloqueada por la respuesta automática; espere 180 s (`curl -m 5 http://10.10.10.20` para probar). |

Capturas de referencia de cómo se ve cada alerta: carpeta `docs/capturas/`.
