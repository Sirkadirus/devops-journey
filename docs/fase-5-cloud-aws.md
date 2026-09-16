# Fase 5 — Cloud & AWS

> Migración del proyecto DevOps Journey desde infraestructura local (Docker Compose en laptop) hacia AWS, con foco en IAM, networking (VPC) y almacenamiento (S3) bajo el principio de mínimo privilegio.

---

## Objetivo de la fase

Llevar el mismo stack (Nginx → FastAPI → PostgreSQL) que ya corría localmente hacia una instancia EC2 real, pública, y construir alrededor de esa instancia un modelo de seguridad e identidad acorde a lo que se espera en un entorno profesional: usuarios diferenciados por propósito, roles sin credenciales hardcodeadas, y accesos acotados por recurso específico, no por conveniencia.

Alcance cubierto:

1. IAM (Users, Groups, Roles, políticas)
2. VPC
3. Subnets
4. Route Tables
5. Internet Gateway
6. Security Groups
7. EC2
8. S3

Quedan fuera de esta fase, deliberadamente: CloudWatch avanzado (ya cubierto de forma básica con un billing alarm + SNS) y RDS (no estaba en el roadmap original; el proyecto sigue con PostgreSQL corriendo dentro de la propia EC2).

---

## 1. Modelo de identidades IAM

### Por qué no se usa un solo usuario para todo

AWS distingue dos tipos de identidad relevantes para este proyecto:

- **IAM User**: representa una persona o proceso identificable de forma permanente, con credenciales fijas.
- **IAM Role**: no tiene credenciales permanentes. Es asumido temporalmente por una entidad autorizada (una instancia EC2, por ejemplo), y AWS entrega credenciales que expiran solas y se renuevan automáticamente.

El **root** de la cuenta es una identidad aparte: no se puede restringir con policies, no admite límites de permisos, y su compromiso implica pérdida total de control sobre la cuenta. Por eso se reserva para el puñado de tareas que ni siquiera `AdministratorAccess` puede hacer (gestión de facturación, cierre de cuenta), y se mantiene fuera del uso diario.

### Jerarquía implementada

```
root
  ↓ (solo tareas irreemplazables — uso excepcional)
devops-admin (AdministratorAccess + MFA)
  ↓ (tareas administrativas puntuales: otorgar permisos a otros usuarios)
j-devops, en grupo devops-lab (mínimo privilegio + MFA)
  ↓ (trabajo operativo diario: EC2, S3 acotado)
ec2-s3-backups-role
  ↓ (asumido por la instancia EC2, sin credenciales expuestas)
```

**`devops-admin`** se creó porque `j-devops` no puede modificar sus propios permisos de IAM (`iam:AttachGroupPolicy` no está entre sus policies, por diseño). En vez de resolver esto con root para cada cambio de permisos, se creó un segundo IAM User con `AdministratorAccess`, MFA obligatorio, y uso exclusivo para tareas administrativas puntuales — nunca como sesión de trabajo diario. Esto es la práctica estándar de AWS: mantiene la trazabilidad en CloudTrail bajo un usuario nombrado (no root), permite revocación instantánea, y no compromete el control total de la cuenta si sus credenciales se vieran expuestas.

**`j-devops`** (grupo `devops-lab`) mantiene el principio de mínimo privilegio: solo tiene los permisos que su trabajo diario requiere en cada momento — `AmazonEC2FullAccess`, `IAMReadOnlyAccess`, y una policy inline acotada a un único bucket S3.

### Policy inline de S3, acotada por recurso

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSpecificBucketOnly",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::devops-journey-backups-kadirus01",
        "arn:aws:s3:::devops-journey-backups-kadirus01/*"
      ]
    }
  ]
}
```

Nota de sintaxis: se necesitan dos ARN distintos porque `ListBucket` opera sobre el bucket como recurso (sin `/*`), mientras que las acciones sobre objetos (`PutObject`, `GetObject`, `DeleteObject`) requieren el sufijo `/*`.

Esta policy fue verificada en ambos sentidos: `j-devops` puede operar sobre el bucket (subida de objeto confirmada), pero **no** puede listar todos los buckets de la cuenta (`s3:ListAllMyBuckets` denegado, por no estar incluido) — confirmando que el acceso está acotado al recurso específico, no a S3 en general.

---

## 2. VPC, Subnets, Route Tables e Internet Gateway

### VPC como red aislada propia

Una VPC (Virtual Private Cloud) es una red privada y lógicamente aislada dentro de AWS, con rango de IPs propio (CIDR block) y control total sobre subnets y enrutamiento. Toda instancia EC2 vive dentro de una VPC — en este proyecto, la VPC default de la cuenta (`172.31.0.0/16`).

### El hallazgo clave: "subnet pública" no es un atributo de la subnet

Una subnet no tiene ningún campo de configuración que la marque como "pública". Lo que determina su comportamiento es exclusivamente su **route table**: si tiene una entrada `0.0.0.0/0 → igw-xxxxx` (apuntando a un Internet Gateway), es efectivamente pública. Si esa entrada no existe, la subnet es privada, sin importar si las instancias dentro tienen IP pública asignada.

Esto se verificó con evidencia real: `172.31.16.0/20` (la subnet de producción, en `sa-east-1b`) tiene la ruta al IGW `igw-032ba62fecc6d3722`, y es alcanzable desde internet. Una segunda subnet, `172.31.32.0/20`, creada deliberadamente **sin** esa ruta (solo con la ruta local automática de la VPC), resultó completamente inalcanzable desde fuera — incluso con una instancia dentro configurada con IP pública asignada (ver Incidente #012).

### Internet Gateway

El IGW es el componente que conecta la VPC con internet. Sin una ruta hacia él en la route table de una subnet, ningún tráfico externo puede completar el camino hacia una instancia en esa subnet, más allá de que la instancia tenga o no una IP pública asignada. Tener IP pública y ser alcanzable desde internet son dos cosas independientes.

---

## 3. Security Groups: stateful, y con drop silencioso

### Security Group vs. Network ACL

| | Security Group | Network ACL (NACL) |
|---|---|---|
| Nivel | Instancia (EC2) | Subnet completa |
| Estado | Stateful — la respuesta a tráfico permitido se autoriza automáticamente | Stateless — hay que permitir entrada y salida por separado |
| Reglas | Solo ALLOW (todo lo no permitido se deniega implícitamente) | ALLOW y DENY explícitos, evaluados en orden numérico |
| Alcance | Solo las instancias asignadas | Todo lo que esté en la subnet |

Este proyecto usa la NACL default de la VPC, sin modificar, y Security Groups personalizados como capa de control real.

### Comportamiento ante un bloqueo: DROP silencioso, no REJECT

Un Security Group que bloquea un puerto no responde con un error — descarta el paquete en el borde de red de AWS sin avisar al cliente. Comprobado eliminando temporalmente la regla del puerto 80 (Incidente #011): el cliente no recibe ningún error inmediato, sino que queda esperando hasta agotar su propio timeout de conexión (~130 segundos).

### Comparación de síntomas según capa de fallo

| Escenario | ¿Llega el paquete a la instancia? | ¿Quién responde? | Respuesta al cliente | Tiempo de fallo |
|---|---|---|---|---|
| Security Group bloquea el puerto | No | Nadie (drop en el borde de AWS) | Ninguna | ~130s (timeout del cliente) |
| Route table sin ruta al IGW | No | Nadie (el paquete no completa el camino hacia/desde la subnet) | Ninguna | Timeout (mismo síntoma, distinta causa) |
| Servicio caído, SG y route table OK | Sí | Kernel Linux (sin proceso en LISTEN) | TCP RST | Instantáneo |
| Servicio activo, backend caído | Sí | Nginx (reverse proxy sin respuesta del backend) | HTTP 502 | Instantáneo |

Dos causas distintas (Security Group vs. route table) producen el mismo síntoma externo (timeout), pero se ubican en capas distintas del recorrido: la route table actúa **antes** de que el paquete llegue a evaluarse contra el Security Group.

### Método de diagnóstico: de afuera hacia adentro y de adentro hacia afuera

1. Desde fuera: `curl -v http://<IP_PUBLICA>/health`
2. Desde dentro (SSH): `ss -tlnp` para confirmar si el proceso está en LISTEN localmente

Interpretación: si `ss -tlnp` confirma el proceso en LISTEN pero `curl` externo da timeout, el bloqueo está en la capa de red de AWS (Security Group o route table), no en la instancia. Si `ss -tlnp` no muestra nada, el problema es local, independiente de AWS.

Nota: `ping` no sirve para este diagnóstico porque usa ICMP, no TCP — un Security Group (o una ruta faltante) puede afectar de forma distinta a ICMP y a TCP según las reglas configuradas.

---

## 4. EC2 y el Instance Metadata Service (IMDSv2)

La instancia de producción corre Ubuntu 24.04 en `t3.micro`, región `sa-east-1`, con el stack completo Nginx/FastAPI/PostgreSQL.

### IMDSv1 vs. IMDSv2

El servicio de metadata de la instancia (`169.254.169.254`, solo alcanzable desde dentro) tiene dos formas de consultarse:

- **IMDSv1**: `GET` directo, sin pasos previos.
- **IMDSv2**: requiere primero un `PUT` para obtener un token, y usar ese token como header en el `GET` posterior. Es el default en instancias modernas, y existe para mitigar ataques SSRF (Server-Side Request Forgery) — con IMDSv2, una vulnerabilidad de SSRF típica ya no alcanza para robar credenciales, porque el paso `PUT` es mucho más difícil de forzar a través de ese vector.

Confirmado en la práctica (Incidente #013): un intento de consulta vía IMDSv1 devolvió `401 Unauthorized`; el flujo correcto con token resolvió la consulta exitosamente.

```bash
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

---

## 5. IAM Role para EC2: credenciales sin secretos

### El problema que resuelve

Sin un IAM Role asociado, la única forma de que la instancia EC2 pudiera hablar con S3 sería incluir access keys de un IAM User dentro de la instancia (variable de entorno, `.env`, o código) — un secreto permanente que, si la instancia se ve comprometida, queda expuesto sin fecha de expiración.

Un IAM Role asociado vía **Instance Profile** resuelve esto: la instancia obtiene credenciales temporales automáticamente a través del Instance Metadata Service, sin que ningún secreto se escriba a mano en ningún archivo.

### Implementación

- Role `ec2-s3-backups-role`, con AWS EC2 como entidad de confianza (trust policy), de forma que únicamente instancias EC2 pueden asumirlo.
- Policy adjunta idéntica en alcance a la de `j-devops`: acotada al bucket `devops-journey-backups-kadirus01` exclusivamente.
- Asociado a la instancia de producción vía **Modify IAM role**, sin necesidad de reinicio — la asociación de un Role es una operación de metadata, no afecta procesos en ejecución.

### Verificación end-to-end

Desde dentro de la instancia, sin ningún `aws configure` ni credencial explícita:

```bash
echo "test backup $(date)" > /tmp/test-backup.txt
aws s3 cp /tmp/test-backup.txt s3://devops-journey-backups-kadirus01/ --region sa-east-1
```

Resultado: subida exitosa. El AWS CLI detectó automáticamente las credenciales temporales del Role vía el Instance Metadata Service, confirmando el flujo completo:

```
EC2 → Instance Profile → IAM Role → credenciales temporales (IMDSv2) → S3 (bucket acotado)
```

---

## 6. S3

Bucket `devops-journey-backups-kadirus01`, región `sa-east-1` (misma región que la instancia, para evitar latencia y complejidad innecesaria).

Configuración:
- **Block Public Access**: habilitado en su totalidad — este bucket es para backups internos, nunca debería exponerse públicamente.
- **Versioning**: habilitado — permite recuperar una versión anterior si un backup corrupto sobrescribe uno válido.
- **Acceso**: exclusivamente vía policy acotada por ARN de recurso, tanto para `j-devops` como para el Role de la instancia. Ningún acceso público, ninguna policy de bucket adicional.

---

## Incidentes de esta fase

Ver detalle completo en `runbook.md`. Resumen:

- **#011** — Security Group sin regla para el puerto 80 → timeout de 133s por drop silencioso, contrastado con RST (servicio caído) y 502 (backend caído).
- **#012** — Subnet sin ruta al Internet Gateway → instancia con IP pública asignada, igualmente inalcanzable. Confirma que "pública" depende de la route table, no de la subnet en sí.
- **#013** — Consulta al Instance Metadata Service vía IMDSv1 → `401 Unauthorized`. Resuelto con el flujo de token de IMDSv2.

---

## Aprendizajes clave de la fase

- El estado "público" de una subnet es enteramente una función de su route table, no un atributo propio.
- Un Security Group bloqueado produce un timeout silencioso (DROP a nivel de red); un servicio caído produce un RST instantáneo (a nivel de kernel); un backend inalcanzable detrás de un reverse proxy produce un 502 instantáneo (a nivel de aplicación). Tres capas, tres síntomas distintos, mismo principio de diagnóstico por capas que en networking clásico.
- IAM User (credenciales permanentes) e IAM Role (credenciales temporales asumidas) resuelven problemas distintos: identidad de persona vs. identidad de proceso/máquina.
- Un IAM User no puede modificar sus propios permisos de IAM — es una restricción de diseño, no una limitación a resolver con root.
- IMDSv2 antepone un paso de token (PUT) al GET de metadata, mitigando SSRF frente a IMDSv1.
- El principio de mínimo privilegio se verifica probando tanto lo que debería funcionar como lo que debería seguir bloqueado — no alcanza con confirmar el caso positivo.

---

## Pendiente / fuera de alcance de esta fase

- CloudWatch avanzado (dashboards, métricas custom) — cubierto solo a nivel básico (billing alarm + SNS).
- RDS — no estaba en el roadmap original de esta fase; PostgreSQL sigue corriendo dentro de la instancia EC2. Queda como candidato para una fase futura si se decide migrar la base de datos a un servicio administrado.
- Decisión de reordenamiento de roadmap (Kubernetes básico vs. Terraform/Ansible) — explícitamente diferida, a revisar ahora que Fase 5 está cerrada.