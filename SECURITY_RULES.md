# SECURITY_RULES

Guia operativa de seguridad para pre-release en inventario_app.

## Objetivo

Implementar aislamiento estricto por tenant y control de acceso por rol en cliente y servidor.

## Principios obligatorios

1. Server-side primero: las reglas de Firestore son la autoridad final.
2. Deny-by-default: toda ruta no permitida explicitamente queda denegada.
3. Tenant isolation: toda lectura/escritura de datos de negocio valida tenant_id contra el tenant del usuario autenticado.
4. Least privilege: cada rol tiene el minimo acceso necesario.
5. Inmutabilidad de tenant: un documento no puede cambiar de tenant_id en updates.

## Fuente autorizada de identidad y contexto

1. request.auth.uid (Firebase Authentication) identifica al usuario.
2. usuarios/{uid} es la fuente de verdad de:
   - estado_activo
   - rol
   - tenant_id
3. Si no existe usuarios/{uid}, el acceso Firestore debe ser denegado.

## Matriz de permisos por rol

### superadmin

1. Acceso global multi-tenant.
2. Puede leer/escribir configuracion global y cualquier tenant.
3. Puede gestionar usuarios de cualquier tenant.

### admin

1. Acceso total dentro de su tenant.
2. Puede gestionar usuarios de su tenant (excepto crear superadmin).
3. Puede gestionar catalogos/configuracion de su tenant.

### empleado / vendedor / cajero / bodeguero

1. Lectura de datos del tenant.
2. Escritura operativa limitada al tenant (ventas, ordenes, movimientos permitidos segun flujo).
3. Sin gestion administrativa de usuarios ni de tenant.

## Reglas de diseno de repositorios (cliente)

1. Toda consulta de negocio debe incluir where('tenant_id', isEqualTo: auth.tenantId).
2. Nunca exponer metodos globales en modulos de operacion de tenant.
3. En writes, enviar tenant_id obligatorio y consistente con auth.tenantId.
4. No confiar en validaciones de UI para seguridad; solo para UX.

## Reglas de presentacion (UI)

1. Ocultar acciones segun rol para reducir errores de operacion.
2. Validar rol antes de acciones sensibles (doble validacion UX).
3. No mostrar datos de otros tenant ni en filtros ni en widgets resumen.

## Checklist pre-release de seguridad

1. Firestore Rules deployadas y versionadas.
2. FirebaseAuth obligatorio para login (sin bypass por password en documento).
3. usuarios/{uid} consistente para todos los usuarios activos.
4. tenant_id presente en colecciones de negocio.
5. Pruebas manuales de acceso cruzado (tenant A intentando leer/escribir tenant B).
6. Pruebas de rol (empleado intentando operacion admin).
7. Revisar logs de permission-denied y corregir rutas no contempladas.

## Politica de PR (obligatoria)

Rechazar PR si se incumple cualquiera de los siguientes puntos:

1. Agrega un nuevo modulo multi-tenant sin tenant_id.
2. Crea consultas Firestore sin filtro de tenant cuando aplica.
3. Introduce bypass de autenticacion/rol en cliente.
4. Cambia reglas sin actualizar esta guia.

## Notas de migracion

1. El sistema requiere usuarios autenticados por FirebaseAuth.
2. El doc usuarios/{uid} debe existir y reflejar el rol/tenant correctos.
3. Si hay usuarios legacy sin uid alineado, migrar antes de endurecer reglas en produccion.
