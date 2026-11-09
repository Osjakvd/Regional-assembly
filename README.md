# Organización de Asamblea Regional (PWA)

Directorio, asignación por departamentos, organigrama, directorios y cartas de invitación en PDF/Excel.
Aplicación estática (sin servidor): todo se guarda en el navegador de cada dispositivo.

## Publicar en GitHub Pages
1. Crea un repositorio nuevo en GitHub (por ejemplo `asamblea`). Para Pages gratis debe ser **público**.
2. Sube **el contenido de esta carpeta** a la raíz del repositorio (`index.html`, `sw.js`, `manifest.webmanifest`, carpetas `icons/` y `lib/`).
   - En la web: *Add file → Upload files* y arrastra todo (las carpetas incluidas).
   - O con Git: `git init`, `git add .`, `git commit -m "primera versión"`, `git branch -M main`, `git remote add origin <URL>`, `git push -u origin main`.
3. En el repositorio: *Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: `main` / carpeta `/ (root)` → Save*.
4. Espera 1-2 minutos. La dirección será `https://TU-USUARIO.github.io/NOMBRE-DEL-REPO/`.
5. Ábrela en el celular o la computadora y usa *Instalar aplicación* / *Agregar a pantalla de inicio*.

## Importante: privacidad
- **No subas al repositorio** el CSV/PDF real del directorio, respaldos JSON ni cartas generadas. Estos datos solo deben vivir en el navegador (y en tus respaldos locales).
- El código no contiene datos personales. Los valores de ejemplo de la pestaña Asamblea se pueden cambiar desde la app.

## Apariencia
Acento vino con modo claro y oscuro automático según el dispositivo (no hay interruptor manual).

## Directorio: sin participación y filtros
En *Directorio* marca la casilla "Sin particip." para quien no acepta o no puede apoyar: deja de aparecer en los selectores de asignación y, si tenía asignación, se le quita. El filtro permite ver: todos, libres, asignados, sin participación, y por área, por rol o por departamento.

## Plantilla de la carta (PDF)
La app busca la plantilla en `plantilla/carta.pdf` (dentro del mismo sitio). Para usarla desde la nube:
1. Deja los campos de tu PDF **vacíos** (sin nombres ni correos de personas).
2. Súbelo al repositorio como `plantilla/carta.pdf`.
3. Al abrir la pestaña *Cartas* se carga sola. Si cambias el PDF en GitHub, la app toma la nueva versión la siguiente vez que haya internet.

También puedes indicar otra dirección (por ejemplo `https://raw.githubusercontent.com/USUARIO/REPO/main/plantilla/carta.pdf`) o subir el PDF manualmente. Si la dirección no responde, se usa la última copia guardada. Google Drive y Dropbox normalmente no sirven porque bloquean la lectura desde el navegador.

## Eventos y respaldos
Cada evento (por ejemplo, cada asamblea) guarda por separado su directorio, asignaciones y datos. Se cambia de evento con el selector de la barra superior. En *Asamblea → Eventos* puedes crear un evento vacío, crear uno copiando el directorio actual, renombrar o eliminar. *Exportar este evento* genera un respaldo por evento; *Exportar todos* uno con todos. Al importar, el respaldo se agrega como evento nuevo.

## Datos entre dispositivos
Los datos NO se sincronizan: cada navegador tiene los suyos. Para pasarlos de un equipo a otro usa
*Asamblea → Exportar respaldo* y *Importar respaldo*. La sincronización real llegará con la versión colaborativa.

## Actualizar la app
1. Reemplaza `index.html` en el repositorio.
2. Cambia `VERSION` en `sw.js` (por ejemplo `asamblea-v4`) para que los dispositivos descarguen la nueva versión.

## Funciona sin internet
Las librerías (PDF, ZIP, Excel, lectura de PDF) están incluidas en `lib/`, así que la app funciona sin conexión después de la primera visita.
