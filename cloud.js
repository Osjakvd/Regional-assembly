/* ===================================================================
   Versión colaborativa (Supabase). Se carga ANTES del script principal.
   - El modo local sigue funcionando igual (sin cuenta, sin internet).
   - En un evento de la nube, `S` (el estado de la app) se sincroniza por
     diferencias: cada save() compara S con la última copia confirmada
     (CL.snap) y envía solo lo que cambió; el tiempo real aplica los
     cambios de otros dispositivos sobre S y sobre CL.snap.
   - Los permisos los impone la base de datos; aquí solo se ocultan o
     desactivan los controles que el rol no puede usar.
   =================================================================== */
const SB_URL=window.SB_URL||'https://ozgauxhdssezcvvbumjb.supabase.co';
const SB_KEY=window.SB_KEY||'sb_publishable_mK9v4mkUvJQtThueDyQ5Mw_Xun0dsrP'; // llave pública: la seguridad la dan las políticas de la base
let sb=null;
try{sb=supabase.createClient(SB_URL,SB_KEY,window.SB_OPT||{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,storageKey:'asamblea-auth'}})}catch(e){console.error('Supabase no disponible',e)}

const CL={ready:false,user:null,prof:null,events:[],cur:null,name:'',role:null,area:null,access:null,superadmin:false,
  snap:null,ch:null,loading:false,dirty:false,busy:false,tm:null,q:Promise.resolve(),team:null,la:null,adm:null,
  mode:'in',recovery:false,pend:false,rtOk:false,invLink:null};
const ASMK=['nombre','tit2','recinto','ciudad','fechas','fcarta','fauto','codigo','hmode','orgp'];
const PEK=['nombre','cong','tel','correo','no'];
const cclone=o=>JSON.parse(JSON.stringify(o));
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

(()=>{try{const s=document.createElement('style');s.textContent='#toast{position:fixed;left:50%;bottom:calc(env(safe-area-inset-bottom,0px) + 18px);transform:translateX(-50%);background:var(--t0);color:var(--bg1);padding:10px 16px;border-radius:10px;z-index:99;max-width:90vw;font-size:14px;box-shadow:0 6px 20px rgba(0,0,0,.3)}#toast.bad{background:var(--dg);color:#fff}#toast[hidden]{display:none}.bdg{background:var(--dg);color:#fff;border-radius:9px;padding:0 6px;font-size:10px;margin-left:3px}.chip{display:inline-block;padding:1px 8px;border-radius:9px;background:var(--bg3);font-size:12px;color:var(--t1);white-space:nowrap}.lk{word-break:break-all;background:var(--bg2);padding:6px 8px;border-radius:6px;font-size:12px;margin:6px 0}.cd input:not([type=checkbox]){width:100%}.cd .r input{width:auto;flex:1;min-width:160px}';document.head.appendChild(s)}catch(e){}})();

let _tt;
function toast(m,bad){try{let t=document.getElementById('toast');if(!t){t=document.createElement('div');t.id='toast';document.body.appendChild(t)}t.className=bad?'bad':'';t.textContent=m;t.hidden=false;clearTimeout(_tt);_tt=setTimeout(()=>{t.hidden=true},bad?7000:3500)}catch(e){}}

function cerr(e){const m=String((e&&e.message)||e||''),c=e&&e.code,d=String((e&&e.details)||'');
  if(c=='23505'&&/assignments_one_per_person/i.test(m+d))return 'Esa persona ya tiene otra asignación en este evento.';
  if(c=='23505'||/duplicate key/i.test(m))return 'Ese puesto ya fue ocupado por otra persona.';
  if(c=='42501'||/row-level security|permission denied/i.test(m))return 'No tienes permiso para hacer ese cambio.';
  if(/Invalid login credentials/i.test(m))return 'Correo o contraseña incorrectos.';
  if(/Email not confirmed/i.test(m))return 'Falta confirmar tu correo: abre el enlace que te enviamos (revisa también spam).';
  if(/already registered/i.test(m))return 'Ese correo ya tiene cuenta: usa «Entrar» o «Olvidé mi contraseña».';
  if(/rate limit|security purposes/i.test(m))return 'Se enviaron demasiados correos; espera unos minutos e inténtalo de nuevo.';
  if(/Password should be|at least \d+ char/i.test(m))return 'La contraseña es demasiado corta (mínimo 6 caracteres).';
  if(/Failed to fetch|NetworkError|Load failed/i.test(m))return 'Sin conexión con el servidor.';
  return m||'Error desconocido';}

/* ---------- Permisos en pantalla (la base de datos es la que manda) ---------- */
const isAdm=()=>!CL.cur||CL.role=='admin';
const depArea=id=>{const a=AREAS.find(x=>x.deps.some(d=>d.id==id));return a?a.id:null};
const canDept=id=>!CL.cur||CL.role=='admin'||(CL.role=='editor'&&depArea(id)==CL.area);
const canSlot=k=>!CL.cur||CL.role=='admin'||(CL.role=='editor'&&isDep(k)&&depArea(k.split(':')[0])==CL.area);
const canAllLetters=()=>!CL.cur||CL.role=='admin'||CL.role==null||CL.access=='approved';
const canNo=p=>!CL.cur||CL.role=='admin'||(CL.role=='editor'&&Object.keys(S.as).filter(k=>S.as[k]==p.id).every(canSlot));
const isRO=()=>!!CL.cur&&CL.role!='admin'&&CL.role!='editor';
const csDis=k=>canSlot(k)?'':'disabled';
const noDis=p=>canNo(p)?'':'disabled';
const roleTxt=()=>{if(!CL.cur)return '';const ar=CL.area?' · '+CL.area:'';return CL.role=='admin'?'Administrador'+ar:CL.role=='editor'?'Editor'+ar:'Solo lectura'};
const cloudRecipsFilter=o=>CL.cur&&!canAllLetters()?o.filter(r=>r.a.id==CL.area):o;
function cloudAreaOpts(){const all=canAllLetters();if(CL.cur&&!all&&CF!=CL.area)CF=CL.area;
  return (all?'<option value="all">Todas las áreas</option>':'')+AREAS.filter(a=>all||a.id==CL.area).map(a=>`<option value="${a.id}"${a.id==CF?' selected':''}>${a.h}</option>`).join('')}
function cloudAsgHint(){return CL.cur&&CL.role=='editor'?`<p class="mu">Puedes editar solo los departamentos de tu área (${esc(CL.area)}); el resto está en solo lectura.</p>`:isRO()?'<p class="mu">Solo lectura.</p>':''}
function cloudAfter(){if(CL.cur&&!isAdm()&&T=='asm')document.querySelectorAll('#v .f input,#v .cd input,#v .cd select,#v .cd button').forEach(e=>{e.disabled=true})}

/* ---------- Pestañas, selector de evento y render ---------- */
function cloudTabs(){const t=TABS.slice();if(CL.cur&&(CL.role=='admin'||CL.superadmin)){const n=(CL.la||[]).filter(r=>r.status=='pending').length;t.push(['eq','Equipo'+(n?`<span class="bdg">${n}</span>`:'')])}t.push(['cta','Cuenta']);return t}
function cloudEvSel(){const cur=CL.cur?'c:'+CL.cur:'l:'+EV.cur,o=(v,t)=>`<option value="${v}"${v==cur?' selected':''}>${esc(t)}</option>`;
  const loc=EV.list.map(e=>o('l:'+e.id,e.n)).join(''),evs=CL.events.slice();if(CL.cur&&!evs.some(e=>e.id==CL.cur))evs.push({id:CL.cur,name:CL.name});
  const body=CL.user&&evs.length?`<optgroup label="En la nube">${evs.map(e=>o('c:'+e.id,e.name)).join('')}</optgroup><optgroup label="En este dispositivo">${loc}</optgroup>`:loc;
  return `<select onchange="evGo(this.value)" title="Evento">${body}</select>`+(CL.cur?` <span class="chip">${esc(roleTxt())}</span>`:'')}
function cloudRender(){const v=document.getElementById('v');if(CL.loading){v.innerHTML='<p class="mu">Cargando evento…</p>';return}
  const V={asm:vAsm,dir:vDir,asg:vAsg,org:vOrg,dds:vDds,dpt:vDpt,cartas:vCartas,log:vLog,cta:vCta,eq:vEq};if(!V[T])T='asm';
  v.innerHTML=V[T]();if(T=='dir')tb();if(T=='log')lgb();cloudAfter()}
function cloudAsmCard(){return `<h2 style="margin-top:20px">Evento en la nube</h2><div class="cd"><b>${esc(CL.name)}</b> <span class="chip">${esc(roleTxt())}</span><p class="mu">Los cambios se guardan solos y se ven en tiempo real en los dispositivos de tu equipo. ${CL.role=='editor'?'Puedes editar solo los departamentos de tu área ('+esc(CL.area)+').':CL.role=='admin'?'Eres el administrador de este evento.':'Estás en modo de solo lectura.'}</p>${CL.role=='admin'?'<div class="r"><button onclick="cloudRename()">Renombrar evento</button></div>':''}</div>`}
function cartasAccessCard(){if(!CL.cur||CL.role!='editor'||CL.access=='approved')return '';
  const st=CL.access;return `<div class="cd"><b>Cartas de otras áreas</b><p class="mu">${st=='pending'?'Tu solicitud está pendiente: el administrador del evento debe aprobarla. Cuando la apruebe, aparecerá aquí el selector de área (solo lectura).':`Ves solo las cartas de tu área (${esc(CL.area)}).${st=='denied'?' El administrador no aprobó tu solicitud anterior.':''} Si necesitas verlas todas (solo lectura), pide permiso al administrador del evento.`}</p>${st=='pending'?'':`<div class="r"><button onclick="cloudReqAccess()">${st=='denied'?'Volver a solicitar':'Solicitar ver las demás áreas'}</button></div>`}</div>`}

/* ---------- Sesión ---------- */
function cloudInit(){
  ICO.cta='<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-7 8-7s8 3 8 7"/>';
  ICO.eq='<circle cx="9" cy="8" r="3.5"/><circle cx="17" cy="9" r="2.5"/><path d="M2.5 20c.6-3.6 3.2-5.5 6.5-5.5s5.9 1.9 6.5 5.5M16 14.5c2.5 0 4.6 1.5 5.2 4.5"/>';
  const m=(location.hash||'').match(/invitar=([0-9a-fA-F]{16,64})/);
  if(m){lss('asamblea-inv',m[1].toLowerCase());try{history.replaceState(null,'',location.pathname+location.search)}catch(e){}T='cta'}
  document.addEventListener('focusout',()=>{if(CL.pend)setTimeout(()=>{const a=document.activeElement;if(!(a&&/^(INPUT|SELECT|TEXTAREA)$/.test(a.tagName))){CL.pend=false;render()}},250)});
  document.addEventListener('visibilitychange',()=>{if(!CL.cur)return;if(document.hidden){CL.hid=Date.now();cloudFlush()}else if(CL.hid&&Date.now()-CL.hid>20000&&!CL.dirty)cloudReload(true)});
  window.addEventListener('online',()=>{if(CL.cur){cloudFlush();cloudReload(true)}});
  window.addEventListener('beforeunload',e=>{if(CL.cur&&(CL.dirty||CL.busy)){e.preventDefault();e.returnValue=''}});
  if(!sb){CL.ready=true;return}
  try{sb.auth.onAuthStateChange((ev,ses)=>{setTimeout(()=>cloudAuth(ev,ses),0)})}catch(e){console.error(e)}
}
async function cloudAuth(ev,ses){
  if(ev=='PASSWORD_RECOVERY'){CL.recovery=true;T='cta'}
  const u=ses&&ses.user||null;
  if(u){if(!CL.user||CL.user.id!=u.id){CL.user=u;CL.ready=true;render();await cloudStart()}else CL.user=u}
  else if(CL.user){CL.user=null;CL.prof=null;CL.events=[];CL.adm=null;if(CL.cur){await cloudClose();evLoad(EV.cur)}}
  CL.ready=true;render()}
async function cloudStart(){
  try{await cloudProfile();const joined=await cloudAcceptPending();await cloudList();
    const last=joined||lsg('asamblea-last')||'';
    if(last.startsWith('c:')&&CL.events.some(e=>'c:'+e.id==last))await cloudOpen(last.slice(2))}
  catch(e){toast(cerr(e),true)}}
async function cloudProfile(){const {data,error}=await sb.from('profiles').select('*').eq('user_id',CL.user.id).maybeSingle();if(error)throw error;CL.prof=data;CL.superadmin=!!(data&&data.is_superadmin)}
async function cloudList(){const {data,error}=await sb.from('events').select('id,name,created_at').order('created_at');if(error)throw error;CL.events=data||[]}
async function cloudAcceptPending(){const code=lsg('asamblea-inv');if(!code)return null;
  try{const {data,error}=await sb.rpc('accept_invite',{p_code:code});if(error)throw error;try{localStorage.removeItem('asamblea-inv')}catch(e){}
    toast(data.already_member?'Ya eras parte de ese evento.':'Te uniste a «'+(data.event_name||'evento')+'» como editor de '+data.area_id+'.');return 'c:'+data.event_id}
  catch(e){const m=cerr(e);if(!/Sin conexión/.test(m))try{localStorage.removeItem('asamblea-inv')}catch(x){}toast('Invitación: '+m,true);return null}}
async function cloudLogin(){const e=(document.getElementById('ce').value||'').trim(),p=document.getElementById('cp').value;if(!e||!p){toast('Escribe tu correo y contraseña.',true);return}
  const {error}=await sb.auth.signInWithPassword({email:e,password:p});if(error)toast(cerr(error),true)}
async function cloudSignup(){const e=(document.getElementById('ce').value||'').trim(),p=document.getElementById('cp').value,n=(document.getElementById('cn').value||'').trim();
  if(!e||!p||!n){toast('Escribe tu nombre, correo y una contraseña (mínimo 6 caracteres).',true);return}
  const {data,error}=await sb.auth.signUp({email:e,password:p,options:{data:{name:n},emailRedirectTo:location.origin+location.pathname}});
  if(error){toast(cerr(error),true);return}
  if(!data.session)toast('Te enviamos un correo para confirmar tu cuenta. Ábrelo desde este mismo dispositivo (revisa también spam).')}
async function cloudMagic(){const e=(document.getElementById('ce').value||'').trim();if(!e){toast('Escribe tu correo.',true);return}
  const {error}=await sb.auth.signInWithOtp({email:e,options:{emailRedirectTo:location.origin+location.pathname}});toast(error?cerr(error):'Te enviamos un enlace para entrar (revisa también spam).',!!error)}
async function cloudReset(){const e=(document.getElementById('ce').value||'').trim();if(!e){toast('Escribe tu correo.',true);return}
  const {error}=await sb.auth.resetPasswordForEmail(e,{redirectTo:location.origin+location.pathname});toast(error?cerr(error):'Te enviamos un correo para cambiar tu contraseña.',!!error)}
async function cloudNewPass(){const p=document.getElementById('cp').value;if((p||'').length<6){toast('La contraseña debe tener al menos 6 caracteres.',true);return}
  const {error}=await sb.auth.updateUser({password:p});if(error){toast(cerr(error),true);return}CL.recovery=false;toast('Contraseña actualizada.');render()}
async function cloudOut(){await cloudFlush();await sb.auth.signOut()}
async function cloudName(v){v=(v||'').trim();if(!v)return;const {error}=await sb.from('profiles').update({display_name:v}).eq('user_id',CL.user.id);if(error)toast(cerr(error),true);else{CL.prof.display_name=v;toast('Nombre guardado.')}}
async function cloudJoin(){const raw=(document.getElementById('cj').value||'').trim(),m=raw.match(/([0-9a-fA-F]{16,64})\s*$/);if(!m){toast('Pega el enlace o el código que te enviaron.',true);return}
  lss('asamblea-inv',m[1].toLowerCase());const j=await cloudAcceptPending();await cloudList();if(j)await cloudOpen(j.slice(2));else render()}

/* ---------- Abrir / cerrar un evento de la nube ---------- */
async function pageAll(t,id,ord){let all=[],from=0;const n=1000;for(;;){const {data,error}=await sb.from(t).select('*').eq('event_id',id).order(ord).range(from,from+n-1);if(error)throw error;all=all.concat(data);if(data.length<n)break;from+=n}return all}
async function cloudLoad(id){
  const me=CL.user.id;
  const [ev,pe,as,pr,cs,lgR,hd,mb,la]=await Promise.all([
    sb.from('events').select('*').eq('id',id).single(),
    pageAll('people',id,'id'),
    sb.from('assignments').select('slot,person_id').eq('event_id',id),
    sb.from('dept_presence').select('dept_id,present').eq('event_id',id),
    sb.from('letter_status').select('slot,state,person_id,updated_at').eq('event_id',id),
    sb.from('change_log').select('at,user_name,msg').eq('event_id',id).order('id',{ascending:false}).limit(1000),
    sb.from('event_header').select('image').eq('event_id',id).maybeSingle(),
    sb.from('members').select('role,area_id').eq('event_id',id).eq('user_id',me).maybeSingle(),
    sb.from('letter_access').select('*').eq('event_id',id)]);
  for(const r of [ev,as,pr,cs,lgR,hd,mb,la])if(r.error)throw r.error;
  const e=ev.data,asm={};ASMK.forEach(k=>asm[k]=e[k]);asm.pdfImg=lsg('asamblea-pdfimg-'+id)=='1';
  const s=cclone(DEF);s.asm=asm;
  s.people=pe.map(p=>({id:p.id,nombre:p.nombre,cong:p.cong,tel:p.tel,correo:p.correo,no:!!p.no}));
  as.data.forEach(r=>{s.as[r.slot]=r.person_id});pr.data.forEach(r=>{s.pres[r.dept_id]=r.present});
  cs.data.forEach(r=>{s.cs[r.slot]={e:r.state,p:r.person_id,t:Date.parse(r.updated_at)}});
  s.log=lgR.data.slice().reverse().map(r=>({t:Date.parse(r.at),u:r.user_name,x:r.msg}));
  S=s;HDR=hd.data?hd.data.image:null;CL.name=e.name;CL.role=mb.data?mb.data.role:null;CL.area=mb.data?mb.data.area_id:null;
  CL.superadmin=!!(CL.prof&&CL.prof.is_superadmin);
  const mine=la.data.find(r=>r.user_id==me);CL.access=mine?mine.status:null;CL.la=(CL.role=='admin'||CL.superadmin)?la.data:null;
  CL.snap=snapNow()}
async function cloudOpen(id){
  if(CL.cur&&CL.cur!=id)await cloudClose();
  const first=!CL.cur;CL.cur=id;CL.loading=true;CL.team=null;if(T=='cta'&&!CL.recovery)T='asm';render();
  try{await cloudLoad(id);if(first||!CL.ch)rt(id)}
  catch(e){toast('No se pudo abrir el evento: '+cerr(e),true);CL.cur=null;CL.loading=false;CL.snap=null;HDR=null;try{evLoad(EV.cur)}catch(x){}return}
  CL.loading=false;lss('asamblea-last','c:'+id);render()}
async function cloudClose(){
  clearTimeout(CL.tm);try{await CL.q}catch(e){}
  if(CL.dirty){try{await cloudPush()}catch(e){}}
  if(CL.ch){try{sb.removeChannel(CL.ch)}catch(e){}CL.ch=null}
  CL.cur=null;CL.role=CL.area=CL.access=null;CL.la=CL.team=CL.snap=null;CL.dirty=false;CL.rtOk=false;HDR=null}
async function cloudReload(quiet){if(!CL.cur||CL.loading||CL.busy)return;const id=CL.cur;clearTimeout(CL.tm);CL.dirty=false;
  try{await cloudLoad(id)}catch(e){if(!quiet)toast('No se pudo actualizar: '+cerr(e),true)}rtRender()}

/* ---------- Sincronización por diferencias ---------- */
function snapNow(){return {asm:ASMK.reduce((o,k)=>{if(S.asm[k]!==undefined)o[k]=S.asm[k];return o},{}),
  people:S.people.map(p=>({id:p.id,nombre:p.nombre||'',cong:p.cong||'',tel:p.tel||'',correo:p.correo||'',no:!!p.no})),
  as:{...S.as},pres:{...S.pres},cs:cclone(S.cs||{})}}
function diffOps(sn){
  const T0=snapNow(),id=CL.cur,o={asm:{},pIns:[],pUpd:[],pDel:[],aDel:[],aUpd:[],aIns:[],prIns:[],prUpd:[],csDel:[],csIns:[],csUpd:[],target:T0};
  ASMK.forEach(k=>{if(T0.asm[k]!==undefined&&T0.asm[k]!==sn.asm[k])o.asm[k]=T0.asm[k]});
  const sp=new Map(sn.people.map(p=>[p.id,p])),np=new Set(T0.people.map(p=>p.id));
  T0.people.forEach(p=>{const q=sp.get(p.id);if(!q)o.pIns.push({id:p.id,event_id:id,nombre:p.nombre,cong:p.cong,tel:p.tel,correo:p.correo,no:p.no});
    else{const d={};PEK.forEach(k=>{if(p[k]!==q[k])d[k]=p[k]});if(Object.keys(d).length)o.pUpd.push({id:p.id,d})}});
  sn.people.forEach(p=>{if(!np.has(p.id))o.pDel.push(p.id)});
  Object.keys(sn.as).forEach(k=>{if(!(k in T0.as))o.aDel.push(k)});
  Object.keys(T0.as).forEach(k=>{if(!(k in sn.as))o.aIns.push({event_id:id,slot:k,person_id:T0.as[k]});else if(sn.as[k]!==T0.as[k])o.aUpd.push({slot:k,person_id:T0.as[k]})});
  Object.keys(T0.pres).forEach(d=>{const v=!!T0.pres[d];if(!(d in sn.pres))o.prIns.push({event_id:id,dept_id:d,present:v});else if(!!sn.pres[d]!==v)o.prUpd.push({dept_id:d,present:v})});
  Object.keys(T0.cs).forEach(k=>{const c=T0.cs[k],q=sn.cs[k];if(!isDep(k)||T0.as[k]!==c.p)return;
    if(!q||q.p!==c.p)o.csIns.push({event_id:id,slot:k,state:c.e});else if(q.e!==c.e)o.csUpd.push({slot:k,state:c.e})});
  Object.keys(sn.cs).forEach(k=>{if(!(k in T0.cs))o.csDel.push(k)});
  o.empty=!(Object.keys(o.asm).length||['pIns','pUpd','pDel','aDel','aUpd','aIns','prIns','prUpd','csDel','csIns','csUpd'].some(x=>o[x].length));
  return o}
const ckr=r=>{if(r.error)throw r.error;return r};
const chunks=(a,n)=>{const r=[];for(let i=0;i<a.length;i+=n)r.push(a.slice(i,i+n));return r};
async function runOps(id,o){
  if(Object.keys(o.asm).length){const r=ckr(await sb.from('events').update(o.asm).eq('id',id).select('id'));if(!r.data.length)throw {message:'No tienes permiso para cambiar los datos del evento.'}}
  for(const c of chunks(o.pIns,300))ckr(await sb.from('people').insert(c));
  for(const u of o.pUpd){const r=ckr(await sb.from('people').update(u.d).eq('id',u.id).select('id'));if(!r.data.length)throw {message:'No tienes permiso para editar a esa persona.'}}
  if(o.aDel.length)ckr(await sb.from('assignments').delete().eq('event_id',id).in('slot',o.aDel));
  for(const r0 of o.prIns)ckr(await sb.from('dept_presence').insert(r0));
  for(const u of o.prUpd){const r=ckr(await sb.from('dept_presence').update({present:u.present}).eq('event_id',id).eq('dept_id',u.dept_id).select('dept_id'));if(!r.data.length)throw {message:'No tienes permiso para cambiar ese departamento.'}}
  for(const u of o.aUpd){const r=ckr(await sb.from('assignments').update({person_id:u.person_id}).eq('event_id',id).eq('slot',u.slot).select('slot'));if(!r.data.length)throw {message:'No tienes permiso para cambiar ese puesto.'}}
  for(const c of chunks(o.aIns,300))ckr(await sb.from('assignments').insert(c));
  if(o.csDel.length)ckr(await sb.from('letter_status').delete().eq('event_id',id).in('slot',o.csDel));
  for(const c of chunks(o.csIns,300))ckr(await sb.from('letter_status').insert(c));
  for(const u of o.csUpd){const r=ckr(await sb.from('letter_status').update({state:u.state}).eq('event_id',id).eq('slot',u.slot).select('slot'));if(!r.data.length)throw {message:'No tienes permiso para cambiar esa carta.'}}
  for(const c of chunks(o.pDel,100)){const r=ckr(await sb.from('people').delete().in('id',c).select('id'));if(!r.data.length&&c.length)throw {message:'No tienes permiso para quitar personas del directorio.'}}}
async function cloudPush(){
  if(!CL.cur||!CL.snap)return;CL.dirty=false;const id=CL.cur,o=diffOps(CL.snap);if(o.empty)return;
  CL.busy=true;
  try{await runOps(id,o);if(CL.cur==id){CL.snap=o.target;
    // el servidor reinicia la carta de un puesto cuando cambia o se quita su persona: se limpia también aquí
    [...o.aDel,...o.aUpd.map(u=>u.slot)].forEach(k=>{if(o.csIns.some(x=>x.slot==k)||o.csUpd.some(x=>x.slot==k))return;delete CL.snap.cs[k];const l=S.cs&&S.cs[k];if(l&&S.as[k]!==l.p)delete S.cs[k]})}}
  catch(e){CL.busy=false;toast('No se guardó el cambio: '+cerr(e),true);await cloudReload();render();return}
  CL.busy=false;if(CL.dirty)cloudFlush()}
function cloudSave(){if(CL.loading||isRO())return;lss('asamblea-pdfimg-'+CL.cur,S.asm.pdfImg?'1':'0');CL.dirty=true;clearTimeout(CL.tm);CL.tm=setTimeout(cloudFlush,500)}
function cloudFlush(){clearTimeout(CL.tm);CL.q=CL.q.then(()=>CL.dirty?cloudPush():null).catch(()=>{});return CL.q}

/* ---------- Tiempo real ---------- */
let _rr;
function rtRender(){clearTimeout(_rr);_rr=setTimeout(()=>{const a=document.activeElement;if(a&&/^(INPUT|SELECT|TEXTAREA)$/.test(a.tagName)&&document.getElementById('v').contains(a)){CL.pend=true;return}render()},150)}
function mergeKey(obj,snapObj,k,val){const old=snapObj[k];snapObj[k]=val;if(obj[k]===old)obj[k]=val}
function dropKey(obj,snapObj,k){const old=snapObj[k];delete snapObj[k];if(obj[k]===old)delete obj[k]}
function rmPerson(id){S.people=S.people.filter(p=>p.id!=id);CL.snap.people=CL.snap.people.filter(p=>p.id!=id);
  for(const k of Object.keys(S.as))if(S.as[k]==id)delete S.as[k];for(const k of Object.keys(CL.snap.as))if(CL.snap.as[k]==id)delete CL.snap.as[k];
  for(const k of Object.keys(S.cs))if(S.cs[k].p==id)delete S.cs[k];for(const k of Object.keys(CL.snap.cs))if(CL.snap.cs[k].p==id)delete CL.snap.cs[k]}
function rtPeople(p){if(p.eventType=='DELETE'){rmPerson(p.old.id);return}
  const n=p.new,r={id:n.id,nombre:n.nombre||'',cong:n.cong||'',tel:n.tel||'',correo:n.correo||'',no:!!n.no},sp=CL.snap.people.find(x=>x.id==r.id),lp=S.people.find(x=>x.id==r.id);
  if(!sp){CL.snap.people.push({...r});if(!lp)S.people.push({...r});return}
  const old={...sp};Object.assign(sp,r);if(!lp){S.people.push({...r});return}PEK.forEach(k=>{if(lp[k]===old[k])lp[k]=r[k]})}
function rtAs(p){const row=p.new||p.old;if(row.event_id&&row.event_id!=CL.cur)return;
  if(p.eventType=='DELETE')dropKey(S.as,CL.snap.as,row.slot);else mergeKey(S.as,CL.snap.as,row.slot,p.new.person_id)}
function rtPres(p){const row=p.new;if(!row||row.event_id!=CL.cur)return;mergeKey(S.pres,CL.snap.pres,row.dept_id,row.present)}
function rtCs(p){const row=p.new||p.old;if(row.event_id&&row.event_id!=CL.cur)return;
  if(p.eventType=='DELETE')dropKey(S.cs,CL.snap.cs,row.slot);else{const c={e:p.new.state,p:p.new.person_id,t:Date.parse(p.new.updated_at)};
    const old=CL.snap.cs[row.slot];CL.snap.cs[row.slot]=c;const l=S.cs[row.slot];if(!l||(old&&l.e===old.e&&l.p===old.p))S.cs[row.slot]={...c}}}
function rtLog(p){const n=p.new;if(n.event_id!=CL.cur)return;S.log.push({t:Date.parse(n.at),u:n.user_name,x:n.msg});if(S.log.length>3000)S.log.splice(0,500)}
function rtEv(p){if(p.eventType=='DELETE'){if(p.old.id==CL.cur){toast('Este evento fue eliminado.',true);cloudClose().then(()=>{CL.events=CL.events.filter(e=>e.id!=p.old.id);evLoad(EV.cur)})}return}
  const n=p.new;if(n.id!=CL.cur)return;ASMK.forEach(k=>{if(n[k]!==undefined)mergeKey(S.asm,CL.snap.asm,k,n[k])});CL.name=n.name;const ce=CL.events.find(e=>e.id==n.id);if(ce)ce.name=n.name}
function rtLa(p){const row=p.new||p.old;if(row.event_id&&row.event_id!=CL.cur)return;
  if(row.user_id==CL.user.id)CL.access=p.eventType=='DELETE'?null:p.new.status;
  if(CL.la){CL.la=CL.la.filter(r=>r.user_id!=row.user_id);if(p.eventType!='DELETE')CL.la.push(p.new)}
  if(T=='eq'&&CL.la)cloudTeamLoad().then(rtRender).catch(()=>{})}
function rtMem(p){const row=p.new||p.old;if(row.event_id&&row.event_id!=CL.cur)return;
  if(p.eventType=='DELETE'&&row.user_id==CL.user.id&&!CL.superadmin){toast('Ya no formas parte de este evento.',true);cloudClose().then(async()=>{await cloudList().catch(()=>{});evLoad(EV.cur)});return}
  if(row.user_id==CL.user.id&&p.new){const ch=CL.role!=p.new.role||CL.area!=p.new.area_id;CL.role=p.new.role;CL.area=p.new.area_id;if(ch)toast('Tu cargo en el evento cambió: '+roleTxt()+'.')}
  if(CL.role=='admin'||CL.superadmin)cloudTeamLoad().then(rtRender).catch(()=>{})}
function rt(id){const f='event_id=eq.'+id,ch=sb.channel('ev:'+id);
  const on=(t,fn,filter,evn)=>ch.on('postgres_changes',{event:evn||'*',schema:'public',table:t,filter:filter||f},p=>{if(CL.cur!=id||!CL.snap)return;try{fn(p);rtRender()}catch(e){console.error(e)}});
  on('people',rtPeople);on('assignments',rtAs);on('dept_presence',rtPres);on('letter_status',rtCs);on('change_log',rtLog,f,'INSERT');
  on('events',rtEv,'id=eq.'+id);on('letter_access',rtLa);on('members',rtMem);
  ch.subscribe(st=>{if(st=='SUBSCRIBED'){if(CL.rtOk)cloudReload(true);CL.rtOk=true}});CL.ch=ch}

async function cloudHdrSet(v){if(!CL.cur){await idb('set',v,'hdr-'+EV.cur);return}ckr(await sb.from('event_header').upsert({event_id:CL.cur,image:v},{onConflict:'event_id'}))}
async function cloudHdrDel(){if(!CL.cur){await idb('del',0,'hdr-'+EV.cur);return}ckr(await sb.from('event_header').delete().eq('event_id',CL.cur))}

/* ---------- Crear, renombrar, eliminar, copiar un evento local a la nube ---------- */
async function cloudCreate(){const n=(document.getElementById('cen').value||'').trim(),a=document.getElementById('cea').value,copy=!CL.cur&&document.getElementById('cec')&&document.getElementById('cec').checked;
  if(!n){toast('Escribe el nombre del evento.',true);return}
  try{const {data,error}=await sb.rpc('create_event',{p_name:n,p_area:a});if(error)throw error;
    if(copy)await copyLocal(data);await cloudList();await cloudOpen(data);toast('Evento creado.')}
  catch(e){toast('No se pudo crear: '+cerr(e),true)}}
async function copyLocal(id){const L=S,map={};L.people.forEach(p=>{map[p.id]=UUID.test(p.id)?p.id:crypto.randomUUID()});
  const patch={};ASMK.forEach(k=>{if(L.asm[k]!==undefined)patch[k]=L.asm[k]});ckr(await sb.from('events').update(patch).eq('id',id));
  const rows=L.people.map(p=>({id:map[p.id],event_id:id,nombre:p.nombre,cong:p.cong||'',tel:p.tel||'',correo:p.correo||'',no:!!p.no}));
  for(const c of chunks(rows,300))ckr(await sb.from('people').insert(c));
  for(const a of AREAS)for(const d of a.deps){const v=L.pres[d.id];if(v!==undefined&&v!==!d.opt)ckr(await sb.from('dept_presence').update({present:v}).eq('event_id',id).eq('dept_id',d.id))}
  const as=Object.keys(L.as).filter(k=>map[L.as[k]]).map(k=>({event_id:id,slot:k,person_id:map[L.as[k]]}));
  for(const c of chunks(as,300))ckr(await sb.from('assignments').insert(c));
  const cs=Object.keys(L.cs||{}).filter(k=>isDep(k)&&L.as[k]&&L.as[k]==L.cs[k].p&&map[L.as[k]]).map(k=>({event_id:id,slot:k,state:L.cs[k].e}));
  for(const c of chunks(cs,300))ckr(await sb.from('letter_status').insert(c));
  if(HDR)ckr(await sb.from('event_header').upsert({event_id:id,image:HDR},{onConflict:'event_id'}))}
async function cloudRename(){const n=prompt('Nuevo nombre del evento:',CL.name);if(!n||!n.trim())return;
  const {error}=await sb.from('events').update({name:n.trim()}).eq('id',CL.cur);if(error){toast(cerr(error),true);return}CL.name=n.trim();const e=CL.events.find(x=>x.id==CL.cur);if(e)e.name=CL.name;render()}
async function cloudDelEv(id,name){if(prompt('Vas a ELIMINAR «'+name+'» con todos sus datos y no se puede deshacer.\nEscribe el nombre exacto del evento para confirmar:')!==name){toast('No se eliminó (el nombre no coincide).',true);return}
  try{if(CL.cur==id){await cloudClose();evLoad(EV.cur)}const {data,error}=await sb.from('events').delete().eq('id',id).select('id');if(error)throw error;if(!data.length)throw {message:'No tienes permiso para eliminar eventos.'}
    await cloudList();await cloudTabLoad('cta');toast('Evento eliminado.')}catch(e){toast(cerr(e),true)}render()}

/* ---------- Equipo, invitaciones y acceso a cartas ---------- */
async function cloudTeamLoad(){if(!CL.cur||!(CL.role=='admin'||CL.superadmin))return;const id=CL.cur;
  const [m,i,l]=await Promise.all([sb.rpc('list_members',{p_event:id}),sb.from('invites').select('*').eq('event_id',id).order('created_at'),sb.from('letter_access').select('*').eq('event_id',id)]);
  for(const r of [m,i,l])if(r.error)throw r.error;CL.team={members:m.data,invites:i.data};CL.la=l.data}
async function cloudTabLoad(t){try{if(t=='eq')await cloudTeamLoad();
    if(t=='cta'&&CL.user){await cloudList();if(CL.superadmin){const [e,u]=await Promise.all([sb.rpc('admin_events'),sb.rpc('admin_list_users')]);ckr(e);ckr(u);CL.adm={events:e.data,users:u.data}}}}
  catch(e){toast(cerr(e),true)}}
function cloudTabEnter(t){if(t=='eq'||t=='cta')cloudTabLoad(t).then(()=>{if(T==t)render()})}
const inviteUrl=c=>location.origin+location.pathname+'#invitar='+c;
async function cloudInvite(){const a=document.getElementById('cia').value;
  try{const {data,error}=await sb.rpc('create_invite',{p_event:CL.cur,p_area:a,p_days:7,p_max_uses:1});if(error)throw error;CL.invLink={code:data,area:a};await cloudTeamLoad()}catch(e){toast(cerr(e),true)}render()}
function cloudCopy(code){const u=inviteUrl(code);try{navigator.clipboard.writeText(u).then(()=>toast('Enlace copiado.'),()=>prompt('Copia el enlace:',u))}catch(e){prompt('Copia el enlace:',u)}}
function cloudWa(code){const t='Te invito a colaborar en «'+CL.name+'» (Asamblea Regional). Abre este enlace, crea tu cuenta o inicia sesión y quedarás unido al evento:\n'+inviteUrl(code);window.open('https://wa.me/?text='+encodeURIComponent(t),'_blank')}
async function cloudRevokeInv(code){const {error}=await sb.from('invites').delete().eq('code',code);if(error)toast(cerr(error),true);else{if(CL.invLink&&CL.invLink.code==code)CL.invLink=null;await cloudTeamLoad().catch(()=>{})}render()}
async function cloudMakeAdmin(u){if(!confirm('¿Pasar el cargo de administrador del evento a esta persona? Tú quedarás como editor de tu área.'))return;
  try{const {error}=await sb.rpc('transfer_event_admin',{p_event:CL.cur,p_user:u});if(error)throw error;await cloudLoad(CL.cur);await cloudTeamLoad().catch(()=>{});toast('Cargo transferido.')}catch(e){toast(cerr(e),true)}render()}
async function cloudRemove(u){if(!confirm('¿Quitar a esta persona del evento? Sus asignaciones se conservan.'))return;
  try{const {data,error}=await sb.from('members').delete().eq('event_id',CL.cur).eq('user_id',u).select('user_id');if(error)throw error;if(!data.length)throw {message:'No tienes permiso para quitar miembros.'};await cloudTeamLoad()}catch(e){toast(cerr(e),true)}render()}
async function cloudLa(u,ok){try{const {error}=await sb.rpc('decide_letters_access',{p_event:CL.cur,p_user:u,p_approve:ok});if(error)throw error;await cloudTeamLoad()}catch(e){toast(cerr(e),true)}render()}
async function cloudReqAccess(){try{const {data,error}=await sb.rpc('request_letters_access',{p_event:CL.cur});if(error)throw error;CL.access=data;toast('Solicitud enviada al administrador del evento.')}catch(e){toast(cerr(e),true)}render()}
async function cloudUserCan(u,v){try{ckr(await sb.rpc('admin_set_can_create',{p_user:u,p_value:v}));await cloudTabLoad('cta')}catch(e){toast(cerr(e),true)}render()}

/* ---------- Pantallas: Cuenta y Equipo ---------- */
const arLbl=a=>{const x=AREAS.find(y=>y.id==a);return x?a+' · '+x.h:a};
function vCta(){
  if(!sb)return '<h2>Cuenta</h2><p class="wn">No se pudo cargar la librería de la nube. Recarga la página con conexión a internet.</p>';
  const inv=lsg('asamblea-inv');
  if(CL.recovery)return `<h2>Nueva contraseña</h2><div class="cd"><label>Escribe tu nueva contraseña<input id="cp" type="password" autocomplete="new-password"></label><div class="r"><button class="on" onclick="cloudNewPass()">Guardar contraseña</button></div></div>`;
  if(!CL.user){const up=CL.mode=='up';
    return `<h2>Cuenta</h2><p class="mu">Con una cuenta puedes colaborar en eventos de la nube. Sin cuenta, la app sigue funcionando en este dispositivo.</p>
${inv?'<div class="cd"><b>Tienes una invitación pendiente</b><p class="mu">Inicia sesión o crea tu cuenta y quedarás unido al evento automáticamente.</p></div>':''}
<div class="cd"><div class="r"><button class="${up?'':'on'}" onclick="CL.mode='in';render()">Entrar</button><button class="${up?'on':''}" onclick="CL.mode='up';render()">Crear cuenta</button></div>
<div class="f" style="margin-top:8px">${up?'<label>Tu nombre (aparece en el registro de cambios)<input id="cn" autocomplete="name"></label>':''}<label>Correo<input id="ce" type="email" autocomplete="email"></label><label>Contraseña<input id="cp" type="password" autocomplete="${up?'new-password':'current-password'}" onkeydown="if(event.key=='Enter')${up?'cloudSignup()':'cloudLogin()'}"></label></div>
<div class="r"><button class="on" onclick="${up?'cloudSignup()':'cloudLogin()'}">${up?'Crear cuenta':'Entrar'}</button>${up?'':'<button onclick="cloudMagic()">Enviarme un enlace por correo</button><button onclick="cloudReset()">Olvidé mi contraseña</button>'}</div></div>`}
  const pf=CL.prof||{};let h=`<h2>Cuenta</h2><div class="cd"><div class="mu">${esc(CL.user.email||'')}${pf.is_superadmin?' · <span class="chip">Administrador general</span>':''}</div>
<label class="mu">Tu nombre (aparece en el registro de cambios)<input value="${esc(pf.display_name||'')}" onchange="cloudName(this.value)"></label><div class="r"><button onclick="cloudOut()">Cerrar sesión</button></div></div>
<div class="cd"><b>Unirme a un evento</b><p class="mu">Pega aquí el enlace o el código que te envió el administrador del evento.</p><div class="r"><input id="cj" placeholder="Enlace o código de invitación"><button onclick="cloudJoin()">Unirme</button></div></div>`;
  if(pf.can_create_events)h+=`<div class="cd"><b>Crear evento en la nube</b><p class="mu">Serás el administrador del evento. Elige el área a la que perteneces (cada área admite 2 personas por evento).</p><div class="f"><label>Nombre del evento<input id="cen"></label><label>Tu área<select id="cea">${AREAS.map(a=>`<option value="${a.id}">${esc(arLbl(a.id))}</option>`).join('')}</select></label></div>
${CL.cur?'':`<label class="mu" style="display:block;margin-top:6px"><input type="checkbox" id="cec"> Copiar a la nube los datos del evento local abierto («${esc((EV.list.find(e=>e.id==EV.cur)||{}).n||'')}»: directorio, asignaciones y cartas)</label>`}<div class="r"><button class="on" onclick="cloudCreate()">Crear evento</button></div></div>`;
  if(CL.superadmin){const A=CL.adm;h+=`<h2 style="margin-top:20px">Administración general</h2>`;
    if(!A)h+='<p class="mu">Cargando…</p>';else{
      h+=`<div class="w"><table><thead><tr><th>Evento</th><th>Administrador</th><th>Miembros</th><th>Personas</th><th>Asignaciones</th><th>Creado</th><th></th></tr></thead><tbody>${A.events.map(e=>`<tr><td>${esc(e.name)}</td><td>${esc(e.admin_name||'—')}<br><span class="mu">${esc(e.admin_email||'')}</span></td><td>${e.members}/6</td><td>${e.people}</td><td>${e.assignments}</td><td>${new Date(e.created_at).toLocaleDateString('es-MX')}</td><td><button onclick="cloudOpen('${e.id}')">Abrir</button> <button onclick="cloudDelEv('${e.id}',this.dataset.n)" data-n="${esc(e.name)}">Eliminar</button></td></tr>`).join('')||'<tr><td colspan="7" class="mu">Aún no hay eventos.</td></tr>'}</tbody></table></div>
<h2 style="margin-top:16px">Quién puede crear eventos</h2><p class="mu">Quien tenga la casilla marcada puede crear eventos y será su administrador.</p><div class="w"><table><thead><tr><th>Cuenta</th><th>Nombre</th><th>Puede crear eventos</th></tr></thead><tbody>${A.users.map(u=>`<tr><td>${esc(u.email||'')}</td><td>${esc(u.display_name||'')}${u.is_superadmin?' <span class="chip">general</span>':''}</td><td><input type="checkbox" ${u.can_create_events?'checked':''} onchange="cloudUserCan('${u.user_id}',this.checked)"></td></tr>`).join('')}</tbody></table></div>`}}
  return h}
function vEq(){
  if(!CL.cur)return '<p class="mu">Abre un evento de la nube para ver su equipo.</p>';
  if(!(CL.role=='admin'||CL.superadmin))return '<p class="mu">Solo el administrador del evento puede ver esta sección.</p>';
  if(!CL.team)return '<p class="mu">Cargando equipo…</p>';
  const M=CL.team.members,cnt=a=>M.filter(m=>m.area_id==a).length,laOf=u=>(CL.la||[]).find(r=>r.user_id==u),pend=(CL.la||[]).filter(r=>r.status=='pending'),nameOf=u=>{const m=M.find(x=>x.user_id==u);return m?(m.display_name||m.email||'—'):'—'};
  const live=CL.team.invites.filter(i=>i.uses<i.max_uses&&new Date(i.expires_at)>new Date());
  let h=`<h2>Equipo de «${esc(CL.name)}»</h2><p class="mu">Máximo 2 personas por área (6 en total). Tú eres quien invita, da acceso a las cartas de otras áreas y puede pasar el cargo de administrador.</p>`;
  if(pend.length)h+=`<div class="cd"><b>Solicitudes para ver las cartas de todas las áreas</b>${pend.map(r=>`<div class="r"><span>${esc(nameOf(r.user_id))}</span><button class="on" onclick="cloudLa('${r.user_id}',true)">Aprobar</button><button onclick="cloudLa('${r.user_id}',false)">Denegar</button></div>`).join('')}</div>`;
  h+=`<div class="w"><table><thead><tr><th>Nombre</th><th>Área</th><th>Cargo</th><th>Cartas de todas las áreas</th><th></th></tr></thead><tbody>${M.map(m=>{const a=laOf(m.user_id),st=m.role=='admin'?'Todas':a&&a.status=='approved'?`Con acceso <button onclick="cloudLa('${m.user_id}',false)">Quitar</button>`:a&&a.status=='pending'?`Solicitó <button class="on" onclick="cloudLa('${m.user_id}',true)">Aprobar</button> <button onclick="cloudLa('${m.user_id}',false)">Denegar</button>`:`Solo su área <button onclick="cloudLa('${m.user_id}',true)">Dar acceso</button>`;
    return `<tr><td>${esc(m.display_name||'—')}<br><span class="mu">${esc(m.email||'')}</span></td><td>${esc(arLbl(m.area_id))}</td><td>${m.role=='admin'?'<span class="chip">Administrador</span>':'Editor'}</td><td>${st}</td><td>${m.role=='admin'?'':`<button onclick="cloudMakeAdmin('${m.user_id}')">Hacer administrador</button> <button onclick="cloudRemove('${m.user_id}')">Quitar</button>`}</td></tr>`}).join('')}</tbody></table></div>`;
  h+=`<div class="cd"><b>Invitar a alguien</b><p class="mu">Genera un enlace de un solo uso (vence en 7 días) y envíalo por WhatsApp. La persona crea su cuenta o inicia sesión y queda como editor del área elegida.</p><div class="r"><select id="cia">${AREAS.map(a=>`<option value="${a.id}"${cnt(a.id)>=2?' disabled':''}>${esc(arLbl(a.id))} (${cnt(a.id)}/2${cnt(a.id)>=2?' · llena':''})</option>`).join('')}</select><button class="on" onclick="cloudInvite()">Generar enlace</button></div>
${CL.invLink?`<div class="lk">${esc(inviteUrl(CL.invLink.code))}</div><div class="r"><button onclick="cloudCopy('${CL.invLink.code}')">Copiar enlace</button><button onclick="cloudWa('${CL.invLink.code}')">Enviar por WhatsApp</button></div>`:''}
${live.length?`<p class="mu" style="margin-top:10px">Invitaciones pendientes</p>${live.map(i=>`<div class="r"><span>${esc(arLbl(i.area_id))} · vence ${new Date(i.expires_at).toLocaleDateString('es-MX')}</span><button onclick="cloudCopy('${i.code}')">Copiar</button><button onclick="cloudWa('${i.code}')">WhatsApp</button><button onclick="cloudRevokeInv('${i.code}')">Revocar</button></div>`).join('')}`:''}</div>`;
  return h}
