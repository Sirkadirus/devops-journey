# Incidente 001 — Connection Refused en /health

**Fecha:** 2026-07-28
**Severidad:** Alta
**Síntoma:** curl devuelve `Connection refused` al consultar GET /health

## Diagnóstico
1. `curl -v` mostró resolución DNS correcta (localhost → 127.0.0.1/::1)
2. El intento de conexión TCP fue rechazado activamente (RST del kernel)
3. `ss -tulnp | grep :8000` no mostró ningún proceso escuchando

## Causa raíz
El proceso Uvicorn no estaba corriendo. El kernel rechazó la conexión
porque no había ningún socket en estado LISTEN sobre el puerto 8000.

## Resolución
Se reinició el servicio: `uvicorn app.main:app --host 0.0.0.0 --port 8000`

## Aprendizaje
"Connection refused" ≠ fallo de red/TCP. Es la respuesta correcta y
esperada del kernel cuando no hay proceso escuchando en el puerto.
Diferenciar de "Connection timed out" (posible fallo de red/firewall).
