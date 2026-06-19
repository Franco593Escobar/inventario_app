---
name: inventario-architect-continuity
description: "Analiza proyectos Flutter con arquitectura por capas (core/data/domain/presentation), mapea modulos existentes y propone continuidad limpia sin modificar codigo existente. Usar para auditoria arquitectonica, onboarding tecnico, plan de expansion CRUD y checklist de produccion por modulo."
argument-hint: "Indica proyecto, objetivo y nivel de detalle: rapido, medio o profundo."
user-invocable: true
---

# Inventario Architect Continuity

## Resultado Que Produce

- Diagnostico de arquitectura actual sin cambios en codigo.
- Inventario de modulos y estado de capas por modulo.
- Plan de continuidad para construir sobre lo existente.
- Checklist de validacion tecnica por modulo (incluye `flutter analyze` por archivo como paso obligatorio).

## Modo Hibrido Recomendado

- Base generica reutilizable para cualquier proyecto Flutter.
- Bloque opcional para proyectos tipo Inventario App con roles, tenant y branding por comercio.
- Si no existen roles/tenant, el skill omite ese bloque sin romper el flujo principal.

## Cuando Usarlo

- Necesitas continuar un sistema existente sin romper estructura.
- Quieres estandarizar nuevos modulos CRUD sobre un patron ya creado.
- Debes evaluar calidad y completitud por capas antes de implementar.
- Quieres una guia de Arquitecto de Software para Flutter + Firebase.

## Entradas Minimas

- Nombre del proyecto.
- Objetivo de continuidad (que modulo o dominio sigue).
- Restriccion de no modificar codigo existente (si aplica).
- Alcance: diagnostico, plan, checklist o todo.

## Flujo De Trabajo

1. Levantar contexto del workspace.
2. Detectar arquitectura y capas reales (`core`, `data`, `domain`, `presentation`).
3. Mapear modulos de negocio existentes por carpeta y por repositorio.
4. Revisar consistencia de nombres entre modelos, repositorios y pantallas.
5. Detectar huecos (por ejemplo: `domain/usecases` vacio, pantallas faltantes o repos sin uso).
6. Identificar patrones reutilizables de UI y estado (providers, shells, widgets comunes).
7. Proponer continuidad sin refactor destructivo: extender patron actual modulo por modulo.
8. Entregar checklist de salida por modulo con validaciones tecnicas y funcionales.

## Decisiones Y Ramas

- Si el usuario pide "sin modificar": solo analisis, plan y checklist.
- Si el proyecto tiene patron de UI reusable: priorizarlo para nuevos modulos.
- Si `domain` esta incompleto: recomendar casos de uso nuevos sin tocar lo existente.
- Si hay inconsistencia de nombres: proponer estandar para siguientes modulos, sin reescritura masiva.
- Si es multi-tenant o por roles: validar permisos y rutas por rol antes de extender modulos.

## Matriz De Severidad Para Deuda Tecnica

- Alto: rompe flujo principal, compromete datos o permisos, bloquea despliegue.
- Medio: afecta mantenibilidad, genera riesgo de regresion o inconsistencias entre capas.
- Bajo: mejoras de estilo, estructura o trazabilidad sin impacto funcional inmediato.

## Checklist De Modulo CRUD Listo Para Produccion

- Modelo en `data/models` definido y validado.
- Repositorio en `data/repositories` con operaciones CRUD completas.
- Provider/presenter con estados de carga, error y exito.
- Pantalla en `presentation/screens/<modulo>/` con:
  - listado
  - creacion
  - edicion
  - eliminacion con confirmacion
  - filtros o busqueda (si aplica)
- Reutiliza widgets base del proyecto (shell/layout/controles comunes).
- Control de permisos por rol (si aplica).
- Manejo de errores amigable y mensajes de usuario.
- Validacion estatica obligatoria:
  - `flutter analyze lib/data/models/<archivo>.dart`
  - `flutter analyze lib/data/repositories/<archivo>.dart`
  - `flutter analyze lib/presentation/providers/<archivo>.dart`
  - `flutter analyze lib/presentation/screens/<modulo>/<archivo>.dart`
- Smoke test manual del flujo principal (crear, listar, editar, eliminar).

## Formato De Salida Recomendado

1. Estado actual (resumen por capas).
2. Modulos detectados y grado de completitud.
3. Riesgos de continuidad y deuda tecnica priorizada por severidad (alto/medio/bajo).
4. Plan incremental en fases (sin romper lo existente).
5. Checklist aplicado y estado final por modulo.

## Bloque Opcional Inventario App

- Verificar roles operativos y administrativos antes de abrir accesos CRUD.
- Confirmar aislamiento por tenant/sucursal en consultas y filtros.
- Validar consistencia de branding (color primario/logo) en pantallas nuevas.
- Revisar navegacion por dashboard segun rol sin mezclar vistas de superadmin y staff.

## Restricciones Operativas

- No modificar archivos salvo que el usuario lo solicite explicitamente.
- Evitar cambios masivos no justificados.
- Preservar patrones ya adoptados por el proyecto.
- Reportar supuestos cuando falte contexto.

## Prompt De Ejemplo

`/inventario-architect-continuity Analiza mi workspace Flutter, mapea modulos existentes y define plan para agregar modulo de compras siguiendo el patron actual, sin modificar codigo existente.`
