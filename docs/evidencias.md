# Evidencias de detección (fase 2.4)

Laboratorio KVM, red 10.10.10.0/24. Atacante 10.10.10.10, objetivo 10.10.10.20, SIEM 10.10.10.30.
Capturas del panel en `docs/capturas/`.

| N.º | Ataque | Herramienta/comando | Regla que detectó | Tiempo a la alerta | MITRE ATT&CK |
|-----|--------|---------------------|-------------------|--------------------|--------------|
| 1 | Reconocimiento | `nmap -sS -sV -p- 10.10.10.20` | Suricata 1000001 (SYN propia) + 1000002 (NSE) + ET SCAN | segundos | T1046, T1595 |
| 2 | Fuerza bruta (login) | `02-fuerza-bruta.sh app` | Wazuh 100100→100101 (nivel 12) + Suricata 1000003 | ~9 s (10 intentos) | T1110.001 |
| 3 | Inyección SQL | `03-sqli.sh` (manual + sqlmap) | Suricata 1000004/1000005/1000006 (sqlmap volcó la tabla users) | segundos | T1190 |
| 4 | Webshell | `04-webshell.sh` | Wazuh FIM 100120 (tiempo real) | segundos | T1505.003 |

## Respuesta automática (fase 2.6)
- Disparador: regla 100101 (10 intentos de login en 30 s desde la misma IP).
- Acción: `firewall-drop` en el agente del objetivo → `iptables ... DROP 10.10.10.10`, 180 s.
- Verificado: durante el bloqueo la atacante recibe HTTP 000 (sin respuesta). La laptop (10.10.10.1)
  y el SIEM están en lista blanca para no cortar tráfico legítimo.
- Riesgo: un atacante que falsee una IP legítima podría provocar el bloqueo de esa IP (denegación
  de servicio por la propia respuesta); por eso el timeout es corto y hay lista blanca.

## Remediación y reevaluación (fase 2.8)
Se corrigió la aplicación subiendo DVWA al nivel `impossible` (consultas preparadas/parametrizadas,
tokens anti-CSRF y validación), vía `DVWA_NIVEL=impossible` en `/opt/tiendacr/.env`.

| Ataque | Antes (low) | Después (impossible) |
|--------|-------------|----------------------|
| 3. Inyección SQL | sqlmap volcó la tabla `users` (hashes incluidos) | `all tested parameters do not appear to be injectable` — falla |
| 2. Fuerza bruta | DVWA responde al formulario vulnerable | consultas preparadas + token; sin acceso |

Riesgo residual: con el código corregido, la inyección SQL baja de nivel Alto a Bajo. La fuerza bruta
se mitiga además con la respuesta automática (bloqueo de IP). Queda como control pendiente el cambio
de la contraseña por defecto `admin/password` y añadir MFA.
