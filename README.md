# DevOps Journey

> Un laboratorio DevOps evolutivo: una única aplicación mínima que crece, capa por capa, desde `localhost` hasta un despliegue completo en AWS con CI/CD.

[![Status](https://img.shields.io/badge/status-en%20progreso-yellow)]()
[![Fase actual](https://img.shields.io/badge/fase-1%20Networking-blue)]()

---

## Qué es esto

Este repositorio documenta mi preparación práctica para mi primera vacante como **DevOps Junior**. No es una aplicación compleja a propósito: es una API mínima en FastAPI que sirve como excusa para construir, romper y diagnosticar infraestructura real — la misma que usaría una empresa pequeña en producción.

Cada fase agrega una capa nueva sobre la misma aplicación. Nada se reescribe desde cero. La evolución completa queda registrada en el historial de commits y en tags de versión.

```
Cliente → HTTP → TCP → IP → Linux → Docker → Nginx → FastAPI → PostgreSQL → AWS → CI/CD
```

## Por qué existe este proyecto

La mayoría de los portafolios Junior muestran una tecnología aislada ("hice un contenedor Docker", "desplegué en AWS"). Este proyecto busca demostrar algo distinto: **la capacidad de operar y diagnosticar un sistema completo de punta a punta**, que es lo que realmente se evalúa en una entrevista y en el día a día del puesto.

Cada incidente que aparece en `docs/incidents/` fue provocado a propósito y resuelto usando herramientas reales de diagnóstico (`curl`, `ss`, `dig`, `journalctl`, `docker logs`, etc.), no simulado en abstracto.

## Roadmap y estado actual

| Fase | Contenido | Estado |
|---|---|---|
| 1 — Networking | OSI, HTTP, TCP, DNS, TLS | ✅ Completa (`v0.1.1`) |
| 2 — Linux Administration | Usuarios, permisos, procesos, systemd | ⏳ En progreso |
| 3 — Servicios | Nginx, PostgreSQL, systemd | 🔜 Pendiente |
| 4 — Contenedores | Docker, Docker Compose | 🔜 Pendiente |
| 5 — Cloud | AWS (EC2, IAM, VPC, S3) | 🔜 Pendiente |
| 6 — Automatización | Git avanzado, GitHub Actions, CI/CD | 🔜 Pendiente |

Documentación detallada de cada fase en [`docs/`](./docs).

## Stack

- **Aplicación:** Python 3 + FastAPI + Uvicorn
- **Infraestructura (progresiva):** Docker, Nginx, PostgreSQL, AWS, GitHub Actions

## Cómo correrlo localmente

```bash
git clone <este-repo>
cd devops-journey
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Verificar:
```bash
curl http://localhost:8000/health
# {"status":"healthy"}
```

## Estructura del proyecto

```
devops-journey/
├── app/                  # Código de la aplicación FastAPI
├── docs/                 # Documentación técnica por fase
│   └── incidents/        # Bitácora de incidentes provocados y resueltos
├── requirements.txt
└── README.md
```

> Nota: la estructura crece fase por fase. Carpetas como `nginx/`, `docker/`, `infra/` o `.github/workflows/` se agregan únicamente cuando la fase correspondiente las necesita — ver el [documento rector del proyecto](./docs/) para el mapa completo de destino.

## Metodología

Cada módulo del roadmap sigue el mismo formato: teoría mínima → implementación → diagnóstico → incidente simulado → documentación. El detalle completo está en `docs/`.

## Convenciones

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `docs`, `chore`, `refactor`, `ci`, `test`)
- **Versionado:** tags `v0.1` → `v1.0`, uno por fase estable

---

*Proyecto en construcción activa como parte de mi preparación para el mercado laboral DevOps.*
