# Arquitectura — DevOps Journey

Este documento reúne la arquitectura descrita en el repositorio. Los estados califican la evidencia documental, no una inspección de servicios en ejecución:

- **CURRENT**: configuración presente en el checkout inspeccionado. No implica que esté activa.
- **HISTORICAL**: implementación o experiencia relatada por la documentación de una fase.
- **PLANNED**: trabajo que la documentación identifica como futuro o pendiente.
- **INFERRED**: interpretación derivada de archivos/documentación que no confirma por sí sola el estado real.

No se inspeccionó runtime, una cuenta AWS, un clúster, GHCR ni secretos de GitHub. Por tanto, el estado operacional actual de esos sistemas no queda confirmado aquí.

## CURRENT — aplicación en el checkout

La aplicación es FastAPI con `GET /health` y `GET /db-check`. `/health` responde de forma independiente de PostgreSQL; `/db-check` ejecuta `SELECT 1` mediante SQLAlchemy. La configuración acepta `DATABASE_URL` o, en su ausencia, variables `DB_*`. El engine de SQLAlchemy se construye al importar `app.db`.

El test visible en el checkout cubre `/health` mediante `TestClient`; no se ejecutaron tests durante esta reorganización.

## CURRENT — Docker Compose configurado

El `docker-compose.yml` define PostgreSQL 16 (`db`), FastAPI (`app`) y Nginx (`nginx`). La aplicación se conecta a `db:5432`; depende del healthcheck de PostgreSQL. Nginx hace proxy a `app:8000`. Compose publica Nginx en el puerto 80 del host y PostgreSQL en el 5433 del host, mantiene datos en el volumen `pgdata` y configura políticas de reinicio.

El README aún indica acceso HTTP por `localhost:8080` y afirma que solo Nginx queda expuesto al host. Esas afirmaciones no coinciden con el Compose presente en el checkout. No se determinó cuál configuración se usa en runtime.

## HISTORICAL — ejecución Linux y servicios

Las fases 2 y 3 documentan ejecución de FastAPI con Uvicorn bajo systemd, Nginx como reverse proxy y PostgreSQL. Los archivos `infra/systemd/` y `infra/nginx/` son configuraciones de referencia; su presencia no confirma que estén instaladas en una máquina.

## HISTORICAL — AWS

La documentación de Fase 5 relata una EC2 con Nginx, FastAPI y PostgreSQL, además de VPC/red, Security Groups, IAM y S3 para backups. Estos son hechos narrados por la fase; no se verificó que los recursos sigan existiendo ni que esa sea la infraestructura activa.

## CURRENT — manifiestos Kubernetes en el checkout

Los manifiestos describen un Deployment de FastAPI con dos réplicas, ConfigMap, Secret y Service NodePort 30080; `kind-config.yaml` mapea ese puerto al host. El ConfigMap contiene un destino privado fijo para PostgreSQL. Esto describe los archivos presentes, no un clúster activo ni conectividad confirmada.

## CURRENT — workflow CI/CD en el checkout

`.github/workflows/ci.yml` define lint, tests y build, y jobs condicionales de publicación en GHCR y despliegue SSH a EC2 en push a `main`. No se verificaron los secretos, permisos externos, el host, ejecuciones del workflow ni el despliegue remoto.

## CURRENT — Terraform local

En el checkout hay configuración local Terraform —el directorio está sin seguimiento Git— que declara un Security Group y una instancia EC2, variables y outputs. No declara explícitamente la VPC/red, IAM, S3 ni provisioning de la aplicación presentes en la descripción de Fase 5. La configuración está en desarrollo; no se ejecutó Terraform ni se inspeccionó AWS.

## PLANNED — evolución documentada

El README marca Terraform como fase en progreso y Ansible como pendiente. La documentación de Kubernetes lo presenta como práctica local satélite; no hay en los archivos inspeccionados evidencia de EKS.

La guía de trabajo del proyecto también propone incorporar logs, métricas, health checks y alertas a medida que la arquitectura evolucione, y distingue logs, métricas, trazas, SLI, SLO y SLA. No se identifica una implementación concreta de una plataforma de observabilidad en la configuración inspeccionada.

## Límites y discrepancias conocidas

- README y Compose difieren en los puertos HTTP y en qué servicios se publican al host.
- Las descripciones de AWS son históricas/documentales y no prueban recursos actuales.
- La configuración Terraform presente no reproduce toda la arquitectura AWS narrada.
- La IP de PostgreSQL configurada para Kubernetes es específica del entorno y no se confirmó que sea válida actualmente.
- Una configuración versionada o local no equivale a un despliegue activo.
