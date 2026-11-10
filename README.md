# Organización de Asamblea Regional

Aplicación web (PWA) para organizar una asamblea regional: directorio de personas, asignación por áreas y departamentos, organigrama, directorios imprimibles y cartas de invitación en PDF.

Funciona en el navegador, se puede instalar en el celular o la computadora y **trabaja sin internet** después de la primera visita. No necesita servidor: los datos se guardan en el propio dispositivo.

> Los datos **no se sincronizan** entre dispositivos. Para pasarlos de uno a otro se usan los respaldos (ver [Respaldos](#respaldos)). Una versión colaborativa está en planeación.

---

## Contenido

- [Primeros pasos](#primeros-pasos)
- [Guía de uso paso a paso](#guía-de-uso-paso-a-paso)
- [Qué hace cada pestaña](#qué-hace-cada-pestaña)
- [Cartas de invitación](#cartas-de-invitación)
- [Respaldos](#respaldos)
- [Privacidad](#privacidad)
- [Preguntas frecuentes](#preguntas-frecuentes)

Para publicar y mantener la aplicación en GitHub Pages, consulta [`MANTENIMIENTO.md`](MANTENIMIENTO.md).

---

## Primeros pasos

1. Abre la dirección de la aplicación (`https://TU-USUARIO.github.io/NOMBRE-DEL-REPO/`).
2. Para instalarla:
   - **Android / Chrome / Edge:** menú del navegador → *Instalar aplicación*.
   - **iPhone / iPad (Safari):** botón *Compartir* → *Agregar a pantalla de inicio*.
3. Se ve en modo claro u oscuro según la configuración del dispositivo.

## Guía de uso paso a paso

1. **Asamblea:** captura el nombre, las fechas, el lugar y el código de los archivos. Elige el encabezado de las cartas y, si quieres, escribe *Tu nombre* para el registro de cambios.
2. **Directorio:** importa el CSV o el PDF de contactos, o agrega personas a mano. Marca como *sin participación* a quien no acepte o no pueda apoyar.
3. **Asignación:** en cada una de las 3 áreas, elige quién es superintendente y auxiliares de cada departamento. Marca los departamentos que sí estarán presentes.
4. **Organigrama y Directorios:** revisa el resultado y descárgalo en PDF.
5. **Dir. dptos.:** descarga el directorio de departamentos en PDF (una hoja) o en Excel.
6. **Cartas:** carga la plantilla, descarga las cartas por persona o todas en un ZIP y lleva el control de su estado (pendiente, enviada, aceptó, declinó).
7. **Respaldos:** exporta un respaldo del evento con frecuencia.

---

## Qué hace cada pestaña

### Selector de evento (barra superior)
Cada evento (por ejemplo, cada asamblea) tiene su propio directorio, asignaciones, registro y datos. Un evento nuevo siempre empieza vacío: se importa su directorio desde un CSV o PDF nuevo.

### Asamblea
- **Datos de la asamblea:** nombre, línea 2 del encabezado, lugar, sede, fechas y código para nombrar archivos (por ejemplo, `AR27`). Se usan como encabezado en el organigrama, los directorios y las cartas.
- **Presidente de la asamblea:** opcional. Aparece en el directorio de departamentos.
- **Fecha y encabezado de las cartas:** ver [Cartas de invitación](#cartas-de-invitación).
- **Tu nombre:** se anota en el registro de cambios de este dispositivo.
- **Eventos:** crear, renombrar o eliminar eventos.
- **Respaldos:** exportar el evento actual, exportar todos o importar.

### Directorio
- **Importar CSV.** Columnas reconocidas: *Congregación, Nombre, Segundo nombre, Apellidos, Teléfono (Celular), Teléfono, Correo electrónico*. Une nombre y apellidos y prefiere el celular. Soporta campos entre comillas con saltos de línea.
- **Importar PDF** de contactos con formato de tarjetas (privilegio, "Apellidos, Nombres", congregación, celular, correo). Antes de guardar se muestra una **pantalla de revisión** donde puedes corregir o desmarcar filas.
- Los duplicados (mismo correo o nombre) se omiten.
- **Búsqueda** por nombre, apellido, congregación o correo; ignora acentos y mayúsculas.
- **Filtros:** todos, libres, asignados, sin participación, y por área, por rol o por departamento.
- **Descargar PDF:** tabla en hoja carta horizontal con el filtro y la búsqueda que tengas activos (Nombre, Congregación, Teléfono, Correo y Asignación). Marca a quienes no participan.
- **Sin participación:** casilla para quien no acepta o no puede apoyar. Deja de aparecer en los selectores y, si tenía asignación, se le quita (la aplicación pide confirmación).

### Asignación
- Una pestaña por área. Cada departamento tiene casilla de *presente*; por defecto están apagados los opcionales (Interpretación táctil, Instalación, Transporte y Materiales).
- Cada departamento tiene superintendente y hasta 3 auxiliares (Seguridad usa "Coordinador"; Audio y Video tiene Auxiliar Audio, Video y Plataforma).
- Cada puesto tiene **un solo campo con sugerencias**: al tocarlo se abre la lista y al escribir se filtra por **nombres y apellidos** (no por congregación; ignora acentos y mayúsculas y acepta varias palabras). Funciona igual en iPad, Android y computadora.
  - Toca una sugerencia para asignar. Si ya hay alguien, aparece al inicio "Quitar asignación". Con teclado: flechas, Enter para elegir y Esc para cerrar.
  - La lista solo muestra personas libres: **una persona no puede tener dos asignaciones**. Si hay más de 40 coincidencias, se muestran las primeras y hay que seguir escribiendo.
- Un departamento que se marca como no presente no cuenta como asignación.

### Organigrama
- **Descargar PDF:** organigrama con nombres completos en **una sola hoja**. El tamaño de letra se ajusta solo; el selector *Hoja* permite elegir **automática** (carta y, si no cabe con letra legible, oficio/legal), **carta** u **oficio (legal)**.
- *Imprimir* usa el diálogo del navegador (en iPad conviene el PDF).

### Directorios (por área)
- **Descargar PDF** con diseño formal ya incluido en la aplicación, sin pedir plantilla: encabezado de la asamblea, franja de color por área, departamentos destacados, filas alternadas, bordes marcados, encabezado de columnas repetido en cada página y pie con "Página X de Y" y fecha de generación. Hoja carta vertical.
- *Imprimir* usa el diálogo del navegador.

### Imagen de encabezado en los PDF (opcional)
Si el evento tiene una imagen de encabezado cargada (ver Cartas), aparece la casilla *Usar la imagen de encabezado en el PDF* en el directorio general, el organigrama y los directorios por área. Viene apagada por defecto; al activarla, la imagen sustituye al encabezado escrito, como hoja membretada.

### Dir. dptos.
Directorio de departamentos con el formato de una hoja: comité, presidente y tabla de departamentos con superintendente y Auxiliar A, B y C (nombre, celular y congregación completos). Se descarga en **PDF** (principal) y en **Excel**. No se incluyen los departamentos que no estén presentes.

### Registro
Historial de cambios por evento: asignaciones y bajas, presencia de departamentos, altas y bajas del directorio, importaciones, marcas de sin participación y estado de cartas. Tiene buscador y se exporta a CSV.

---

## Cartas de invitación

### Plantilla
La aplicación busca la plantilla en `plantilla/carta.pdf` (dentro del mismo sitio). También puedes indicar otra dirección o subir el PDF a mano en la pestaña *Cartas*. Si la dirección no responde, usa la última copia guardada en el navegador.

La plantilla debe ser un PDF con **10 campos de texto**. Se llenan **por posición, de arriba abajo**, sin importar su nombre:

| # | Campo | Contenido |
|---|---|---|
| 1 | Fecha | Fecha de la carta |
| 2 | Nombre | Persona asignada |
| 3 | Asignación | Por ejemplo, "Auxiliar de Limpieza" |
| 4 | Lugar | Sede |
| 5 | Fechas | Fechas de la asamblea |
| 6 | Supervisor | Superintendente o coordinador del área |
| 7 | Superintendente directo | Solo para auxiliares |
| 8 | Correo | Correo del supervisor |
| 9 | Nombre de la asamblea | Con comillas |
| 10 | Acuse de recibo (nombre) | Queda vacío |

### Fecha
Por defecto se usa la fecha del día en que se genera la carta. Desmarca *Usar la fecha actual* para elegir otra.

### Encabezado (Asamblea → Fecha y encabezado de las cartas)
- **Escrito:** título, línea 2 y lugar a partir de los datos de la asamblea.
- **Imagen subida:** una imagen (proporción cercana a 5:1) se coloca arriba, ajustada al ancho de la hoja y hasta 128 pt de alto. Cada evento guarda la suya.
- **Ninguno:** cuando la plantilla ya trae su propio encabezado.

Usa "Escrito" o "Imagen" con plantillas **sin** encabezado propio, para que no salga doble.

### Descarga y control
- Nombre de archivo: `AAAAMM CÓDIGO Asignación - Nombre.pdf`, por ejemplo `202611 AR27 Auxiliar de Limpieza - Ana Pérez.pdf`.
- **Descargar visibles (ZIP)** respeta los filtros de área y estado.
- **Estado de cada carta:** Pendiente, Enviada, Aceptó, Declinó. Se puede marcar como enviadas las pendientes visibles y exportar el estado a CSV.
- Si marcas *Declinó*, la aplicación ofrece quitar la asignación y marcar a la persona como sin participación.
- Si cambia la persona asignada a un puesto, el estado vuelve a *Pendiente*.
- Las cartas no se envían desde la aplicación: se descargan y se mandan por correo.

---

## Respaldos

- **Exportar este evento** genera un archivo JSON con el nombre del evento (directorio, asignaciones, registro, estados y encabezado de imagen). **Exportar todos** genera uno con todos los eventos.
- **Importar** agrega el respaldo como un evento nuevo, sin sobrescribir el actual.
- Los datos viven en el navegador: **borrar los datos del navegador o desinstalar la aplicación los elimina**. Haz respaldos periódicos y guarda los archivos fuera del dispositivo.

## Privacidad

- La aplicación no envía datos a ningún servidor; todo se procesa en el dispositivo.
- El directorio contiene datos personales. **No subas al repositorio** el CSV o PDF del directorio, los respaldos ni las cartas generadas.
- La plantilla `plantilla/carta.pdf` debe tener los campos vacíos.

## Preguntas frecuentes

**¿Puedo usarla sin internet?** Sí, después de abrirla una vez con conexión. Cargar la plantilla desde una dirección externa sí requiere internet; si no hay, se usa la última copia guardada.

**No veo la versión nueva.** Cierra y vuelve a abrir la aplicación; si sigue igual, recarga la página. Para el mantenedor: ver `MANTENIMIENTO.md`.

**La importación de PDF no reconoce mi archivo.** Funciona con PDF de texto (no escaneados) con formato de tarjetas o de filas con teléfono o correo. Si falla, exporta a CSV.

**Un nombre salió mal en el PDF.** Los PDF que genera la aplicación usan letra estándar (Helvetica y Times) y omiten símbolos fuera del alfabeto latino.

**Las sugerencias no aparecen al escribir.** Toca el campo del puesto; la lista se abre al enfocarlo. Si no muestra a nadie, esa persona ya tiene otra asignación o está marcada como sin participación.

**Las descargas piden confirmación o no se guardan.** Revisa que el navegador permita descargas del sitio.

**Quiero trabajar en equipo.** Hoy cada dispositivo tiene sus propios datos. Pasa los datos con respaldos; la versión colaborativa permitirá compartirlos con inicio de sesión y permisos por área.
