# Fase 2 — Linux Administration

**Estado:** ✅ Cerrada
**Tag:** `v0.2`
**Última actualización:** 2026-07-30

---

## Objetivo de la fase

Administrar correctamente el sistema Linux que sostiene la aplicación: procesos, usuarios, permisos, systemd, journalctl y bash. La API en sí no cambia — el foco está en operar el entorno que la rodea.

---

## Checklist de conceptos

| Concepto | Teoría | Implementación | Diagnóstico |
|---|---|---|---|
| Procesos (PID, señales) | ✅ | ✅ (`kill` sobre Uvicorn) | ✅ (`ps aux`) |
| Usuarios y permisos | ✅ | ✅ (`scripts/start.sh`) | ✅ (`ls -l`, `chmod`) |
| Sistema de archivos | ✅ | ✅ (fix de ruta relativa en `start.sh`) | ✅ (`ModuleNotFoundError` diagnosticado) |
| systemd / journalctl | ✅ | ✅ (`devops-journey.service`) | ✅ (`systemctl status`, `journalctl -f`, ticket combinado) |
| Bash scripting | ✅ (básico, vía start.sh) | ✅ | ✅ |

---

## Módulo 4 — Procesos

### Conceptos clave
- **PID**: identificador único de proceso. **PPID**: PID del proceso padre.
- Señales: `kill` (sin flags) envía `SIGTERM` — cierre ordenado. `kill -9` envía `SIGKILL` — terminación forzada, sin cleanup. Regla: siempre intentar `SIGTERM` primero.
- `ps aux` puede matchear su propio proceso `grep` al buscarse a sí mismo en el listado. Truco: `grep "[u]vicorn"` evita el auto-match usando una clase de caracteres que no coincide con el patrón literal.

### Diagnóstico realizado
Se identificó el proceso Uvicorn vía `ps aux`, se interpretaron todas sus columnas (USER, PID, %CPU, %MEM, VSZ, RSS, TTY, STAT, START, TIME, COMMAND), y se terminó con `kill <PID>` (SIGTERM), confirmando cierre limpio sin necesidad de `-9`. Se verificó la liberación del puerto con `ss -tulnp`.

---

## Módulo 5 — Usuarios y Permisos

### Conceptos clave
- Estructura de permisos: `-rwxr-xr-x` → tipo de archivo, permisos dueño/grupo/otros.
- Notación numérica: `r=4, w=2, x=1`, sumados por columna (ej. `755` = `rwxr-xr-x`).
- Un archivo sin bit `x` no puede ejecutarse directamente (`./archivo`), aunque sí pueda ser interpretado pasándolo como argumento a su intérprete (`python3 archivo.py`).
- **Git versiona el bit de ejecución.** El modo `100755` en `git ls-files -s` confirma que el permiso viaja con el repositorio — clave para que scripts de despliegue funcionen sin fricción en runners de CI/CD (Fase 6).

### Diagnóstico e implementación
1. `ls -l app/main.py` → `rw-rw-r--`, sin bit de ejecución (correcto: es un módulo importado, no un script standalone).
2. Se intentó `./app/main.py` → `Permission denied`, confirmando la teoría en vivo.
3. Se creó `scripts/start.sh` sin permisos → mismo error `Permission denied`.
4. Se aplicó `chmod 755 scripts/start.sh` → ejecución exitosa, Uvicorn levantado correctamente.
5. Se confirmó el modo `100755` versionado en Git con `git ls-files -s`.

---

## EN/ES — Términos clave

| Inglés | Español |
|---|---|
| Process | Proceso |
| Parent process / child process | Proceso padre / proceso hijo |
| Signal | Señal (mensaje enviado a un proceso) |
| Foreground / background | Primer plano / segundo plano |
| Owner | Dueño (de un archivo) |
| Permission bit | Bit de permiso |
| Execute bit | Bit de ejecución |
| Shebang | Línea `#!/bin/...` que indica el intérprete de un script |
| Runner (CI/CD) | Máquina que ejecuta los pasos de un pipeline |

---

## Módulo 6 — Sistema de archivos

### Conceptos clave
- Jerarquía FHS: `/etc` (configuración), `/var/log` (logs), `/home` (usuarios), `/proc` (filesystem virtual del kernel), `/opt` (software de terceros).
- Ruta absoluta (`/home/j/devops-journey/app/main.py`) vs relativa (`app/main.py`): la relativa depende del directorio de trabajo (`cwd`) desde donde se ejecuta el comando.
- El directorio de trabajo de un proceso es independiente de dónde "vive" físicamente el script que lo lanza.

### Diagnóstico e implementación
Se ejecutó `scripts/start.sh` desde `~` (fuera del proyecto) y se obtuvo `ModuleNotFoundError: No module named 'app'`. Se diagnosticó que el binario de Uvicorn sí se resolvió correctamente (ruta absoluta interna del venv), pero el argumento `app.main:app` se interpretó de forma relativa al `cwd`, que no era la raíz del proyecto.

**Fix aplicado:**
```bash
#!/bin/bash
cd "$(dirname "$0")/.."
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
El script ahora se auto-posiciona en su directorio raíz usando `dirname "$0"`, independientemente de desde dónde se invoque.

---

## Módulo 7 — systemd y journalctl

### Conceptos clave
- systemd es el sistema init (PID 1) que gestiona el ciclo de vida de los servicios: arranque, reinicio automático, logs centralizados.
- Un archivo `.service` define `ExecStart` (siempre con rutas absolutas — systemd no tiene noción de "directorio actual de una terminal"), `WorkingDirectory`, `User`, y política de reinicio (`Restart=on-failure`).
- `systemctl enable` crea un symlink hacia el target de arranque (no inicia el servicio); `systemctl start` sí lo inicia. Son operaciones independientes.
- **`daemon-reload` y `restart` son pasos distintos:** editar un `.service` no tiene efecto sobre el proceso corriendo hasta que se recarga la definición (`daemon-reload`) y se reinicia el proceso (`restart`), en ese orden.
- journalctl centraliza automáticamente el `stdout`/`stderr` de cualquier servicio gestionado por systemd, sin configuración adicional de logging.

### Servicio creado (`/etc/systemd/system/devops-journey.service`)
```ini
[Unit]
Description=DevOps Journey API
After=network.target

[Service]
User=j
WorkingDirectory=/home/j/devops-journey
ExecStart=/home/j/devops-journey/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### Diagnóstico realizado
- `systemctl status` interpretado campo por campo (`Active`, `Main PID`, `Memory`, `CGroup` — mismo mecanismo de aislamiento de recursos que usa Docker por debajo).
- `journalctl -u devops-journey -f` en vivo, confirmando que Uvicorn loguea automáticamente cada request (IP origen, método, ruta, status code) sin configuración extra.
- `curl -v` reveló que el cliente intenta conectar primero por IPv6 (`::1`), recibe `Connection refused` (`--host 0.0.0.0` solo cubre IPv4), y cae automáticamente a IPv4.

### Ticket de soporte — cambio de puerto no aplicado
Se simuló un incidente real: editar `ExecStart` para cambiar el puerto sin recargar el servicio. Se confirmó que el servicio siguió respondiendo en el puerto **viejo** hasta ejecutar `daemon-reload` + `restart`, evidenciando que los cambios en disco no afectan a un proceso ya en ejecución. Se revirtió el cambio aplicando correctamente la misma secuencia.

---

## Aprendizajes clave

- `kill` sin flags es la opción correcta por defecto; `-9` es el último recurso.
- La ausencia del bit `x` es una causa extremadamente común de fallos en scripts de deploy y pipelines — y ahora se entiende el mecanismo exacto, no solo el síntoma.
- Los permisos de archivo son parte de los metadatos versionados por Git, no solo del sistema de archivos local.
- Un script debe auto-posicionarse en su propio directorio raíz para funcionar de forma predecible sin importar desde dónde se lo invoque.
- Editar un archivo de configuración de systemd no tiene ningún efecto hasta hacer `daemon-reload` y reiniciar el servicio — error de secuencia muy común en operación real.

---

## EN/ES — Términos adicionales de estos módulos

| Inglés | Español |
|---|---|
| Filesystem Hierarchy Standard (FHS) | Estándar de jerarquía del sistema de archivos |
| Working directory (cwd) | Directorio de trabajo actual |
| Init system | Sistema de inicialización (PID 1) |
| Unit file | Archivo de definición de un servicio systemd |
| Symlink | Enlace simbólico |
| Restart policy | Política de reinicio |
| Follow (logs) | Seguir logs en tiempo real (`-f`) |
| cgroup | Grupo de control del kernel para aislar/limitar recursos de un proceso |

---

## Commits de la fase

```
feat(scripts): agrega start.sh con permisos de ejecución para levantar la API
fix(scripts): usa ruta relativa al propio script para que start.sh funcione desde cualquier directorio
feat(systemd): agrega devops-journey.service con reinicio automático y logging centralizado
docs: cierra Fase 2 (Linux Administration) - procesos, permisos, filesystem y systemd
```

**Tag:** `v0.2`
