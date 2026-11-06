// grumpy-loading: The Territories Gazette
const CFG = window.GAZETTE_CONFIG || {};
const $ = (id) => document.getElementById(id);
const timers = [];
const every = (fn, ms) => { const id = setInterval(fn, ms); timers.push(id); return id; };
const fmt = (str, ...args) => { let n = 0; return String(str || '').replace(/%s/g, () => args[n++] ?? ''); };
const num = (v, def) => (typeof v === 'number' && isFinite(v) ? v : def);

let L = {};
let finished = false;

/* ---------- Scale the 1600x900 canvas to the screen ---------- */
function fit() {
  const s = Math.min(window.innerWidth / 1600, window.innerHeight / 900);
  document.documentElement.style.setProperty('--scale', s);
}
window.addEventListener('resize', fit);
fit();

/* ---------- Locale ---------- */
const getJSON = (url) => fetch(url).then((r) => r.json()).catch(() => ({}));
function loadLocale(lang) {
  const code = String(lang || 'en').toLowerCase();
  const reqs = [getJSON('../locales/en.json')];
  if (code !== 'en') reqs.push(getJSON('../locales/' + code + '.json'));
  return Promise.all(reqs).then(([en, sel]) => Object.assign({}, en, sel || {}));
}
// prefix_1_field, prefix_2_field ... until the first gap
function numbered(prefix, field) {
  const out = [];
  for (let n = 1; L[prefix + n + (field ? '_' + field : '')] !== undefined; n++) out.push(n);
  return out;
}
const t = (key) => L[key] || '';

/* ---------- Masthead ---------- */
function dateline() {
  const now = new Date();
  const d = new Date(num(CFG.year, 1899), now.getMonth(), now.getDate());
  return d.toLocaleDateString(document.documentElement.lang || 'en', {
    weekday: 'long', month: 'long', day: 'numeric', year: 'numeric',
  });
}
function issueNumber() {
  const first = new Date(String(CFG.firstIssue || '') + 'T00:00:00');
  if (isNaN(first)) return 1;
  const days = Math.floor((Date.now() - first.getTime()) / 86400000);
  return Math.max(1, days + 1);
}
function masthead() {
  document.title = t('page_title');
  $('title').textContent = t('masthead_title');
  $('earLeft').textContent = t('ear_left');
  $('earRight').textContent = t('ear_right');
  $('issue').textContent = fmt(t('issue'), issueNumber());
  $('dateline').textContent = dateline();
  $('price').textContent = t('price');
  $('motto').textContent = t('motto');
  $('wireLabel').textContent = t('wire_label');

  const info = (window.nuiHandoverData || {}).grumpyLoading;
  $('population').textContent = info
    ? fmt(t('population'), info.players, info.maxPlayers)
    : t('population_unknown');
}

/* ---------- Front page story rotation ---------- */
function stories() {
  const list = numbered('story_', 'headline');
  if (!list.length) return;
  let i = 0;
  const show = (n) => {
    $('leadKicker').textContent = t('story_' + n + '_kicker');
    $('leadHeadline').textContent = t('story_' + n + '_headline');
    $('leadDeck').textContent = t('story_' + n + '_deck');
    $('leadBody').textContent = t('story_' + n + '_body');
  };
  show(list[0]);
  if (list.length < 2) return;
  const lead = $('lead');
  every(() => {
    lead.classList.add('fading');
    setTimeout(() => { i = (i + 1) % list.length; show(list[i]); lead.classList.remove('fading'); }, 600);
  }, num(CFG.storySeconds, 14) * 1000);
}

/* ---------- Paths, wanted poster, notices ---------- */
function columns() {
  $('pathsTitle').textContent = t('paths_title');
  const box = $('pathsList');
  numbered('path_', 'name').forEach((n) => {
    const el = document.createElement('div');
    el.className = 'path';
    [['path-name', 'name'], ['path-motto', 'motto'], ['path-text', 'text']].forEach(([cls, f]) => {
      const p = document.createElement('div');
      p.className = cls;
      p.textContent = t('path_' + n + '_' + f);
      el.appendChild(p);
    });
    box.appendChild(el);
  });

  $('wantedTitle').textContent = t('wanted_title');
  $('wantedSubject').textContent = t('wanted_subject');
  $('wantedText').textContent = t('wanted_text');
  $('wantedReward').textContent = t('wanted_reward');
  if (CFG.discord) {
    $('wantedDiscord').textContent = fmt(t('wanted_discord'), CFG.discord);
    $('wantedDiscord').classList.remove('hidden');
  }

  $('noticesTitle').textContent = t('notices_title');
  const notices = numbered('notice_').map((n) => t('notice_' + n));
  if (!notices.length) return;
  const el = $('notice');
  let i = 0;
  el.textContent = notices[0];
  if (notices.length < 2) return;
  every(() => {
    el.classList.add('fading');
    setTimeout(() => { i = (i + 1) % notices.length; el.textContent = notices[i]; el.classList.remove('fading'); }, 500);
  }, num(CFG.noticeSeconds, 8) * 1000);
}

/* ---------- Backgrounds (optional slideshow behind the paper) ---------- */
function backgrounds() {
  const list = (Array.isArray(CFG.backgrounds) ? CFG.backgrounds : [CFG.backgrounds])
    .filter((v) => typeof v === 'string' && v);
  if (!list.length) return;
  const layers = [$('bgA'), $('bgB')];
  layers.forEach((l) => l.style.setProperty('--bg-dim', Math.max(0, Math.min(1, num(CFG.backgroundDim, 0.55)))));
  let idx = 0, front = 0;
  const show = (src) => {
    const img = new Image();
    img.onload = () => {
      const next = layers[1 - front];
      next.style.backgroundImage = `url("${src}")`;
      next.classList.add('show');
      layers[front].classList.remove('show');
      front = 1 - front;
    };
    img.src = src;
  };
  show(list[0]);
  if (list.length > 1) every(() => { idx = (idx + 1) % list.length; show(list[idx]); }, num(CFG.backgroundSeconds, 15) * 1000);
}

/* ---------- Music ---------- */
function music() {
  const audio = $('music');
  if (!CFG.music) return;
  audio.src = CFG.music;
  audio.volume = Math.max(0, Math.min(1, num(CFG.musicVolume, 0.3)));
  audio.play().catch(() => {});
  $('musicHint').textContent = t('music_hint');
  $('musicHint').classList.remove('hidden');
  window.addEventListener('keydown', (e) => {
    if (e.code !== 'Space' || finished) return;
    if (audio.paused) audio.play().catch(() => {}); else audio.pause();
  });
}
function fadeMusic(seconds) {
  const audio = $('music');
  if (!audio || audio.paused) return;
  const steps = 20, start = audio.volume;
  let n = 0;
  const id = setInterval(() => {
    n++;
    audio.volume = Math.max(0, start * (1 - n / steps));
    if (n >= steps) { audio.pause(); clearInterval(id); }
  }, (seconds * 1000) / steps);
}

/* ---------- Telegraph progress ---------- */
function buildPoles() {
  const poles = $('wirePoles');
  for (let n = 0; n <= 12; n++) {
    const p = document.createElement('div');
    p.className = 'wire-pole';
    p.style.left = (n / 12) * 100 + '%';
    poles.appendChild(p);
  }
}
let shown = 0;
function setProgress(pct) {
  pct = Math.max(shown, Math.min(100, pct)); // the wire never runs backwards
  shown = pct;
  $('wireFill').style.width = pct + '%';
  $('wireSpark').style.left = pct + '%';
  $('wirePct').textContent = Math.floor(pct) + '%';
  if (finished) return;
  const stages = numbered('wire_stage_');
  if (stages.length) {
    const s = stages[Math.min(stages.length - 1, Math.floor((pct / 100) * stages.length))];
    $('wireStatus').textContent = t('wire_stage_' + s);
  }
}

// Fallback: drift forward on its own until the game sends real progress
// (also makes the page work when previewed in a normal browser).
let realProgress = false;
let sim = 0;
const simId = every(() => {
  if (realProgress || finished) return clearInterval(simId);
  sim = Math.min(sim + Math.random() * 2.5, 95);
  setProgress(sim);
}, 300);

window.addEventListener('message', (e) => {
  const data = e.data || {};
  if (typeof data.loadFraction === 'number' && !finished) {   // RedM/FiveM loadProgress
    realProgress = true;
    setProgress(data.loadFraction * 100);
  }
  if (data.type === 'grumpy-loading:finish') finish();         // sent by client/main.lua
});

function finish() {
  if (finished) return;
  setProgress(100);
  finished = true;
  timers.forEach(clearInterval);
  $('wireStatus').textContent = t('wire_ready');
  $('musicHint').classList.add('hidden');
  fadeMusic(num(CFG.musicFadeSeconds, 1));
}

/* ---------- Boot ---------- */
buildPoles();
setProgress(0);
loadLocale(CFG.locale).then((data) => {
  L = data;
  document.documentElement.lang = String(CFG.locale || 'en');
  masthead();
  stories();
  columns();
  setProgress(shown);
  music();
});
backgrounds();

const autoClose = num(CFG.autoCloseSeconds, 300);
if (autoClose > 0) {
  setTimeout(() => {
    finish();
    setTimeout(() => { if (window.invokeNative) window.invokeNative('shutdownLoadingScreenNui'); }, 1200);
  }, autoClose * 1000);
}
