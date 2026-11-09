# Mantenimiento y publicación

Guía para quien publica y actualiza la aplicación en GitHub Pages. Para el uso diario, consulta `README.md`.

## Estructura del repositorio

```
index.html              Aplicación completa (HTML, CSS y JavaScript)
sw.js                   Service worker: caché para uso sin conexión
manifest.webmanifest    Datos de instalación (nombre, colores, íconos)
icons/                  icon-192.png, icon-512.png
lib/                    Librerías incluidas (no se cargan de internet)
  pdf-lib.min.js          generar y llenar PDF
  jszip.min.js            archivos ZIP
  exceljs.min.js          archivos Excel
  pdf.min.js              lectura de PDF (importar directorio)
  pdf.worker.min.js
plantilla/
  carta.pdf             Plantilla de la carta (campos vacíos)
README.md               Uso de la aplicación
MANTENIMIENTO.md        Este documento
```

## Publicar en GitHub Pages

1. Crea un repositorio nuevo (por ejemplo, `asamblea`). Para usar Pages gratis debe ser **público**.
2. Sube el contenido a la raíz del repositorio:
   - En la web: *Add file → Upload files* y arrastra los archivos y carpetas.
   - Con Git:
     ```
     git init
     git add .
     git commit -m "primera versión"
     git branch -M main
     git remote add origin <URL-DEL-REPOSITORIO>
     git push -u origin main
     ```
3. *Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: `main` / `/ (root)` → Save*.
4. Espera uno o dos minutos. La dirección será `https://TU-USUARIO.github.io/NOMBRE-DEL-REPO/`.

Las rutas son relativas, así que funciona dentro de la subcarpeta del repositorio.

## Actualizar la aplicación

1. Reemplaza en el repositorio los archivos que cambiaron (normalmente `index.html`).
2. **Cambia `VERSION` en `sw.js`** (por ejemplo, de `asamblea-v1.7` a `asamblea-v1.8`). Sin este cambio, los dispositivos siguen usando la versión guardada en caché.
3. Los dispositivos descargan la nueva versión al abrir la aplicación con conexión; puede requerir cerrarla y abrirla una segunda vez.

Si agregas o quitas archivos de `lib/` o `icons/`, actualiza también la lista `FILES` de `sw.js`.

Los datos de los usuarios no se pierden al actualizar la aplicación: se guardan en el navegador (localStorage e IndexedDB), no en los archivos del sitio.

## Plantilla de la carta

- Colócala en `plantilla/carta.pdf` con los campos **vacíos** (sin nombres ni correos de personas).
- La aplicación llena **los 10 campos de texto por posición, de arriba abajo**: fecha, nombre, asignación, lugar, fechas, supervisor, superintendente directo, correo del supervisor, nombre de la asamblea y nombre del acuse (vacío). Si agregas, quitas o reordenas campos, hay que ajustar el código.
- Si quieres usar otra dirección (por ejemplo, `raw.githubusercontent.com/USUARIO/REPO/main/plantilla/carta.pdf`), se indica en la pestaña *Cartas*. Google Drive y Dropbox normalmente no funcionan porque bloquean la lectura desde el navegador.
- Con una plantilla que ya trae encabezado, usa la opción de encabezado *Ninguno*.
- Al actualizar la plantilla en el repositorio, la aplicación toma la nueva versión la siguiente vez que haya conexión.

## Datos y privacidad

- **No subas al repositorio** directorios reales (CSV/PDF), respaldos JSON ni cartas generadas. El repositorio es público.
- Revisa que `plantilla/carta.pdf` no tenga datos de personas.
- El código no incluye datos personales; los valores de ejemplo de la pestaña *Asamblea* se editan desde la aplicación.

## Dónde se guardan los datos

| Qué | Dónde |
|---|---|
| Eventos (directorio, asignaciones, registro, estados) | `localStorage` del navegador |
| Plantilla PDF en caché e imagen de encabezado | `IndexedDB` del navegador |
| Nombre del usuario y dirección de la plantilla | `localStorage` |

`localStorage` suele permitir unos 5 MB por sitio. Con directorios de cientos de personas hay margen, pero conviene exportar respaldos.

## Solución de problemas

- **No aparece la versión nueva:** comprueba que cambiaste `VERSION` en `sw.js`; cierra y reabre la aplicación o recarga la página. En el navegador, *Herramientas de desarrollo → Application → Service Workers → Unregister* fuerza la actualización.
- **La página no carga en GitHub Pages:** revisa que el repositorio sea público, que Pages esté activado en `main` / raíz y que `index.html` esté en la raíz.
- **Las librerías no cargan:** confirma que la carpeta `lib/` se subió completa (incluido `pdf.worker.min.js`).
- **No se instala como aplicación:** debe abrirse con `https://`; en iPhone usa Safari → *Compartir → Agregar a pantalla de inicio*.
- **La plantilla no se carga desde la nube:** revisa la dirección en la pestaña *Cartas* y que el archivo sea un PDF accesible públicamente; si no, súbela manualmente.
- **Se borraron los datos:** limpiar los datos del navegador o desinstalar la aplicación los elimina. Restáuralos importando un respaldo.

## Historial de versiones

| Versión | Cambios |
|---|---|
| 1.7 | Columna "Asignación" también en la tabla de cartas y en el CSV de estado |
| 1.6 | Nombre de archivo `AAAAMM CÓDIGO Asignación - Nombre`; presidente en la pestaña Asamblea; "Asignación" en directorios |
| 1.5 | Encabezado de carta como imagen, fecha actual por defecto |
| 1.4 | Registro de cambios y estado de las cartas; eventos siempre vacíos |
| 1.3 | Filtros y "sin participación" en el directorio; estilo vino con modo claro/oscuro |
| 1.2 | Eventos, respaldos por evento, plantilla de carta desde la nube |
| 1.1 | Directorio de departamentos en PDF y Excel; presidente; importación de PDF |
| 1.0 | Directorio, asignación, organigrama, directorios y cartas |

*(La numeración anterior a la 1.4 es aproximada; ajústala a tu propio historial si lo llevas.)*
