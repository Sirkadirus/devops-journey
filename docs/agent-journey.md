# Agent Journey

## Aprendizajes desde la instalación de Codex hasta su integración en DevOps Journey

**Proyecto:** DevOps Journey
**Objetivo:** Aprender a utilizar agentes de IA como herramientas de desarrollo, operación y razonamiento técnico dentro de un proyecto DevOps real de aprendizaje.

---

## 1. Punto de partida

El objetivo no fue simplemente aprender a utilizar un agente para generar código.

La intención fue entender cómo incorporar agentes de IA dentro de un flujo de trabajo DevOps sin perder comprensión técnica, control ni capacidad de diagnóstico.

El principio adoptado fue:

> **El agente es un multiplicador de capacidades, no un sustituto del conocimiento técnico.**

Por eso, el proyecto DevOps Journey se utiliza como laboratorio para experimentar tanto con tecnologías DevOps como con nuevas formas de trabajar asistidas por agentes.

---

# 2. Instalación de Codex

Se instaló Codex CLI directamente en Ubuntu mediante npm:

```bash
npm install -g @openai/codex
```

Después se verificó la instalación y el entorno.

Se aprendió a distinguir entre:

* instalación global mediante npm;
* ubicación del ejecutable;
* versión de Node.js/npm;
* arquitectura del sistema;
* entorno Linux;
* autenticación de Codex;
* permisos de ejecución del agente.

Codex quedó funcionando desde el directorio del proyecto:

```text
/home/j/devops-journey
```

---

# 3. Autenticación y permisos

Uno de los primeros aprendizajes importantes fue que un agente que puede modificar un proyecto necesita un modelo de permisos.

Se configuró Codex utilizando la cuenta de ChatGPT y se seleccionó un modo conservador:

> **Ask for approval**

Esto significa que el agente puede trabajar dentro del workspace, pero determinadas operaciones requieren aprobación.

Esto permitió comprender una idea importante:

### El agente no debería tener libertad ilimitada por defecto.

El acceso debe limitarse según el riesgo de la operación.

Por ejemplo:

### Bajo riesgo

* leer archivos;
* analizar código;
* revisar documentación;
* buscar inconsistencias.

### Mayor riesgo

* modificar archivos;
* ejecutar comandos;
* instalar dependencias;
* cambiar infraestructura.

### Alto riesgo

* `terraform apply`;
* `terraform destroy`;
* operaciones destructivas de Git;
* cambios fuera del workspace;
* operaciones que puedan afectar infraestructura real.

---

# 4. Contexto del agente: AGENTS.md

Uno de los aprendizajes más importantes fue entender que un agente necesita conocer el contexto y las reglas del proyecto.

Para esto se creó:

```text
AGENTS.md
```

El archivo define cómo debe comportarse el agente dentro de DevOps Journey.

Entre las reglas establecidas están:

* actuar como colaborador técnico y mentor;
* no asumir conocimientos senior;
* inspeccionar antes de actuar;
* explicar razonamiento importante;
* trabajar mediante hipótesis y evidencia;
* no inventar resultados;
* proteger credenciales;
* proponer antes de realizar cambios importantes;
* hacer cambios pequeños;
* verificar después de modificar;
* preservar el valor educativo del proyecto.

El flujo fundamental quedó definido como:

```text
Understand
    ↓
Observe
    ↓
Hypothesis
    ↓
Evidence
    ↓
Test
    ↓
Propose
    ↓
Authorized Change
    ↓
Verify
    ↓
Document
```

Esto cambió la forma de utilizar el agente.

Ya no se trata simplemente de:

> "Hazme esto."

Sino de:

> "Inspecciona, entiende, explica, propone y luego ejecuta el cambio autorizado."

---

# 5. Separación entre ChatGPT y Codex

También se aprendió que no todas las tareas necesitan un agente conectado al repositorio.

Se estableció una división práctica:

### ChatGPT

Para:

* estudiar conceptos;
* diseñar soluciones;
* razonar sobre arquitectura;
* decidir prioridades;
* preparar instrucciones;
* analizar problemas conceptualmente;
* aprender tecnologías.

### Codex

Para:

* inspeccionar el repositorio;
* leer múltiples archivos;
* buscar referencias;
* detectar inconsistencias;
* modificar archivos;
* ejecutar pruebas;
* revisar Git;
* verificar resultados;
* trabajar directamente sobre DevOps Journey.

Esto permite conservar recursos del agente para tareas donde realmente necesita acceso al proyecto.

---

# 6. El agente como herramienta de diagnóstico

Una de las ideas centrales aprendidas fue que el agente no debería utilizarse únicamente como generador de código.

Puede utilizarse como herramienta de diagnóstico.

El enfoque adoptado es:

```text
Síntoma
   ↓
Identificar capa
   ↓
Hipótesis
   ↓
Evidencia
   ↓
Prueba
   ↓
Causa raíz
   ↓
Remediación
   ↓
Verificación
   ↓
Prevención
```

Esto es especialmente importante para un perfil DevOps.

La meta no es que el agente simplemente diga:

> "Cambia esta línea."

La meta es entender:

> "¿Qué está fallando, en qué capa, cómo sabemos que está fallando y cómo verificamos que la solución realmente funciona?"

---

# 7. Uso de Codex sobre el proyecto real

Después de instalarlo, Codex comenzó a trabajar directamente sobre:

```text
/home/j/devops-journey
```

El agente pudo inspeccionar:

* aplicación FastAPI;
* Docker Compose;
* Nginx;
* PostgreSQL;
* GitHub Actions;
* GHCR;
* Kubernetes;
* AWS;
* Terraform;
* documentación;
* estructura Git.

Esto permitió comprobar una diferencia importante entre:

### Conocer un proyecto

y

### Tener un agente que puede inspeccionarlo.

El agente puede recorrer rápidamente el repositorio y construir una imagen del estado actual antes de actuar.

---

# 8. Reorganización de la documentación

Uno de los primeros trabajos importantes realizados con Codex fue una reorganización de la documentación.

Se estableció una separación conceptual:

```text
AGENTS.md
    ↓
Cómo debe trabajar el agente

README.md
    ↓
Qué es el proyecto

docs/
    ↓
Cómo fue construido, operado y evolucionó
```

La documentación se reorganizó en áreas como:

```text
docs/
├── README.md
├── architecture/
│   └── overview.md
├── incidents/
│   ├── 001-connection-refused.md
│   └── incident-history.md      # luego renombrado a runbook.md
├── fase-1-networking.md
├── fase-2-linux-administration.md
├── fase-3-servicios.md
├── fase-4-contenedores.md
├── fase-5-cloud-aws.md
├── fase-6-kubernetes-basico.md
├── fase-7-cicd.md
└── fase-8-terraform.md
```

También se aprendió a distinguir entre:

* instrucciones del agente;
* documentación del proyecto;
* arquitectura;
* historial de incidentes;
* fases de aprendizaje.

---

# 9. Uso correcto de Git con agentes

Otro aprendizaje importante fue que el agente no debe tener libertad para hacer todo el ciclo Git automáticamente.

Se utilizó un proceso controlado:

```text
Inspección
    ↓
Propuesta
    ↓
Staging selectivo
    ↓
Revisión
    ↓
Aprobación
    ↓
Commit
    ↓
Revisión
    ↓
Push
```

Esto permitió aprender una práctica muy importante:

> **El staging funciona como una frontera de seguridad y revisión.**

En lugar de:

```bash
git add .
git commit
git push
```

se utilizaron archivos específicos.

Por ejemplo, durante la reorganización documental se verificó que:

* Terraform no entrara accidentalmente;
* `.gitignore` no entrara;
* `.env` no entrara;
* `terraform.tfvars` no entrara;
* `.terraform/` no entrara;
* ningún state entrara;
* ningún secreto entrara.

---

# 10. Primer commit importante

La reorganización documental fue incorporada mediante:

```text
226991f docs: reorganize project documentation
```

Después se detectó una inconsistencia entre el README y el alcance real de Terraform.

En lugar de ignorarla, se utilizó el agente para:

1. localizar la afirmación;
2. comprobar el estado real;
3. modificar únicamente la línea necesaria;
4. revisar el diff;
5. ejecutar `git diff --check`;
6. hacer staging únicamente del README;
7. crear un commit independiente.

El resultado fue:

```text
3c616eb docs: align Terraform phase description
```

Esto enseñó otro principio:

> **La documentación debe representar el estado real del sistema, no el estado que pretendemos tener en el futuro.**

---

# 11. Auditoría de Terraform con Codex

El siguiente paso fue utilizar Codex como auditor técnico en modo READ-ONLY.

Se le pidió explícitamente:

* no modificar archivos;
* no ejecutar `terraform apply`;
* no ejecutar `terraform destroy`;
* no hacer commit;
* no hacer push;
* inspeccionar únicamente.

La auditoría encontró que Terraform actualmente contiene:

```text
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
└── .terraform.lock.hcl
```

La infraestructura actual está centrada en:

```text
Security Group
       ↓
     EC2
```

con variables para:

* región;
* AMI;
* tipo de instancia;
* key pair;
* IP/CIDR de SSH.

Y outputs para:

* IP pública;
* ID de instancia.

La auditoría también determinó que todavía no están representados mediante Terraform:

* VPC;
* subnet;
* route table;
* Internet Gateway;
* Nginx;
* FastAPI;
* PostgreSQL;
* IAM;
* S3.

Esto permitió evitar una conclusión equivocada:

> "Como ya tengo Terraform, tengo toda mi infraestructura como código."

La realidad es que actualmente tenemos una **introducción práctica a IaC**, no una reproducción completa de la arquitectura AWS.

> **Actualización (Fase 8 cerrada, `v0.8`):** esta auditoría motivó ampliar el alcance. Terraform pasó a reproducir la Fase 5 completa: VPC, subnet pública, Internet Gateway, route table, Security Group, EC2, IAM Role con Instance Profile y bucket S3 (13 recursos), en paralelo a producción. Nginx, FastAPI y PostgreSQL siguen fuera de Terraform: su configuración corresponde a la fase de Ansible. Ver [`fase-8-terraform.md`](./fase-8-terraform.md).

---

# 12. Seguridad y control de secretos

Durante el trabajo con agentes también se aprendió a diferenciar archivos que deben versionarse de archivos que deben permanecer locales.

### Versionables

```text
*.tf
.terraform.lock.hcl
```

### No versionables

```text
terraform.tfvars
.terraform/
*.tfstate
*.tfstate.backup
.env
credenciales
claves privadas
```

También se aprendió que un `key_pair_name` de AWS no es una clave privada.

Terraform puede referenciar el nombre de un key pair sin almacenar la clave privada dentro del repositorio.

---

# 13. Qué aprendí sobre Terraform gracias al agente

El objetivo no fue memorizar cada argumento de Terraform.

El aprendizaje principal fue entender:

### Terraform es declarativo

Se describe el estado deseado y Terraform calcula las acciones necesarias.

### Variables

Permiten separar configuración del código.

### Resources

Representan infraestructura.

### Outputs

Exponen información útil después de crear recursos.

### Provider

Conecta Terraform con AWS.

### Lockfile

Permite controlar la versión concreta del provider utilizada.

### State

Terraform necesita mantener información sobre los recursos que administra.

### Plan

Permite revisar qué pretende cambiar Terraform antes de aplicarlo.

### Apply

Ejecuta los cambios aprobados.

El agente ayuda a escribir y revisar Terraform, pero el objetivo es que yo pueda explicar **qué está haciendo y por qué**.

---

# 14. Principio aprendido: no automatizar por automatizar

Una de las conclusiones más importantes de este proceso fue que utilizar agentes no significa delegar absolutamente todo.

El criterio aprendido es:

> **Automatizar cuando aumenta la capacidad, reduce trabajo repetitivo o mejora la confiabilidad; mantener bajo control humano las decisiones importantes.**

Por eso:

```text
Agente
  ↓
Analiza
  ↓
Propone
  ↓
Ejecuta cambios autorizados
  ↓
Verifica
```

en lugar de:

```text
Agente
  ↓
Hace todo automáticamente
```

---

# 15. Resultado obtenido

Al finalizar esta etapa, DevOps Journey ya no es solamente un proyecto para practicar:

* Linux;
* Docker;
* AWS;
* Kubernetes;
* CI/CD;
* Terraform.

También se convirtió en un laboratorio para aprender:

* interacción con agentes;
* contexto de agentes;
* control de permisos;
* revisión de cambios;
* diagnóstico asistido;
* Git como mecanismo de recuperación;
* documentación asistida;
* auditorías READ-ONLY;
* automatización segura;
* separación entre análisis y ejecución;
* verificación de resultados.

---

# 16. Competencia adquirida

La habilidad que estoy desarrollando no es simplemente:

> "Sé utilizar Codex."

Es:

> **"Sé integrar un agente de IA dentro de un flujo técnico controlado para inspeccionar, diagnosticar, modificar, verificar y documentar un sistema DevOps."**

Esto es especialmente relevante para mi objetivo profesional porque conecta directamente:

```text
Linux
+
Cloud
+
Infrastructure
+
Git
+
CI/CD
+
Automation
+
Troubleshooting
+
AI Agents
```

---

# 17. Próximo nivel

> **Nota:** el paso siguiente descrito aquí ya se cumplió. Terraform fue incorporado al repositorio con staging selectivo y revisión de diff (Fase 8). El próximo frente de trabajo con agentes es monitoreo y observabilidad.

El siguiente paso será incorporar Terraform al repositorio de forma controlada.

Primero:

```text
Auditar
  ↓
Stage selectivo
  ↓
Revisar diff
  ↓
Commit
```

Después podremos seguir utilizando agentes para:

* diagnóstico de incidentes;
* revisión de infraestructura;
* análisis de CI/CD;
* troubleshooting;
* pruebas;
* documentación;
* evolución de Terraform;
* automatización de tareas repetitivas.

La meta final sigue siendo la misma:

> **Utilizar IA para aumentar mi capacidad técnica sin perder la comprensión de los sistemas que estoy construyendo y operando.**