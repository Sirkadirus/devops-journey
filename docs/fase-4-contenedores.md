# Fase 4 — Contenedores

**Estado:** ✅ Cerrada (extendida)
**Tag:** `v0.4` → `v0.4.1`
**Última actualización:** 2026-09-07

---

## Objetivo de la fase

Migrar la aplicación de un proceso corriendo directo sobre Linux (gestionado por systemd) a una arquitectura contenerizada: primero un solo contenedor manual con Docker, después una orquestación completa de dos servicios (API + PostgreSQL) con Docker Compose, en su propia red aislada con persistencia de datos.

**Extensión post-cierre (v0.4.1):** al revisar el resultado inicial, se detectaron dos gaps reales antes de avanzar a AWS: Nginx seguía corriendo solo de forma manual (fuera de Compose, contra el servicio systemd), y ningún contenedor tenía política de reinicio ante un reboot del host o del daemon de Docker. Ambos se cerraron para dejar un único stack contenerizado, coherente, listo para trasladarse a una instancia EC2.

---

## Checklist de conceptos

| Concepto | Teoría | Implementación | Diagnóstico |
|---|---|---|---|
| Imagen vs. contenedor, Dockerfile | ✅ | ✅ (`Dockerfile`, `devops-journey:v0.1`) | ✅ (`docker images`, `docker ps -a`) |
| Arquitectura cliente-daemon de Docker | ✅ | ✅ (grupo `docker`, socket) | ✅ (`docker run hello-world`) |
| Layer caching | ✅ | ✅ (orden `COPY requirements` antes de `COPY app/`) | ✅ (tiempos de build comparados) |
| Redes de Docker (`bridge` vs. user-defined) | ✅ | ✅ (`docker network create`) | ✅ (`ping` por nombre entre contenedores) |
| Volúmenes y persistencia | ✅ | ✅ (`docker volume create`) | ✅ (prueba de pérdida de datos sin volumen vs. con volumen) |
| Comunicación entre host y contenedor | ✅ | ✅ (`host.docker.internal`) | ✅ (Incidente #006) |
| Docker Compose: servicios, redes y volúmenes declarativos | ✅ | ✅ (`docker-compose.yml`) | ✅ |
| `depends_on` vs. `healthcheck` / `condition: service_healthy` | ✅ | ✅ | ✅ (Incidente #007) |
| Nginx como servicio dockerizado (bind mount de config) | ✅ | ✅ (`nginx/devops-journey.conf`) | ✅ (Incidente #008) |
| Política de reinicio de contenedores (`restart:`) | ✅ | ✅ (`unless-stopped` en los 3 servicios) | ✅ (simulación de `systemctl restart docker`) |

---

## Módulo — Docker (contenedor único)

### Instalación
Se instaló Docker Engine desde el repositorio oficial (no `docker.io` de Ubuntu), incluyendo la verificación de la clave GPG del repositorio — mismo principio de cadena de confianza ya visto con certificados TLS en Fase 1.

### Permisos — socket de Docker
Se diagnosticó `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock` aplicando el mismo modelo de permisos de Fase 2: el socket pertenece al grupo `docker` (`srw-rw----`), y el usuario no pertenecía a ese grupo. Resuelto con `usermod -aG docker $USER`.

### El primer Dockerfile
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
Se ordenó deliberadamente `COPY requirements.txt` + `RUN pip install` **antes** de `COPY app/`, para que Docker pueda reutilizar la capa de dependencias (la más lenta, ~16s) cuando solo cambia el código de la aplicación — confirmado comparando tiempos de build.

Se diagnosticaron y corrigieron dos errores de sintaxis reales durante la escritura del archivo: un typo de nombre de archivo (`requirement.txt` vs. el nombre real del proyecto, que resultó ser `requeriments.txt` — corregido a `requirements.txt` con `git mv`) y comillas mal balanceadas en la instrucción `CMD`.

### `.dockerignore`
Excluye `venv/`, `__pycache__/`, `.env`, `.git/`, `docs/`, `runbook.md`, `learning/` — mismo principio de seguridad que `.gitignore` aplicado al contexto de build: nunca hornear secretos ni artefactos innecesarios dentro de una imagen.

### Incidente #006 (ver `runbook.md`)
Al correr el primer contenedor con `docker run -p 8001:8000`, se encontraron y resolvieron tres causas encadenadas para lograr que el contenedor conectara a PostgreSQL (corriendo en el host, no en Docker todavía):
1. `DATABASE_URL` llegaba como `None` — `.env` correctamente excluido de la imagen, pero no inyectado en runtime.
2. `Connection refused` hacia `host.docker.internal` — Postgres solo escuchaba en `127.0.0.1`, invisible desde la red de Docker.
3. `no pg_hba.conf entry` — faltaba regla de autorización para la red de Docker, más un typo de usuario en la connection string.

---

## Módulo — Redes de Docker (previo a Compose)

Se investigaron las redes por defecto (`bridge`, `host`, `none`) con `docker network ls`, y se creó una red propia definida por el usuario (`devops-net`) para comprobar la diferencia clave: las redes user-defined tienen DNS interno automático entre contenedores, mientras que la red `bridge` default no.

**Prueba realizada:** dos contenedores (`web-test` y un `alpine` temporal) en la misma red `devops-net` se resolvieron por nombre (`ping web-test`) sin necesidad de conocer IPs — confirmando el mecanismo que después Compose usa automáticamente entre `app` y `db`.

---

## Módulo — Volúmenes de Docker (previo a Compose)

Se demostró experimentalmente la naturaleza efímera del sistema de archivos de un contenedor:
1. Se corrió Postgres **sin volumen**, se insertó una fila de prueba, se destruyó el contenedor y se recreó → la tabla no existía (`relation "prueba" does not exist`).
2. Se repitió el experimento **con un volumen nombrado** (`-v pgdata-test:/var/lib/postgresql/data`) → el dato sobrevivió íntegro a la destrucción y recreación del contenedor.

Esto estableció, por experiencia directa y no solo por lectura, por qué toda base de datos en Docker requiere un volumen declarado.

---

## Módulo — Docker Compose

### `docker-compose.yml` (versión final, tras v0.4.1)
```yaml
services:
  db:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: devops_j
      POSTGRES_PASSWORD: clave
      POSTGRES_DB: devops_journey
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U devops_j -d devops_journey"]
      interval: 5s
      timeout: 5s
      retries: 5

  app:
    build: .
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://devops_j:clave@db:5432/devops_journey
    depends_on:
      db:
        condition: service_healthy

  nginx:
    image: nginx:1.24-alpine
    restart: unless-stopped
    volumes:
      - ./nginx/devops-journey.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "8080:80"
    depends_on:
      - app

volumes:
  pgdata:
```

### Decisiones de diseño relevantes
- **`db` no expone puertos al host** (`ports:` fue evaluado y descartado deliberadamente): la comunicación `app`↔`db` ocurre puertas adentro de la red que crea Compose, sin necesidad de exponer Postgres al host. Confirmado con `docker compose ps`, donde `db` no muestra mapeo `0.0.0.0:*->5432`, a diferencia de `app`.
- **`db` usa el hostname `db`** en `DATABASE_URL`, resuelto automáticamente por el DNS interno de la red de Compose (`devops-journey_default`) — elimina por completo la necesidad de `host.docker.internal` usada en el módulo anterior.
- **Volumen `pgdata`** gestionado por Compose (nombrado `devops-journey_pgdata`), persistiendo los datos de Postgres independientemente del ciclo de vida del contenedor `db`.
- **`app` dejó de exponer `ports:` al host** una vez agregado `nginx`: Nginx pasó a ser la única puerta de entrada del stack, mismo principio de menor superficie expuesta ya aplicado a `db`.

### Incidente #007 (ver `runbook.md`) — Race condition
Se detectó, leyendo logs de una corrida en primer plano (`docker compose up --build` sin `-d`), que `app` arrancaba (`Uvicorn running...`) **antes** de que `db` completara su inicialización interna de PostgreSQL. `depends_on` en su forma simple solo garantiza orden de arranque de contenedores, no disponibilidad real del servicio interno.

**Fix:** se agregó `healthcheck` con `pg_isready` a `db`, y se cambió `depends_on` a la forma extendida `condition: service_healthy` en `app`. Verificado repitiendo la prueba desde cero (`docker compose down -v && docker compose up --build`): el log mostró `Container devops-journey-db-1 Healthy` antes de que `app` arrancara, y `curl` respondió `200 OK` en el primer intento sin depender del timing.

---

## Módulo — Nginx dockerizado (v0.4.1)

### Motivación
Hasta este punto convivían dos arquitecturas paralelas: Nginx manual (Fase 3, contra el servicio systemd en el puerto 8000 del host) y el stack de Compose (API + Postgres, expuesto directo en el puerto 8002). Antes de AWS se decidió unificar en un único stack completamente contenerizado.

### Configuración (`nginx/devops-journey.conf`)
```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://app:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
Única diferencia real respecto a la config manual de Fase 3: `proxy_pass http://app:8000` (nombre de servicio, resuelto por el DNS interno de Compose) en lugar de `http://127.0.0.1:8000`.

El contenedor usa la imagen oficial `nginx:1.24-alpine` sin necesidad de construir una imagen propia — la configuración se inyecta vía **bind mount** (`./nginx/devops-journey.conf:/etc/nginx/conf.d/default.conf:ro`), a diferencia del volumen nombrado usado para los datos de Postgres. Se estableció la distinción entre ambos tipos: bind mount para archivos de configuración versionados en Git y editados directamente por el desarrollador; volumen nombrado para datos generados en runtime por la propia aplicación.

### Incidente #008 (ver `runbook.md`) — Bind mount montado como directorio fantasma
El archivo de configuración se creó por error en la raíz del proyecto en lugar de dentro de `nginx/`. Docker, al no encontrar el archivo en la ruta esperada durante un intento previo, creó automáticamente un directorio vacío (propiedad de `root`) en su lugar — lo cual produjo un error de mount confuso (`not a directory`) en el intento siguiente. Diagnosticado con `ls -la`, comparando dueño y tipo de archivo entre la ruta esperada y la ruta real.

### Incidente #009 (ver `runbook.md`) — 405 por confundir `curl -I` con `curl -i`
Durante la verificación final, `curl -I` (petición `HEAD`) devolvió `405 Method Not Allowed` en un endpoint sano, porque `/health` solo tiene handler para `GET`. El propio header `allow: GET` de la respuesta permitió descartar rápidamente un problema de infraestructura y aislar el error al comando usado, no al stack.

---

## Módulo — Política de reinicio de contenedores (v0.4.1)

### Motivación
Se detectó que, aunque el daemon de Docker estaba `enabled` (arranca solo al bootear el sistema), ningún contenedor tenía definida una política de reinicio — un reboot de la máquina o un reinicio del propio daemon dejaba el stack completo detenido hasta una intervención manual.

### Implementación
Se agregó `restart: unless-stopped` a los tres servicios (`db`, `app`, `nginx`). Se distinguieron las cuatro políticas disponibles (`no`, `always`, `unless-stopped`, `on-failure`) y se eligió `unless-stopped` por ser la más adecuada para servicios de larga duración que deben sobrevivir a crashes y reinicios del host, sin pelear contra una detención manual intencional (`docker compose down`).

### Verificación
Se simuló un reinicio del daemon sin reiniciar la máquina completa: `sudo systemctl restart docker`, seguido de `docker compose ps` — los tres contenedores volvieron a estado `Up` automáticamente, sin intervención manual adicional.

---

## EN/ES — Términos clave

| Inglés | Español |
|---|---|
| Image / Container | Imagen / Contenedor |
| Layer (Docker) | Capa (unidad inmutable de una imagen) |
| Layer caching | Caché de capas (reutilización de capas ya construidas) |
| Build context | Contexto de build (directorio que Docker usa para resolver `COPY`, etc.) |
| Daemon (`dockerd`) | Proceso servidor que gestiona contenedores, imágenes y redes |
| Socket activation | Activación por socket (arrancar un proceso al primer uso, no al boot) |
| Bridge network | Red tipo puente — red virtual aislada, con o sin DNS interno según sea default o user-defined |
| Network namespace | Espacio de nombres de red — aislamiento de red por proceso/contenedor a nivel de kernel |
| Named volume | Volumen nombrado — almacenamiento persistente gestionado por Docker, independiente del contenedor |
| Ephemeral filesystem | Sistema de archivos efímero (el de un contenedor, sin volumen) |
| Healthcheck | Verificación de salud — comando periódico para confirmar que un servicio está realmente operativo |
| Race condition | Condición de carrera — resultado dependiente del orden/tiempo relativo de eventos concurrentes |
| Single responsibility container | Principio de un contenedor, una responsabilidad |
| Bind mount | Montaje directo de un archivo/carpeta del host dentro del contenedor (a diferencia de un volumen gestionado por Docker) |
| Restart policy | Política de reinicio (`no`, `always`, `unless-stopped`, `on-failure`) |
| Phantom directory | Directorio fantasma — creado automáticamente por Docker cuando un bind mount no encuentra el archivo esperado |

---

## Aprendizajes clave

- Un contenedor comparte el kernel del host (a diferencia de una VM) — más liviano, usa los mismos mecanismos (`cgroups`, `namespaces`) ya vistos en systemd, aplicados ahora también al aislamiento de red.
- El orden de las instrucciones en un Dockerfile importa: poner lo que cambia con menos frecuencia (dependencias) antes que lo que cambia seguido (código) maximiza el aprovechamiento de caché.
- `.dockerignore` cumple para el contexto de build el mismo rol que `.gitignore` para el repositorio: nunca secretos, nunca artefactos de entorno local dentro de la imagen.
- Cada contenedor tiene su propio namespace de red; `127.0.0.1` dentro de un contenedor nunca apunta al host — para eso existe `host.docker.internal`, o mejor aún, una red compartida de Compose cuando ambos servicios son contenedores.
- El sistema de archivos de un contenedor es efímero por defecto; solo los volúmenes sobreviven a la destrucción y recreación del contenedor.
- `depends_on` ordena arranque, no garantiza disponibilidad — para dependencias reales entre servicios (especialmente bases de datos) es necesario `healthcheck` + `condition: service_healthy`.
- Un incidente real puede tener múltiples causas encadenadas (Incidente #006: configuración → red → autenticación); diagnosticar de abajo hacia arriba evita conclusiones prematuras.
- Mantener dos arquitecturas paralelas para la misma funcionalidad (Nginx manual vs. Compose) genera deuda técnica silenciosa; conviene unificar antes de avanzar a la fase siguiente, no arrastrar ambas indefinidamente.
- Un daemon `enabled` en systemd no implica que los contenedores que gestiona tengan política de reinicio propia — son dos niveles independientes que deben configurarse por separado.
- Docker puede crear un directorio vacío automáticamente cuando un bind mount no encuentra el archivo esperado, lo cual puede producir errores confusos en intentos posteriores si no se limpia ese directorio fantasma primero.
- No todo código de error HTTP indica una falla de infraestructura — los propios headers de la respuesta (como `allow` en un `405`) suelen contener la pista para descartar rápidamente el resto del stack.

---

## Commits de la fase

```
feat(docker): agrega Dockerfile con build multi-capa optimizado (python:3.12-slim)
docs(runbook): documenta incidente 006 - conexión Docker a PostgreSQL (3 causas encadenadas)
feat(compose): agrega docker-compose.yml con servicios app y db en red y volumen dedicados
fix(compose): agrega healthcheck a db y condition service_healthy en app - corrige race condition
docs(runbook): documenta incidente 007 - race condition en Docker Compose
docs: cierra Fase 4 (Contenedores) - Docker y Docker Compose implementados
feat(compose): agrega nginx como reverse proxy dockerizado y restart:unless-stopped en todos los servicios
docs(runbook): documenta incidentes 008 y 009 - bind mount fantasma y 405 por curl -I
docs: actualiza Fase 4 (v0.4.1) - Nginx dockerizado y restart policy en todos los servicios
```

**Tag:** `v0.4` → `v0.4.1`