# Runbook — DevOps Journey

Colección de incidentes provocados y resueltos durante la construcción del proyecto, documentados en formato de runbook operativo. Cada entrada sigue una estructura estándar: síntoma, diagnóstico, causa raíz, solución y prevención.

Este documento se actualiza al cierre de cada incidente relevante, en paralelo a las bitácoras de fase (`docs/fase-N-*.md`), que documentan el *aprendizaje*. Este archivo documenta la *operación*: qué hacer si el síntoma vuelve a aparecer.

**Nota de credenciales:** a partir del incidente #007, el usuario/base de PostgreSQL usado en ejercicios y en `docker-compose.yml` es `devops_j` / `devops_journey` (antes `devops_app`, usado en incidentes #006 y anteriores contra el Postgres del host).

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
  - Origen doble: faltaba una regla de autorización para el rango de red de Docker en `pg_hba.conf`, y además la connection string usaba un usuario con typo (`devops_j` en vez de `devops_app`, que no existía como rol en ese momento).
  - Fix: regla `host devops_journey devops_app 172.17.0.0/16 scram-sha-256` en `pg_hba.conf` + corrección del usuario en `DATABASE_URL`.

- **Causa raíz consolidada**: la combinación de (a) separación correcta pero incompleta entre imagen y configuración runtime, (b) PostgreSQL configurado por defecto para aceptar únicamente conexiones locales, y (c) un error de tipeo en el usuario de la connection string.
- **Solución aplicada**: variable de entorno inyectada vía `-e`, `listen_addresses = '*'`, regla en `pg_hba.conf` para la red bridge de Docker, y corrección del usuario en `DATABASE_URL`.
- **Comando de verificación**: `curl -i http://localhost:8001/db-check` → `200 OK`, `{"database":"connected"}`
- **Prevención**: documentar en `.env.example` el uso de `host.docker.internal` para desarrollo local con Docker; en Docker Compose (Incidente #007), Postgres pasó a ser otro contenedor en la misma red, eliminando la necesidad de `host.docker.internal` y de abrir Postgres a toda la red bridge.
- **Aprendizaje clave**: un incidente real rara vez tiene una sola causa. Diagnosticar de abajo hacia arriba (¿llega la variable? → ¿hay red? → ¿hay autorización?) evita "arreglar" una capa superior mientras la inferior sigue rota, lo cual habría hecho parecer que la corrección no funcionaba.
- **Tiempo estimado de resolución**: 40 minutos

---

### Incidente #007 – Race condition entre `app` y `db` en Docker Compose

- **Fase**: v0.4 — Contenedores (Docker Compose)
- **Categoría**: 🟢 Despliegue / 🟡 Configuración
- **Síntoma**: Al levantar el stack desde cero (`docker compose up`, incluyendo un volumen recién creado), a veces la API responde `500`/`Connection refused` en `/db-check` justo después de arrancar, y a veces no — comportamiento intermitente.
- **Diagnóstico**:
  - Comandos usados: `docker compose down -v` (para forzar reinicialización completa de Postgres), `docker compose up --build` (sin `-d`, para ver logs en vivo intercalados de ambos servicios)
  - Evidencia clave: en los logs, `app-1 | Uvicorn running on http://0.0.0.0:8000` apareció **antes** de que `db-1` completara su ciclo de inicialización (`database system is ready to accept connections` llegó varias líneas después). Un `curl` disparado en ese punto exacto habría fallado.
- **Causa raíz**: `depends_on: - db` (forma simple) solo garantiza el **orden de arranque de los contenedores**, no espera a que la aplicación interna (Postgres) esté realmente lista para aceptar conexiones. La imagen oficial de Postgres, además, ejecuta un ciclo interno de init → shutdown → restart en su primer arranque, extendiendo la ventana de vulnerabilidad.
- **Solución aplicada**:
  - Cambio realizado: se agregó un `healthcheck` al servicio `db` usando `pg_isready`, y se cambió `depends_on` a la forma extendida con `condition: service_healthy` en `app`.
  - Comando de verificación: `docker compose down -v && docker compose up --build` → en los logs, `Container devops-journey-db-1 Healthy` aparece antes de que `app-1` arranque; `curl -i http://localhost:8002/db-check` responde `200 OK` en el primer intento, sin importar el timing.
- **Prevención**: cualquier servicio con dependencia de otro que tenga un arranque no instantáneo (bases de datos, colas de mensajes) debe usar `healthcheck` + `condition: service_healthy`, nunca confiar en `depends_on` simple para garantizar disponibilidad real.
- **Aprendizaje clave**: `depends_on` ordena procesos, no garantiza disponibilidad de servicio. Es una distinción sutil pero crítica — el mismo tipo de error puede pasar desapercibido en desarrollo (por timing favorable, como ocurrió en la primera corrida) y aparecer de forma intermitente en producción bajo distinta carga o velocidad de hardware.
- **Tiempo estimado de resolución**: 25 minutos

---

### Incidente #008 – Bind mount de Nginx falla por directorio fantasma creado por Docker

- **Fase**: v0.4 — Contenedores (Docker Compose, Nginx dockerizado)
- **Categoría**: 🟡 Configuración
- **Síntoma**: `docker compose up -d --build` falla al arrancar el contenedor `nginx` con el error `mount ... not a directory: Are you trying to mount a directory onto a file (or vice-versa)?`
- **Diagnóstico**:
  - Comandos usados: `ls -la` en la raíz del proyecto y dentro de la carpeta `nginx/`
  - Evidencia clave: `nginx/` aparecía como directorio con dueño `root root` (no `j j` como el resto de los archivos del proyecto), y el archivo de configuración real (`devops-journey.conf`, dueño `j j`) estaba en la raíz del proyecto, no dentro de `nginx/`.
- **Causa raíz**: el archivo de configuración se creó en la ubicación incorrecta (raíz del proyecto en lugar de dentro de `nginx/`). Al no encontrar un archivo en la ruta declarada en el bind mount, Docker creó automáticamente un directorio vacío en su lugar durante un intento de arranque previo — ese directorio fantasma (propiedad de root, creado por el daemon) quedó ocupando la ruta esperada.
- **Solución aplicada**:
  - Cambio realizado: `sudo rmdir nginx` (eliminar el directorio fantasma) + `mkdir nginx` + mover el archivo real a `nginx/devops-journey.conf`.
  - Comando de verificación: `docker compose up -d --build` → los tres contenedores (`db`, `app`, `nginx`) arrancan correctamente; `docker compose ps` los muestra `Up`.
- **Prevención**: verificar con `ls -la` que un archivo de bind mount existe y es del tipo correcto (archivo, no directorio) *antes* de correr `docker compose up`, especialmente después de un intento fallido previo.
- **Aprendizaje clave**: Docker no valida que el lado del host de un bind mount sea del tipo correcto antes de intentar montarlo — si no existe, puede crear un directorio vacío automáticamente en su lugar, lo cual produce un error confuso en el intento siguiente si luego se coloca ahí un archivo real sin limpiar primero el directorio fantasma.
- **Tiempo estimado de resolución**: 15 minutos

---

### Incidente #009 – 405 Method Not Allowed por confundir `curl -I` con `curl -i`

- **Fase**: v0.4 — Contenedores (verificación post-Nginx)
- **Categoría**: 🟡 Configuración (error de comando, no de infraestructura)
- **Síntoma**: `curl -I http://localhost:8080/health` devuelve `405 Method Not Allowed` a pesar de que el stack completo (Nginx + app + db) está sano y `Up`.
- **Diagnóstico**:
  - Comandos usados: lectura del header de respuesta `allow: GET`
  - Evidencia clave: el propio servidor confirmó que `GET` sí está permitido en esa ruta — la petición realizada no fue `GET`.
- **Causa raíz**: `curl -I` (mayúscula) envía una petición `HEAD`, no `GET`. El endpoint `/health` en FastAPI solo tiene un handler registrado para `GET` (`@app.get(...)`), por lo que cualquier otro método recibe `405`.
- **Solución aplicada**:
  - Cambio realizado: ninguno en la infraestructura — se corrigió el comando a `curl -i` (minúscula), que sí realiza una petición `GET` e incluye los headers en la salida.
  - Comando de verificación: `curl -i http://localhost:8080/health` → `200 OK`, `{"status":"healthy"}`
- **Prevención**: recordar la distinción `-i` (incluir headers, método GET) vs. `-I` (petición HEAD únicamente) al construir comandos de diagnóstico con curl.
- **Aprendizaje clave**: un código de error HTTP no siempre indica una falla de infraestructura — el propio header `allow` de una respuesta `405` suele contener la pista exacta para descartar rápidamente el resto del stack y enfocarse en el método usado en la petición.
- **Tiempo estimado de resolución**: 5 minutos

---

### Incidente #010 – Credenciales hardcodeadas en docker-compose.yml versionado

- **Fase**: v0.5 — Cloud (AWS), previo a desplegar en EC2
- **Categoría**: 🔵 Seguridad
- **Síntoma**: ninguno funcional — el stack corría perfectamente. El problema se detectó por revisión propia antes de subir el proyecto a un servidor real: las credenciales de PostgreSQL (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`) y la `DATABASE_URL` completa estaban escritas en texto plano dentro de `docker-compose.yml`, archivo versionado y público en GitHub.
- **Diagnóstico**: revisión manual del archivo antes de un despliegue a producción (EC2). No requirió comandos de diagnóstico — el hallazgo fue de revisión de buenas prácticas, no de un fallo técnico.
- **Causa raíz**: al escribir el `docker-compose.yml` por primera vez (Fase 4), las credenciales se declararon directamente como valores literales en lugar de referenciarlas desde variables de entorno, a diferencia de `app/db.py`, que sí usaba `.env` correctamente desde Fase 3.
- **Solución aplicada**:
  - Cambio realizado: se reemplazaron los valores literales por variables `${DB_USER}`, `${DB_PASSWORD}`, `${DB_NAME}`, aprovechando que Docker Compose carga automáticamente un archivo `.env` en el mismo directorio sin configuración adicional. `.env` (con los valores reales) permanece excluido de Git; `.env.example` (con placeholders) se actualizó y se versiona normalmente.
  - Comando de verificación: `docker compose down && docker compose up -d --build` seguido de `curl -i http://localhost:8080/health` → `200 OK`, confirmando que Compose sigue resolviendo las variables correctamente.
- **Prevención**: al escribir cualquier archivo que vaya a versionarse en Git, revisar explícitamente si contiene credenciales, tokens o secretos antes del primer commit — no asumir que "es solo para desarrollo local" es excusa suficiente, dado que el repositorio es público.
- **Aprendizaje clave**: `.gitignore`/`.dockerignore` protegen archivos completos (como `.env`), pero no evitan que un secreto se filtre si se escribe directamente dentro de un archivo que sí se versiona. La disciplina de "nunca secretos en código" debe aplicarse activamente en cada archivo nuevo, no solo delegarse a la exclusión de archivos completos.
- **Tiempo estimado de resolución**: 15 minutos

---

## Pendientes de catálogo (para incidentes futuros, por fase)

Banco de incidentes a provocar en fases próximas — no son un calendario fijo, se resuelven en el orden natural en que la infraestructura los haga relevantes:

- **Fase 4 (Docker, continuación):** OOMKill (límite de memoria), conflicto de puertos, tag de imagen incorrecto
- **Fase 6 (CI/CD):** build fallido por dependencia rota, deploy que no actualiza por uso de tag `latest`
- **Fase 7 (AWS):** disco lleno en EC2, Security Group bloqueando tráfico, certificado TLS expirado, CPU throttling en instancia tipo burst

---

## Estadísticas (se actualiza al cierre de cada fase)

| Categoría | Incidentes resueltos | Tiempo promedio |
|---|---|---|
| 🔴 Red | 4 | ~12 min |
| 🟡 Configuración | 7 | ~17 min |
| 🟢 Despliegue | 3 | ~16 min |
| 🔵 Seguridad | 2 | ~27 min |
| 🟣 Recursos | 0 | — |

## Incidente #011 — Security Group bloqueando tráfico HTTP (provocado)

**Síntoma:**
```
curl: (28) Failed to connect to <IP> port 80 after 133780 ms: Couldn't connect to server
```

**Diagnóstico:**
Se eliminó intencionalmente la regla de entrada del puerto 80 (HTTP) en el Security Group de la instancia EC2 para observar el comportamiento exacto de un bloqueo a nivel de firewall de AWS.

A diferencia de un servicio caído (que responde con TCP RST de forma instantánea) o un backend inalcanzable detrás de un reverse proxy (HTTP 502 instantáneo), un bloqueo de Security Group produce un **timeout silencioso**: el paquete se descarta en el borde de red de AWS sin ninguna respuesta al cliente, que solo falla al agotar su propio timeout de conexión.

**Root cause:**
Ausencia de regla ALLOW para el puerto 80/TCP en el Security Group asociado a la instancia.

**Solución:**
Restaurar la regla de entrada: Type HTTP, Port 80, Source según corresponda (0.0.0.0/0 para acceso público).

**Prevención:**
- Documentar los Security Groups como código (futuro: Terraform) para evitar cambios manuales no versionados.
- Ante un timeout (no un error HTTP), sospechar primero de capas de red (Security Group, NACL, route table) antes de revisar la aplicación.

**Método de diagnóstico aplicado:**
`curl` externo (timeout) contrastado con `ss -tlnp` interno (proceso en LISTEN confirmado) → aísla el problema en la capa de red de AWS, no en la instancia.

---

## Incidente #012 — Subnet sin ruta al Internet Gateway (provocado)

**Síntoma:**
Instancia EC2 lanzada en una subnet nueva, con IP pública asignada, completamente inalcanzable desde fuera — tanto `curl` como `ping` fallan por timeout, sin respuesta de ningún tipo.

**Diagnóstico:**
Se creó deliberadamente una subnet nueva (`172.31.32.0/20`) dentro de la misma VPC de producción, asociada a una route table que solo contenía la ruta local automática de la VPC (sin entrada `0.0.0.0/0 → igw-xxxxx`). Se lanzó una instancia de prueba en esa subnet con auto-asignación de IP pública habilitada.

A pesar de tener IP pública asignada, la instancia resultó inalcanzable: sin la ruta hacia el Internet Gateway en la route table de la subnet, el tráfico externo no tiene forma de completar el camino de ida y vuelta hacia la instancia, independientemente de si esta tiene o no una IP pública asociada.

Esto confirma que el estado "pública" de una subnet no es un atributo propio de la subnet, sino un efecto exclusivo de su route table.

**Root cause:**
Route table de la subnet sin entrada de ruta hacia el Internet Gateway (`0.0.0.0/0 → igw-xxxxx`).

**Solución:**
Se terminó (`terminate`) la instancia de prueba una vez confirmado el comportamiento. No se agregó la ruta, ya que la subnet fue creada exclusivamente para este ejercicio de diagnóstico, sin uso productivo.

**Prevención:**
- Al diseñar una arquitectura con subnets públicas y privadas, verificar explícitamente la route table de cada subnet, no asumir el estado por el nombre que se le haya dado.
- Tener IP pública asignada no garantiza alcanzabilidad — son dos configuraciones independientes (IP pública a nivel de instancia, ruta a nivel de subnet).

**Método de diagnóstico aplicado:**
Comparación de comportamiento entre TCP (`curl`) e ICMP (`ping`) contra la misma instancia: ambos fallan por igual, porque el corte ocurre antes de llegar a la subnet (a nivel de VPC/routing), no a nivel de un firewall específico de protocolo o puerto (como sí ocurre con Security Groups).

---

## Incidente #013 — 401 Unauthorized al consultar el Instance Metadata Service (IMDSv1 vs IMDSv2)

**Síntoma:**
```
curl -i http://169.254.169.254/latest/meta-data/iam/security-credentials/
HTTP/1.1 401 Unauthorized
```

**Diagnóstico:**
Al intentar verificar que el IAM Role `ec2-s3-backups-role` estaba correctamente asociado a la instancia, una consulta directa por `GET` al Instance Metadata Service (IMDSv1) devolvió `401 Unauthorized`. La instancia tiene configurado IMDSv2 (default en instancias modernas de EC2), que exige un paso previo de autenticación por token antes de permitir el acceso a los metadatos.

**Root cause:**
Uso del flujo de consulta de IMDSv1 (GET directo) contra una instancia configurada para requerir IMDSv2 (token vía PUT + GET con header).

**Solución:**
```bash
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/
```
Respuesta exitosa: `ec2-s3-backups-role`, confirmando la asociación correcta del Role.

**Prevención:**
- Al trabajar con el Instance Metadata Service en instancias EC2 modernas, asumir IMDSv2 por defecto y usar el flujo de token, no el GET directo heredado de IMDSv1.

**Método de diagnóstico aplicado:**
El `401` (no un timeout ni un error de conexión) indicó que el servicio estaba disponible y respondiendo, pero rechazando la forma de la solicitud — señal de un problema de autenticación/protocolo, no de red ni de permisos IAM del Role en sí.

## Incidente #014 — CrashLoopBackOff por variable de entorno ausente (Kubernetes)

**Síntoma:**
```
kubectl get pods
NAME                                  READY   STATUS   RESTARTS
fastapi-deployment-5c8948d978-7fghp   0/1     Error    3
fastapi-deployment-5c8948d978-smr9v   0/1     Error    3
```
`kubectl describe pod` muestra `State: Waiting — Reason: CrashLoopBackOff`, `Exit Code: 1`, `Environment: <none>`.

**Diagnóstico:**
El manifiesto inicial del Deployment no declaraba ninguna variable de entorno. `app/db.py` lee `DATABASE_URL` con `os.getenv("DATABASE_URL")` (sin default) y llama a `create_engine(DATABASE_URL)` **a nivel de módulo** — fuera de cualquier función. En Python, el código a nivel de módulo se ejecuta inmediatamente al hacer `import`, sin importar si los endpoints que usarían esa conexión están comentados en el archivo de la aplicación. Sin `DATABASE_URL`, `create_engine(None)` produce un error inmediato, y el contenedor termina con `Exit Code 1` apenas arranca — de ahí el `CrashLoopBackOff` (Kubernetes reintenta arrancarlo repetidamente, y vuelve a fallar cada vez).

**Root cause:**
Ausencia de la variable de entorno `DATABASE_URL` (ni como valor único ni como piezas sueltas) en el manifiesto del Deployment. A diferencia de Docker Compose, donde `.env` se inyecta automáticamente, en Kubernetes ninguna variable de entorno es implícita — todo tiene que declararse explícitamente en el manifiesto.

**Solución:**
Se creó un Secret (`DB_USER`, `DB_PASSWORD`) y un ConfigMap (`DB_HOST`, `DB_PORT`, `DB_NAME`), y se modificó `app/db.py` para armar `DATABASE_URL` a partir de esas piezas sueltas cuando la variable completa no está presente, manteniendo compatibilidad con Docker Compose (que sí la pasa completa).

**Prevención:**
- Al portar una aplicación de Docker Compose a Kubernetes, listar explícitamente todas las variables de entorno que el código espera antes de escribir el primer manifiesto de Deployment.
- Un `Environment: <none>` en `describe pod`, combinado con `Exit Code: 1` inmediato, es señal fuerte de configuración faltante — revisar `kubectl logs` para el traceback exacto antes de asumir la causa.

---

## Incidente #015 — Fallo de resolución DNS de `host.docker.internal` desde un Pod en Kind (Linux)

**Síntoma:**
```
curl http://localhost:30080/db-check
{"detail":"database error: (psycopg2.OperationalError) could not translate host name \"host.docker.internal\" to address: Name or service not known..."}
```

**Diagnóstico:**
El ConfigMap apuntaba a `host.docker.internal` como host de la base de datos, siguiendo el patrón habitual para que un contenedor alcance servicios publicados en el host. Ese hostname especial es resuelto automáticamente por Docker Desktop en Mac/Windows, pero su resolución dentro de contenedores anidados (un Pod de Kind, que corre dentro del contenedor del nodo de Kind, que a su vez corre sobre Docker en Linux) no es confiable — el error indica una falla de resolución DNS, no de credenciales ni de conexión rechazada.

**Root cause:**
`host.docker.internal` no resuelve de forma confiable dentro de la cadena de contenedores anidados de Kind sobre Docker en Linux.

**Solución:**
Se reemplazó el hostname por la IP real de la LAN del host (obtenida con `hostname -I`), apuntando al puerto explícitamente publicado por el contenedor de PostgreSQL (`5433`, mapeado al host vía `docker-compose.yml`). Se actualizó el ConfigMap y se forzó la recreación de los Pods con `kubectl rollout restart deployment`, ya que los Pods en ejecución no adoptan cambios de ConfigMap automáticamente.

**Prevención:**
- En entornos Kubernetes locales sobre Linux, preferir la IP real de red del host sobre `host.docker.internal` para alcanzar servicios expuestos fuera del clúster.
- Confirmar siempre el puerto **publicado al host** (no el puerto interno del contenedor de destino) al conectar desde fuera de la red Docker de origen.

---

## Incidente #016 — Service NodePort inaccesible desde el host (configuración por defecto de Kind)

**Síntoma:**
`kubectl get services` mostraba el Service correctamente mapeado (`8000:30080/TCP`), pero `curl http://localhost:30080` fallaba (connection refused) desde el host.

**Diagnóstico:**
El clúster de Kind corre como un contenedor Docker. Por defecto, ese contenedor solo publica al host el puerto del API server de Kubernetes (visible en `kubectl cluster-info`) — no publica automáticamente el rango de puertos usado por Services tipo `NodePort`. `docker ps` sobre el contenedor del control-plane confirmó que únicamente el puerto del API server estaba mapeado.

**Root cause:**
Ausencia de mapeo de puerto (`extraPortMappings`) en la configuración de creación del clúster de Kind.

**Solución:**
Se recreó el clúster (`kind delete cluster` + `kind create cluster`) usando un archivo `kind-config.yaml` con `extraPortMappings` declarando explícitamente el puerto `30080` a publicar al host. Los manifiestos de Kubernetes (Secret, ConfigMap, Deployment, Service) se reaplicaron sin cambios, ya que viven versionados como código independientemente del clúster.

**Prevención:**
- Al planificar acceso externo a un Service `NodePort` en Kind, declarar `extraPortMappings` en la configuración del clúster **antes** de crearlo — no puede agregarse a un clúster ya existente.
- Mantener los manifiestos de Kubernetes en archivos versionados (no solo aplicados ad-hoc) para que recrear un clúster sea una operación de segundos, no una pérdida de trabajo.