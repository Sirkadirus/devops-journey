# Runbook — DevOps Journey

Colección de incidentes provocados y resueltos durante la construcción del proyecto, documentados en formato de runbook operativo. Cada entrada sigue una estructura estándar: síntoma, diagnóstico, causa raíz, solución y prevención.

Este documento se actualiza al cierre de cada incidente relevante, en paralelo a las bitácoras de fase (`docs/fase-N-*.md`), que documentan el *aprendizaje*. Este archivo documenta la *operación*: qué hacer si el síntoma vuelve a aparecer.

---

## Categorías

- 🔴 **Red** — DNS, TCP, puertos, conectividad
- 🟡 **Configuración** — archivos de config no aplicados o incorrectos
- 🟢 **Despliegue** — systemd, procesos, ciclo de vida de servicios
- 🔵 **Seguridad** — identidad, autenticación, permisos
- 🟣 **Recursos** — memoria, disco, CPU (pendiente de incidentes)

---

### Incidente #001 – Connection Refused

- **Fase**: v0.1 — Networking
- **Categoría**: 🔴 Red
- **Síntoma**: `curl http://localhost:8000/health` devuelve `curl: (7) Failed to connect... Connection refused`
- **Diagnóstico**:
  - Comandos usados: `curl -v http://localhost:8000/health`, `ss -tulnp | grep ":8000"`
  - Evidencia clave: `curl -v` mostró resolución DNS correcta y rechazo activo de conexión (`Connection refused`); `ss -tulnp` no devolvió ningún proceso en estado `LISTEN` sobre el puerto 8000.
- **Causa raíz**: El proceso Uvicorn no estaba corriendo. El kernel rechazó la conexión (RST) porque ningún socket escuchaba en ese puerto.
- **Solución aplicada**:
  - Cambio realizado: se reinició el servicio manualmente (`uvicorn app.main:app --host 0.0.0.0 --port 8000`).
  - Comando de verificación: `curl http://localhost:8000/health` → `200 OK`
- **Prevención**: Gestionar el proceso vía systemd con `Restart=on-failure` (ver Incidente #004) en lugar de ejecución manual en terminal.
- **Aprendizaje clave**: `Connection refused` ≠ fallo de red/TCP. Es la respuesta correcta y esperada del kernel cuando no hay proceso escuchando. Diferenciar de `Connection timed out`, que sí sugiere problema de red/firewall.
- **Tiempo estimado de resolución**: 5 minutos

---

### Incidente #002 – Bind incorrecto a localhost en lugar de 0.0.0.0

- **Fase**: v0.1 — Networking
- **Categoría**: 🔴 Red / 🟡 Configuración
- **Síntoma**: El servicio responde en `curl localhost:8000` pero no sería alcanzable desde otra máquina de la red.
- **Diagnóstico**:
  - Comandos usados: `ss -tulnp | grep ":8000"`
  - Evidencia clave: el socket aparecía como `127.0.0.1:8000` en lugar de `0.0.0.0:8000`.
- **Causa raíz**: Uvicorn se ejecutó sin el flag `--host 0.0.0.0`; el valor por defecto es `127.0.0.1` (solo loopback).
- **Solución aplicada**:
  - Cambio realizado: se agregó explícitamente `--host 0.0.0.0` al comando de arranque.
  - Comando de verificación: `ss -tulnp | grep ":8000"` → confirma `0.0.0.0:8000`
- **Prevención**: Definir el host explícitamente en el `ExecStart` del `.service` (ver `infra/systemd/`), nunca depender del valor por defecto.
- **Aprendizaje clave**: Esta es la causa más común de `502 Bad Gateway` una vez que se introduce un reverse proxy o contenedores: el backend "funciona" pero solo escucha internamente, invisible para quien lo consulta desde afuera. El mismo patrón reapareció en el Incidente #006 con PostgreSQL.
- **Tiempo estimado de resolución**: 10 minutos

---

### Incidente #003 – Módulo no encontrado al ejecutar script fuera de su directorio

- **Fase**: v0.2 — Linux Administration
- **Categoría**: 🟡 Configuración
- **Síntoma**: `./scripts/start.sh` ejecutado desde `~` falla con `ModuleNotFoundError: No module named 'app'`
- **Diagnóstico**:
  - Comandos usados: ejecución directa del script, lectura de traceback de Python
  - Evidencia clave: el binario de Uvicorn se resolvió correctamente (ruta absoluta interna del venv), pero el argumento `app.main:app` se interpretó relativo al directorio de trabajo (`cwd`), que no era la raíz del proyecto.
- **Causa raíz**: El script no fijaba su propio directorio de trabajo antes de invocar a Uvicorn.
- **Solución aplicada**:
  - Cambio realizado: se agregó `cd "$(dirname "$0")/.."` al inicio de `start.sh` para que se auto-posicione en su raíz sin importar desde dónde se invoque.
  - Comando de verificación: `cd ~ && ./devops-journey/scripts/start.sh` → arranca correctamente
- **Prevención**: Todo script de arranque debe fijar explícitamente su working directory. Es el mismo patrón que luego resuelve `WorkingDirectory=` en el `.service` de systemd.
- **Tiempo estimado de resolución**: 15 minutos

---

### Incidente #004 – Cambio de configuración de systemd no aplicado

- **Fase**: v0.2 — Linux Administration
- **Categoría**: 🟢 Despliegue
- **Síntoma**: Se edita `ExecStart` en `devops-journey.service` (cambio de puerto 8000 → 9000), pero el servicio sigue respondiendo en el puerto viejo.
- **Diagnóstico**:
  - Comandos usados: `curl http://localhost:8000/health` (sigue respondiendo tras editar el archivo), `journalctl -u devops-journey -n 20`
  - Evidencia clave: el archivo en disco ya tenía el puerto nuevo, pero el proceso en memoria seguía siendo el arrancado con la configuración vieja.
- **Causa raíz**: Editar un archivo `.service` no tiene ningún efecto sobre un proceso ya en ejecución hasta que se recarga la definición y se reinicia el proceso.
- **Solución aplicada**:
  - Cambio realizado: `sudo systemctl daemon-reload && sudo systemctl restart devops-journey`
  - Comando de verificación: `curl http://localhost:8000/health` → falla (puerto viejo); `curl http://localhost:9000/health` → responde (puerto nuevo)
- **Prevención**: Siempre ejecutar `daemon-reload` inmediatamente después de editar cualquier unit file, antes de `restart`.
- **Aprendizaje clave**: `daemon-reload` (releer configuración) y `restart` (aplicar el proceso) son pasos independientes y ambos son necesarios, en ese orden.
- **Tiempo estimado de resolución**: 10 minutos

---

### Incidente #005 – 502 Bad Gateway con Nginx como reverse proxy

- **Fase**: v0.3 — Servicios (Nginx)
- **Categoría**: 🔴 Red / 🟢 Despliegue
- **Síntoma**: `curl http://localhost:80/health` devuelve `HTTP/1.1 502 Bad Gateway` (página de error generada por Nginx, `Server: nginx/1.24.0`).
- **Diagnóstico**:
  - Comandos usados: `nc -vz 127.0.0.1 80`, `ss -tlnp | grep ":80"`, `sudo tail -n 20 /var/log/nginx/error.log`, `ss -tlnp | grep ":8000"`, `sudo systemctl status devops-journey`
  - Evidencia clave:
    1. `nc -vz 127.0.0.1 80` → `succeeded` y `ss -tlnp` confirmaron Nginx sano, escuchando y aceptando conexiones — descartando problema de red hacia el proxy.
    2. `error.log` de Nginx mostró el mensaje exacto: `connect() failed (111: Connection refused) while connecting to upstream ... upstream: "http://127.0.0.1:8000/health"` — código `111` = `ECONNREFUSED` a nivel de sistema operativo.
    3. `ss -tlnp | grep ":8000"` no devolvió resultados — ningún proceso escuchando en el puerto del backend.
    4. `systemctl status devops-journey` confirmó `inactive (dead)`, proceso detenido con `signal=TERM`.
- **Causa raíz**: El servicio backend (Uvicorn/FastAPI) estaba detenido. Nginx funcionaba correctamente como proxy, pero al no poder establecer conexión TCP con su upstream, generó y devolvió un 502 al cliente por su propia cuenta.
- **Solución aplicada**:
  - Cambio realizado: `sudo systemctl start devops-journey`
  - Comando de verificación: `curl http://localhost:80/health` → `200 OK`, `{"status":"healthy"}`
- **Prevención**: Configurar `Restart=on-failure` en el `.service` (ya implementado desde Fase 2) reduce el riesgo de que el backend quede caído por un crash; para detenciones manuales/deploys, considerar un healthcheck que alerte si el backend no responde antes de que un usuario lo note.
- **Aprendizaje clave**: Un 502 siempre lo genera la capa intermedia (proxy/gateway), nunca el backend — el backend ni siquiera llega a enterarse de la petición. El término técnico que usa Nginx para el backend es "upstream", y el código de sistema `111` corresponde exactamente a `ECONNREFUSED`, el mismo error ya visto en incidentes anteriores, ahora observado desde la perspectiva de Nginx actuando como cliente.
- **Tiempo estimado de resolución**: 15 minutos

---

### Incidente #006 – Contenedor no puede conectar a PostgreSQL del host (3 causas encadenadas)

- **Fase**: v0.4 — Contenedores (Docker)
- **Categoría**: 🟡 Configuración / 🔴 Red / 🔵 Seguridad (identidad/autenticación)
- **Síntoma**: `curl http://localhost:8001/db-check` contra el contenedor devuelve `500 Internal Server Error`, con distintos mensajes en cada etapa del diagnóstico.
- **Diagnóstico y causas (en cadena, resueltas una por una):**

  **Causa 1 — `DATABASE_URL` llega como `None`:**
  - Evidencia: `docker logs devops-journey-app` mostró traceback completo terminando en `sqlalchemy.exc.ArgumentError: Expected string or URL object, got None`.
  - Origen: `.env` fue correctamente excluido del contexto de build vía `.dockerignore` (buena práctica de seguridad), pero eso significa que no existe dentro del contenedor — `load_dotenv()` no encuentra nada que cargar.
  - Fix: inyectar la variable en runtime con `docker run -e DATABASE_URL=...`, no dentro de la imagen.

  **Causa 2 — `Connection refused` hacia `host.docker.internal`:**
  - Evidencia: `psycopg2.OperationalError: connection ... (172.17.0.1), port 5432 failed: Connection refused`.
  - Origen: cada contenedor tiene su propio network namespace; `127.0.0.1` dentro del contenedor no apunta al host. `host.docker.internal` resuelve correctamente al host, pero PostgreSQL solo escuchaba en `127.0.0.1` (confirmado con `ss -tlnp | grep 5432`), invisible desde la interfaz bridge de Docker (`172.17.0.1`).
  - Fix: `listen_addresses = '*'` en `postgresql.conf` + `sudo systemctl restart postgresql@16-main`.

  **Causa 3 — `no pg_hba.conf entry for host "172.17.0.2"`:**
  - Evidencia: Postgres rechazó explícitamente indicando host de origen, usuario y base de datos que no coincidían con ninguna regla.
  - Origen doble: faltaba una regla de autorización para el rango de red de Docker en `pg_hba.conf`, y además la connection string usaba un usuario con typo (`devops_j` en vez de `devops_app`, que no existe como rol).
  - Fix: regla `host devops_journey devops_app 172.17.0.0/16 scram-sha-256` en `pg_hba.conf` + corrección del usuario en `DATABASE_URL`.

- **Causa raíz consolidada**: la combinación de (a) separación correcta pero incompleta entre imagen y configuración runtime, (b) PostgreSQL configurado por defecto para aceptar únicamente conexiones locales, y (c) un error de tipeo en el usuario de la connection string.
- **Solución aplicada**: variable de entorno inyectada vía `-e`, `listen_addresses = '*'`, regla en `pg_hba.conf` para la red bridge de Docker, y corrección del usuario en `DATABASE_URL`.
- **Comando de verificación**: `curl -i http://localhost:8001/db-check` → `200 OK`, `{"database":"connected"}`
- **Prevención**: documentar en `.env.example` el uso de `host.docker.internal` para desarrollo local con Docker; en Fase 5 (Docker Compose), Postgres pasará a ser otro contenedor en la misma red definida por Compose, eliminando la necesidad de `host.docker.internal` y de abrir Postgres a toda la red bridge.
- **Aprendizaje clave**: un incidente real rara vez tiene una sola causa. Diagnosticar de abajo hacia arriba (¿llega la variable? → ¿hay red? → ¿hay autorización?) evita "arreglar" una capa superior mientras la inferior sigue rota, lo cual habría hecho parecer que la corrección no funcionaba.
- **Tiempo estimado de resolución**: 40 minutos

---

## Pendientes de catálogo (para incidentes futuros, por fase)

Banco de incidentes a provocar en fases próximas — no son un calendario fijo, se resuelven en el orden natural en que la infraestructura los haga relevantes:

- **Fase 4 (Docker, continuación):** OOMKill (límite de memoria), conflicto de puertos, tag de imagen incorrecto
- **Fase 5 (PostgreSQL/Compose):** 502 por red interna de Docker Compose mal configurada, migración fallida (`relation already exists`), healthcheck mal calibrado
- **Fase 6 (CI/CD):** build fallido por dependencia rota, deploy que no actualiza por uso de tag `latest`
- **Fase 7 (AWS):** disco lleno en EC2, Security Group bloqueando tráfico, certificado TLS expirado, CPU throttling en instancia tipo burst

---

## Estadísticas (se actualiza al cierre de cada fase)

| Categoría | Incidentes resueltos | Tiempo promedio |
|---|---|---|
| 🔴 Red | 4 | ~12 min |
| 🟡 Configuración | 4 | ~19 min |
| 🟢 Despliegue | 2 | ~12 min |
| 🔵 Seguridad | 1 | 40 min (compartido con Red/Config en #006) |
| 🟣 Recursos | 0 | — |
