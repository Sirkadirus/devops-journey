# Fase 3 — Servicios

**Estado:** ✅ Cerrada
**Tag:** `v0.3`
**Última actualización:** 2026-08-28

---

## Objetivo de la fase

Incorporar Nginx como reverse proxy y PostgreSQL como base de datos, transformando la API de un proceso aislado a un servicio con arquitectura real de producción: Cliente → Nginx → FastAPI → PostgreSQL.

---

## Checklist de conceptos

| Concepto | Teoría | Implementación | Diagnóstico |
|---|---|---|---|
| Nginx como reverse proxy | ✅ | ✅ (`infra/nginx/devops-journey.conf`) | ✅ (Incidente #005) |
| Headers de proxy (`X-Real-IP`, `X-Forwarded-*`) | ✅ | ✅ | — |
| PostgreSQL: usuarios, bases, conexión | ✅ | ✅ (`devops_app` / `devops_journey`) | ✅ (`psql` manual, `\conninfo`) |
| SQLAlchemy: engine, sessionmaker, dependencia `get_db` | ✅ | ✅ (`app/db.py`) | ✅ (`GET /db-check`) |
| Manejo de credenciales (.env) | ✅ | ✅ | — |

---

## Módulo — Nginx como Reverse Proxy

### Implementación
Bloque `server` propio en `/etc/nginx/sites-available/devops-journey.conf`, enlazado a `sites-enabled/` (con el `default` removido para evitar ambigüedad), reenviando a `http://127.0.0.1:8000` con headers `Host`, `X-Real-IP`, `X-Forwarded-For` y `X-Forwarded-Proto`.

### Diagnóstico — Incidente #005 (ver `runbook.md`)
Se provocó un `502 Bad Gateway` deteniendo el servicio backend con Nginx activo. Se diagnosticó en capas: red del proxy sana (`nc -vz`, `ss -tlnp`) → error específico en `error.log` de Nginx (`connect() failed (111: Connection refused)` al upstream) → confirmación del backend caído (`ss -tlnp :8000` vacío, `systemctl status` inactive). Aprendizaje clave: el 502 siempre lo genera la capa proxy, nunca el backend.

---

## Módulo — PostgreSQL

### Instalación y verificación
- Se identificó la diferencia entre el paquete cliente (`postgresql-client-common`) y el paquete completo (`postgresql` + `postgresql-contrib`, que incluye el motor/servidor).
- Se diagnosticó la arquitectura de servicios de PostgreSQL en Ubuntu: `postgresql.service` (wrapper, `active exited` es normal) vs. `postgresql@16-main.service` (instancia real del motor, debe estar `active running`). Confirmado con `systemctl list-units --type=service | grep -i postgres`.
- Verificación en capas: proceso activo (`systemctl status`) → acepta conexiones (`psql` conecta) → ejecuta SQL real (`SELECT version()`).

### Usuario y base de datos
```sql
CREATE USER devops_app WITH PASSWORD '********';
CREATE DATABASE devops_journey OWNER devops_app;
```
Se evitó usar el superusuario `postgres` para la aplicación — principio de menor privilegio. Se confirmó la conexión por TCP con `-h 127.0.0.1` (autenticación por contraseña, no `peer`), incluyendo TLS habilitado por defecto (confirmado con `\conninfo`).

### Conexión desde FastAPI
- Librerías: `sqlalchemy` (ORM), `psycopg2-binary` (driver de bajo nivel), `python-dotenv` (carga de `.env`).
- `app/db.py`: `create_engine(DATABASE_URL)` + `sessionmaker(...)` para gestionar sesiones.
- `DATABASE_URL` gestionada vía `.env` (excluido de Git desde Fase 1) con `.env.example` versionado como plantilla.
- Endpoint `GET /db-check`: usa el patrón de inyección de dependencias de FastAPI (`Depends(get_db)`) con un generador (`yield`) que garantiza el cierre de la sesión, ejecutando `SELECT 1` como verificación mínima de conectividad.

### Verificación final
```
curl http://localhost:8000/db-check  → {"database":"connected"}  (server: uvicorn)
curl http://localhost:80/db-check    → {"database":"connected"}  (Server: nginx)
```
Confirmado el recorrido completo: Cliente → Nginx → FastAPI → SQLAlchemy → psycopg2 → PostgreSQL.

---

## EN/ES — Términos clave

| Inglés | Español |
|---|---|
| Reverse proxy | Proxy inverso |
| Upstream | Backend al que un proxy reenvía peticiones |
| Connection string | Cadena de conexión (URL con credenciales y destino de la BD) |
| Cluster (PostgreSQL) | Instancia completa del motor, no múltiples servidores |
| Role / user | Rol / usuario dentro del motor de base de datos |
| Driver | Librería de bajo nivel que implementa el protocolo de comunicación con la BD |
| ORM | Mapeo objeto-relacional (traduce clases Python a filas SQL) |
| Dependency injection | Inyección de dependencias |
| Generator (yield) | Función generadora — entrega un valor y retiene su estado hasta ser reanudada |
| Least privilege | Principio de menor privilegio (dar solo los permisos estrictamente necesarios) |

---

## Aprendizajes clave

- Un `502` es siempre generado por la capa proxy/gateway, nunca por el backend — el backend puede ni enterarse de que existió la petición.
- El código de sistema `111` en Linux corresponde a `ECONNREFUSED` — mismo significado ya visto en incidentes de Fase 1 y 2, ahora observado desde la perspectiva de Nginx actuando como cliente.
- Distinguir el servicio "wrapper" (`postgresql.service`) del servicio real (`postgresql@16-main.service`) es necesario para diagnósticos correctos con `systemctl`/`journalctl`.
- Nunca conectar la aplicación con el superusuario de la base de datos — crear un rol con permisos acotados a su propia base.
- El patrón `get_db()` con `yield` + `Depends()` es el estándar de FastAPI para garantizar que las sesiones de base de datos se cierren correctamente, incluso si ocurre un error.

---

## Commits de la fase

```
feat(nginx): agrega reverse proxy hacia Uvicorn en puerto 8000
docs(runbook): documenta incidente 005 - 502 bad gateway con backend detenido
feat(db): agrega conexión a PostgreSQL vía SQLAlchemy y endpoint GET /db-check
docs: cierra Fase 3 (Servicios) - Nginx y PostgreSQL integrados
```

**Tag:** `v0.3`
