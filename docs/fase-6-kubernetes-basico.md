# Fase 6 — Kubernetes (básico)

> Práctica satélite: el mismo FastAPI del proyecto principal, desplegado en un clúster de Kubernetes local (Kind), para dominar el vocabulario y los objetos fundamentales que se evalúan en una entrevista DevOps Junior — sin necesidad de administrar un clúster de producción.

---

## Objetivo de la fase

A diferencia de las fases anteriores, esta no vive dentro de la progresión lineal EC2 → Terraform → Ansible: es un módulo independiente, elegido deliberadamente **antes** de Terraform/Ansible porque Kubernetes básico aparece con frecuencia como filtro de entrevista Junior, y no tiene dependencia técnica real de esas herramientas.

Alcance cubierto: **Pod, Deployment, Service, ConfigMap, Secret** — los cinco objetos que un Junior necesita poder nombrar, explicar y haber usado. Deliberadamente fuera de alcance: administración de clúster, Helm, Ingress, operators, Kubernetes en AWS (EKS).

Entorno: clúster local de un solo nodo con **Kind** (Kubernetes in Docker), elegido sobre Minikube por reutilizar el conocimiento de Docker ya sólido del proyecto, sin sumar una capa de virtualización adicional.

---

## 1. Qué problema resuelve Kubernetes (que Docker Compose no resuelve)

Docker Compose coordina contenedores en **una sola máquina**. No tiene un concepto nativo de "quiero N réplicas de este contenedor, siempre, y que si una muere se reemplace sola" ni de distribuir contenedores entre múltiples hosts.

Kubernetes existe para orquestar contenedores a través de múltiples máquinas, manteniendo un **estado deseado** de forma continua y automática — no como reacción puntual a un evento, sino como verificación constante de "¿lo que existe ahora coincide con lo que declaré?".

---

## 2. Los cinco objetos fundamentales

| Objeto | Qué es | Por qué existe |
|---|---|---|
| **Pod** | La unidad más pequeña que Kubernetes gestiona; envuelve uno o más contenedores que comparten red y almacenamiento | Rara vez se crea directamente — casi siempre nace de un Deployment |
| **Deployment** | Declara "quiero N réplicas de este Pod, siempre" | Autocuración: si un Pod muere, el Deployment crea uno nuevo automáticamente |
| **Service** | IP estable (y nombre DNS interno) que enruta tráfico hacia los Pods correctos, vía selector de labels | Los Pods son efímeros y cambian de IP al recrearse; el Service abstrae eso |
| **ConfigMap** | Configuración no sensible (host, puerto, nombre de recurso), separada del código de la imagen | Evita reconstruir la imagen cada vez que cambia un valor de configuración |
| **Secret** | Datos sensibles (usuario, password), codificados en base64 (no cifrados por default) | Separa credenciales del resto de la configuración; reduce exposición accidental en logs |

---

## 3. Implementación

### Manifiestos (`k8s/`)

```
k8s/
├── fastapi-secret.yaml       # DB_USER, DB_PASSWORD (Opaque, base64)
├── fastapi-configmap.yaml    # DB_HOST, DB_PORT, DB_NAME
├── fastapi-deployment.yaml   # 2 réplicas, referencia Secret + ConfigMap
└── fastapi-service.yaml      # NodePort 30080 → puerto 8000 del contenedor
```

El Deployment no contiene valores de configuración directamente — usa `configMapKeyRef` y `secretKeyRef` para referenciar los otros dos objetos por nombre. Esto exige aplicar Secret y ConfigMap **antes** que el Deployment, o las referencias fallan al no encontrar el objeto.

### Ajuste de código: `app/db.py` compatible con ambos orquestadores

Kubernetes no arma automáticamente una URL de conexión a partir de piezas sueltas — hubo que decidir entre pasar `DATABASE_URL` completa en el Secret (menos correcto, más simple) o separarla en variables individuales y armarla en Python (más realista). Se eligió la segunda opción:

```python
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")
    DB_HOST = os.getenv("DB_HOST")
    DB_PORT = os.getenv("DB_PORT")
    DB_NAME = os.getenv("DB_NAME")
    DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

engine = create_engine(DATABASE_URL)
```

Docker Compose sigue pasando `DATABASE_URL` ya armada (vía `.env`); Kubernetes pasa las cinco variables sueltas (Secret + ConfigMap). El mismo código soporta ambos entornos sin duplicar lógica — el patrón real de una app que no conoce ni le importa qué orquestador la ejecuta.

### `imagePullPolicy: Never`

Como la imagen se construye localmente (`docker build`) y se carga al clúster con `kind load docker-image`, el Deployment necesita esta directiva explícita para no intentar descargarla de un registry externo (lo que produciría `ImagePullBackOff`).

### Kind y el rango de NodePorts

Por default, el contenedor de Kind que aloja el clúster **no publica el rango de NodePorts al host** — solo expone el puerto del API server. Acceder a un Service tipo `NodePort` desde fuera del clúster requiere declarar explícitamente el mapeo de puerto en un archivo de configuración de Kind, **al momento de crear el clúster**:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
```

```bash
kind create cluster --name devops-journey --config kind-config.yaml
```

Esto no se puede agregar a un clúster ya existente — requiere recrearlo. Como los objetos de Kubernetes viven declarados en `k8s/`, recrear el clúster y reaplicar los manifiestos es una operación de segundos, no una pérdida real de trabajo.

---

## 4. Incidentes de esta fase

Ver detalle completo en `runbook.md`. Resumen:

- **#014** — `CrashLoopBackOff` por variable de entorno ausente: un `import` a nivel de módulo ejecuta `create_engine(DATABASE_URL)` inmediatamente, incluso con los endpoints que la usan comentados.
- **#015** — Fallo de resolución DNS de `host.docker.internal` desde dentro de un Pod en Kind sobre Linux; resuelto apuntando a la IP real de la LAN del host contra el puerto explícitamente publicado por Docker.
- **#016** — Service `NodePort` inaccesible desde el host por configuración por defecto de Kind; resuelto con `extraPortMappings` en la configuración de creación del clúster.

---

## 5. Verificación de autocuración

Con el Deployment funcionando (2 réplicas, ambos endpoints respondiendo), se eliminó manualmente uno de los dos Pods:

```bash
kubectl delete pod fastapi-deployment-767b7c5dc4-lfwvv
kubectl get pods
```

Resultado: el Deployment creó automáticamente un Pod de reemplazo (nombre distinto, `AGE` en segundos), mientras el segundo Pod original seguía intacto — confirmando en la práctica que el Deployment mantiene el estado declarado (`replicas: 2`) de forma continua, sin que ninguna lógica de reemplazo esté escrita explícitamente en el manifiesto.

---

## Aprendizajes clave de la fase

- Un `import` de Python se ejecuta al cargar el módulo, no al llamar a la función que lo usa — un `create_engine()` a nivel de módulo puede fallar aunque el endpoint que lo usaría esté comentado.
- La resolución de `host.docker.internal` desde un contenedor anidado (Kind sobre Docker en Linux) no es confiable; la IP real de la LAN del host, contra un puerto explícitamente publicado, es más robusta.
- Un Deployment no reacciona a la muerte de un Pod con lógica puntual: mantiene continuamente el número de réplicas declarado — el mismo mecanismo cubre la muerte de un Pod, de varios, o del nodo entero.
- Separar Secret (sensible, base64) de ConfigMap (no sensible, texto plano) refleja el mismo principio ya aplicado con IAM en AWS: aislar lo que requiere manejo cuidadoso de lo que no.
- Cambios en un ConfigMap o Secret no se propagan a Pods ya corriendo — requieren `kubectl rollout restart` para tomar efecto.
- La fricción encontrada (DNS, puertos, configuración de red) es propia de correr Kubernetes local con una dependencia externa al clúster (Postgres en el host) — no es específica de Kind; Minikube presenta fricciones equivalentes por el mismo motivo estructural.

---

## Pendiente / fuera de alcance de esta fase

- PostgreSQL dentro del propio clúster (como Deployment + Service + PersistentVolume) — se optó por Postgres externo para mantener el foco en los objetos básicos.
- Ingress, Helm, administración multi-nodo, Kubernetes en AWS (EKS) — quedan para una eventual fase futura, después de Terraform y Ansible.