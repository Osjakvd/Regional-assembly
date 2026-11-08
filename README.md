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

## Datos entre dispositivos
Los datos NO se sincronizan: cada navegador tiene los suyos. Para pasarlos de un equipo a otro usa
*Asamblea → Exportar respaldo* y *Importar respaldo*. La sincronización real llegará con la versión colaborativa.

## Actualizar la app
1. Reemplaza `index.html` en el repositorio.
2. Cambia `VERSION` en `sw.js` (por ejemplo `asamblea-v2`) para que los dispositivos descarguen la nueva versión.

## Funciona sin internet
Las librerías (PDF, ZIP, Excel, lectura de PDF) están incluidas en `lib/`, así que la app funciona sin conexión después de la primera visita.
