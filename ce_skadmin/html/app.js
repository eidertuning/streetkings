(function(){
  'use strict';
  const $=(s,r=document)=>r.querySelector(s);
  const $$=(s,r=document)=>Array.from(r.querySelectorAll(s));
  const APP_ID='sk_admin';
  const inTablet=window.parent!==window;
  const CLASS_ORDER=['ALL','STARTER','C','B','A','S'];
  const DEALER_ORDER=['ALL','starter','tuner','sportscar','muscle','offroad'];
  const CLASS_LABEL={ALL:'Todos',STARTER:'Starter',C:'Clase C',B:'Clase B',A:'Clase A',S:'Clase S'};
  const DEALER_LABEL={ALL:'Todos',starter:'Starter',tuner:'Tuner',sportscar:'Sports',muscle:'Muscle',offroad:'Off-Road'};
  const WEATHER=['CLEAR','EXTRASUNNY','CLOUDS','OVERCAST','RAIN','THUNDER','FOGGY','SMOG','XMAS'];
  const TIMES=[0,6,9,12,16,20,22];
  const WEATHER_ASSETS={sun:'assets/weather/sun.svg',moon:'assets/weather/moon.svg',cloudy:'assets/weather/cloudy.svg',stars:'assets/weather/stars.svg'};
  const WEATHER_ICON={CLEAR:'sun',EXTRASUNNY:'sun',CLOUDS:'cloudy',OVERCAST:'cloudy',RAIN:'cloudy',THUNDER:'cloudy',FOGGY:'cloudy',SMOG:'cloudy',XMAS:'stars'};

  const state={tab:'dashboard',data:null,catalog:[],selected:null,selectedSave:{},garage:null,booted:false,booting:false,lastRoute:{},lastError:null,catalogClass:'ALL',catalogDealer:'ALL',screen:{live:false,timer:null,last:null,busy:false,sessionId:null,pc:null,stream:null,status:'Desconectado',pollAfter:0,polling:false,remoteSet:false}};
  const imageCache=Object.create(null);

  const svg={
    shield:'M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3z',
    dashboard:'M3 13h8V3H3v10zm10 8h8V3h-8v18zM3 21h8v-6H3v6z',
    bolt:'M13 2 4 14h7l-1 8 9-12h-7l1-8z',
    users:'M7 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm10 0a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2 21c0-4 2.7-7 6-7s6 3 6 7H2zm12.5 0c-.2-2.2-1-4-2.3-5.4A6.2 6.2 0 0 1 17 14c3 0 5 2.7 5 7h-7.5z',
    hand:'M7 11V5a2 2 0 1 1 4 0v5h1V4a2 2 0 1 1 4 0v6h1V6a2 2 0 1 1 4 0v7c0 5-3 9-8 9h-2c-3.5 0-6.2-1.8-7.5-5L2 12a2 2 0 1 1 3.8-1l1.2 3V11z',
    eye:'M12 5c5.5 0 9.4 4.1 10.5 7-1.1 2.9-5 7-10.5 7S2.6 14.9 1.5 12C2.6 9.1 6.5 5 12 5zm0 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
    garage:'M3 21V8l9-5 9 5v13h-4v-7H7v7H3zm5-9h8V9H8v3z',
    money:'M4 6h16v12H4V6zm8 9a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM6 8v2a2 2 0 0 0 2-2H6zm12 8v-2a2 2 0 0 0-2 2h2z',
    world:'M12 22a10 10 0 1 1 0-20 10 10 0 0 1 0 20zm0-2c1.8-2.1 2.8-4.5 2.9-7H9.1c.1 2.5 1.1 4.9 2.9 7zm2.9-9A13.6 13.6 0 0 0 12 4a13.6 13.6 0 0 0-2.9 7h5.8z',
    message:'M3 5h18v12H8l-5 4V5zm4 5h10V8H7v2zm0 4h7v-2H7v2z',
    diag:'M9 3h6v3h4v15H5V6h4V3zm2 2v2h2V5h-2zm-3 6h8V9H8v2zm0 4h8v-2H8v2zm0 4h5v-2H8v2z',
    target:'M12 2v3a7 7 0 0 1 7 7h3v2h-3a7 7 0 0 1-7 7v3h-2v-3a7 7 0 0 1-7-7H0v-2h3a7 7 0 0 1 7-7V2h2zm-1 5a5 5 0 1 0 0 10 5 5 0 0 0 0-10zm0 3a2 2 0 1 1 0 4 2 2 0 0 1 0-4z',
    refresh:'M17.7 6.3A8 8 0 1 0 20 12h-2a6 6 0 1 1-1.8-4.2L13 11h8V3l-3.3 3.3z',
    camera:'M4 7h3l2-3h6l2 3h3v13H4V7zm8 10a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
    close:'M6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12 19 6.4 17.6 5 12 10.6 6.4 5z',
    car:'M4 15l1.5-5A3 3 0 0 1 8.4 8h7.2a3 3 0 0 1 2.9 2l1.5 5v4h-2v2h-3v-2H9v2H6v-2H4v-4zm4-5-1 4h10l-1-4H8z',
    trash:'M6 7h12l-1 14H7L6 7zm3-3h6l1 2H8l1-2z',
    plus:'M11 4h2v7h7v2h-7v7h-2v-7H4v-2h7V4z',
    copy:'M8 7h11v14H8V7zm-3 10H3V3h11v2H5v12z',
    check:'M9.5 17.5 4 12l1.6-1.6 3.9 3.9 8.9-8.9L20 7 9.5 17.5z',
    lock:'M7 10V7a5 5 0 0 1 10 0v3h2v11H5V10h2zm2 0h6V7a3 3 0 0 0-6 0v3z',
    id:'M4 5h16v14H4V5zm3 4h5V7H7v2zm0 4h10v-2H7v2zm0 4h7v-2H7v2z',
    wrench:'M22 6.5a6.5 6.5 0 0 1-8.7 6.1l-7.2 7.2a2.5 2.5 0 0 1-3.5-3.5l7.2-7.2A6.5 6.5 0 0 1 17.5 2l-4 4 4 4 4-3.5z',
    soap:'M6 12h12a3 3 0 0 1 3 3v1a5 5 0 0 1-5 5H8a5 5 0 0 1-5-5v-1a3 3 0 0 1 3-3zm1-5a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm6 2a3 3 0 1 1 0-6 3 3 0 0 1 0 6z',
    rotate:'M12 4a8 8 0 1 1-7.4 5H2l4-5 4 5H7a5 5 0 1 0 5-3V4z',
    map:'M3 5l6-2 6 2 6-2v16l-6 2-6-2-6 2V5zm8 .5v12l2 .7v-12l-2-.7z',
    gauge:'M12 4a10 10 0 0 1 10 10c0 2.2-.7 4.2-2 5.8H4A10 10 0 0 1 12 4zm1 10 5-5-1.4-1.4-5 5A2 2 0 1 0 13 14z',
    music:'M9 18V5l10-2v13a3 3 0 1 1-2-2.8V7.4l-6 1.2V18a3 3 0 1 1-2 0z',
    video:'M3 6h12v12H3V6zm13 4 5-3v10l-5-3v-4z',
    phone:'M8 2h8a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zm2 3v12h4V5h-4zm2 16a1 1 0 1 0 0-2 1 1 0 0 0 0 2z',
    location:'M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6a2.5 2.5 0 0 1 0 5.5z',
    snow:'M11 2h2v20h-2V2zM4 6l16 12-1.2 1.6L2.8 7.6 4 6zm16 0 1.2 1.6-16 12L4 18 20 6z',
    heart:'M12 21s-8-5.2-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.8-8 11-8 11z',
    skull:'M12 2a8 8 0 0 0-8 8v5l2 2v3h12v-3l2-2v-5a8 8 0 0 0-8-8zM9 12a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm6 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4z',
  };
  function icon(name){return `<svg class="skico" viewBox="0 0 24 24" aria-hidden="true"><path d="${svg[name]||svg.bolt}"></path></svg>`;}
  function weatherAsset(kind){return WEATHER_ASSETS[kind]||WEATHER_ASSETS.cloudy;}
  function weatherKind(weather,hour){weather=String(weather||'CLEAR').toUpperCase(); if(weather==='XMAS')return 'stars'; if(['CLOUDS','OVERCAST','RAIN','THUNDER','FOGGY','SMOG'].includes(weather))return 'cloudy'; const h=Number(hour); return (h>=20||h<6)?'moon':'sun';}
  function weatherClass(weather,hour){const kind=weatherKind(weather,hour); const night=(Number(hour)>=20||Number(hour)<6); const storm=['RAIN','THUNDER'].includes(String(weather||'').toUpperCase()); return `${kind} ${night?'night':'day'} ${storm?'storm':''}`;}
  function weatherCard(weather,label,hour){const kind=weatherKind(weather,hour);return `<button class="chip weather-chip" data-world-weather="${esc(weather)}"><img src="${weatherAsset(kind)}" alt=""><span>${esc(label||weather)}</span></button>`;}
  function skyScene(current){const weather=String(current.weather||'CLEAR').toUpperCase();const h=Number(current.h??12);const kind=weatherKind(weather,h);const cls=weatherClass(weather,h);return `<div class="weather-stage ${cls}"><img class="weather-stars" src="${weatherAsset('stars')}" alt=""><img class="weather-main" src="${weatherAsset(kind)}" alt=""><img class="weather-cloud one" src="${weatherAsset('cloudy')}" alt=""><img class="weather-cloud two" src="${weatherAsset('cloudy')}" alt=""><div class="weather-rain"></div><div class="weather-scan"></div></div>`;}
  function playSiren(){const a=$('#tsunamiSiren');if(!a){toast('No está cargado el sonido','error');return;}try{a.currentTime=0;a.volume=.72;const p=a.play();if(p&&p.catch)p.catch(()=>toast('Pulsa otra vez para activar audio','info'));toast('Sirena UI activada','info');}catch(e){toast('Audio bloqueado por el navegador','error');}}
  function stopSiren(){const a=$('#tsunamiSiren');if(a){a.pause();a.currentTime=0;}toast('Sirena detenida','ok');}
  function esc(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));}
  function money(v){return '$'+Number(v||0).toLocaleString('en-US');}
  function short(v,n=26){v=String(v||'');return v.length>n?v.slice(0,Math.max(8,n-8))+'…'+v.slice(-6):v;}
  function wait(ms){return new Promise(r=>setTimeout(r,ms));}
  function reveal(){document.body.classList.remove('boot-hidden','standalone-hidden');}
  function hideStandalone(){document.body.classList.add('standalone-hidden');}

  function fallbackFetchNui(event,data){
    if(typeof fetchNui==='function')return fetchNui(event,data||{});
    if(typeof GetParentResourceName==='function')return fetch(`https://${GetParentResourceName()}/${event}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data||{})}).then(r=>r.json());
    return Promise.resolve({ok:false,error:'no_tablet_sdk'});
  }
  async function callNui(event,data,retries=2){
    let last=null;
    for(let i=0;i<=retries;i++){
      try{const r=await fallbackFetchNui(event,data||{}); last=r; if(r&&r.error!=='invalid_app_request'&&r.error!=='app_not_ready')return r;}catch(e){last={ok:false,error:e.message||'fetch_error'};}
      await wait(240+i*140);
    }
    return last||{ok:false,error:'no_response'};
  }
  function toast(msg,type='ok'){const t=$('#toast'); if(!t)return; t.className='toast '+(type==='error'?'err':type); t.textContent=msg||''; t.classList.remove('hidden'); clearTimeout(toast._t); toast._t=setTimeout(()=>t.classList.add('hidden'),3200);}

  async function boot(force){
    if(state.booting&&!force)return; state.booting=true;
    if(!inTablet){state.lastError='No abierto desde la tablet oficial.';hideStandalone();state.booting=false;return;}
    reveal(); renderShellIcons(); await wait(250);
    const res=await callNui('skAdminBoot',{fromTabletFrame:true,appId:APP_ID,route:state.lastRoute||{}},8);
    if(!res||!res.ok){state.booting=false;showLocked(res?.error||'not_authorized');return;}
    state.booted=true; state.booting=false; $('#app')?.classList.remove('locked'); await load();
  }
  async function ensureBooted(){if(state.booted)return true; await boot(true); return state.booted;}
  function showLocked(reason){reveal();state.booted=false;$('#app')?.classList.add('locked');renderShellIcons();renderTabs();const c=$('#content');if(c)c.innerHTML=`<div class="empty-state"><div class="empty-icon">${icon('lock')}</div><h3>Acceso bloqueado</h3><p>${esc(reason||'Esta app solo funciona desde la tablet y con permiso admin.')}</p><button class="btn gold" id="retryBoot">Reintentar</button></div>`;$('#retryBoot')?.addEventListener('click',()=>boot(true));}
  async function load(){
    if(!state.booted)return showLocked(state.lastError||'Sesión no iniciada.');
    const res=await callNui('skAdminGetData',{},2);
    if(!res||!res.ok){if(['missing_session','bad_session','no_session','session_expired','invalid_app_request'].includes(res?.error)){state.booted=false;await boot(true);return;}return showLocked(res?.error||'No autorizado');}
    state.data=res; state.catalog=Array.isArray(res.catalog)?res.catalog:[];
    $('#rankPill').textContent=(res.auth?.rank||'admin').toUpperCase(); $('#clockPill').textContent=res.serverTime||'--:--'; $('#playerCount').textContent=(res.players||[]).length+' conectados';
    syncDefaultSelection(); renderTabs(); renderPlayers(); renderTarget(); renderContent();
  }
  function syncDefaultSelection(){const players=state.data?.players||[]; if(!state.selected&&players[0])state.selected=players[0].id; for(const p of players){if(!state.selectedSave[p.id])state.selectedSave[p.id]=p.defaultSaveId||p.characters?.[0]?.id||(p.activeSave?'__active':'');}}
  function selected(){return(state.data?.players||[]).find(p=>String(p.id)===String(state.selected));}
  function currentSave(p=selected()){if(!p)return null;const key=state.selectedSave[p.id]||'';if(key==='__active')return{id:'__active',displayName:'Personaje cargado',live:true,cash:p.cash,level:p.level,garageCount:p.garageCount,activeVehicleName:p.activeVehicle?.displayName||p.activeVehicle?.modelName};return(p.characters||[]).find(x=>String(x.id)===String(key))||p.characters?.[0]||null;}
  function savePayload(){const p=selected(),sv=currentSave(p); if(!p||!sv||sv.id==='__active')return{}; return{targetSaveId:String(sv.id),targetSlot:sv.slotIndex};}
  function renderShellIcons(){if($('#brandIcon'))$('#brandIcon').innerHTML=icon('shield'); if($('#refreshBtn'))$('#refreshBtn').innerHTML=icon('refresh'); if($('#closeBtn'))$('#closeBtn').innerHTML=icon('close');}

  const tabs=[['dashboard','dashboard','Control'],['actions','bolt','Admin'],['economy','money','Dinero/XP'],['garage','garage','Garaje'],['world','world','Ambiente'],['messages','message','Mensajes'],['screen','camera','Vista'],['diagnostics','diag','Logs']];
  function renderTabs(){const el=$('#tabs'); if(!el)return; el.innerHTML=tabs.map(t=>`<button class="tab ${state.tab===t[0]?'active':''}" data-tab="${t[0]}">${icon(t[1])}<span>${t[2]}</span></button>`).join('');}

  function renderPlayers(){
    const q=($('#playerSearch')?.value||'').toLowerCase();
    const players=(state.data?.players||[]).filter(p=>!q||String(p.name).toLowerCase().includes(q)||String(p.id).includes(q)||String(p.license||'').toLowerCase().includes(q));
    const el=$('#playersList'); if(!el)return;
    el.innerHTML=players.map(p=>{const sv=currentSave(p)||{};const active=!!p.activeSave;return `<button class="player-card room-player ${String(p.id)===String(state.selected)?'active':''}" data-player="${p.id}"><div class="row-head"><div class="room-id"><b>#${p.id} ${esc(p.name)}</b><small>${active?'save cargado':'base de datos'} · ${p.characters?.length||0} slots</small></div><span class="status-dot ${active?'':'off'}">${p.ping||0}ms</span></div><div class="id-line"><span title="${esc(p.license||'')}">${esc(short(p.license||'sin licencia',34))}</span><span class="copy-mini" data-copy="${esc(p.license||'')}">${icon('copy')}</span></div><div class="badges"><span class="badge ${active?'ok':'warn'}">${active?'Online':'DB'}</span><span class="badge">${money(sv.cash??p.cash)}</span><span class="badge">LV ${sv.level??p.level??1}</span><span class="badge">${sv.garageCount??p.garageCount??0} coches</span></div></button>`;}).join('')||'<div class="empty-mini">Sin jugadores.</div>';
  }
  function renderTarget(){
    const p=selected(); const box=$('#targetBox'); if(!box)return; if(!p){box.className='target-box empty';box.textContent='Selecciona un jugador.';return;}
    const sv=currentSave(p)||{};
    box.className='target-box';
    const options=(p.characters||[]).map(x=>`<option value="${esc(x.id)}" ${String(sv.id)===String(x.id)?'selected':''}>Slot ${x.slotIndex} · ${esc(x.displayName)} · ${money(x.cash)} · ${x.garageCount||0} coches</option>`).join('');
    box.innerHTML=`<div class="target-title"><span>${icon('target')}</span><div><h3>#${p.id} ${esc(p.name)}</h3><p>${p.activeSave?'personaje cargado':'solo datos guardados'}</p></div></div><label class="mini-label">Personaje / slot</label><select id="saveSelect" class="save-select">${p.activeSave?`<option value="__active" ${sv.id==='__active'?'selected':''}>Personaje cargado ahora</option>`:''}${options}</select><div class="target-grid"><div class="kv"><b>Cash</b><span>${money(sv.cash??p.cash)}</span></div><div class="kv"><b>Nivel</b><span>${sv.level??p.level??1}</span></div><div class="kv"><b>Vehículo</b><span title="${esc(sv.activeVehicleName||p.activeVehicle?.displayName||p.activeVehicle?.modelName||'')}">${esc(short(sv.activeVehicleName||p.activeVehicle?.displayName||p.activeVehicle?.modelName||'—',26))}</span></div><div class="kv"><b>Garaje</b><span>${sv.garageCount??p.garageCount??0} coches</span></div><div class="kv"><b>Vida</b><span>${p.health||0}</span></div><div class="kv"><b>Chaleco</b><span>${p.armor||0}</span></div><div class="kv"><b>Licencia</b><span class="copy-value"><em title="${esc(p.license||'')}">${esc(short(p.license||'',28))}</em><button class="copy-btn" data-copy="${esc(p.license||'')}">${icon('copy')}</button></span></div><div class="kv"><b>Coords</b><span>${Number(p.coords?.x||0).toFixed(1)}, ${Number(p.coords?.y||0).toFixed(1)}, ${Number(p.coords?.z||0).toFixed(1)}</span></div></div>`;
  }

  function renderContent(){
    const p=selected(); const c=$('#content'); if(!c)return;
    if(state.tab==='dashboard')c.innerHTML=dashboard(p);
    if(state.tab==='actions')c.innerHTML=actions(p);
    if(state.tab==='economy')c.innerHTML=economy(p);
    if(state.tab==='garage'){c.innerHTML=garage(p); loadGarage(false);}
    if(state.tab==='world')c.innerHTML=world();
    if(state.tab==='messages')c.innerHTML=messages(p);
    if(state.tab==='screen')c.innerHTML=screen(p);
    if(state.tab==='diagnostics')c.innerHTML=diagnostics(p);
    hydrateImages();
  }
  function dashboard(p){
    const players=state.data?.players||[];
    const active=players.filter(x=>x.activeSave).length;
    const roomCards=players.map(x=>{const sv=currentSave(x)||{};const isSel=String(x.id)===String(state.selected);return `<button class="room-card ${isSel?'active':''}" data-player="${x.id}"><div><div class="status-dot ${x.activeSave?'':'off'}">${x.activeSave?'ACTIVO':'DB'}</div><h4>#${x.id} ${esc(x.name)}</h4><p>${esc(short(x.license||'sin licencia',38))}</p><div class="room-meta"><span class="room-tag">${money(sv.cash??x.cash)}</span><span class="room-tag">LV ${sv.level??x.level??1}</span><span class="room-tag">${sv.garageCount??x.garageCount??0} coches</span></div></div><div class="room-side"><span class="room-ping">${x.ping||0}ms</span><span class="room-tag">${x.characters?.length||0} slots</span></div></button>`;}).join('')||'<div class="empty-mini">No hay jugadores conectados.</div>';
    return `<div class="control-hero"><div><div class="control-hero-kicker">${icon('shield')} Five Horizon</div><h2>Sala de control</h2><p>Selecciona un jugador, revisa su slot/personaje y ejecuta acciones desde la tablet oficial del servidor.</p></div><button class="btn gold" data-tab="actions">Abrir acciones</button></div><div class="grid three"><div class="card stat"><b>${players.length}</b><span>Jugadores detectados</span></div><div class="card stat"><b>${active}</b><span>Con save activo</span></div><div class="card stat"><b>${p?'#'+p.id:'--'}</b><span>Objetivo seleccionado</span></div></div><div class="room-board card"><div class="room-board-head"><h3>Sala admin</h3><span>${players.length} entradas</span></div><div class="console-line"><b>Modo seguro:</b> usa sesión temporal de tablet, permisos por rango y selección de slot antes de tocar cash, XP o garaje. <em>No se abre fuera de la tablet.</em></div><div class="room-list-grid">${roomCards}</div></div>`;
  }
  function actions(p){
    const groups=[
      ['Jugador',[['player.goto','location','Ir a jugador'],['player.bring','hand','Traer'],['player.spectate','eye','Observar'],['capture.open','camera','Vista tablet'],['player.freeze','snow','Congelar'],['player.revive','heart','Revivir'],['player.heal','heart','Curar'],['player.armor','shield','Chaleco'],['player.kill','skull','Matar']]],
      ['Vehículo',[['vehicle.repair','wrench','Reparar coche'],['vehicle.clean','soap','Limpiar'],['vehicle.flip','rotate','Voltear'],['vehicle.warpwp','map','Warp mapa']]],
      ['Framework',[['vehicle.speedometer','gauge','Velocímetro'],['vehicle.soundtrack','music','Música'],['vehicle.cinematic','video','Cine'],['phone.toggle','phone','Abrir teléfono']]]
    ];
    return `<div class="action-board">${groups.map(g=>`<section class="card action-section"><h3>${icon('bolt')} ${g[0]}</h3><div class="action-grid">${g[1].map(a=>`<button class="action-btn" data-action="${a[0]}" ${!p?'disabled':''}>${icon(a[1])}<span>${a[2]}</span></button>`).join('')}</div></section>`).join('')}</div>`;
  }
  function economy(p){const d=state.data?.defaults||{};return `<div class="grid two"><div class="card section"><h3>${icon('money')} Dinero</h3><p class="mini-note">Se aplica al personaje/slot seleccionado.</p>${inputAction('cashAmount','Cantidad cash',d.cash||1000,'cash.add','Añadir cash')}${inputAction('cashRemove','Quitar cash',d.cash||1000,'cash.remove','Quitar cash')}</div><div class="card section"><h3>${icon('bolt')} Experiencia</h3><p class="mini-note">Jugador = nivel del personaje. Vehículo = coche activo del slot.</p>${inputAction('pxp','XP jugador',d.playerXp||250,'xp.player','Dar XP jugador')}${inputAction('vxp','XP vehículo',d.vehicleXp||100,'xp.vehicle','Dar XP vehículo')}</div></div>`;}
  function inputAction(id,label,val,act,btn){return `<label class="amount-row"><span>${label}</span><div><input id="${id}" type="number" min="1" value="${val}"><button class="btn gold" data-input="${id}" data-input-action="${act}">${btn}</button></div></label>`;}

  function garage(p){
    const countByClass={ALL:state.catalog.length}; for(const v of state.catalog){const c=v.class||'OTHER';countByClass[c]=(countByClass[c]||0)+1;}
    state.catalogDealer='ALL';
    return `<div class="garage-clean"><section class="garage-owned card"><div class="card-head"><h3>${icon('garage')} Garaje del personaje</h3><span id="garageCountLabel">Cargando...</span></div><div id="garageList" class="owned-list"><div class="empty-mini">Cargando garaje...</div></div></section><section class="garage-catalog card"><div class="card-head"><h3>${icon('plus')} Catálogo StreetKings por clase</h3><span id="catalogCountLabel">${state.catalog.length} coches</span></div><div class="catalog-tools"><input id="catalogSearch" class="search compact" placeholder="Buscar modelo, nombre, marca o clase..."><div id="classFilters" class="filter-grid class-filter">${CLASS_ORDER.map(c=>`<button class="seg-btn ${state.catalogClass===c?'active':''}" data-catalog-class="${c}"><span>${CLASS_LABEL[c]||c}</span><small>${countByClass[c]||0}</small></button>`).join('')}</div></div><div id="catalogList" class="catalog-list"></div></section></div>`;
  }
  async function loadGarage(force){
    const p=selected(); if(!p)return; const sv=currentSave(p); const key=p.id+':'+(sv?.id||'');
    if(!force&&state.garage&&state.garage.key===key){renderGarageLists();return;}
    const res=await callNui('skAdminGarage',Object.assign({target:p.id,targetLicense:p.license},savePayload()),2);
    state.garage={key,data:res&&res.ok?res:{vehicles:[],error:res?.error||'garage_error'}}; renderGarageLists();
  }
  function catalogEntry(model){model=String(model||'').toLowerCase(); return (state.catalog||[]).find(v=>String(v.model||'').toLowerCase()===model);}
  function imageSourcesFor(v){
    const model=String(v.model||v.modelName||'').toLowerCase(); const cat=catalogEntry(model); let src=[];
    if(v.imageUrl)src.push(v.imageUrl); if(Array.isArray(v.imageSources))src=src.concat(v.imageSources); if(cat?.imageUrl)src.push(cat.imageUrl); if(Array.isArray(cat?.imageSources))src=src.concat(cat.imageSources);
    const seen=new Set(); return src.filter(x=>typeof x==='string'&&x&& !seen.has(x) && seen.add(x));
  }
  function imageBox(v){
    const model=String(v.model||v.modelName||v.id||'').toLowerCase(); const srcs=imageSourcesFor(v); const key=model||String(v.id||Math.random()); const cached=imageCache[key];
    if(cached&&cached.ok)return `<div class="veh-thumb with-img" style="background-image:url('${esc(cached.url)}')"></div>`;
    return `<div class="veh-thumb noimg" data-img-key="${esc(key)}" data-img-srcs="${esc(JSON.stringify(srcs))}">${icon('car')}</div>`;
  }
  function hydrateImages(){
    $$('[data-img-key]').forEach(el=>{
      const key=el.dataset.imgKey; if(!key)return; const cached=imageCache[key];
      if(cached?.ok){el.classList.remove('noimg');el.classList.add('with-img');el.style.backgroundImage=`url('${cached.url}')`;el.innerHTML='';return;}
      if(cached?.failed||cached?.loading)return;
      let srcs=[]; try{srcs=JSON.parse(el.dataset.imgSrcs||'[]')}catch(e){}
      if(!Array.isArray(srcs)||!srcs.length){imageCache[key]={failed:true};return;}
      imageCache[key]={loading:true}; let i=0;
      const next=()=>{ if(i>=srcs.length){imageCache[key]={failed:true};return;} const url=srcs[i++]; const img=new Image(); img.onload=()=>{imageCache[key]={ok:true,url}; $$('[data-img-key]').filter(x=>x.dataset.imgKey===key).forEach(x=>{x.classList.remove('noimg');x.classList.add('with-img');x.style.backgroundImage=`url('${url}')`;x.innerHTML='';});}; img.onerror=next; img.src=url; };
      next();
    });
  }
  function classBadge(v){const c=v.class||'—';return `<span class="class-badge c-${String(c).toLowerCase()}">${esc(c)}</span>`;}
  function renderGarageLists(){
    const res=state.garage?.data||{}, vehicles=res.vehicles||[];
    const gl=$('#garageList'); if(gl){$('#garageCountLabel')&&($('#garageCountLabel').textContent=vehicles.length+' coches'); gl.innerHTML=vehicles.map(v=>`<div class="vehicle-row owned ${v.active?'active':''}">${imageBox(v)}<div class="veh-main"><div class="veh-title"><h4 title="${esc(v.displayName||v.modelName||v.id)}">${esc(v.displayName||v.modelName||v.id)}</h4>${v.active?'<span class="live-dot">Activo</span>':''}</div><p>${esc(v.modelName)} · ${esc(v.plate||'sin placa')}</p><div class="mini-badges"><span>LV ${v.data?.level||1}</span><span>XP ${v.data?.xp||0}</span></div></div><div class="vehicle-actions"><button class="icon-btn" title="Poner activo" data-garage-set="${esc(v.id)}">${icon('check')}</button><button class="icon-btn danger" title="Borrar" data-garage-delete="${esc(v.id)}">${icon('trash')}</button></div></div>`).join('')||'<div class="empty-mini">Sin coches en este personaje.</div>';}
    renderCatalog(); hydrateImages();
  }
  function filteredCatalog(){
    const q=($('#catalogSearch')?.value||'').toLowerCase().trim();
    return (state.catalog||[]).filter(v=>{
      if(state.catalogClass!=='ALL'&&String(v.class)!==state.catalogClass)return false;
      if(!q)return true;
      return [v.model,v.name,v.displayName,v.brand,v.class,v.dealerLabel,v.dealerType].some(x=>String(x||'').toLowerCase().includes(q));
    });
  }
  function renderCatalog(){
    const el=$('#catalogList'); if(!el)return; const list=filteredCatalog(); const total=$('#catalogCountLabel'); if(total)total.textContent=list.length+' / '+state.catalog.length+' coches';
    if(state.catalogClass==='ALL'&&!($('#catalogSearch')?.value||'').trim()){
      const by={}; for(const v of list){const c=v.class||'OTHER';(by[c]=by[c]||[]).push(v);}
      el.innerHTML=CLASS_ORDER.filter(c=>c!=='ALL'&&by[c]?.length).map(c=>`<div class="class-section"><div class="class-title"><b>${CLASS_LABEL[c]||c}</b><span>${by[c].length} coches</span></div><div class="catalog-grid">${by[c].map(catalogCard).join('')}</div></div>`).join('')||'<div class="empty-mini">Sin resultados.</div>';
    }else{el.innerHTML=`<div class="catalog-grid">${list.map(catalogCard).join('')}</div>`||'<div class="empty-mini">Sin resultados.</div>';}
    hydrateImages();
  }
  function catalogCard(v){return `<div class="catalog-card">${imageBox(v)}<div class="veh-main"><div class="veh-title"><h4 title="${esc(v.name||v.model)}">${esc(v.name||v.model)}</h4>${classBadge(v)}</div><p>${esc(v.brand||'Sin marca')} · ${esc(v.model)} · ${esc(v.dealerLabel||v.category||'')}</p><div class="mini-badges"><span>${money(v.price)}</span><span>${esc(v.type||'auto')}</span></div></div><button class="btn gold small" data-add-model="${esc(v.model)}">Agregar</button></div>`;}

  function world(){
    const current=state.data?.worldState||{};
    const hh=String(current.h??'--').padStart(2,'0'), mm=String(current.m??'00').padStart(2,'0');
    const hNum=Number(current.h??12);
    const weather=String(current.weather||'CLEAR').toUpperCase();
    const labels={CLEAR:'Despejado',EXTRASUNNY:'Soleado',CLOUDS:'Nubes',OVERCAST:'Cubierto',RAIN:'Lluvia',THUNDER:'Tormenta',FOGGY:'Niebla',SMOG:'Smog',XMAS:'Nieve'};
    return `<div class="world-clean enhanced-world"><div class="world-status card world-visual"><div><h3>${icon('world')} Ambiente StreetKings</h3><div class="status-cards"><b>${hh}:${mm}</b><span>${esc(weather||'desconocido')}</span><em>${current.autoWeather===false?'Auto clima OFF':'Auto clima'} · ${current.weatherFrozen?'clima fijado':'clima libre'}</em></div><p class="mini-note">Ahora usa los SVG copiados dentro del recurso: sol, luna, nubes y estrellas con animación según hora/clima.</p></div>${skyScene(current)}</div><div class="grid two"><div class="card section"><h3>${icon('world')} Hora animada</h3><div class="chip-grid time-grid">${TIMES.map(h=>`<button class="chip time-chip ${(Number(current.h)===h)?'active':''}" data-world-time="${h}"><span>${String(h).padStart(2,'0')}:00</span><small>${h>=20||h<6?'Noche':h<12?'Mañana':h<18?'Día':'Tarde'}</small></button>`).join('')}</div><label class="amount-row"><span>Hora personalizada</span><div><input id="customHour" type="number" min="0" max="23" placeholder="0-23"><button class="btn gold" data-custom-time>Aplicar</button></div></label></div><div class="card section"><h3>${icon('world')} Clima con SVG</h3><div class="chip-grid weather-grid animated-weather">${WEATHER.map(w=>weatherCard(w,labels[w]||w,hNum)).join('')}</div></div></div><div class="card section siren-card"><div><h3>${icon('music')} Tsunami siren UI</h3><p class="mini-note">Sonido integrado en assets/sounds. Botón de prueba solo para la interfaz de admin.</p></div><div class="siren-actions"><button class="btn gold" data-siren-test>Probar sirena</button><button class="btn danger" data-siren-stop>Detener</button></div></div></div>`;
  }


  function screen(p){
    const status=state.screen.status||'Desconectado';
    const selfId=Number(state.data?.self?.id||0);
    const isSelf=!!p&&Number(p.id)===selfId;
    const target=p?`#${p.id} ${esc(p.name)}`:'Sin jugador seleccionado';
    const disabled=!p||isSelf||state.screen.live;
    const hint=isSelf?'Selecciona otro jugador conectado. No puedes abrir vista sobre tu propia tablet.':(p?'Vista directa del jugador seleccionado.':'Selecciona un jugador conectado.');
    return `<div class="screen-layout"><div class="card section screen-card live-card"><div class="live-head"><div><h3>${icon('camera')} Vista en vivo</h3><p class="mini-note">${hint}</p></div><div class="live-status ${state.screen.live?'on':''}">${state.screen.live?'LIVE':'OFF'}</div></div><div class="live-toolbar"><span class="live-target">${target}</span><span id="liveStatusText" class="mini-note">${esc(status)}</span><button class="btn gold" data-live-start ${disabled?'disabled':''}>Iniciar vista</button><button class="btn danger" data-live-stop ${!state.screen.live?'disabled':''}>Detener</button></div><div id="screenView" class="screen-view live-view ${state.screen.live?'':'empty'}"><video id="liveVideo" autoplay playsinline muted></video><div class="live-empty">${icon('camera')}<span>${state.screen.live?'Conectando con el jugador...':(isSelf?'Selecciona otro jugador para ver la vista.':'Selecciona un jugador y pulsa Iniciar vista.')}</span></div></div></div></div>`;
  }

  function messages(p){return `<div class="grid two"><div class="card section"><h3>${icon('message')} Mensaje al jugador</h3><input id="msgSender" value="Admin"><textarea id="msgBody">Mensaje de administración.</textarea><p class="mini-note">Si el teléfono oficial no tiene personaje cargado, se envía aviso directo.</p><button class="btn gold" data-send-message ${!p?'disabled':''}>Enviar</button></div><div class="card section"><h3>${icon('message')} Broadcast</h3><textarea id="broadcastBody">Mensaje global de administración.</textarea><p class="mini-note">Avisa a todos los jugadores conectados.</p><button class="btn gold" data-broadcast>Enviar a todos</button></div></div>`;}
  function diagnostics(p){const data={selected:p,selectedSave:currentSave(p),catalogCount:state.catalog.length,garage:state.garage?.data,worldState:state.data?.worldState,imageCache,logs:state.data?.logs||[],lastError:state.lastError}; return `<div class="card section"><h3>${icon('diag')} Diagnóstico</h3><pre class="diag">${esc(JSON.stringify(data,null,2))}</pre></div>`;}


  const LIVE_ICE={iceServers:[{urls:'stun:stun.l.google.com:19302'},{urls:'stun:stun1.l.google.com:19302'},{urls:'stun:stun2.l.google.com:19302'},{urls:'stun:stun3.l.google.com:19302'},{urls:'stun:stun4.l.google.com:19302'}],iceCandidatePoolSize:6};
  function setLiveStatus(text,type){state.screen.status=text||'';const el=$('#liveStatusText');if(el)el.textContent=state.screen.status;const view=$('#screenView');if(view){view.classList.toggle('empty',!state.screen.stream);}}
  async function liveSend(signal){if(!state.screen.sessionId)return;return callNui('skAdminLiveSignal',{sessionId:state.screen.sessionId,signal},1);}
  async function handleLiveSignal(signal){
    if(!signal||!state.screen.pc)return;
    try{
      if(signal.type==='broadcaster_ready'){setLiveStatus('Jugador listo, enviando conexión...');return;}
      if(signal.type==='broadcaster_error'){setLiveStatus('Error objetivo: '+(signal.error||'desconocido'),'error');toast('Live error: '+(signal.error||'objetivo'),'error');return;}
      if(signal.type==='broadcaster_closed'){setLiveStatus('El jugador cerró el stream');stopLive(false);return;}
      if(signal.sdp){await state.screen.pc.setRemoteDescription(new RTCSessionDescription(signal.sdp));state.screen.remoteSet=true;setLiveStatus('Stream conectado');return;}
      if(signal.candidate){await state.screen.pc.addIceCandidate(new RTCIceCandidate(signal.candidate));}
    }catch(e){setLiveStatus('Error WebRTC: '+(e.message||e));}
  }
  async function pollLiveSignals(){
    if(!state.screen.live||!state.screen.sessionId||state.screen.polling)return;
    state.screen.polling=true;
    try{
      const res=await callNui('skAdminLivePoll',{sessionId:state.screen.sessionId,after:state.screen.pollAfter||0},0);
      if(!res||!res.ok){setLiveStatus(res?.error||'Live cerrado');stopLive(false);return;}
      for(const item of (res.signals||[])){state.screen.pollAfter=Math.max(state.screen.pollAfter||0,Number(item.id)||0);await handleLiveSignal(item.signal);}
    }finally{state.screen.polling=false;}
  }
  function bindLiveVideo(){const v=$('#liveVideo'); if(v&&state.screen.stream&&v.srcObject!==state.screen.stream){v.srcObject=state.screen.stream; v.play?.().catch(()=>{});} }
  async function startLive(){
    const p=selected(); if(!p){toast('Selecciona un jugador','error');return;}
    if(state.screen.live)return;
    stopLive(false);
    state.screen.live=true;state.screen.status='Creando sesión live...';state.screen.pollAfter=0;renderContent();
    const res=await callNui('skAdminLiveStart',Object.assign({target:p.id,targetLicense:p.license},savePayload()),2);
    if(!res||!res.ok){const msg=res?.error||'No se pudo iniciar live';toast(msg,'error');state.screen.status=msg;stopLive(false);renderContent();return;}
    state.screen.sessionId=res.sessionId;setLiveStatus('Conectando WebRTC...');
    const pc=new RTCPeerConnection(res.iceConfig||LIVE_ICE);state.screen.pc=pc;
    pc.ontrack=ev=>{state.screen.stream=ev.streams&&ev.streams[0];setLiveStatus('Stream conectado');bindLiveVideo();};
    pc.onicecandidate=ev=>{if(ev.candidate)liveSend({candidate:ev.candidate});};
    pc.onconnectionstatechange=()=>{const st=pc.connectionState;setLiveStatus('Estado: '+st);if(['failed','closed','disconnected'].includes(st)){setTimeout(()=>{if(state.screen.live&&['failed','closed'].includes(pc.connectionState))stopLive(true);},1200);}};
    try{
      const offer=await pc.createOffer({offerToReceiveVideo:true,offerToReceiveAudio:false});
      await pc.setLocalDescription(offer);
      await liveSend({sdp:pc.localDescription});
      const ms=Math.max(150,Number(res.pollMs||250));
      state.screen.timer=setInterval(()=>{ if(state.tab!=='screen'){stopLive(true);return;} pollLiveSignals(); },ms);
      pollLiveSignals();
    }catch(e){toast('Error live: '+(e.message||e),'error');stopLive(true);renderContent();}
  }
  async function stopLive(notifyServer=true){
    if(state.screen.timer){clearInterval(state.screen.timer);state.screen.timer=null;}
    const sessionId=state.screen.sessionId;
    try{if(state.screen.pc)state.screen.pc.close();}catch(e){}
    if(state.screen.stream){try{state.screen.stream.getTracks().forEach(t=>t.stop());}catch(e){}}
    state.screen.live=false;state.screen.sessionId=null;state.screen.pc=null;state.screen.stream=null;state.screen.remoteSet=false;state.screen.polling=false;state.screen.status='Desconectado';
    if(notifyServer&&sessionId)await callNui('skAdminLiveStop',{sessionId,reason:'closed_by_admin'},0);
    if(state.tab==='screen')renderContent();
  }

  async function doAction(payload,refresh=true){
    if(!(await ensureBooted()))return; const p=selected(); payload=payload||{}; if(p)Object.assign(payload,{target:p.id,targetLicense:p.license},savePayload());
    const res=await callNui('skAdminAction',payload,2);
    if(['missing_session','bad_session','session_expired','no_session','invalid_app_request'].includes(res?.error)){state.booted=false;await boot(true);return doAction(payload,refresh);}
    toast(res?.message||res?.error||(res?.ok?'OK':'Error'),res?.ok?'ok':'error'); if(!refresh)return;
    if(String(payload.action||'').startsWith('garage.')){await loadGarage(true); await load(); return;} await load(); if(state.tab==='garage')await loadGarage(true);
  }
  async function copyText(text){try{await navigator.clipboard.writeText(text);toast('Copiado','ok');}catch(e){const ta=document.createElement('textarea');ta.value=text;document.body.appendChild(ta);ta.select();document.execCommand('copy');ta.remove();toast('Copiado','ok');}}

  document.addEventListener('click',async e=>{
    const cp=e.target.closest('[data-copy]'); if(cp){e.stopPropagation();return copyText(cp.dataset.copy||'');}
    const tab=e.target.closest('[data-tab]'); if(tab){if(state.tab==='screen'&&tab.dataset.tab!=='screen')stopLive();state.tab=tab.dataset.tab;renderTabs();renderContent();return;}
    const pc=e.target.closest('[data-player]'); if(pc){state.selected=Number(pc.dataset.player);const p=selected();if(p&&!state.selectedSave[p.id])state.selectedSave[p.id]=p.defaultSaveId||p.characters?.[0]?.id||(p.activeSave?'__active':'');state.garage=null;renderPlayers();renderTarget();renderContent();return;}
    const ctab=e.target.closest('[data-catalog-class]'); if(ctab){state.catalogClass=ctab.dataset.catalogClass;renderGarageFiltersOnly();renderCatalog();return;}
    const dtab=e.target.closest('[data-catalog-dealer]'); if(dtab){state.catalogDealer=dtab.dataset.catalogDealer;renderGarageFiltersOnly();renderCatalog();return;}
    const a=e.target.closest('[data-action]'); if(a){if(a.dataset.action==='capture.open'){state.tab='screen';renderTabs();renderContent();return;}return doAction({action:a.dataset.action},false);}
    const ia=e.target.closest('[data-input-action]'); if(ia){const el=$('#'+ia.dataset.input);return doAction({action:ia.dataset.inputAction,amount:el.value});}
    const gt=e.target.closest('[data-garage-set]'); if(gt)return doAction({action:'garage.setactive',vehicleId:gt.dataset.garageSet});
    const gd=e.target.closest('[data-garage-delete]'); if(gd&&confirm('¿Borrar vehículo?'))return doAction({action:'garage.delete',vehicleId:gd.dataset.garageDelete});
    const add=e.target.closest('[data-add-model]'); if(add){const v=(state.catalog||[]).find(x=>x.model===add.dataset.addModel);return doAction({action:'garage.add',vehicle:v});}
    const wt=e.target.closest('[data-world-time]'); if(wt)return doAction({action:'world.time',hour:wt.dataset.worldTime});
    const ww=e.target.closest('[data-world-weather]'); if(ww)return doAction({action:'world.weather',weather:ww.dataset.worldWeather});
    if(e.target.closest('[data-custom-time]'))return doAction({action:'world.time',hour:$('#customHour').value});
    if(e.target.closest('[data-live-start]'))return startLive();
    if(e.target.closest('[data-live-stop]'))return stopLive(true);
    if(e.target.closest('[data-siren-test]'))return playSiren();
    if(e.target.closest('[data-siren-stop]'))return stopSiren();
    if(e.target.closest('[data-send-message]'))return doAction({action:'phone.message',sender:$('#msgSender').value,body:$('#msgBody').value},false);
    if(e.target.closest('[data-broadcast]'))return doAction({action:'phone.broadcast',sender:'Admin',body:$('#broadcastBody').value},false);
  });
  function renderGarageFiltersOnly(){ $$('#classFilters .seg-btn').forEach(b=>b.classList.toggle('active',b.dataset.catalogClass===state.catalogClass)); }
  document.addEventListener('change',e=>{if(e.target?.id==='saveSelect'){const p=selected(); if(p){state.selectedSave[p.id]=e.target.value;state.garage=null;renderPlayers();renderTarget();renderContent();}}});
  document.addEventListener('input',e=>{if(e.target?.id==='playerSearch')renderPlayers(); if(e.target?.id==='catalogSearch')renderCatalog();});
  $('#refreshBtn')?.addEventListener('click',()=>{state.garage=null;load();});
  $('#closeBtn')?.addEventListener('click',()=>{if(typeof closeApp==='function')closeApp();});
  if(typeof onNuiEvent==='function'){
    onNuiEvent('route',route=>{state.lastRoute=route||{}; if(route?.tab)state.tab=route.tab; if(!state.booted)boot(true); else{renderTabs();renderContent();}});
    onNuiEvent('refresh',()=>load());
  }
  window.addEventListener('error',ev=>{try{toast('Error UI: '+(ev.message||'JS'),'error');}catch(e){}});
  setTimeout(()=>boot(false),500);
})();
