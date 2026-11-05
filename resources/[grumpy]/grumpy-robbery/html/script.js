const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-robbery';
const $ = id => document.getElementById(id);
let L = {}, data = { stores: [], maxShelves: 4 }, selected = null, search = '';

const post = (name, body = {}) => fetch(`https://${resource}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
});

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}
function button(label, onClick, cls = '') {
  const b = el('button', 'wood-btn ' + cls, label);
  b.addEventListener('click', e => { e.stopPropagation(); onClick(); });
  return b;
}
const fmt = n => Number(n).toFixed(1);

function header(title, subtitle, canBack) {
  $('title').textContent = title;
  $('subtitle').textContent = subtitle || '';
  $('back').style.visibility = canBack ? 'visible' : 'hidden';
}

/* ---------------- store list ---------------- */
function renderList() {
  header(L.ui_title, L.ui_subtitle, false);
  const view = $('view');
  view.innerHTML = '';
  const bar = el('div', 'toolbar');
  const input = el('input');
  input.placeholder = L.ui_search;
  input.value = search;
  input.addEventListener('input', () => { search = input.value; renderRows(list); });
  bar.appendChild(input);
  bar.appendChild(button(L.ui_reload, () => post('reload')));
  view.appendChild(bar);
  const list = el('div', 'list');
  view.appendChild(list);
  renderRows(list);
  setTimeout(() => input.focus(), 0);
}

function renderRows(list) {
  list.innerHTML = '';
  const q = search.trim().toLowerCase();
  data.stores.filter(s => !q || s.label.toLowerCase().includes(q) || String(s.id) === q).forEach(s => {
    const row = el('div', 'row');
    row.appendChild(el('span', 'badge-icon', '✦'));
    const text = el('div', 'row-text');
    text.appendChild(el('div', 'row-title', `${s.label} (#${s.id})`));
    text.appendChild(el('div', 'row-desc', `${s.distance ?? '?'} m`));
    row.appendChild(text);
    const pills = el('div', 'pills');
    pills.appendChild(el('span', 'pill ' + (s.enabled ? 'on' : 'off'), s.enabled ? L.ui_on : L.ui_off));
    pills.appendChild(el('span', 'pill', `${(s.shelves || []).length}/${data.maxShelves}`));
    if (s.safe) pills.appendChild(el('span', 'pill', L.ui_safe));
    row.appendChild(pills);
    row.addEventListener('click', () => { selected = s.id; renderStore(); });
    list.appendChild(row);
  });
  if (!list.children.length) list.appendChild(el('div', 'empty', L.ui_no_stores));
}

/* ---------------- one store ---------------- */
function renderStore() {
  const s = data.stores.find(x => x.id === selected);
  if (!s) { selected = null; return renderList(); }
  header(s.label, `#${s.id} · ${s.distance ?? '?'} m`, true);
  const view = $('view');
  view.innerHTML = '';

  // robbable toggle
  const toggle = el('div', 'row');
  toggle.appendChild(el('span', 'badge-icon', '$'));
  const t = el('div', 'row-text');
  t.appendChild(el('div', 'row-title', L.ui_robbable));
  toggle.appendChild(t);
  toggle.appendChild(el('span', 'pill ' + (s.enabled ? 'on' : 'off'), s.enabled ? L.ui_on : L.ui_off));
  toggle.addEventListener('click', () => post('toggle', { id: s.id, enabled: !s.enabled }));
  view.appendChild(toggle);

  // shelves
  view.appendChild(el('div', 'section', `${L.ui_shelves} (${(s.shelves || []).length}/${data.maxShelves})`));
  const list = el('div', 'list');
  (s.shelves || []).forEach((p, i) => {
    const row = el('div', 'row static');
    row.appendChild(el('span', 'badge-icon', String(i + 1)));
    const text = el('div', 'row-text');
    text.appendChild(el('div', 'row-title', `${L.ui_shelf} ${i + 1}`));
    text.appendChild(el('div', 'row-desc', `${fmt(p.x)}, ${fmt(p.y)}, ${fmt(p.z)}`));
    row.appendChild(text);
    const btns = el('div', 'mini-btns');
    btns.appendChild(button(L.ui_teleport, () => post('teleport', p)));
    btns.appendChild(button(L.ui_remove, () => post('removeShelf', { id: s.id, index: i + 1 }), 'danger'));
    row.appendChild(btns);
    list.appendChild(row);
  });
  if (!list.children.length) list.appendChild(el('div', 'empty', L.ui_none));
  view.appendChild(list);
  const addRow = el('div', 'actions');
  const add = button(L.ui_add_shelf, () => post('addShelf', { id: s.id }));
  add.disabled = (s.shelves || []).length >= data.maxShelves;
  addRow.appendChild(add);
  view.appendChild(addRow);

  // safe
  view.appendChild(el('div', 'section', L.ui_safe));
  if (s.safe) {
    const row = el('div', 'row static');
    row.appendChild(el('span', 'badge-icon', '▣'));
    const text = el('div', 'row-text');
    text.appendChild(el('div', 'row-title', s.safe.prop ? L.ui_safe_prop : L.ui_safe_marker));
    text.appendChild(el('div', 'row-desc', `${fmt(s.safe.x)}, ${fmt(s.safe.y)}, ${fmt(s.safe.z)}`));
    row.appendChild(text);
    const btns = el('div', 'mini-btns');
    btns.appendChild(button(L.ui_teleport, () => post('teleport', s.safe)));
    btns.appendChild(button(L.ui_remove, () => post('removeSafe', { id: s.id }), 'danger'));
    row.appendChild(btns);
    view.appendChild(row);
  } else {
    view.appendChild(el('div', 'empty', L.ui_none));
  }
  const safeRow = el('div', 'actions');
  safeRow.appendChild(button(L.ui_set_safe_here, () => post('safeHere', { id: s.id })));
  safeRow.appendChild(button(L.ui_place_safe_prop, () => post('safeProp', { id: s.id })));
  view.appendChild(safeRow);

  const tp = el('div', 'actions');
  tp.appendChild(button(L.ui_teleport, () => post('teleport', { x: s.x, y: s.y, z: s.z }), 'muted'));
  view.appendChild(tp);
}

function render() { selected ? renderStore() : renderList(); }

window.addEventListener('message', ({ data: msg }) => {
  if (msg.locale) L = msg.locale;
  if (msg.action === 'open') { data = msg.data; selected = null; render(); $('app').classList.remove('hidden'); }
  if (msg.action === 'update') { data = msg.data; render(); }
  if (msg.action === 'close' || msg.action === 'hide') $('app').classList.add('hidden');
  if (msg.action === 'show') $('app').classList.remove('hidden');
});

$('close').addEventListener('click', () => post('close'));
$('back').addEventListener('click', () => { selected = null; renderList(); });
document.addEventListener('keydown', e => {
  if (e.key !== 'Escape') return;
  if (selected) { selected = null; renderList(); } else post('close');
});
