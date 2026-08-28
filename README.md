# DevOps Journey

> Un laboratorio DevOps evolutivo: una única aplicación mínima que crece, capa por capa, desde `localhost` hasta un despliegue completo en AWS con CI/CD.

[![Status](https://img.shields.io/badge/status-en%20progreso-yellow)]()
[![Fase actual](https://img.shields.io/badge/fase-4%20Contenedores-blue)]()

---

## Qué es esto

Este repositorio documenta mi preparación práctica para mi primera vacante como **DevOps Junior**. No es una aplicación compleja a propósito: es una API mínima en FastAPI que sirve como excusa para construir, romper y diagnosticar infraestructura real — la misma que usaría una empresa pequeña en producción.

Cada fase agrega una capa nueva sobre la misma aplicación. Nada se reescribe desde cero. La evolución completa queda registrada en el historial de commits y en tags de versión.

```
Cliente → HTTP → TCP → IP → Linux → Docker → Nginx → FastAPI → PostgreSQL → AWS → CI/CD
```

## Por qué existe este proyecto

La mayoría de los portafolios Junior muestran una tecnología aislada ("hice un contenedor Docker", "desplegué en AWS"). Este proyecto busca demostrar algo distinto: **la capacidad de operar y diagnosticar un sistema completo de punta a punta**, que es lo que realmente se evalúa en una entrevista y en el día a día del puesto.

Cada incidente resuelto queda documentado en [`runbook.md`](./runbook.md) siguiendo un formato operativo estándar (síntoma → diagnóstico → causa raíz → solución → prevención), usando siempre herramientas reales de diagnóstico (`curl -v`, `ss`, `dig`, `ps`, `journalctl`, `nginx -t`, `psql`, etc.), nunca simulado en abstracto.

## Roadmap y estado actual

| Fase | Contenido | Estado |
|---|---|---|
| 1 — Networking | OSI, HTTP, TCP, DNS, TLS | ✅ Completa (`v0.1.1`) |
| 2 — Linux Administration | Procesos, permisos, sistema de archivos, systemd/journalctl | ✅ Completa (`v0.2`) |
| 3 — Servicios | Nginx (reverse proxy) + PostgreSQL (SQLAlchemy, `/db-check`) | ✅ Completa (`v0.3`) |
| 4 — Contenedores | Docker, Docker Compose | ⏳ En progreso |
| 5 — Cloud | AWS (EC2, IAM, VPC, S3) | 🔜 Pendiente |
| 6 — Automatización | Git avanzado, GitHub Actions, CI/CD | 🔜 Pendiente |

Documentación detallada de cada fase en [`docs/`](./docs).

## Stack

- **Aplicación:** Python 3 + FastAPI + Uvicorn + SQLAlchemy
- **Base de datos:** PostgreSQL 16
- **Infraestructura implementada:** systemd (servicio gestionado, con reinicio automático), Nginx (reverse proxy)
- **Infraestructura pendiente:** Docker, Docker Compose, AWS, GitHub Actions

## Cómo correrlo localmente

```bash
git clone <este-repo>
cd devops-journey
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # completar DATABASE_URL con tus credenciales locales
```

**Opción A — manual (desarrollo):**
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Opción B — como servicio systemd (recomendado, ver `infra/systemd/`):**
```bash
sudo cp infra/systemd/devops-journey.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now devops-journey
```

**Nginx como reverse proxy** (config de referencia en `infra/nginx/`):
```bash
sudo cp infra/nginx/devops-journey.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/devops-journey.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

**PostgreSQL** (rol y base dedicados, no usar el superusuario):
```sql
CREATE USER devops_app WITH PASSWORD 'tu_password';
CREATE DATABASE devops_journey OWNER devops_app;
```

Verificar:
```bash
curl http://localhost:8000/health     # directo a la app
curl http://localhost:8000/db-check   # verifica conexión real a PostgreSQL
curl http://localhost:80/health       # a través de Nginx — fijate el header "Server" en curl -v
```

## Estructura del proyecto

```
devops-journey/
├── app/                        # Código de la aplicación FastAPI
│   ├── __init__.py
│   ├── main.py                 # Endpoints: /health, /db-check
│   └── db.py                   # Engine y sesiones de SQLAlchemy
├── scripts/
│   └── start.sh                # Arranque manual, auto-posicionado en su directorio raíz
├── infra/
│   ├── systemd/
│   │   └── devops-journey.service   # Copia de referencia del unit file real
│   └── nginx/
│       └── devops-journey.conf      # Copia de referencia de la config real de Nginx
├── docs/                       # Documentación técnica por fase (teoría + implementación + diagnóstico)
│   ├── fase-1-networking.md
│   ├── fase-2-linux-administration.md
│   └── fase-3-servicios.md
├── runbook.md                  # Incidentes resueltos en formato operativo estándar
├── .env.example                 # Plantilla de variables de entorno (sin secretos)
├── requirements.txt
└── README.md
```

> Nota: la estructura crece fase por fase. Carpetas como `docker/`, `.github/workflows/` se agregan únicamente cuando la fase correspondiente las necesita.

## Metodología

Cada módulo del roadmap sigue el mismo formato: teoría mínima → implementación → diagnóstico → incidente simulado → documentación. El detalle completo está en `docs/`.

## Incidentes resueltos (destacados)

Ver el listado completo en [`runbook.md`](./runbook.md). Algunos ejemplos:

- **Connection Refused** — diagnóstico de la diferencia entre rechazo activo del kernel (RST) y timeout de red real.
- **Bind a `127.0.0.1` en lugar de `0.0.0.0`** — causa raíz más común de fallos de conectividad al introducir un reverse proxy.
- **Cambio de configuración de systemd no aplicado** — por qué `daemon-reload` y `restart` son pasos independientes y obligatorios en ese orden.
- **502 Bad Gateway con backend detenido** — diagnóstico en capas (red del proxy → log de Nginx → estado del backend) demostrando que el 502 siempre lo genera la capa proxy, no la aplicación.

## Convenciones

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `docs`, `chore`, `refactor`, `ci`, `test`)
- **Versionado:** tags `v0.1` → `v1.0`, uno por fase estable

---

*Proyecto en construcción activa como parte de mi preparación para el mercado laboral DevOps.*