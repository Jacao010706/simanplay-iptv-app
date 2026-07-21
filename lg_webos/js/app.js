// ============================================================
// SimanPlay IPTV - LG webOS App
// Baseado no mesmo app Tizen com adaptações para LG
// ============================================================

const API_BASE = 'https://simanplay-backend.up.railway.app';
const PRIMARY_COLOR = 'APP_THEME_PLACEHOLDER';
const APP_NAME = 'APP_NAME_PLACEHOLDER';

let session = null;
let currentSection = 'login';
let currentMenu = 'live';
let channels = [];
let categories = [];
let focusedElement = null;

window.onload = function() {
    document.getElementById('appTitle').textContent = APP_NAME;
    document.querySelector('.app-title').textContent = APP_NAME;
    document.documentElement.style.setProperty('--primary', '#' + PRIMARY_COLOR);

    document.addEventListener('keydown', handleKeyDown);

    const saved = localStorage.getItem('simanplay_session');
    if (saved) {
        try { session = JSON.parse(saved); showHome(); loadCategories(); }
        catch(e) { showLogin(); }
    } else { showLogin(); }

    setTimeout(() => focusEl('userInput'), 300);
};

function handleKeyDown(e) {
    const key = e.keyCode;
    switch(key) {
        case 38:   navigate('up'); break;
        case 40:   navigate('down'); break;
        case 37:   navigate('left'); break;
        case 39:   navigate('right'); break;
        case 13:   selectCurrent(); break;
        case 461:  goBack(); break;  // LG Back button
        case 10009:goBack(); break;  // Alternativo
        case 27:   goBack(); break;
    }
    e.preventDefault();
}

function focusEl(id) {
    const el = document.getElementById(id);
    if (el) { el.focus(); focusedElement = el; }
}

function navigate(dir) {
    if (!focusedElement) return;
    const focusable = Array.from(document.querySelectorAll('[data-focus]'))
        .filter(el => el.offsetParent !== null);
    const idx = focusable.indexOf(focusedElement);
    let next = -1;
    if (dir === 'down' && idx < focusable.length - 1) next = idx + 1;
    if (dir === 'up'   && idx > 0) next = idx - 1;
    if (next >= 0) { focusable[next].focus(); focusedElement = focusable[next]; }
}

function selectCurrent() { if (focusedElement) focusedElement.click(); }
function goBack() {
    if (currentSection === 'player') { stopPlayer(); return; }
    if (currentSection === 'home')   { showLogin(); return; }
}

function showLogin() {
    currentSection = 'login';
    document.getElementById('loginScreen').style.display = 'flex';
    document.getElementById('homeScreen').style.display  = 'none';
    document.getElementById('playerScreen').style.display = 'none';
    setTimeout(() => focusEl('userInput'), 100);
}

async function login() {
    const username = document.getElementById('userInput').value.trim();
    const password = document.getElementById('passInput').value.trim();
    const status   = document.getElementById('loginStatus');
    if (!username || !password) { status.textContent = 'Preencha usuário e senha'; return; }
    status.textContent = 'Autenticando...'; status.style.color = '#ffaa00';
    try {
        const res  = await fetch(`${API_BASE}/api/auth/login`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({username, password})});
        const data = await res.json();
        if (data.status === 'ativo') {
            session = {type:'simanplay', username, password, m3uUrl:data.primaryUrl, xtreamHost:data.xtreamHost, xtreamUsername:data.xtreamUsername, xtreamPassword:data.xtreamPassword};
            localStorage.setItem('simanplay_session', JSON.stringify(session));
            showHome(); loadCategories();
        } else { status.textContent = 'Usuário ou senha inválidos'; status.style.color = '#ff4444'; }
    } catch(e) { status.textContent = 'Erro de conexão'; status.style.color = '#ff4444'; }
}

function loginXtream() {
    const host = document.getElementById('xHost').value.trim();
    const user = document.getElementById('xUser').value.trim();
    const pass = document.getElementById('xPass').value.trim();
    if (!host||!user||!pass) { document.getElementById('loginStatus').textContent='Preencha todos os campos'; return; }
    session = {type:'xtream', host, username:user, password:pass};
    localStorage.setItem('simanplay_session', JSON.stringify(session));
    showHome(); loadCategories();
}

function showHome() {
    currentSection = 'home';
    document.getElementById('loginScreen').style.display  = 'none';
    document.getElementById('homeScreen').style.display   = 'flex';
    document.getElementById('playerScreen').style.display = 'none';
    document.getElementById('sidebarTitle').textContent   = APP_NAME;
    setTimeout(() => focusEl('menuLive'), 100);
}

function selectMenu(menu) {
    currentMenu = menu;
    document.querySelectorAll('.menu-item').forEach(el => el.classList.remove('active'));
    document.getElementById('menu'+capitalize(menu)).classList.add('active');
    loadCategories();
}

async function loadCategories() {
    document.getElementById('categoryList').innerHTML = '<div class="loading">Carregando...</div>';
    document.getElementById('contentGrid').innerHTML = '';
    const {host, user, pass} = getXtreamCreds();
    const action = {live:'get_live_categories', movies:'get_vod_categories', series:'get_series_categories'}[currentMenu];
    try {
        const res = await fetch(`${host}/player_api.php?username=${user}&password=${pass}&action=${action}`);
        categories = await res.json(); renderCategories();
    } catch(e) { document.getElementById('categoryList').innerHTML='<div class="error">Erro ao carregar</div>'; }
}

function renderCategories() {
    const list = document.getElementById('categoryList');
    list.innerHTML = '';
    categories.forEach((cat, i) => {
        const el = document.createElement('div');
        el.className = 'category-item'; el.setAttribute('data-focus',''); el.textContent = cat.category_name; el.tabIndex = 0;
        el.onclick = () => loadChannels(cat.category_id, cat.category_name, el);
        if (i === 0) { el.classList.add('active'); loadChannels(cat.category_id, cat.category_name, el); }
        list.appendChild(el);
    });
}

async function loadChannels(categoryId, name, elCat) {
    document.querySelectorAll('.category-item').forEach(e=>e.classList.remove('active'));
    if (elCat) elCat.classList.add('active');
    document.getElementById('contentGrid').innerHTML = '<div class="loading">Carregando...</div>';
    const {host, user, pass} = getXtreamCreds();
    const action = {live:'get_live_streams', movies:'get_vod_streams', series:'get_series'}[currentMenu];
    try {
        const res = await fetch(`${host}/player_api.php?username=${user}&password=${pass}&action=${action}&category_id=${categoryId}`);
        channels = await res.json(); renderChannels();
    } catch(e) { document.getElementById('contentGrid').innerHTML='<div class="error">Erro</div>'; }
}

function renderChannels() {
    const grid = document.getElementById('contentGrid'); grid.innerHTML = '';
    channels.forEach(ch => {
        const name = ch.name||ch.title||''; const icon = ch.stream_icon||ch.cover||'';
        const el = document.createElement('div');
        el.className='content-card'; el.setAttribute('data-focus',''); el.tabIndex=0;
        el.innerHTML=`<div class="card-img" style="${icon?`background-image:url('${icon}')`:''}">${!icon?`<span class="card-initial">${name.charAt(0)}</span>`:''}</div><div class="card-name">${name}</div>`;
        el.onclick = () => playChannel(ch); grid.appendChild(el);
    });
}

function playChannel(ch) {
    const {host, user, pass} = getXtreamCreds();
    let url = '';
    if (currentMenu==='live')   url=`${host}/live/${user}/${pass}/${ch.stream_id}.m3u8`;
    if (currentMenu==='movies') url=`${host}/movie/${user}/${pass}/${ch.stream_id}.${ch.container_extension||'mp4'}`;
    if (!url) return;
    currentSection='player';
    document.getElementById('homeScreen').style.display='none';
    document.getElementById('playerScreen').style.display='flex';
    document.getElementById('nowPlaying').textContent=ch.name||ch.title||'';
    const v=document.getElementById('videoPlayer'); v.src=url; v.play().catch(()=>{});
}

function stopPlayer() {
    const v=document.getElementById('videoPlayer'); v.pause(); v.src='';
    currentSection='home';
    document.getElementById('playerScreen').style.display='none';
    document.getElementById('homeScreen').style.display='flex';
}

function getXtreamCreds() {
    if (!session) return {host:'',user:'',pass:''};
    if (session.type==='xtream') return {host:session.host, user:session.username, pass:session.password};
    return {host:session.xtreamHost||'', user:session.xtreamUsername||'', pass:session.xtreamPassword||''};
}

function capitalize(s) { return s.charAt(0).toUpperCase()+s.slice(1); }
function logout() { localStorage.removeItem('simanplay_session'); session=null; showLogin(); }
function switchTab(tab) {
    document.querySelectorAll('.tab-btn').forEach(b=>b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c=>c.style.display='none');
    document.getElementById('tab'+capitalize(tab)).classList.add('active');
    document.getElementById(tab+'Fields').style.display='flex';
}
