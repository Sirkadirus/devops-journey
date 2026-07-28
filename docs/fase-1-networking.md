# Fase 1 — Networking

**Estado:** ✅ Cerrada
**Tag:** `v0.1.1`
**Fecha de cierre:** 2026-07-28

---

## Objetivo de la fase

Comprender y diagnosticar el recorrido completo de una petición HTTP, desde el cliente hasta la aplicación, implementando el endpoint mínimo `GET /health` en FastAPI.

---

## Checklist de conceptos

| Concepto | Teoría | Implementación | Diagnóstico |
|---|---|---|---|
| Modelo OSI / recorrido completo | ✅ | ✅ (`/health`) | ✅ |
| HTTP | ✅ | ✅ | ✅ (`curl -v`) |
| TCP | ✅ | ✅ | ✅ (`ss -tulnp`, connection refused) |
| DNS | ✅ | ⏳ Pendiente (llega en Fase 5, AWS) | ✅ (`dig`, TTL, caché local) |
| TLS | ✅ | ⏳ Pendiente (llega en Fase 4, Nginx) | ✅ (`curl -v https`) |

DNS y TLS quedan sin implementación propia en esta fase de forma intencional: todavía no existe un dominio propio ni un reverse proxy que los requiera. Vuelven con contexto real más adelante.

---

## Implementación

- API mínima en FastAPI con endpoint `GET /health` (`{"status": "healthy"}`)
- Servidor Uvicorn, verificado escuchando en `0.0.0.0:8000`
- Entorno virtual de Python aislado (`venv/`)

## EN/ES — Términos clave

| Inglés | Español |
|---|---|
| Virtual environment (venv) | Entorno virtual |
| Host | Interfaz/dirección donde escucha el servicio |
| Bind | Asociar un proceso a una IP/puerto |
| Socket | Combinación IP + puerto que identifica un extremo de conexión |
| Listen (state) | Estado de un socket esperando conexiones entrantes |
| Three-Way Handshake | Establecimiento de conexión TCP (SYN, SYN-ACK, ACK) |
| Connection refused | Rechazo activo del kernel: no hay proceso escuchando en el puerto |
| Connection timed out | Sin respuesta alguna: posible fallo de red/firewall |
| TTL (Time To Live) | Segundos que una respuesta DNS puede permanecer en caché |
| Resolver | Servicio que resuelve nombres DNS a IPs (local o externo) |
| CA (Certificate Authority) | Entidad de confianza que firma certificados TLS |
| Chain of trust | Cadena de confianza: navegador → CA → certificado del sitio |
| ALPN | Negociación del protocolo de aplicación (HTTP/1.1 vs HTTP/2) durante el TLS handshake |

---

## Diagnósticos realizados

### 1. `curl -v` sobre HTTP local
Confirmó el flujo completo: resolución de `localhost`, conexión TCP, envío de la petición GET y respuesta `200 OK` con el body JSON.

### 2. `ss -tulnp`
Confirmó el proceso Uvicorn en estado `LISTEN` sobre el puerto 8000, primero incorrectamente en `127.0.0.1` (bug real detectado y corregido) y luego correctamente en `0.0.0.0`.

### 3. Incidente simulado — Connection Refused
Ver `docs/incidents/001-connection-refused.md`. Se detuvo el servicio a propósito y se diagnosticó con `curl -v` + `ss -tulnp`, confirmando que "Connection refused" es un rechazo activo del kernel (RST) y no un fallo de la capa de transporte en sí.

### 4. `dig google.com` — DNS y caché
Primera consulta: `Query time: 26 msec`, TTL inicial `283`.
Segunda consulta: `Query time: 0 msec`, TTL descendido a `146` — confirmó el comportamiento de caché del resolver local (`127.0.0.53`, systemd-resolved) y el conteo regresivo del TTL. Se identificó además que DNS opera sobre UDP.

### 5. `curl -v https://google.com` — TLS Handshake
Se observó el handshake completo de TLS 1.3 (Client Hello → Server Hello → Certificate → verificación → Finished), la validación de la cadena de confianza (`SSL certificate verify ok.`), las fechas de expiración del certificado, y la negociación de HTTP/2 vía ALPN.

---

## Aprendizajes clave

- `Connection refused` ≠ fallo de red. Es la respuesta correcta y esperada del kernel cuando no hay un proceso escuchando en el puerto (diferenciar de `Connection timed out`, que sí sugiere problema de red/firewall).
- El bind por defecto de Uvicorn es `127.0.0.1`; para exponer el servicio en la red hace falta `--host 0.0.0.0` explícito. Este error es la causa más común de `502 Bad Gateway` una vez que se introduce Nginx/Docker (Fase 4).
- Los certificados TLS expiran — una causa real y común de caídas en producción.
- DNS resuelve vía UDP por defecto (consulta corta, sin necesidad de handshake).

---

## Commits de la fase

```
feat(api): agrega endpoint GET /health con FastAPI
fix(api): corrige bind de host a 0.0.0.0 para exponer el servicio en la red
docs(incidents): documenta incidente 001 - connection refused por servicio caído
docs: cierra Fase 1 (networking) - DNS y TLS diagnosticados con dig y curl -v
```

**Tags:** `v0.1` → `v0.1.1`
