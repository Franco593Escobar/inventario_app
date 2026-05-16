# inventario_app

Aplicacion Flutter para gestion de inventario con autenticacion propia basada en Cloud Firestore.

## Estado actual

- Inicio de sesion funcional contra la coleccion `usuarios`.
- Resolucion de pantalla inicial segun rol autenticado.
- Panel inicial para `superadmin` con accesos principales del sistema.
- Ejecucion validada en web usando `localhost:8080`.

## Flujo de autenticacion

El login consulta la coleccion `usuarios` en la base de Firestore nombrada `inventario-bdd`.

Campos esperados por usuario:

- `nombre_usuario`
- `password`
- `estado_activo`
- `rol`
- `nombres`

Si el usuario se autentica correctamente:

- `superadmin` entra al panel principal de administracion.
- Otros roles usan una vista autenticada base mientras se implementan sus modulos.

## Ejecucion en web

1. Instala dependencias con `flutter pub get`.
2. Ejecuta la app con `flutter run -d web-server --debug --web-port 8080`.
3. Abre `http://localhost:8080`.

## Notas tecnicas

- Firebase se inicializa una sola vez en `main.dart`.
- La consulta de autenticacion usa la base Firestore nombrada `inventario-bdd`.
- El panel `superadmin` actual muestra accesos base y deja listos los puntos de extension para los modulos reales.
