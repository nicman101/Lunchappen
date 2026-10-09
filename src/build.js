// Builds the web app (repo root), the iOS bundle (ios/Lunchappen/Web) and the icons from src/app.html.
// Run: node src/build.js   (needs playwright + python3 with Pillow)
const fs=require('fs');const path=require('path');
const {chromium}=require('playwright');
(async()=>{
const dir=__dirname, out=path.join(dir,'..'), tmp=path.join(dir,'.build'); fs.mkdirSync(tmp,{recursive:true}); fs.mkdirSync(out,{recursive:true});
const icon=fs.readFileSync(path.join(dir,'icon.svg'),'utf8');
let app=fs.readFileSync(path.join(dir,'app.html'),'utf8').replace('ICON_SVG',JSON.stringify(icon));
fs.writeFileSync(path.join(tmp,'artifact.html'),app);
const titleEnd=app.indexOf('</title>')+8;
const head=app.slice(0,app.indexOf('<div class="app">'));
const body=app.slice(app.indexOf('<div class="app">'));
const index=`<!doctype html>
<html lang="sv">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#F2F1F5" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0E0D13" media="(prefers-color-scheme: dark)">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="Lunchappen">
<meta name="description" content="Registrera frukost, lunch och middag på restaurang och följ dina utlägg.">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" href="icon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
${head}<style>html{color-scheme:light dark}body{margin:0;padding-top:env(safe-area-inset-top,0px)}[hidden]{display:none!important}img{max-width:100%}</style>
<script>window.LUNCHAPPEN_PWA=true;try{var t=localStorage.getItem('lunchappen.theme');if(t==='light'||t==='dark')document.documentElement.setAttribute('data-theme',t)}catch(e){}</script>
</head>
<body>
${body}
</body>
</html>
`;
fs.writeFileSync(path.join(out,'index.html'),index);
fs.writeFileSync(path.join(out,'icon.svg'),icon);
fs.writeFileSync(path.join(out,'manifest.webmanifest'),JSON.stringify({
 name:'Lunchappen',short_name:'Lunchappen',description:'Registrera restaurangutlägg och följ statistik.',
 lang:'sv',start_url:'./',scope:'./',display:'standalone',orientation:'portrait',
 background_color:'#F2F1F5',theme_color:'#E5432B',
 icons:[{src:'icon-192.png',sizes:'192x192',type:'image/png'},{src:'icon-512.png',sizes:'512x512',type:'image/png'},{src:'icon-maskable-512.png',sizes:'512x512',type:'image/png',purpose:'maskable'},{src:'icon.svg',sizes:'any',type:'image/svg+xml'}]
},null,2));
fs.writeFileSync(path.join(out,'sw.js'),`const CACHE='lunchappen-v5';
const SHELL=['./','index.html','manifest.webmanifest','icon.svg','icon-192.png','icon-512.png','apple-touch-icon.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET')return;
  e.respondWith(caches.match(e.request).then(hit=>{
    const net=fetch(e.request).then(r=>{if(r&&(r.ok||r.type==='opaque')){const c=r.clone();caches.open(CACHE).then(ca=>ca.put(e.request,c))}return r}).catch(()=>hit||caches.match('index.html'));
    return hit||net;
  }));
});
`);
// iOS bundle: same page, fonts bundled locally, no manifest/service worker
const ios=path.join(dir,'..','ios','Lunchappen','Web'); fs.mkdirSync(path.join(ios,'fonts'),{recursive:true});
const gfont=/<link rel="preconnect"[^>]*>\n<link rel="preconnect"[^>]*>\n<link rel="stylesheet" href="https:\/\/fonts\.googleapis\.com[^>]*>/;
if(!gfont.test(head)) throw new Error('font link not found');
const iosHead=head.replace(gfont,'<link rel="stylesheet" href="fonts/fonts.css">');
fs.writeFileSync(path.join(ios,'index.html'),`<!doctype html>
<html lang="sv">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="format-detection" content="telephone=no">
${iosHead}<style>html{color-scheme:light dark}body{margin:0;padding-top:env(safe-area-inset-top,0px);-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}input,textarea{-webkit-user-select:text;user-select:text}[hidden]{display:none!important}img{max-width:100%}</style>
<script>try{var t=localStorage.getItem('lunchappen.theme');if(t==='light'||t==='dark')document.documentElement.setAttribute('data-theme',t)}catch(e){}</script>
</head>
<body>
${body}
</body>
</html>
`);
for(const f of fs.readdirSync(path.join(dir,'fonts'))) if(/\.(woff2|css)$/.test(f)) fs.copyFileSync(path.join(dir,'fonts',f),path.join(ios,'fonts',f));
const b=await chromium.launch();const pg=await b.newPage();
const svgUrl='data:image/svg+xml,'+encodeURIComponent(icon);
for(const [name,size,radius,inset] of [['icon-192.png',192,0,0],['icon-512.png',512,0,0],['apple-touch-icon.png',180,0,0],['icon-maskable-512.png',512,0,0],['preview-icon.png',256,56,0],['appicon-1024.png',1024,0,0]]){
  await pg.setViewportSize({width:size,height:size});
  await pg.setContent(`<html><body style="margin:0;background:transparent"><img src="${svgUrl}" style="width:${size}px;height:${size}px;display:block;border-radius:${radius}px"></body></html>`);
  await pg.waitForTimeout(100);
  await pg.screenshot({path:path.join(name==='preview-icon.png'?tmp:name==='appicon-1024.png'?tmp:out,name),omitBackground:true});
}
await b.close();
// App Store icons must not have an alpha channel
require('child_process').execFileSync('python3',['-c',"from PIL import Image;import sys;Image.open(sys.argv[1]).convert('RGB').save(sys.argv[2])",path.join(tmp,'appicon-1024.png'),path.join(dir,'..','ios','Lunchappen','Assets.xcassets','AppIcon.appiconset','AppIcon-1024.png')]);
})();
