# Documentación de DevOps Journey

Este directorio reúne arquitectura, operación, registros históricos de incidentes y el recorrido educativo del proyecto.

- [Arquitectura](architecture/overview.md): topologías y estado documental por entorno.
- [Incidentes](incidents/): registros históricos; `incident-history.md` conserva el runbook original completo y `001-connection-refused.md` es el registro individual existente.
- **Operaciones:** no hay todavía un `operations/runbook.md` separado. El archivo original contiene incidentes históricos, no procedimientos reutilizables independientes.
- **Fases:** [Networking](fase-1-networking.md), [Linux](fase-2-linux-administration.md), [Servicios](fase-3-servicios.md), [Contenedores](fase-4-contenedores.md), [AWS](fase-5-cloud-aws.md), [Kubernetes](fase-6-kubernetes-basico.md), [CI/CD](fase-7-cicd.md) y [Terraform](fase-8-terraform.md).

La documentación de fases conserva el aprendizaje y el contexto histórico. La configuración fuente del comportamiento actual se encuentra en los archivos de código y configuración del repositorio; su presencia no demuestra que un servicio o recurso esté activo en runtime.
