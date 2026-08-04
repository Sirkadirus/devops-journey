# Runbook — DevOps Journey

Colección de incidentes provocados y resueltos durante la construcción del proyecto, documentados en formato de runbook operativo. Cada entrada sigue una estructura estándar: síntoma, diagnóstico, causa raíz, solución y prevención.

Este documento se actualiza al cierre de cada incidente relevante, en paralelo a las bitácoras de fase (`docs/fase-N-*.md`), que documentan el *aprendizaje*. Este archivo documenta la *operación*: qué hacer si el síntoma vuelve a aparecer.

---

## Categorías

- 🔴 **Red** — DNS, TCP, puertos, conectividad
- 🟡 **Configuración** — archivos de config no aplicados o incorrectos
- 🟢 **Despliegue** — systemd, procesos, ciclo de vida de servicios
- 🔵 **Recursos** — memoria, disco, CPU (pendiente de incidentes)

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
- **Prevención**: Gestionar el proceso vía systemd con `Restart=on-failure` (ver Incidente #003) en lugar de ejecución manual en terminal.
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
- **Aprendizaje clave**: Esta es la causa más común de `502 Bad Gateway` una vez que se introduce un reverse proxy o contenedores: el backend "funciona" pero solo escucha internamente, invisible para quien lo consulta desde afuera.
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

### Incidente #005 – [En progreso] 502 Bad Gateway con Nginx como reverse proxy

- **Fase**: v0.3 — Servicios (Nginx)
- **Categoría**: 🔴 Red / 🟡 Configuración
- **Síntoma**: _(pendiente — se documentará al provocar y resolver el incidente)_
- **Diagnóstico**: _(pendiente)_
- **Causa raíz**: _(pendiente)_
- **Solución aplicada**: _(pendiente)_
- **Prevención**: _(pendiente)_
- **Tiempo estimado de resolución**: _(pendiente)_

---

## Pendientes de catálogo (para incidentes futuros, por fase)

Banco de incidentes a provocar en fases próximas — no son un calendario fijo, se resuelven en el orden natural en que la infraestructura los haga relevantes:

- **Fase 3 (Nginx):** 504 Gateway Timeout, rotación de logs con `logrotate`
- **Fase 4 (Docker):** `ImagePullBackOff`-equivalente (tag incorrecto), OOMKill (límite de memoria), conflicto de puertos, 502 por red interna de Docker mal configurada
- **Fase 5 (PostgreSQL/Compose):** migración fallida (`relation already exists`), variable `DB_HOST` incorrecta, healthcheck mal calibrado
- **Fase 6 (CI/CD):** build fallido por dependencia rota, deploy que no actualiza por uso de tag `latest`
- **Fase 7 (AWS):** disco lleno en EC2, Security Group bloqueando tráfico, certificado TLS expirado, CPU throttling en instancia tipo burst

---

## Estadísticas (se actualiza al cierre de cada fase)

| Categoría | Incidentes resueltos | Tiempo promedio |
|---|---|---|
| 🔴 Red | 2 | ~7 min |
| 🟡 Configuración | 3 | ~12 min |
| 🟢 Despliegue | 1 | 10 min |
| 🔵 Recursos | 0 | — |
