# Mini SOC en la nube — TiendaCR

**Curso:** ITI-922 Seguridad de TI II · **Proyecto 2** (15 %) · Prof. Marcos C.
**Integrantes:** _Apellido1, Nombre1_ · _Apellido2, Nombre2_
**Fecha:** 25 de noviembre de 2026
**Repositorio:** _(URL del repositorio público de GitHub)_

> **Declaración de uso de IA.** Se utilizó un asistente de IA (Claude) para apoyar la
> redacción del informe, la generación de los scripts de despliegue y de ataque, y la
> depuración de las reglas de detección. Todo el contenido fue revisado y comprendido por
> el equipo; la configuración se ejecutó y verificó en el laboratorio propio. El uso de IA
> no sustituye la comprensión que se evalúa en la defensa oral.

---

## Resumen ejecutivo

Se diseñó y operó un centro de operaciones de seguridad (SOC) mínimo para la tienda en línea
ficticia **TiendaCR**. El SOC protege un servidor web vulnerable (DVWA sobre contenedor) con
controles de acceso de denegación por defecto, lo monitorea con un IDS de red (Suricata) y un
HIDS/SIEM (Wazuh), y responde de forma automática a los ataques. Sobre esta plataforma se
ejecutaron cuatro ataques controlados —reconocimiento, fuerza bruta, inyección SQL y subida de
webshell— **todos detectados** por reglas propias, con su evidencia, tiempo de alerta y técnica
MITRE ATT&CK. La respuesta automática bloqueó en el firewall la IP atacante tras superar el umbral
de fallos de autenticación, y el bloqueo se verificó y se liberó solo. Finalmente se remedió la
aplicación y se repitieron los ataques: la inyección SQL pasó de volcar la tabla de usuarios
completa a **no ser explotable**, reduciendo el riesgo residual de Alto a Bajo.

El laboratorio se construyó en local sobre **KVM/libvirt** (equivalente a VirtualBox, justificado
en §4), con una red interna aislada 10.10.10.0/24 y el cortafuegos UFW en lugar de un grupo de
seguridad de nube.

---

## Fase 1. Investigación

### 1.1 Comparativa de herramientas de seguridad en la nube

Se comparan cinco herramientas: un servicio gestionado de un proveedor cloud (AWS GuardDuty) y
cuatro de código abierto (Wazuh, Suricata, Falco y CrowdSec).

| Criterio | **AWS GuardDuty** | **Wazuh 4.14** | **Suricata 7** | **Falco** | **CrowdSec** |
|---|---|---|---|---|---|
| **Qué detecta / protege** | Cuenta e identidades, red y cargas de trabajo en AWS (CloudTrail, VPC Flow Logs, DNS, EKS) | Host: registros, integridad de archivos (FIM), detección de vulnerabilidades, SCA; es SIEM + HIDS | Red (NIDS/IPS): tráfico y capa de aplicación | Host/contenedor/Kubernetes en tiempo de ejecución (syscalls) | Red y aplicación; IPS colaborativo basado en comportamiento |
| **Cómo** | Anomalías + inteligencia de amenazas + ML, sin firmas que mantener | Reglas y decodificadores propios; correlación por frecuencia | Firmas (reglas ET/propias) + anomalías de protocolo | Reglas sobre llamadas al sistema | Escenarios de comportamiento + listas de reputación compartidas |
| **Despliegue / recursos** | SaaS, sin agentes ni infraestructura; se activa por consola | Manager + indexer + dashboard (≥ 4 GB RAM) y agente ligero | Un binario en el host/sensor; liviano | DaemonSet / servicio en el host; liviano | Agente + "bouncer"; muy liviano |
| **Costo / licencia** | De pago, por volumen analizado (p. ej. VPC Flow Logs ~US$1.00/GB el primer tramo, con descuentos por volumen); sin costo fijo | Gratis, **GPLv2** | Gratis, **GPL-2.0** | Gratis, **Apache-2.0** (CNCF) | Gratis, motor **MIT**; listas premium opcionales |
| **Respuesta automática** | Sí, vía EventBridge → Lambda/Security Hub | Sí, *active response* (p. ej. `firewall-drop`) | Como IPS en línea (modo inline) | Alertas; respuesta vía herramientas externas | Sí, el *bouncer* bloquea en firewall/proxy |
| **Integración** | Nativa con todo AWS (Security Hub, Detective) | Suricata, OpenSearch, MITRE, VirusTotal, Slack | Wazuh, ELK, Zeek, SIEM vía EVE JSON | Falcosidekick, Prometheus, SIEM | Firewall, Nginx, Cloudflare, listas comunitarias |
| **Limitaciones** | Solo AWS; costo crece con el tráfico; caja negra | Consume RAM; ruido si no se afinan reglas | No ve dentro de TLS sin descifrado; solo red | Solo host/contenedor, no ve la red | Enfocado en reputación; menos FIM/compliance |

**Justificación de la elección.** Para TiendaCR se eligieron **Wazuh** como SIEM/HIDS central y
**Suricata** como IDS de red, ambos recomendados por el enunciado y de licencia libre, sin costo
y reproducibles en un laboratorio local. Wazuh aporta la correlación, la integridad de archivos
(clave para el ataque 4) y la respuesta automática; Suricata aporta la visibilidad de red (clave
para los ataques 1 y 3) y permite reglas propias sencillas. GuardDuty se descartó para la
operación por requerir la nube de AWS y tener costo por volumen, pero se incluye como referencia
del modelo gestionado. Falco y CrowdSec se evaluaron pero no se usaron: Falco no ve el tráfico de
red y CrowdSec se orienta a reputación, menos útil para los requisitos de FIM y de reglas propias.

### 1.2 Modelo de responsabilidad compartida

En un servidor de tipo **máquina virtual (IaaS)**, la responsabilidad se reparte así (tomando AWS
como proveedor de referencia; en el laboratorio local el "proveedor" es el equipo que administra
el host KVM):

| Capa | Responsable |
|---|---|
| Instalaciones físicas, hardware, red física, hipervisor | **Proveedor** (o el administrador del host en local) |
| Sistema operativo invitado, parches del SO | **Cliente (nosotros)** |
| Configuración de red virtual: grupos de seguridad / firewall | **Cliente** |
| Aplicación (DVWA), su base de datos y sus dependencias | **Cliente** |
| Control de acceso, llaves SSH, gestión de identidades | **Cliente** |
| Monitoreo, registros, detección y respuesta | **Cliente** |
| Cifrado de datos y gestión de las llaves | **Cliente** (el proveedor ofrece el servicio; el uso es nuestro) |

La lección central (Dotson, 2019) es que en IaaS **casi todo lo que está por encima del
hipervisor es responsabilidad del cliente**. El proveedor garantiza la seguridad *de* la nube;
nosotros garantizamos la seguridad *en* la nube. Este proyecto cubre precisamente esa parte del
cliente: endurecer el SO, restringir el acceso, monitorear y responder.

### 1.3 Análisis de riesgos del escenario (NIST SP 800-30)

#### 1.3.1 Inventario de activos

| Activo | C | I | D | Valor |
|---|---|---|---|---|
| A1. Servidor objetivo (SO + Docker) | Alta | Alta | Alta | Alto |
| A2. Aplicación web DVWA (TiendaCR) | Alta | Alta | Media | Alto |
| A3. Base de datos (usuarios, hashes) | Alta | Alta | Media | Alto |
| A4. Servidor SIEM (Wazuh + alertas) | Alta | Alta | Alta | Crítico |
| A5. Llaves SSH y credenciales | Alta | Alta | Baja | Crítico |
| A6. Red interna del laboratorio | Media | Media | Alta | Medio |

#### 1.3.2 Matriz de riesgos (probabilidad × impacto)

Escala: Baja(1) / Media(2) / Alta(3). Nivel = P×I → 1–2 Bajo, 3–4 Medio, 6–9 Alto.

| # | Activo | Amenaza / vulnerabilidad | P | I | Nivel |
|---|---|---|---|---|---|
| R1 | A2 | Inyección SQL (CWE-89) → fuga de la BD | 3 | 3 | **Alto (9)** |
| R2 | A2 | Subida de webshell (CWE-434) → RCE | 3 | 3 | **Alto (9)** |
| R3 | A1/A5 | Fuerza bruta a SSH/login (CWE-307) | 3 | 3 | **Alto (9)** |
| R4 | A2 | XSS reflejado/almacenado (CWE-79) | 2 | 2 | Medio (4) |
| R5 | A1 | Puertos/servicios expuestos a Internet | 2 | 3 | **Alto (6)** |
| R6 | A1 | Software sin parches (SO/contenedor) | 2 | 3 | **Alto (6)** |
| R7 | A5 | Credenciales por defecto (`admin/password`) | 3 | 2 | **Alto (6)** |
| R8 | A3 | Exfiltración de hashes y descifrado offline | 2 | 3 | **Alto (6)** |
| R9 | A4 | Caída/saturación del SIEM → ceguera | 2 | 3 | **Alto (6)** |
| R10 | A4 | Respuesta automática bloquea tráfico legítimo | 2 | 2 | Medio (4) |
| R11 | A6 | Reconocimiento/escaneo previo al ataque | 3 | 1 | Medio (3) |
| R12 | A1 | Path traversal / lectura de archivos (CWE-22) | 2 | 2 | Medio (4) |

#### 1.3.3 Puntajes CVSS v3.1 de vulnerabilidades reales usadas

| Vulnerabilidad | CWE / OWASP | Vector CVSS 3.1 | Base | Severidad |
|---|---|---|---|---|
| Inyección SQL (ataque 3) | CWE-89 / A03:2021-Injection | `AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:N` | **8.1** | Alta |
| Subida de archivo sin restricción → webshell (ataque 4) | CWE-434 / A04:2021 | `AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H` | **8.8** | Alta |
| Credenciales débiles + fuerza bruta (ataque 2) | CWE-307/CWE-521 / A07:2021 | `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N` | **9.1** | Crítica |

#### 1.3.4 Plan de tratamiento

| # | Decisión | Control propuesto | Responsable |
|---|---|---|---|
| R1 | Mitigar | Consultas parametrizadas (nivel `impossible`) + reglas IDS 1000004/5/6 | Dev / SOC |
| R2 | Mitigar | Validar tipo de archivo, carpeta sin ejecución; FIM 100120 | Dev / SOC |
| R3 | Mitigar | SSH solo con llave; respuesta automática `firewall-drop` | SOC |
| R5 | Mitigar | UFW deny por defecto; solo IP del equipo | SOC |
| R6 | Mitigar | `apt upgrade`, imágenes de contenedor al día | Sysadmin |
| R7 | Mitigar | Cambiar credenciales por defecto; política de contraseñas | Dev |
| R8 | Transferir/Mitigar | Hash fuerte (bcrypt), no MD5; cifrado en reposo | Dev |
| R9 | Mitigar | Dimensionar RAM del SIEM; alertas de disponibilidad | SOC |
| R10 | Aceptar | Lista blanca de IP del equipo + timeout corto (180 s) | SOC |
| R11 | Aceptar | Es inevitable; se monitorea (reglas 1000001/2) | SOC |

La **reevaluación** del riesgo residual, tras aplicar los controles, está en §8.

---

## 2. Arquitectura y despliegue (Fase 2.1)

```
  Laptop del equipo (host KVM)  10.10.10.1
        │  (SSH admin, panel Wazuh)
        │
  ┌─────┴───────── Red interna soc-net (10.10.10.0/24, NAT) ─────────────┐
  │                          │                           │
  ▼                          ▼                           ▼
 Kali (atacante)       Servidor objetivo            Servidor SIEM
 10.10.10.10           10.10.10.20                  10.10.10.30
 nmap, hydra,          Ubuntu 24.04:                Ubuntu 24.04:
 sqlmap                · DVWA en Docker             · Wazuh manager
 (contenedor Kali)     · Suricata (IDS)             · Wazuh indexer
                       · Agente Wazuh               · Wazuh dashboard
                       · UFW (deny por defecto)     · UFW (deny por defecto)
                          │  alertas (1514/1515)       ▲
                          └────────────────────────────┘
                       Respuesta automática: el manager ordena al agente
                       bloquear la IP atacante en el firewall (firewall-drop).
```

- **Servidor objetivo:** Ubuntu Server 24.04 LTS con DVWA en un contenedor (`ghcr.io/digininja/dvwa`)
  y su base de datos MariaDB. Los registros de Apache se exponen al agente y la carpeta de subidas
  se vigila con integridad de archivos.
- **Servidor SIEM:** Wazuh 4.14.10 "todo en uno" (manager + indexer + dashboard).
- **Atacante:** máquina con el contenedor oficial `kalilinux/kali-rolling` y sus herramientas.

---

## 3. Control de acceso y de tráfico (Fase 2.2)

Política de **denegación por defecto** en ambos sentidos (UFW). Todo acceso administrativo y a la
aplicación está restringido a las IP del equipo (10.10.10.1 la laptop y 10.10.10.10 la atacante),
**nunca a 0.0.0.0/0**. SSH solo con llave, sin contraseña y sin root directo (cloud-init endurece
`sshd`). Tabla de reglas del servidor objetivo:

| Regla | Sentido | Origen → Puerto | Justificación | Riesgo que mitiga | Principio |
|---|---|---|---|---|---|
| R1 | in | laptop → 22/tcp | Administración | Acceso no autorizado | Menor privilegio |
| R2 | in | Kali → 22/tcp | Prueba de fuerza bruta | — (controlado) | Denegación por defecto |
| R3 | in | laptop → 80/tcp | Uso de la tienda | Exposición de la app | Menor privilegio |
| R4 | in | Kali → 80/tcp | Ataques controlados | — (controlado) | Denegación por defecto |
| R5 | out | → SIEM 1514/1515 | Envío de alertas | Pérdida de visibilidad | Necesidad de saber |
| R6–R9 | out | DNS, apt/HTTPS, NTP, BD | Operación mínima | Canal encubierto | Menor privilegio |

Toda otra entrada y salida queda **denegada**. El SIEM solo acepta el panel (443) y SSH desde la
laptop, y los eventos del agente (1514/1515) desde el objetivo.

---

## 4. Monitoreo (Fase 2.3) y reglas propias (Fase 2.5)

- **Suricata 7** en el servidor objetivo, con el conjunto ET Open (~53 500 firmas) más **7 reglas
  propias** (`objetivo/suricata/tiendacr.rules`, sid 1000001–1000007). Sus alertas (EVE JSON) se
  integran al panel de Wazuh.
- **Wazuh 4.14.10**: agente en el objetivo que inspecciona los registros de autenticación y web,
  la integridad de archivos (FIM en tiempo real sobre la carpeta de subidas) y la detección de
  vulnerabilidades. En el manager se cargaron **3 reglas propias** (`siem/local_rules.xml`,
  100100/100101/100110/100120).

El enunciado pedía 2 reglas de Suricata y 1 de Wazuh; se entregaron **7 y 3** respectivamente, cada
una ligada a un ataque de la tabla.

> **Nota de entorno.** El laboratorio se montó en **KVM/libvirt**, no en VirtualBox: el equipo ya
> tenía KVM instalado y en Linux ambos hipervisores entran en conflicto. Las reglas (red interna,
> denegación por defecto con UFW, IP fijas) son idénticas a las de VirtualBox. La imagen *cloud* de
> Kali reiniciaba en bucle en este hardware (i5-11400H), por lo que la máquina atacante usa Kali en
> contenedor sobre una base Ubuntu; el tráfico sale igual desde 10.10.10.10, transparente para el IDS.

---

## 5. Ataques controlados y detecciones (Fase 2.4)

| # | Ataque | Herramienta / comando | Regla que detectó | Tiempo a la alerta | MITRE ATT&CK |
|---|---|---|---|---|---|
| 1 | Reconocimiento | `nmap -sS -sV -p- 10.10.10.20` | Suricata **1000001** (SYN) + **1000002** (NSE) + ET SCAN | segundos | T1046, T1595 |
| 2 | Fuerza bruta (login) | 20 intentos al formulario `/vulnerabilities/brute/` | Wazuh **100100 → 100101** (nivel 12) + Suricata **1000003** | ~9 s (al 10.º intento) | T1110.001 |
| 3 | Inyección SQL | manual (`' OR '1'='1`, `UNION SELECT`) + `sqlmap --dump` | Suricata **1000004/1000005/1000006** | segundos | T1190 |
| 4 | Webshell (subida) | `.php` subido a `/vulnerabilities/upload/` y ejecutado | Wazuh FIM **100120** (tiempo real) | segundos | T1505.003 |

**Evidencia observada.** El ataque 3 con `sqlmap` volcó la tabla `dvwa.users` completa, incluidos
los hashes MD5 (`5f4dcc3b…` = `password`). El ataque 4 subió `tienda_shell.php` y ejecutó
`id` (`uid=33(www-data)`), y Wazuh levantó la alerta de webshell en tiempo real. El detalle con
conteos por regla está en `docs/evidencias.md`.

---

## 6. Respuesta automática (Fase 2.6)

- **Disparador:** regla Wazuh **100101** (10 intentos de login en 30 s desde la misma IP, nivel 12).
- **Acción:** comando `firewall-drop` ejecutado en el agente del objetivo, que inserta
  `iptables … DROP 10.10.10.10` durante **180 s**.
- **Verificación:** durante el bloqueo, la atacante recibe HTTP 000 (sin respuesta); el bloqueo se
  liberó solo al expirar el timeout (19:40:22 → 19:43:25 en la prueba).
- **Riesgo (R10).** Una respuesta automática puede bloquear tráfico legítimo si un atacante falsea
  la IP de un usuario real (denegación de servicio inducida). Se mitiga con **lista blanca** de la
  laptop (10.10.10.1) y el SIEM (10.10.10.30) —que nunca se bloquean— y un **timeout corto** que
  evita cortes permanentes. En producción se complementaría con CAPTCHA y bloqueo por cuenta, no
  solo por IP.

---

## 7. Plan de respuesta a incidentes (Fase 2.7)

Aplicado al **ataque 2 (fuerza bruta contra el login)**. Roles: _Analista SOC_ (monitorea y
contiene) y _Administrador_ (erradica y recupera).

| Fase (NIST SP 800-61) | Acciones | Tiempo objetivo |
|---|---|---|
| **Preparación** | SOC desplegado, reglas y respuesta automática activas, respaldos y llaves documentados | Previo |
| **Detección y análisis** | Alerta 100101 en el panel; el analista confirma IP origen, cuenta objetivo y número de intentos | ≤ 1 min |
| **Contención** | La respuesta automática ya bloqueó la IP (180 s); el analista extiende el bloqueo si persiste | ≤ 2 min |
| **Erradicación** | Cambiar credenciales por defecto, forzar contraseñas fuertes, revisar accesos exitosos en los registros | ≤ 30 min |
| **Recuperación** | Confirmar que no hubo acceso válido; levantar el bloqueo; reanudar operación monitoreada | ≤ 1 h |
| **Lecciones aprendidas** | Documentar; añadir MFA/CAPTCHA; ajustar umbrales si hubo falsos positivos | ≤ 1 semana |

---

## 8. Remediación y reevaluación (Fase 2.8)

Se corrigió la aplicación llevando DVWA al nivel **`impossible`** (consultas preparadas, tokens
anti-CSRF y validación de entrada) y se repitieron los ataques 2 y 3:

| Ataque | Antes (nivel `low`) | Después (nivel `impossible`) |
|---|---|---|
| 3. Inyección SQL | `sqlmap` volcó la tabla `users` con sus hashes | `all tested parameters do not appear to be injectable` — **falla** |
| 2. Fuerza bruta | el formulario vulnerable responde | consultas preparadas + token; sin acceso, y la IP queda bloqueada |

**Reevaluación del riesgo residual:**

| # | Nivel inicial | Control aplicado | Riesgo residual |
|---|---|---|---|
| R1 (SQLi) | Alto (9) | Consultas parametrizadas + IDS | **Bajo (2)** |
| R2 (Webshell) | Alto (9) | Validación de subida + FIM | **Medio (4)** |
| R3 (Fuerza bruta) | Alto (9) | SSH con llave + respuesta automática | **Bajo (2)** |
| R5 (Exposición) | Alto (6) | UFW deny por defecto | **Bajo (2)** |
| R7 (Credenciales) | Alto (6) | Cambio de credenciales (pendiente de política) | **Medio (4)** |

---

## 9. Conclusiones

1. Un SOC mínimo pero completo —controles de acceso, IDS de red, HIDS/SIEM y respuesta
   automática— se puede construir con herramientas libres y detectar los cuatro ataques del
   escenario con evidencia medible.
2. La **defensa en capas** funcionó: cuando una capa no vería el ataque (p. ej. el IDS de red no
   distingue bien un webshell ya subido), otra sí lo hace (la integridad de archivos del HIDS).
3. La **remediación es verificable**: la misma prueba que antes volcaba la base de datos, después
   no encuentra inyección. Medir antes y después es lo que convierte una corrección en evidencia.
4. La **respuesta automática** es potente pero peligrosa: sin lista blanca y timeouts, el propio
   SOC puede causar una denegación de servicio. El diseño debe asumir ese riesgo.

---

## 10. Referencias (APA)

- Dotson, C. (2019). *Practical cloud security: A guide for secure design and deployment*. O'Reilly Media.
- Guijarro Rodríguez, A. et al. (2020). *DevOps y seguridad cloud*. Editorial Universitaria.
- Wazuh Inc. (2026). *Wazuh documentation (v4.14)*. https://documentation.wazuh.com/
- Open Information Security Foundation. (2026). *Suricata user guide (v7)*. https://docs.suricata.io/
- National Institute of Standards and Technology. (2012). *Guide for conducting risk assessments (NIST SP 800-30 Rev. 1)*. https://doi.org/10.6028/NIST.SP.800-30r1
- National Institute of Standards and Technology. (2012). *Computer security incident handling guide (NIST SP 800-61 Rev. 2)*. https://doi.org/10.6028/NIST.SP.800-61r2
- MITRE. (2026). *MITRE ATT&CK Matrix for Enterprise*. https://attack.mitre.org/
- FIRST. (2019). *Common Vulnerability Scoring System v3.1: Specification document*. https://www.first.org/cvss/

---

## Anexos

- **Anexo A.** Repositorio con el README reproducible, scripts de infraestructura y ataque, reglas
  propias y archivos de configuración.
- **Anexo B.** `docs/evidencias.md`: tabla de detecciones con conteos por regla.
- **Anexo C.** Capturas del panel de Wazuh (dashboard, alertas por ataque, bloqueo automático).
