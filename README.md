# DevOps Journey

> Un laboratorio DevOps evolutivo: una única aplicación mínima que crece, capa por capa, desde `localhost` hasta un despliegue completo en AWS con CI/CD.

[![Status](https://img.shields.io/badge/status-en%20progreso-yellow)]()
[![Fase actual](https://img.shields.io/badge/fase-8%20Terraform-blue)]()

---

## Qué es esto

Este repositorio documenta mi preparación práctica para mi primera vacante como **DevOps Junior**. No es una aplicación compleja a propósito: es una API mínima en FastAPI que sirve como excusa para construir, romper y diagnosticar infraestructura real — la misma que usaría una empresa pequeña en producción.

Cada fase agrega una capa nueva sobre la misma aplicación. Nada se reescribe desde cero. La evolución completa queda registrada en el historial de commits y en tags de versión.

```
git push a main
   ↓
CI: lint → tests → build
   ↓
Registry: imagen publicada en GHCR
   ↓
CD: deploy automático por SSH
   ↓
Cliente → Internet Gateway → Security Group → EC2 → Nginx → FastAPI → PostgreSQL
                                                         ↓
                                                   IAM Role → S3 (backups)
```

> El mismo FastAPI también corre, en paralelo, como práctica satélite en un clúster de Kubernetes local (Fase 6) — ver `docs/fase-6-kubernetes-basico.md`.

## Por qué existe este proyecto

La mayoría de los portafolios Junior muestran una tecnología aislada ("hice un contenedor Docker", "desplegué en AWS"). Este proyecto busca demostrar algo distinto: **la capacidad de operar y diagnosticar un sistema completo de punta a punta**, que es lo que realmente se evalúa en una entrevista y en el día a día del puesto.

El historial de incidentes está preservado en [`docs/incidents/incident-history.md`](./docs/incidents/incident-history.md). El registro individual de Connection Refused está en [`docs/incidents/001-connection-refused.md`](./docs/incidents/001-connection-refused.md). Todavía no hay un runbook separado con procedimientos reutilizables.

## Roadmap y estado actual

| Fase | Contenido | Estado |
|---|---|---|
| 1 — Networking | OSI, HTTP, TCP, DNS, TLS | ✅ Completa (`v0.1.1`) |
| 2 — Linux Administration | Procesos, permisos, sistema de archivos, systemd/journalctl | ✅ Completa (`v0.2`) |
| 3 — Servicios | Nginx (reverse proxy) + PostgreSQL (SQLAlchemy, `/db-check`) | ✅ Completa (`v0.3`) |
| 4 — Contenedores | Docker, Docker Compose, Nginx dockerizado, restart policy | ✅ Completa (`v0.4.1`) |
| 5 — Cloud (AWS) | IAM (Users/Roles/mínimo privilegio), VPC, Subnets, Route Tables, IGW, Security Groups, EC2, S3 | ✅ Completa (`v0.5`) |
| 6 — Kubernetes (básico) | Pod, Deployment, Service, ConfigMap, Secret (clúster local con Kind) | ✅ Completa (`v0.6`) |
| 7 — CI/CD | GitHub Actions (lint, tests, build), GHCR, despliegue automático a EC2 por SSH | ✅ Completa (`v0.7`) |
| 8 — Terraform | Introducción a Infrastructure as Code con Terraform para AWS, actualmente centrada en EC2 + Security Group | ⏳ En progreso |
| 9 — Ansible | Configuración y provisioning de la instancia vía playbooks | 🔜 Pendiente |

> Kubernetes básico se practicó como módulo satélite (clúster local, no en AWS): no tiene dependencia técnica de Terraform/Ansible, y se priorizó antes por aparecer con frecuencia como filtro en entrevistas Junior. Una eventual migración a EKS queda como posible fase futura, una vez dominados Terraform y Ansible.

Índice de arquitectura, operación, incidentes y fases en [`docs/README.md`](./docs/README.md).

## Stack

- **Aplicación:** Python 3 + FastAPI + Uvicorn + SQLAlchemy
- **Base de datos:** PostgreSQL 16
- **Infraestructura implementada:** systemd, Docker, Docker Compose (Nginx + API + PostgreSQL, los tres contenedorizados, con reinicio automático y healthcheck); AWS (EC2, VPC, Security Groups, IAM con Users/Roles diferenciados, S3 con acceso vía Instance Profile); Kubernetes local con Kind (Pod, Deployment, Service, ConfigMap, Secret); CI/CD con GitHub Actions (lint con ruff, tests con pytest, build y publicación en GHCR, despliegue automático a EC2 por SSH)
- **Infraestructura pendiente:** Terraform, Ansible

## Cómo correrlo localmente

### Stack completo con Docker Compose (recomendado — un solo comando)

```bash
git clone <este-repo>
cd devops-journey
docker compose up -d --build
```

Esto levanta los tres servicios en su propia red aislada: `nginx` (puerta de entrada), `app` (FastAPI) y `db` (PostgreSQL con volumen persistente). Ninguno salvo `nginx` está expuesto directamente al host.

Verificar:
```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/db-check   # verifica conexión real Nginx → app → PostgreSQL
```

### Usar la imagen ya publicada (sin build local)

```bash
docker pull ghcr.io/sirkadirus/devops-journey-app:latest
```

Imagen pública, construida y validada automáticamente por el pipeline de CI en cada push a `main`.

### Alternativa: clúster local de Kubernetes (Kind)

```bash
kind create cluster --name devops-journey --config kind-config.yaml
kind load docker-image devops-journey-app:latest --name devops-journey
kubectl apply -f k8s/fastapi-secret.yaml
kubectl apply -f k8s/fastapi-configmap.yaml
kubectl apply -f k8s/fastapi-deployment.yaml
kubectl apply -f k8s/fastapi-service.yaml
```

Verificar:
```bash
curl http://localhost:30080/health
curl http://localhost:30080/db-check
```

Detalle completo, incluyendo por qué `app/db.py` soporta ambos entornos sin duplicar lógica, en [`docs/fase-6-kubernetes-basico.md`](./docs/fase-6-kubernetes-basico.md).

### Alternativa manual, directo sobre Linux (sin Docker)

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # completar DATABASE_URL con tus credenciales locales de Postgres
```

**Como servicio systemd** (ver `infra/systemd/`):
```bash
sudo cp infra/systemd/devops-journey.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now devops-journey
```

**Nginx manual como reverse proxy** (ver `infra/nginx/`):
```bash
sudo cp infra/nginx/devops-journey.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/devops-journey.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

**PostgreSQL** (rol y base dedicados, no usar el superusuario):
```sql
CREATE USER devops_j WITH PASSWORD 'password';
CREATE DATABASE database_name OWNER user;
```

## CI/CD

Cada push o Pull Request hacia `main` dispara automáticamente:

```
lint (ruff check + ruff format --check)
   ↓
test (pytest)
   ↓
build (docker build)
   ↓ — solo en push directo a main —
publish (build + push a ghcr.io/sirkadirus/devops-journey-app)
   ↓
deploy (SSH a EC2 → docker compose pull + up -d)
```

Credenciales de despliegue (clave SSH dedicada, host, usuario) gestionadas vía GitHub Secrets — nunca en el repositorio. Detalle completo en [`docs/fase-7-cicd.md`](./docs/fase-7-cicd.md).

## Estructura del proyecto

```
devops-journey/
├── app/                        # Código de la aplicación FastAPI
│   ├── __init__.py
│   ├── main.py                 # Endpoints: /health, /db-check
│   └── db.py                   # Engine y sesiones de SQLAlchemy (compatible Compose + Kubernetes)
├── tests/
│   └── test_main.py            # Tests con pytest + TestClient
├── nginx/
│   └── devops-journey.conf     # Config de Nginx usada DENTRO de Docker Compose (bind mount)
├── scripts/
│   └── start.sh                # Arranque manual, auto-posicionado en su directorio raíz
├── infra/
│   ├── systemd/
│   │   └── devops-journey.service   # Copia de referencia del unit file real
│   └── nginx/
│       └── devops-journey.conf      # Config de Nginx para el modo MANUAL (fuera de Docker)
├── k8s/                        # Manifiestos de Kubernetes (Fase 6)
│   ├── fastapi-secret.yaml     # Credenciales de DB (Opaque, base64)
│   ├── fastapi-configmap.yaml  # Configuración no sensible de DB
│   ├── fastapi-deployment.yaml # Deployment, 2 réplicas
│   └── fastapi-service.yaml    # Service tipo NodePort
├── kind-config.yaml            # Configuración del clúster Kind (publica el NodePort al host)
├── .github/
│   └── workflows/
│       └── ci.yml               # Pipeline: lint, test, build, publish (GHCR), deploy (EC2)
├── docs/                       # Arquitectura, operación, incidentes y fases
│   ├── README.md
│   ├── architecture/overview.md
│   ├── incidents/
│   │   ├── 001-connection-refused.md
│   │   └── incident-history.md
│   ├── fase-1-networking.md
│   ├── fase-2-linux-administration.md
│   ├── fase-3-servicios.md
│   ├── fase-4-contenedores.md
│   ├── fase-5-cloud-aws.md
│   ├── fase-6-kubernetes-basico.md
│   ├── fase-7-cicd.md
│   └── fase-8-terraform.md
├── Dockerfile                  # Imagen de la aplicación (build multi-capa optimizado)
├── .dockerignore
├── docker-compose.yml          # Orquesta nginx + app + db, con red, volumen, healthcheck y restart policy
├── pyproject.toml              # Configuración de ruff (lint + format)
├── .env.example                 # Plantilla de variables de entorno (sin secretos)
├── requirements.txt
└── README.md
```

> Nota: la estructura crece fase por fase. Carpetas como `.github/workflows/` se agregan únicamente cuando la fase correspondiente las necesita.

## Metodología

Cada módulo del roadmap sigue el mismo formato: teoría mínima → implementación → diagnóstico → incidente simulado → documentación. El detalle completo está en `docs/`.

## Incidentes resueltos (destacados)

Ver el historial completo en [`docs/incidents/incident-history.md`](./docs/incidents/incident-history.md). Algunos ejemplos:

- **Connection Refused** — diagnóstico de la diferencia entre rechazo activo del kernel (RST) y timeout de red real.
- **Bind a `127.0.0.1` en lugar de `0.0.0.0`** — causa raíz más común de fallos de conectividad al introducir un reverse proxy o contenedores.
- **502 Bad Gateway con backend detenido** — diagnóstico en capas (red del proxy → log de Nginx → estado del backend) demostrando que el 502 siempre lo genera la capa proxy, no la aplicación.
- **Conexión Docker → PostgreSQL con 3 causas encadenadas** — variable de entorno no inyectada, red aislada del contenedor, y autenticación de Postgres, diagnosticadas y resueltas una por una.
- **Race condition en Docker Compose** — `depends_on` ordena arranque pero no garantiza disponibilidad; resuelto con `healthcheck` + `condition: service_healthy`.
- **Bind mount montado como directorio fantasma** — Docker crea un directorio automáticamente cuando el archivo esperado no existe, produciendo un error de mount confuso en el intento siguiente.
- **Security Group bloqueando tráfico (drop silencioso)** — a diferencia de un servicio caído (RST instantáneo) o un backend inalcanzable (502 instantáneo), un Security Group bloqueado no responde: el cliente falla recién al agotar su propio timeout.
- **Subnet sin ruta al Internet Gateway** — una instancia con IP pública asignada resulta igualmente inalcanzable si la route table de su subnet no tiene ruta hacia el IGW; el estado "pública" depende de la ruta, no de la subnet en sí.
- **401 en el Instance Metadata Service (IMDSv1 vs IMDSv2)** — una consulta de metadata con el flujo antiguo (GET directo) es rechazada por instancias modernas, que exigen primero un token vía PUT (mitigación de SSRF).
- **CrashLoopBackOff por variable de entorno ausente (Kubernetes)** — un `import` a nivel de módulo ejecuta `create_engine(DATABASE_URL)` de inmediato, aun con los endpoints que la usan comentados.
- **Resolución DNS de `host.docker.internal` fallando en Kind sobre Linux** — resuelto apuntando a la IP real de la LAN del host contra el puerto explícitamente publicado.
- **Service NodePort inaccesible por configuración por defecto de Kind** — resuelto declarando `extraPortMappings` en la configuración del clúster.
- **`requirements.txt` con dependencias concatenadas** — un `>>` sin salto de línea final rompió el parseo de `pip` en un runner limpio de CI, aunque funcionaba en local.
- **`DATABASE_URL` con `"None"` literal en CI** — un f-string inserta la palabra `"None"` cuando una variable de entorno no existe, en vez de dejarla vacía, rompiendo el parseo de SQLAlchemy.
- **`toLower()` inexistente en GitHub Actions** — resuelto con un step de shell (`tr`) para normalizar nombres de tag de Docker a minúsculas.
- **Fix perdido tras un merge prematuro** — un commit pusheado después del merge de su PR no llega a `main`; resuelto con `git cherry-pick` hacia una rama nueva.
- **Secret de clave SSH mal copiado** — `ssh: no key found` por contenido incompleto en el GitHub Secret; resuelto recreándolo con el archivo completo.

## Convenciones

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `docs`, `chore`, `refactor`, `ci`, `test`)
- **Versionado:** tags `v0.1` → `v1.0`, uno por fase estable
- **Ramas:** Pull Requests hacia `main` (sin push directo), desde que `main` dispara despliegues reales en Fase 7

---

*Proyecto en construcción activa como parte de mi preparación para el mercado laboral DevOps.*
