# Fase 8 — Terraform (Infrastructure as Code)

> La infraestructura que en la Fase 5 se construyó a mano en la consola de AWS, reproducida como código versionable, revisable y destruible.

---

## Objetivo de la fase

En la Fase 5 la infraestructura se creó clickeando en la consola: funciona, pero no es reproducible, no deja historial de cambios y no se puede revisar antes de aplicarla. Terraform describe esa misma infraestructura en archivos `.tf` que se versionan en Git como cualquier código.

**Enfoque elegido:** construir todo **en paralelo**, con nombres propios, sin importar ni tocar la infraestructura de producción de la Fase 5. Se descartó `terraform import` sobre producción porque un error de configuración podría modificar o destruir un servicio que funciona. La producción nunca estuvo en el state de Terraform.

Una auditoría de solo lectura hecha con Codex mostró que el primer ejercicio cubría únicamente Security Group + EC2, bastante menos que la Fase 5. Por eso se amplió el alcance.

**Cubre:**

- Red propia: VPC, subnet pública, Internet Gateway, route table y su asociación
- Security Group y EC2 dentro de esa red
- IAM Role con Instance Profile y policy inline acotada a un bucket
- Bucket S3 con versioning y Block Public Access

**No cubre (decisión deliberada):**

- Usuarios, grupos, MFA y root de IAM: son identidades humanas; codificarlas pondría credenciales en el state y un error puede dejar sin acceso a la propia cuenta.
- La instancia de producción y su configuración interna (Nginx, Docker, la aplicación): eso corresponde a la fase de Ansible (Fase 10, después de monitoreo y observabilidad).
- Backend remoto del state, módulos y ejecución de Terraform desde CI.

---

## 1. Qué cambia respecto de un script

Un script (`aws ec2 run-instances ...`) **ejecuta una acción**: correrlo dos veces crea dos instancias. Terraform es **declarativo**: se describe el estado final deseado y Terraform calcula la diferencia mínima contra lo que ya existe.

| Concepto | Qué es |
|---|---|
| **Provider** | Plugin que sabe hablar con la API de una nube (aquí `hashicorp/aws`, versión fijada con `~> 5.0`) |
| **Resource** | Un recurso real que Terraform crea y administra |
| **Data source** | Consulta o cálculo que no crea nada (por ejemplo armar el JSON de una policy) |
| **Variable** | Parámetro configurable; separa configuración de lógica |
| **Output** | Valor que Terraform muestra después de aplicar (IP pública, ID de instancia) |
| **State** | Registro de qué recursos existen realmente; lo que permite calcular el plan |
| **Lock file** | `.terraform.lock.hcl`: fija la versión exacta del provider; **sí se versiona** |

### Flujo de trabajo

```bash
terraform init       # descarga el provider (local, no toca AWS)
terraform fmt        # ordena el formato
terraform validate   # revisa la sintaxis sin tocar AWS
terraform plan       # muestra qué cambiaría, sin cambiar nada
terraform apply      # ejecuta el plan, pide escribir 'yes'
terraform destroy    # destruye todo lo que está en el state
```

La línea que siempre se lee antes de aplicar es el resumen del plan: `Plan: X to add, Y to change, Z to destroy`. Un `destroy` inesperado es la señal para frenar.

Los valores `(known after apply)` son atributos que AWS asigna al crear el recurso (IDs, IP pública). Terraform no puede conocerlos de antemano y los completa después, por eso existe el bloque `output`.

---

## 2. Estructura

```
terraform/
├── main.tf              # provider, Security Group, instancia EC2
├── network.tf           # VPC, subnet, Internet Gateway, route table y asociación
├── iam.tf               # Role, trust policy, policy inline, Instance Profile
├── s3.tf                # Bucket, versioning, Block Public Access
├── variables.tf
├── outputs.tf
├── terraform.tfvars     # valores propios (AMI, key pair, IP) — NO se versiona
└── .terraform.lock.hcl  # versión del provider — SÍ se versiona
```

Excluido del repositorio (`.gitignore`): `terraform.tfvars` (contiene la IP personal), `*.tfstate` y `*.tfstate.*` (pueden contener datos sensibles y no deben versionarse en un repo público) y `.terraform/` (carpeta regenerable con `init`).

Las referencias entre recursos (`aws_vpc.main.id`) forman el **grafo de dependencias**: Terraform crea primero lo que no depende de nada y destruye en el orden inverso. No hace falta indicar el orden a mano.

---

## 3. Primer ejercicio: Security Group + EC2 en la VPC default

`apply`: `2 added`. El primer plan mostró `Plan: 2 to add, 0 to change, 0 to destroy`.

### Diagnóstico por capas con la instancia recién creada

La instancia es Ubuntu sin ningún servicio, con el puerto 80 permitido en el Security Group.

| Prueba | Resultado | Lectura |
|---|---|---|
| `curl` al puerto 80 desde afuera | `Connection refused` en 33 ms | El paquete llegó (el SG lo permitió) y el kernel respondió con RST porque nada escucha en el 80 |
| `ss -tulnp` dentro de la instancia | Solo el 22 (`sshd`) en LISTEN | Confirma desde adentro lo que `curl` mostró desde afuera |

Es el contraste con el incidente #011 (Security Group bloqueando): ahí `curl` esperó 133 segundos. Un fallo instantáneo significa que alguien respondió.

### Cambio de IP y drift

La IP pública cambió y había que actualizar la regla SSH (`/32`). Se modificó **el código** (`terraform.tfvars`), no la consola. Si se cambia a mano en AWS, el siguiente `plan` detecta la diferencia (*drift*) y propone revertir el cambio manual.

```
Plan: 0 to add, 1 to change, 0 to destroy.
~ update in-place  →  aws_security_group.terraform_demo_sg
```

El Security Group conservó su `id` y la instancia no apareció en el plan. Un `-/+` (destruir y recrear) habría cambiado el ID del SG.

### Idempotencia y state

Con el código y la infraestructura ya alineados:

```
No changes. Your infrastructure matches the configuration.
```

Ejecutar `apply` dos veces seguidas no crea nada nuevo. `terraform state list` y `terraform state show` muestran lo que Terraform sabe de cada recurso, incluidos atributos que nunca se escribieron (por ejemplo `http_tokens = "required"`, que confirma IMDSv2 obligatorio por defecto en esta AMI, y `delete_on_termination = true` en el disco raíz).

### Destroy

`terraform destroy` mostró `0 to add, 0 to change, 2 to destroy` y destruyó primero la instancia (20 s) y después el Security Group (1 s). El orden es inverso al de creación: la instancia referencia el ID del SG, y AWS rechazaría borrar un SG que sigue en uso. Terraform solo destruye lo que está en su state: el key pair preexistente y la infraestructura de producción no se tocaron.

---

## 4. 8a — Red propia

Se declaró una VPC `10.0.0.0/16` con una subnet pública `10.0.1.0/24` en `sa-east-1b`, un Internet Gateway, una route table con `0.0.0.0/0 → IGW` y su asociación a la subnet. El rango `10.0.0.0/16` evita cualquier solapamiento con la VPC default (`172.31.0.0/16`), donde vive producción.

Puntos clave:

- **Qué hace pública a una subnet:** el bloque `route { 0.0.0.0/0 → IGW }` más la `aws_route_table_association`. Sin la asociación, la subnet usa la route table principal de la VPC, que no tiene ruta al IGW. Es exactamente la causa del incidente #012.
- `map_public_ip_on_launch = true` solo asigna una IP pública automática; la alcanzabilidad la da la ruta.
- `enable_dns_hostnames = true`: la VPC default lo trae activo, una VPC nueva no, por eso se declara.
- El Security Group necesita `vpc_id` para vivir en la VPC nueva, y la instancia necesita `subnet_id`.

`terraform plan`: `7 to add, 0 to change, 0 to destroy` (5 de red + Security Group + EC2).

**Verificación:**

- La IP privada de la instancia es `10.0.1.225/24`, dentro de la subnet declarada, no de la default (`172.31.x.x`).
- `curl -sI https://example.com` desde la instancia devuelve `HTTP/2 200`: la salida a internet funciona por la ruta al IGW.
- El SSH desde el portátil confirma el sentido de entrada.

---

## 5. 8b — IAM Role, Instance Profile y S3

Nombres propios, distintos de los de producción: Role `ec2-s3-backups-role-tf`, Instance Profile `ec2-s3-backups-profile-tf` y bucket `devops-journey-backups-tf-kadirus01` (los nombres de bucket son únicos a nivel global).

- **Trust policy** (`aws_iam_policy_document`): declara quién puede asumir el Role, solo el servicio EC2.
- **Policy inline** acotada por ARN: `s3:ListBucket` sobre el bucket y `s3:PutObject`, `s3:GetObject` y `s3:DeleteObject` sobre `bucket/*`. Es el mismo principio de mínimo privilegio de la Fase 5.
- **Instance Profile:** en la consola AWS lo crea por detrás; en Terraform es un recurso explícito que muestra que el Role no se asocia directo a la instancia.
- **Bucket:** desde la versión 4 del provider, versioning y Block Public Access son recursos separados.
- **`force_destroy = true`:** solo para laboratorio, para que `destroy` pueda vaciar el bucket versionado. Nunca en un bucket de backups reales, porque borraría los backups.

`terraform plan`: `13 to add` (5 de red + 2 + 6 de este paso) → `Apply complete! Resources: 13 added, 0 changed, 0 destroyed.`

**Verificación del 8b (las cuatro pruebas dieron el resultado esperado):**

| Prueba (dentro de la instancia) | Resultado esperado |
|---|---|
| Consulta de metadata con token IMDSv2 | Devuelve `ec2-s3-backups-role-tf` |
| `aws s3 cp` al bucket `-tf-` | Subida exitosa, sin credenciales almacenadas |
| `aws s3 ls` (todos los buckets) | `AccessDenied` |
| `aws s3 ls` sobre el bucket de producción | `AccessDenied` |

Las dos pruebas negativas importan tanto como la positiva: confirman que la policy quedó acotada a su bucket.

### Cierre: `destroy` y comprobación de residuos

Con las credenciales temporales de `devops-admin` vigentes, `terraform destroy` terminó con `Destroy complete! Resources: 13 destroyed.` (red, instancia, Role, policy, Instance Profile y bucket). Después se comprobó que no quedaba nada: ninguna instancia con el tag `Project = devops-journey-fase8` y `head-bucket` con `404 Not Found`. Un `Destroy complete` indica que se borró lo que estaba en el state, no que AWS esté limpio, por eso se verifica aparte. Por último se soltaron las credenciales (`unset`) y se confirmó que producción seguía respondiendo.

---

## 6. Identidad con la que se ejecuta Terraform

`j-devops` (mínimo privilegio) no puede crear Roles de IAM ni buckets. Dar access keys permanentes de administrador a un portátil es justo el riesgo que se quiere evitar, así que se usaron **credenciales temporales de `devops-admin`**:

```bash
aws login --profile devops-admin
eval "$(aws configure export-credentials --profile devops-admin --format env)"
aws sts get-caller-identity   # confirmar siempre: debe terminar en user/devops-admin
```

- `aws login` autentica en el navegador con las credenciales de consola (MFA incluido) y entrega una sesión temporal.
- `export-credentials` las convierte en variables de entorno que viven solo en esa terminal.
- Se exportan variables en vez de usar `AWS_PROFILE` porque el provider fijado (5.100) es anterior a `aws login` y no se verificó su compatibilidad con ese tipo de sesión.
- Al terminar: `unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`. Tanto `apply` como `destroy` necesitan estas credenciales.

---

## 7. Incidentes de esta fase

Ver el detalle en `runbook.md`.

- **#022** — `apt` rechaza el repositorio de HashiCorp (`NO_PUBKEY`): la clave GPG no se importó correctamente.
- **#023** — IP pública dinámica: la regla SSH del Security Group apuntaba a la IP anterior (corregida por código, plan en `update in-place`).
- **#024** — Terraform/CLI con la identidad equivocada o con la sesión de `aws login` vencida.

---

## Aprendizajes clave de la fase

- IaC es declarativo: se describe el estado final y Terraform calcula la diferencia. Correr `apply` dos veces no duplica nada.
- El código es la fuente de verdad: un cambio manual en la consola genera *drift* y el siguiente `plan` propone deshacerlo.
- Leer el resumen del plan, sobre todo el número de `destroy`, es el hábito central antes de cada `apply`.
- Terraform solo toca lo que está en su state. Construir en paralelo permite practicar sin riesgo sobre lo que ya funciona.
- Qué hace pública a una subnet es la ruta al IGW y su asociación, no un atributo propio de la subnet: ahora se ve explícito en código.
- Cada capacidad de un bucket S3 (versioning, bloqueo público) es un recurso separado; el Instance Profile, que la consola oculta, es un recurso explícito.
- Un fallo instantáneo (`Connection refused`) significa que alguien respondió; un timeout, que nadie lo hizo. Es el mismo método de diagnóstico por capas de la Fase 5.
- Antes de cada `plan` o `apply` conviene confirmar la identidad activa (`aws sts get-caller-identity`) y la IP del `tfvars`.
- Las credenciales de administrador deben ser temporales y vivir solo en la terminal que las necesita.

---

## Pendiente / fuera de alcance de esta fase

- Backend remoto del state (con locking) para trabajo en equipo.
- Módulos para reutilizar bloques de infraestructura.
- Ejecutar `fmt`, `validate` y `plan` en el pipeline de CI sobre cada Pull Request.
- `terraform import` de la infraestructura de producción real.
- Configuración interna de la instancia (instalar Docker, el AWS CLI, desplegar la aplicación): Fase 10, Ansible.
- Restringir el puerto 22 de producción, hoy abierto a `0.0.0.0/0` (en Terraform la regla SSH usa la IP propia con `/32`).