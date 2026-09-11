let state = {
    unit:'kmh', x:50, bottom:9, scale:.82, maxRPM:10, redlineRPM:8,
    editing:false, hudEnabled:true, limiterEnabled:false, limiterSpeed:130,
    limiterMin:20, limiterMax:350, limiterStep:5, limiterOpen:false
};

const $ = id => document.getElementById(id);
const clamp = (v,min,max) => Math.max(min,Math.min(max,v));
const resourceName = GetParentResourceName();

// Apply HUD layout / Aplikon pozicionin e HUD-it
function applyLayout(){
    $('anchor').style.left=`${state.x}%`;
    $('anchor').style.bottom=`${state.bottom}vh`;
    $('scale').style.transform=`translateX(-50%) scale(${state.scale})`;
}

// Update HUD enabled state / Përditëson gjendjen e HUD-it
function applyEnabled(){
    $('hud').classList.toggle('user-hidden',!state.hudEnabled);
    $('visibilityIcon').textContent=state.hudEnabled?'◉':'○';
}

// Update limiter controls / Përditëson kontrollet e limituesit
function applyLimiter(){
    $('limiterHandle').classList.toggle('active',state.limiterEnabled);
    $('limiterToggle').classList.toggle('active',state.limiterEnabled);
    $('limiterToggleText').textContent=state.limiterEnabled?'ON':'OFF';
    $('limiterValue').textContent=Math.round(state.limiterSpeed);
    $('limiterUnit').textContent=state.unit==='mph'?'MPH':'KM/H';
    $('limiterPanel').classList.toggle('open',state.editing&&state.limiterOpen);
}

// Initialize HUD data / Inicializon të dhënat e HUD-it
function init(data){
    state={...state,...data};
    $('unit').textContent=state.unit==='mph'?'MPH':'KM/H';
    applyLayout();
    applyEnabled();
    applyLimiter();
}

function level(el,warn,critical){
    el.classList.toggle('warn',warn&&!critical);
    el.classList.toggle('crit',critical);
}

// Save layout in KVP through Lua / Ruan pozicionin në KVP përmes Lua
function saveLayout(){
    fetch(`https://${resourceName}/saveLayout`,{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({x:state.x,bottom:state.bottom,scale:state.scale})
    }).catch(()=>{});
}

// Apply limiter settings for this session / Aplikon limituesin vetëm për këtë sesion
function saveLimiter(){
    fetch(`https://${resourceName}/setLimiter`,{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({enabled:state.limiterEnabled,speed:state.limiterSpeed})
    }).catch(()=>{});
}

function setEditMode(enabled){
    state.editing=!!enabled;
    if(!state.editing) state.limiterOpen=false;
    $('hud').classList.toggle('editing',state.editing);
    applyLimiter();
}

let vehicleAnimationTimer=null;

// Slide the HUD in from the right when entering / Rrëshqet HUD-in nga e djathta kur hyn në veturë
function playVehicleEnter(){
    clearTimeout(vehicleAnimationTimer);
    const hud=$('hud');
    hud.classList.remove('hidden','vehicle-exit','vehicle-enter');
    void hud.offsetWidth;
    hud.classList.add('vehicle-enter');
    vehicleAnimationTimer=setTimeout(()=>hud.classList.remove('vehicle-enter'),440);
}

// Slide the HUD back to the right before hiding / Rrëshqet HUD-in prapa në të djathtë para fshehjes
function playVehicleExit(){
    clearTimeout(vehicleAnimationTimer);
    const hud=$('hud');
    hud.classList.remove('vehicle-enter','vehicle-exit');
    void hud.offsetWidth;
    hud.classList.add('vehicle-exit');
    vehicleAnimationTimer=setTimeout(()=>{
        hud.classList.remove('vehicle-exit');
        hud.classList.add('hidden');
    },320);
}

window.addEventListener('message',e=>{
    const data=e.data||{};

    if(data.action==='init') init(data);
    if(data.action==='vehicleTransition'){
        if(data.entering) playVehicleEnter(); else playVehicleExit();
    }
    if(data.action==='visibility'){
        if(data.visible){
            if(!$('hud').classList.contains('vehicle-exit')) $('hud').classList.remove('hidden');
        }else if(!$('hud').classList.contains('vehicle-exit')){
            $('hud').classList.add('hidden');
        }
    }
    if(data.action==='editMode') setEditMode(data.enabled);
    if(data.action==='hudEnabled'){
        state.hudEnabled=!!data.enabled;
        applyEnabled();
    }
    if(data.action==='limiter'){
        state.limiterEnabled=!!data.enabled;
        state.limiterSpeed=Number(data.speed)||state.limiterSpeed;
        applyLimiter();
    }
    if(data.action==='update'){
        $('speed').textContent=Math.max(0,Math.round(data.speed||0));
        $('gear').textContent=(data.gear||0)===0?'N':String(data.gear);

        const rpm=Number(data.rpm)||0;
        $('rpmfill').style.width=`${clamp(rpm/Math.max(1,state.maxRPM)*100,0,100)}%`;
        $('rpmfill').classList.toggle('red',rpm>=state.redlineRPM);

        const fuel=clamp(Number(data.fuel)||0,0,100);
        $('fuelIcon').textContent=data.electric?'🔋':'⛽';
        $('fuel').textContent=`${Math.round(fuel)}%`;
        level($('fuelItem'),fuel<=20,fuel<=8);

        const temp=Number(data.temp)||0;
        $('temp').textContent=`${Math.round(temp)}°C`;
        level($('tempItem'),temp>=105,temp>=115);

        if(typeof data.limiterEnabled!=='undefined') state.limiterEnabled=!!data.limiterEnabled;
        if(typeof data.limiterSpeed!=='undefined') state.limiterSpeed=Number(data.limiterSpeed)||state.limiterSpeed;
        applyLimiter();
    }
});

// Move HUD with mouse / Lëviz HUD-in me maus
$('moveHandle').addEventListener('pointerdown',event=>{
    if(!state.editing)return;
    event.preventDefault();
    $('moveHandle').setPointerCapture(event.pointerId);

    const sx=event.clientX,sy=event.clientY,sl=state.x,sb=state.bottom;
    const move=e=>{
        state.x=clamp(sl+((e.clientX-sx)/innerWidth)*100,4,96);
        state.bottom=clamp(sb-((e.clientY-sy)/innerHeight)*100,1,92);
        applyLayout();
    };
    const up=()=>{
        $('moveHandle').removeEventListener('pointermove',move);
        $('moveHandle').removeEventListener('pointerup',up);
        $('moveHandle').removeEventListener('pointercancel',up);
        saveLayout();
    };

    $('moveHandle').addEventListener('pointermove',move);
    $('moveHandle').addEventListener('pointerup',up);
    $('moveHandle').addEventListener('pointercancel',up);
});

// Resize HUD with mouse / Ndryshon madhësinë e HUD-it me maus
$('resizeHandle').addEventListener('pointerdown',event=>{
    if(!state.editing)return;
    event.preventDefault();
    $('resizeHandle').setPointerCapture(event.pointerId);

    const sx=event.clientX,sy=event.clientY,ss=state.scale;
    const move=e=>{
        state.scale=clamp(ss+((e.clientX-sx)+(e.clientY-sy))/280,.45,1.8);
        applyLayout();
    };
    const up=()=>{
        $('resizeHandle').removeEventListener('pointermove',move);
        $('resizeHandle').removeEventListener('pointerup',up);
        $('resizeHandle').removeEventListener('pointercancel',up);
        saveLayout();
    };

    $('resizeHandle').addEventListener('pointermove',move);
    $('resizeHandle').addEventListener('pointerup',up);
    $('resizeHandle').addEventListener('pointercancel',up);
});

// Reset HUD from icon / Rivendos HUD-in nga ikona
$('resetHandle').addEventListener('click',()=>fetch(`https://${resourceName}/resetLayout`,{
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:'{}'
}).catch(()=>{}));

// Show or hide HUD from icon / Shfaq ose fsheh HUD-in nga ikona
$('visibilityHandle').addEventListener('click',()=>{
    state.hudEnabled=!state.hudEnabled;
    applyEnabled();
    fetch(`https://${resourceName}/setHudEnabled`,{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({enabled:state.hudEnabled})
    }).catch(()=>{});
});

// Open speed limiter controls / Hap kontrollet e limituesit të shpejtësisë
$('limiterHandle').addEventListener('click',()=>{
    if(!state.editing)return;
    state.limiterOpen=!state.limiterOpen;
    applyLimiter();
});

// Enable or disable speed limiter with ON/OFF switch / Aktivizon ose çaktivizon limituesin me ON/OFF
$('limiterToggle').addEventListener('click',()=>{
    state.limiterEnabled=!state.limiterEnabled;
    applyLimiter();
    saveLimiter();
});

// Decrease speed limiter / Ul limituesin e shpejtësisë
$('limiterMinus').addEventListener('click',()=>{
    state.limiterSpeed=clamp(state.limiterSpeed-state.limiterStep,state.limiterMin,state.limiterMax);
    applyLimiter();
    saveLimiter();
});

// Increase speed limiter / Rrit limituesin e shpejtësisë
$('limiterPlus').addEventListener('click',()=>{
    state.limiterSpeed=clamp(state.limiterSpeed+state.limiterStep,state.limiterMin,state.limiterMax);
    applyLimiter();
    saveLimiter();
});

// INSERT or ESC closes editor / INSERT ose ESC mbyll editorin
window.addEventListener('keydown',event=>{
    if(state.editing&&(event.key==='Escape'||event.key==='Insert')){
        fetch(`https://${resourceName}/closeEdit`,{
            method:'POST',
            headers:{'Content-Type':'application/json'},
            body:'{}'
        }).catch(()=>{});
    }
});

fetch(`https://${resourceName}/ready`,{
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:'{}'
}).catch(()=>{});
