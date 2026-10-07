# Fase 8 — Terraform

> Estado documentado: en progreso. Esta página describe únicamente la configuración Terraform presente en el checkout; no afirma que se haya aplicado ni que reproduzca toda la infraestructura AWS de Fase 5.

## Configuración observada

El proveedor requerido es `hashicorp/aws` en la rama de versión `~> 5.0`; la región se configura con `aws_region` (por defecto `sa-east-1`). La configuración declara:

- un Security Group con SSH limitado al CIDR indicado por `my_ip`, HTTP desde `0.0.0.0/0` y egress permitido;
- una instancia EC2 que usa `ami_id`, `instance_type` (por defecto `t3.micro`), el Security Group anterior y un key pair existente;
- outputs para la IP pública y el ID de instancia.

Variables y recursos están definidos en `terraform/variables.tf` y `terraform/main.tf`; los outputs, en `terraform/outputs.tf`. Hay un lockfile del proveedor. Los valores locales de variables no se reproducen aquí.

## Alcance y límites

La configuración observada no declara explícitamente VPC, subnet, route table, Internet Gateway, IAM, S3 ni instalación/configuración de la aplicación. Por ello, no equivale por sí sola a la arquitectura AWS descrita en Fase 5. La fase puede ampliar ese alcance posteriormente; no se infiere aquí una decisión de diseño futura.

Los archivos Terraform están sin seguimiento Git en el estado inspeccionado. No se ejecutaron `terraform init`, `validate`, `plan` ni `apply`; no se afirma que la configuración haya sido validada o aplicada.

## Conceptos de Terraform

La configuración (`.tf`), el estado de Terraform y los recursos reales son cosas distintas. Un plan permite revisar los cambios propuestos antes de una aplicación; cualquier aplicación de recursos AWS requiere identificar cuenta, región, costo, permisos, impacto de red, recuperación y autorización explícita.

El flujo de aprendizaje documentado es `terraform fmt`, `terraform init`, `terraform validate`, `terraform plan` y, después de revisar el plan y contar con autorización, `terraform apply`. `terraform destroy` es destructivo y requiere autorización explícita. Ninguno de esos comandos se ejecutó durante esta reorganización.
