# Versión colaborativa con Supabase — esquema v2

## Archivos
| Archivo | Para qué |
|---|---|
| `01_esquema.sql` | **El único que ejecutas en Supabase** (SQL Editor → pegar todo → Run). |
| `03_parche_admin_desde_sql_editor.sql` | Parche si ya ejecutaste `01_esquema.sql` antes del arreglo: permite usar las funciones `admin_*` desde el SQL Editor. No borra datos. |
| `04_parche_acceso_cartas.sql` | Parche para el acceso a cartas de otras áreas. Ya está dentro de `01_esquema.sql`; ejecútalo solo si corriste el esquema antes de este cambio. No borra datos y se puede repetir. |
| `99_reiniciar_SOLO_PRUEBAS.sql` | Borra todo lo de la app. Úsalo antes de volver a ejecutar el esquema si ya habías ejecutado una versión anterior. |
| `00_simulacion_supabase_SOLO_PRUEBAS.sql`, `02_pruebas_SOLO_LOCAL.sql` | Pruebas en un Postgres local (214 comprobaciones, todas pasan). No ejecutar en Supabase. |

## Modelo de usuarios
- **Administrador general** (`profiles.is_superadmin`): ve todos los eventos y todo su contenido (solo lectura), puede **eliminar eventos**, gestionar miembros, devolver/transferir el cargo de administrador de evento y dar permiso de crear eventos. No edita directorio, asignaciones ni cartas.
- **Evento**: máximo **6 usuarios, 2 por área** (AC, AP, AA). Todos pertenecen a un área.
  - **Administrador del evento** (uno solo): el usuario con permiso `can_create_events` que lo crea; elige su área al crearlo. Puede todo dentro del evento: directorio, jefes de área, presidente, datos, encabezado, invitaciones, miembros.
  - **Editor de área** (los otros 5): asigna solo en departamentos de su área, ve solo las cartas de su área, puede marcar "sin participación" (libres o de su área) y encender/apagar departamentos de su área.
- No hay lectores. Quien no es miembro no ve nada.

## Pasos para empezar
1. Ejecutar `01_esquema.sql`.
2. Crear tu cuenta (Authentication → Users → Add user).
3. Hacerte administrador general: `update public.profiles set is_superadmin = true where email = 'TU_CORREO';`
4. Dar permiso de crear eventos a quien será administrador de evento (también a ti si quieres crear eventos): `update public.profiles set can_create_events = true where email = 'correo';` (la app tendrá un botón para esto).
5. Configurar SMTP propio en Authentication.

## Funciones (RPC) para la app
Editor: `request_letters_access(evento)`
Administrador de evento: `create_event(nombre, área)` · `create_invite(evento, área, días=7, usos=1)` · `accept_invite(código)` · `list_members(evento)` · `transfer_event_admin(evento, usuario)`
Administrador general: `decide_letters_access(evento, usuario, aprobar)` · `admin_events()` (resumen de todos los eventos) · `admin_list_users()` · `admin_set_can_create(usuario, true/false)` · y `delete` directo sobre `events`.
Anti-pausa: `ping()` con la llave anon (`POST /rest/v1/rpc/ping`).
Enlace de WhatsApp: `…/index.html#invitar=<código>`; tras iniciar sesión se llama `accept_invite`.

## Acceso a las cartas de otras áreas
Por defecto un editor ve solo las cartas (estados) de su área. Para ver las demás:
1. El editor llama `request_letters_access(evento)` → queda **pendiente**.
2. El administrador del evento (o el general) llama `decide_letters_access(evento, usuario, true/false)`: aprueba, deniega o revoca. También puede conceder sin solicitud.
3. Con acceso aprobado la persona **solo lee** las cartas de todas las áreas (aparece el selector de área). Marcar estados sigue siendo del administrador del evento y del editor de esa área.
- Dura hasta que se revoque o la persona salga del evento; si le deniegan puede volver a pedir. El permiso es por persona (no se hereda al compañero de área) y se conserva si cambia el administrador.
- La tabla `letter_access` está en Realtime: la insignia de solicitudes del administrador y el selector del editor aparecen sin recargar. La solicitud solo la ven quien la hace, el administrador del evento y el general.
- Al registro de cambios van las aprobaciones y revocaciones, no las solicitudes ni las negativas a una solicitud pendiente.
- Alcance real: las cartas en PDF se generan en el navegador con datos que todos los miembros ya leen (directorio, asignaciones, evento); lo que la base protege es el **seguimiento de estados**. Ocultar los botones de generar/descargar de otras áreas es solo de pantalla.

## Reglas impuestas por la base de datos
- Una persona, una asignación vigente por evento (error `23505`). Un departamento "no presente" conserva sus asignaciones sin contarlas; reactivarlo con conflicto da mensaje claro.
- Cupo: 2 por área (error `23514`), también al aceptar una invitación o mover a alguien de área.
- Un solo administrador por evento; no puede salirse sin transferir el cargo.
- "Sin participación" quita todas las asignaciones de esa persona y bloquea asignarla.
- El registro de cambios lo escribe la base con el usuario real; importaciones y cartas masivas generan una sola línea.
- El estado de la carta se reinicia si cambia la persona del puesto.

## Superadmin que también participa en eventos
Ser administrador general es independiente de ser miembro: puedes crear tus propios eventos (con `can_create_events`) o aceptar invitaciones como editor de área en eventos de otros. En cada evento donde seas miembro tienes los permisos de tu rol ahí; en los demás, solo lectura.

## Decisiones confirmadas / pendientes
1. Solo el administrador general elimina eventos (el administrador del evento no).
2. El administrador general solo lee el contenido, a menos que también sea miembro del evento.
3. El administrador del evento también ocupa una de las 2 plazas de su área.
4. Todos los miembros leen el registro de cambios, el directorio completo y lo necesario para el organigrama y los directorios por departamento. Las cartas: administrador del evento y editor de esa área, más quien reciba acceso aprobado (solo lectura).
5. El nombre del evento nuevo también se usa como nombre de la asamblea (`nombre`).
6. La imagen de encabezado va en `event_header` (máx. ~1.5 MB).

## Notas para la fase 3 (cliente)
- Realtime: los DELETE traen solo las llaves (`event_id`, `slot`/`id`), suficiente para quitar la fila.
- Errores a mapear: `23505` persona ya asignada · `42501` sin permiso · `P0001` invitación caducada/usada · `23514` regla (cupo, cargo, sin participación).
- Eventos locales → nube: insertar `people` con uuid nuevos, luego `assignments`, `dept_presence` y `letter_status` con ese mapa de ids.
