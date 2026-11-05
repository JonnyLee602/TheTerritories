const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-reputation';
const $ = id => document.getElementById(id);
let L = {};

const post = (name, body = {}) => fetch(`https://${resource}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
});

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

const fmt = v => typeof v === 'number' ? Math.floor(v).toLocaleString('en-US') : String(v);

function render(d) {
  $('title').textContent = L.ui_title || '';
  $('subtitle').textContent = L.ui_subtitle || '';
  $('tier-name').textContent = d.tierLabel || '';
  $('tier-desc').textContent = d.tierDesc || '';
  $('lbl-outlaw').textContent = L.ui_outlaw || '';
  $('lbl-legit').textContent = L.ui_legit || '';
  const pos = Math.max(0, Math.min(1, Number(d.position) || 0.5));
  $('marker').style.left = (pos * 100) + '%';
  $('value').textContent = (typeof d.standing === 'number') ? `${L.ui_standing}: ${d.standing > 0 ? '+' : ''}${d.standing}` : '';

  $('skills-title').textContent = L.ui_skills || '';
  const list = $('list');
  list.innerHTML = '';
  (d.reps || []).forEach(r => {
    const row = el('div', 'row static');
    row.appendChild(el('span', 'badge-icon', '✦'));
    const text = el('div', 'row-text');
    text.appendChild(el('div', 'row-title', r.label));
    row.appendChild(text);
    row.appendChild(el('span', 'pill', fmt(r.value)));
    list.appendChild(row);
  });
  if (!list.children.length) list.appendChild(el('div', 'empty', L.ui_no_skills || ''));
}

window.addEventListener('message', ({ data }) => {
  if (data.locale) L = data.locale;
  if (data.action === 'open') { render(data.data || {}); $('app').classList.remove('hidden'); }
  if (data.action === 'update') render(data.data || {});
  if (data.action === 'close') $('app').classList.add('hidden');
});

$('close').addEventListener('click', () => post('close'));
document.addEventListener('keydown', e => { if (e.key === 'Escape') post('close'); });
