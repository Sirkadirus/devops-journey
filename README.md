# DevOps Journey

> Un laboratorio DevOps evolutivo: una única aplicación mínima que crece, capa por capa, desde `localhost` hasta un despliegue completo en AWS con CI/CD.

[![Status](https://img.shields.io/badge/status-en%20progreso-yellow)]()
[![Fase actual](https://img.shields.io/badge/fase-6%20Kubernetes%20(b%C3%A1sico)-blue)]()

---

## Qué es esto

Este repositorio documenta mi preparación práctica para mi primera vacante como **DevOps Junior**. No es una aplicación compleja a propósito: es una API mínima en FastAPI que sirve como excusa para construir, romper y diagnosticar infraestructura real — la misma que usaría una empresa pequeña en producción.

Cada fase agrega una capa nueva sobre la misma aplicación. Nada se reescribe desde cero. La evolución completa queda registrada en el historial de commits y en tags de versión.

```
Cliente → Internet Gateway → Security Group → EC2 → Nginx → FastAPI → PostgreSQL
                                                         ↓
                                                   IAM Role → S3 (backups)
```

## Por qué existe este proyecto

La mayoría de los portafolios Junior muestran una tecnología aislada ("hice un contenedor Docker", "desplegué en AWS"). Este proyecto busca demostrar algo distinto: **la capacidad de operar y diagnosticar un sistema completo de punta a punta**, que es lo que realmente se evalúa en una entrevista y en el día a día del puesto.

Cada incidente resuelto queda documentado en [`runbook.md`](./runbook.md) siguiendo un formato operativo estándar (síntoma → diagnóstico → causa raíz → solución → prevención), usando siempre herramientas reales de diagnóstico (`curl -v`, `ss`, `dig`, `ps`, `journalctl`, `nginx -t`, `psql`, `docker logs`, etc.), nunca simulado en abstracto.

## Roadmap y estado actual

| Fase | Contenido | Estado |
|---|---|---|
| 1 — Networking | OSI, HTTP, TCP, DNS, TLS | ✅ Completa (`v0.1.1`) |
| 2 — Linux Administration | Procesos, permisos, sistema de archivos, systemd/journalctl | ✅ Completa (`v0.2`) |
| 3 — Servicios | Nginx (reverse proxy) + PostgreSQL (SQLAlchemy, `/db-check`) | ✅ Completa (`v0.3`) |
| 4 — Contenedores | Docker, Docker Compose, Nginx dockerizado, restart policy | ✅ Completa (`v0.4.1`) |
| 5 — Cloud (AWS) | IAM (Users/Roles/mínimo privilegio), VPC, Subnets, Route Tables, IGW, Security Groups, EC2, S3 | ✅ Completa (`v0.5`) |
| 6 — Kubernetes (básico) | Pods, Deployments, Services, ConfigMaps, kubectl (clúster local con Kind) | ⏳ En progreso |
| 7 — CI/CD | Git avanzado, GitHub Actions | 🔜 Pendiente |
| 8 — Terraform | Infraestructura de la Fase 5 reproducida como código | 🔜 Pendiente |
| 9 — Ansible | Configuración y provisioning de la instancia vía playbooks | 🔜 Pendiente |

> Kubernetes básico se practica como módulo satélite (clúster local, no en AWS): no tiene dependencia técnica de Terraform/Ansible, y se priorizó antes por aparecer con frecuencia como filtro en entrevistas Junior. Una eventual migración a EKS queda como posible fase futura, una vez dominados Terraform y Ansible.

Documentación detallada de cada fase en [`docs/`](./docs).

## Stack

- **Aplicación:** Python 3 + FastAPI + Uvicorn + SQLAlchemy
- **Base de datos:** PostgreSQL 16
- **Infraestructura implementada:** systemd, Docker, Docker Compose (Nginx + API + PostgreSQL, los tres contenedorizados, con reinicio automático y healthcheck); AWS (EC2, VPC, Security Groups, IAM con Users/Roles diferenciados, S3 con acceso vía Instance Profile)
- **Infraestructura pendiente:** Kubernetes (clúster local), Terraform, Ansible, GitHub Actions

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

## Estructura del proyecto

```
devops-journey/
├── app/                        # Código de la aplicación FastAPI
│   ├── __init__.py
│   ├── main.py                 # Endpoints: /health, /db-check
│   └── db.py                   # Engine y sesiones de SQLAlchemy
├── nginx/
│   └── devops-journey.conf     # Config de Nginx usada DENTRO de Docker Compose (bind mount)
├── scripts/
│   └── start.sh                # Arranque manual, auto-posicionado en su directorio raíz
├── infra/
│   ├── systemd/
│   │   └── devops-journey.service   # Copia de referencia del unit file real
│   └── nginx/
│       └── devops-journey.conf      # Config de Nginx para el modo MANUAL (fuera de Docker)
├── docs/                       # Documentación técnica por fase (teoría + implementación + diagnóstico)
│   ├── fase-1-networking.md
│   ├── fase-2-linux-administration.md
│   ├── fase-3-servicios.md
│   ├── fase-4-contenedores.md
│   └── fase-5-cloud-aws.md
├── Dockerfile                  # Imagen de la aplicación (build multi-capa optimizado)
├── .dockerignore
├── docker-compose.yml          # Orquesta nginx + app + db, con red, volumen, healthcheck y restart policy
├── runbook.md                  # Incidentes resueltos en formato operativo estándar
├── .env.example                 # Plantilla de variables de entorno (sin secretos)
├── requirements.txt
└── README.md
```

> Nota: la estructura crece fase por fase. Carpetas como `.github/workflows/` se agregan únicamente cuando la fase correspondiente las necesita.

## Metodología

Cada módulo del roadmap sigue el mismo formato: teoría mínima → implementación → diagnóstico → incidente simulado → documentación. El detalle completo está en `docs/`.

## Incidentes resueltos (destacados)

Ver el listado completo en [`runbook.md`](./runbook.md). Algunos ejemplos:

- **Connection Refused** — diagnóstico de la diferencia entre rechazo activo del kernel (RST) y timeout de red real.
- **Bind a `127.0.0.1` en lugar de `0.0.0.0`** — causa raíz más común de fallos de conectividad al introducir un reverse proxy o contenedores.
- **502 Bad Gateway con backend detenido** — diagnóstico en capas (red del proxy → log de Nginx → estado del backend) demostrando que el 502 siempre lo genera la capa proxy, no la aplicación.
- **Conexión Docker → PostgreSQL con 3 causas encadenadas** — variable de entorno no inyectada, red aislada del contenedor, y autenticación de Postgres, diagnosticadas y resueltas una por una.
- **Race condition en Docker Compose** — `depends_on` ordena arranque pero no garantiza disponibilidad; resuelto con `healthcheck` + `condition: service_healthy`.
- **Bind mount montado como directorio fantasma** — Docker crea un directorio automáticamente cuando el archivo esperado no existe, produciendo un error de mount confuso en el intento siguiente.
- **Security Group bloqueando tráfico (drop silencioso)** — a diferencia de un servicio caído (RST instantáneo) o un backend inalcanzable (502 instantáneo), un Security Group bloqueado no responde: el cliente falla recién al agotar su propio timeout.
- **Subnet sin ruta al Internet Gateway** — una instancia con IP pública asignada resulta igualmente inalcanzable si la route table de su subnet no tiene ruta hacia el IGW; el estado "pública" depende de la ruta, no de la subnet en sí.
- **401 en el Instance Metadata Service (IMDSv1 vs IMDSv2)** — una consulta de metadata con el flujo antiguo (GET directo) es rechazada por instancias modernas, que exigen primero un token vía PUT (mitigación de SSRF).

## Convenciones

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `docs`, `chore`, `refactor`, `ci`, `test`)
- **Versionado:** tags `v0.1` → `v1.0`, uno por fase estable

---

*Proyecto en construcción activa como parte de mi preparación para el mercado laboral DevOps.*