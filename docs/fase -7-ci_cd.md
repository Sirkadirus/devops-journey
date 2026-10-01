# Fase 7 — CI/CD

> Automatización del ciclo completo commit → producción: cada push a `main` valida el código, publica una imagen versionada, y la despliega en la instancia EC2 de Fase 5 — sin intervención manual.

---

## Objetivo de la fase

Hasta esta fase, cada actualización del proyecto en producción implicaba conectarse por SSH a la EC2 y actuar manualmente. Fase 7 automatiza ese ciclo completo en tres escalones, cada uno con una responsabilidad propia:

- **7a — CI**: cada push/PR corre lint, tests y build, sin que nadie tenga que acordarse de hacerlo.
- **7b — Registry**: la imagen validada se publica en GitHub Container Registry (GHCR), versionada por tag `latest` y por SHA de commit.
- **7c — CD**: al llegar a `main`, la EC2 se actualiza sola, descargando y desplegando la imagen recién publicada.

Se adoptó, en paralelo, una estrategia de ramas con Pull Requests hacia `main` (abandonando el trabajo directo sobre `main` de fases anteriores), ya que `main` pasó a disparar despliegues reales a producción.

---

## 1. CI — lint, tests, build

### Estructura en jobs separados

El workflow (`.github/workflows/ci.yml`) separa `lint` y `test` en jobs independientes (no un único job secuencial), para que corran en paralelo y para que un fallo de lint no oculte el resultado de los tests:

```yaml
jobs:
  lint:     # ruff check + ruff format --check
  test:     # pytest, con env vars dummy inyectadas
  build:
    needs: [lint, test]
  publish:
    needs: build
  deploy:
    needs: publish
```

`build` solo corre si `lint` y `test` pasaron; cada job siguiente depende explícitamente (`needs:`) del anterior — ningún paso avanza sobre una base que no se validó.

### Primer test real del proyecto

```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
```

### `ruff` como linter y formateador

`pyproject.toml` configura el alcance y las excepciones:

```toml
[tool.ruff]
extend-exclude = ["learning", "scripts/learning_python", "venv"]

[tool.ruff.lint]
ignore = ["B008", "BLE001"]
```

- `extend-exclude` saca del linting las carpetas de práctica personal de Python (no forman parte del proyecto en sí).
- `B008` (llamada a función en default de argumento) y `BLE001` (`except Exception` genérico) se ignoran a nivel de proyecto: ambos son falsos positivos conocidos en el contexto de FastAPI — `Depends()` es el patrón oficial de inyección de dependencias, y un `except Exception` amplio es intencional en un healthcheck de base de datos.

---

## 2. Registry — GHCR

### Por qué GHCR y no reconstruir en cada entorno

Publicar la imagen una vez, versionada, permite que cualquier entorno (la EC2, o cualquier otra máquina) la descargue ya construida y validada, sin repetir el build. Es el mismo artefacto exacto que pasó por CI, identificable por el SHA del commit que lo generó.

### Autenticación sin secretos permanentes

GHCR se autentica con `secrets.GITHUB_TOKEN`, una credencial temporal que GitHub genera automáticamente para cada corrida del workflow — no requiere crear ni almacenar ningún token manualmente, y el permiso de escritura se otorga explícitamente y de forma acotada:

```yaml
permissions:
  contents: read
  packages: write
```

### El problema de las mayúsculas en los tags

Docker/OCI exige nombres de repositorio en minúsculas. `github.repository_owner` devuelve el username tal cual está en GitHub (en este caso, con mayúscula), y GitHub Actions **no tiene** una función `toLower()` nativa. Se resolvió con un step de shell:

```yaml
- name: Set lowercase repository owner
  id: vars
  run: echo "owner=$(echo '${{ github.repository_owner }}' | tr '[:upper:]' '[:lower:]')" >> "$GITHUB_OUTPUT"
```

### Visibilidad del paquete

Un paquete en GHCR nace **privado por default**, incluso en un repositorio público — no hereda la visibilidad del repo automáticamente. Se cambió manualmente a público desde Package Settings → Danger Zone, confirmado con un `docker pull` exitoso sin autenticación desde una máquina externa.

---

## 3. CD — despliegue automático a EC2

### Separación de credenciales

Se generó un par de claves SSH **dedicado exclusivamente al pipeline** (`gha-devops-journey`, ed25519, sin passphrase), distinto de la clave personal usada para acceso manual — permite revocar el acceso del pipeline sin afectar el acceso propio, el mismo principio de separación de identidades ya aplicado en Fase 5 (usuario administrativo vs. usuario operativo).

Credenciales almacenadas como GitHub Secrets, nunca en el repositorio:

| Secret | Contenido |
|---|---|
| `EC2_SSH_KEY` | Clave privada completa (BEGIN/END incluidos) |
| `EC2_HOST` | IP pública de la instancia |
| `EC2_USER` | `ubuntu` |

### El cambio de arquitectura en `docker-compose.yml` (EC2)

```diff
  app:
-   build: .
+   image: ghcr.io/sirkadirus/devops-journey-app:latest
```

La producción deja de reconstruir la imagen localmente; usa exactamente la que CI ya construyó y validó. El build en producción desaparece como fuente de divergencia entre lo probado y lo desplegado.

### El job de deploy

```yaml
deploy:
  needs: publish
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to EC2
      uses: appleboy/ssh-action@v1.0.3
      with:
        host: ${{ secrets.EC2_HOST }}
        username: ${{ secrets.EC2_USER }}
        key: ${{ secrets.EC2_SSH_KEY }}
        script: |
          cd ~/devops-journey
          docker compose pull app
          docker compose up -d app
          docker image prune -f
```

`docker image prune -f` evita que cada deploy deje una imagen vieja acumulada en el disco de la instancia.

---

## 4. Incidentes de esta fase

Ver detalle completo en `runbook.md`. Resumen:

- **#017** — `requirements.txt` con dos paquetes concatenados en una sola línea (`>>` sin salto de línea final previo), rompiendo el parseo de `pip` en un runner limpio.
- **#018** — `ValueError: invalid literal for int() with base 10: 'None'` en la recolección de tests: `DATABASE_URL` armada con la palabra literal `"None"` cuando las variables de entorno no existen en el runner.
- **#019** — `toLower()` no existe en el lenguaje de expresiones de GitHub Actions; resuelto con un step de shell (`tr`) que expone el resultado vía `$GITHUB_OUTPUT`.
- **#020** — Un PR mergeado antes de que su último fix llegara a esa rama dejó `main` con una versión rota del workflow; resuelto trayendo el commit faltante a una rama nueva vía `git cherry-pick`.
- **#021** — Secret `EC2_SSH_KEY` mal copiado (contenido incompleto) causó `ssh: no key found`; resuelto recreando el Secret con el contenido completo de la clave privada.

---

## Aprendizajes clave de la fase

- Un error silencioso en un archivo (como `requirements.txt` con líneas concatenadas) puede pasar inadvertido en un entorno local donde las dependencias ya están instaladas, y solo manifestarse en un entorno limpio que fuerza el parseo completo — exactamente el valor de correr CI en una máquina nueva cada vez.
- Un f-string de Python nunca deja un valor `None` "vacío": lo convierte en el string literal `"None"`, lo cual puede producir errores de parseo río abajo (en este caso, en SQLAlchemy) muy alejados de la causa real.
- GitHub Actions tiene un set acotado de funciones de expresión; no asumir que una función de otro ecosistema (`toLower()`) existe sin verificarlo.
- El merge de un PR congela el estado de esa rama en ese momento — commits posteriores a esa rama no llegan a destino salvo un nuevo PR o un cherry-pick explícito.
- Separar credenciales por propósito (clave SSH dedicada al pipeline, distinta de la personal) permite revocar el acceso de automatización sin afectar el acceso humano — mismo principio aplicado con los distintos usuarios de IAM en Fase 5.
- Reutilizar en producción la misma imagen que CI construyó y validó (en vez de reconstruir en el servidor) elimina una fuente de divergencia entre "lo que se probó" y "lo que corre".

---

## Pendiente / fuera de alcance de esta fase

- Restricción del puerto 22 (SSH) en el Security Group, actualmente abierto a `0.0.0.0/0` — candidato a hardening futuro (IP fija, VPN, o AWS Systems Manager Session Manager en reemplazo de SSH directo).
- Rollback automático ante un deploy fallido — el pipeline actual no revierte si el contenedor nuevo no levanta correctamente.
- Notificaciones del resultado del pipeline (Slack, email) — no implementadas.
- Migración del código de aprendizaje de Python (`learning/`, `scripts/learning_python/`) a un repositorio separado, para que `devops-journey` refleje únicamente el portafolio de infraestructura.