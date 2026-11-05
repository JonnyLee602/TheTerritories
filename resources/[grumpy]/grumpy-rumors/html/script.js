const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-rumors';
const $ = id => document.getElementById(id);
let L = {};
let deadline = 0, timer = null;

const post = (name, body = {}) => fetch(`https://${resource}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
});

function fmtTime(sec) {
  sec = Math.max(0, Math.floor(sec));
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
  return (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(s).padStart(2, '0');
}

function tick() {
  const left = (deadline - Date.now()) / 1000;
  $('timer').textContent = fmtTime(left);
  $('meta').classList.toggle('warn', left <= 600);
  if (left <= 0) post('close');
}

function open(d) {
  $('title').textContent = d.title || '';
  $('subtitle').textContent = L.ui_subtitle || '';
  $('text').textContent = d.text || '';
  $('good-for').textContent = L.ui_good_for || '';
  $('put-away').textContent = L.ui_put_away || '';
  $('act').textContent = L.ui_act || '';
  $('act').classList.toggle('hidden', !d.canAct);
  $('group').textContent = d.canAct ? (d.group || '') : (L.ui_flavour || '');
  deadline = Date.now() + (Number(d.remaining) || 0) * 1000;
  clearInterval(timer);
  timer = setInterval(tick, 1000);
  tick();
  $('app').classList.remove('hidden');
}

function close() {
  clearInterval(timer);
  $('app').classList.add('hidden');
}

window.addEventListener('message', ({ data }) => {
  if (data.locale) L = data.locale;
  if (data.action === 'open') open(data.data || {});
  if (data.action === 'close') close();
});

$('close').addEventListener('click', () => post('close'));
$('put-away').addEventListener('click', () => post('close'));
$('act').addEventListener('click', () => post('act'));
document.addEventListener('keydown', e => { if (e.key === 'Escape') post('close'); });
