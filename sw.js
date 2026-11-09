// Cambia VERSION cada vez que actualices index.html o lib/ para que los dispositivos descarguen la nueva versión.
const VERSION='asamblea-v1.3';
const FILES=['./','index.html','manifest.webmanifest','icons/icon-192.png','icons/icon-512.png','lib/pdf-lib.min.js','lib/jszip.min.js','lib/pdf.min.js','lib/pdf.worker.min.js','lib/exceljs.min.js'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(VERSION).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==VERSION).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;e.respondWith(caches.match(e.request,{ignoreSearch:true}).then(r=>r||fetch(e.request)))});
