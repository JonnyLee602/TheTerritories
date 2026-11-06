// grumpy-gambling NUI: admin panel (/gambling) and the game + tier picker.
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-gambling';
const $ = (id) => document.getElementById(id);

let L = {};
let view = null;
let data = null;
let st = {};

function post(name, body = {}) {
  return fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body),
  }).catch(() => {});
}

function tr(key, ...args) {
  let s = L[key] || key;
  for (const a of args) s = s.replace('%s', a);
  return s;
}

const money = (n) => Number(n || 0).toFixed(2);

// Small DOM builder. Text always goes through textContent (labels come from admins and modules).
function el(tag, props = {}, children = []) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'class') e.className = v;
    else if (k === 'text') e.textContent = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else if (k === 'value') e.value = v;
    else e.setAttribute(k, v === true ? '' : v);
  }
  for (const c of [].concat(children)) if (c) e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
  return e;
}

function button(text, onclick, cls = '', disabled = false) {
  return el('button', { class: `wood-btn ${cls}`, text, onclick, disabled });
}

function select(options, value, onchange) {
  const s = el('select', { onchange: (e) => onchange(e.target.value) },
    options.map((o) => el('option', { value: o.value, text: o.label, disabled: o.disabled })));
  s.value = value;
  return s;
}

function field(label, input) {
  return el('div', { class: 'field' }, [el('label', { text: label }), input]);
}

function row({ icon, title, desc, pills = [], selected, onclick, disabled }) {
  return el('div', { class: `row${selected ? ' selected' : ''}${disabled ? ' disabled' : ''}`, onclick: disabled ? null : onclick }, [
    el('div', { class: 'badge-icon', text: icon }),
    el('div', { class: 'row-text' }, [el('div', { class: 'row-title', text: title }), desc ? el('div', { class: 'row-desc', text: desc }) : null]),
    pills.length ? el('div', { class: 'pills' }, pills.map((p) => el('span', { class: `pill ${p.cls || ''}`, text: p.text }))) : null,
  ]);
}

// ---------------------------------------------------------------- modal
function openModal(title, body, actions) {
  $('modal-title').textContent = title;
  const b = $('modal-body');
  b.replaceChildren(...[].concat(body));
  $('modal-actions').replaceChildren(...actions);
  $('modal-wrap').classList.remove('hidden');
}
function closeModal() { $('modal-wrap').classList.add('hidden'); }
const modalOpen = () => !$('modal-wrap').classList.contains('hidden');

function openSnippet(text) {
  const area = el('textarea', { class: 'snippet', readonly: true });
  area.value = text;
  const copyBtn = button(tr('ui_copy'), () => {
    area.select();
    document.execCommand('copy');
    copyBtn.textContent = tr('ui_copied');
  });
  openModal(tr('ui_snippet_title'), [el('div', { class: 'info', text: tr('ui_snippet_hint') }), area], [copyBtn, button(tr('ui_close'), closeModal, 'muted')]);
}

// ---------------------------------------------------------------- admin
const stateLabel = (s) => tr(`ui_state_${s}`);
const kindLabel = (k) => tr(`ui_kind_${k}`);

function tablePills(t) {
  const pills = [];
  if (!t.enabled) pills.push({ text: tr('ui_disabled'), cls: 'bad' });
  if (t.source === 'micro') pills.push({ text: tr('tier_micro'), cls: 'good' });
  if (t.currency === 'bloodmoney') pills.push({ text: tr('ui_bloodmoney'), cls: 'warn' });
  if (t.bound) pills.push({ text: tr('ui_bound') });
  return pills;
}

function renderAdminList() {
  if (!data.tables.length) return [el('div', { class: 'note', text: tr('ui_no_tables') })];
  return [el('div', { class: 'list' }, data.tables.map((t) => row({
    icon: t.kind === 'pvp' ? 'P' : 'D',
    title: `${t.label}  #${t.id}`,
    desc: `${kindLabel(t.kind)} · ${stateLabel(t.state)} · ${tr('ui_players', t.players, t.seats)}`,
    pills: tablePills(t),
    onclick: () => { st.detail = t.id; render(); },
  })))];
}

function renderAdminDetail(t) {
  const calText = t.calibrated ? tr('ui_cal_table') : t.modelCalibrated ? tr('ui_cal_model') : tr('ui_cal_seed');
  const info = el('div', { class: 'info' }, [
    el('div', {}, [el('b', { text: kindLabel(t.kind) }), ` · ${t.model}`]),
    el('div', { text: `${t.source === 'micro' ? tr('ui_source_micro') : tr('ui_source_public')} · ${tr(`ui_${t.currency}`)}${t.bound ? ' · ' + tr('ui_bound') : ''}` }),
    el('div', { text: `${stateLabel(t.state)} · ${tr('ui_players', t.players, t.seats)}${t.game ? ' · ' + t.game : ''}${t.tier ? ' · ' + tr('tier_' + t.tier) : ''}` }),
    el('div', { text: calText }),
  ]);
  const nameInput = el('input', { value: t.label, maxlength: 60 });
  const id = t.id;
  const busy = t.players > 0;
  return [
    info,
    el('div', { class: 'field-row' }, [
      field(tr('ui_label'), nameInput),
    ]),
    button(tr('ui_save'), () => post('adminRename', { id, label: nameInput.value })),
    el('div', { class: 'btn-grid' }, [
      button(tr('ui_teleport'), () => post('adminTeleport', { id })),
      button(tr('ui_move'), () => post('adminMove', { id }), '', t.bound || busy),
      button(tr('ui_calibrate_table'), () => post('adminCalibrate', { id, scope: 'table' }), '', busy),
      button(tr('ui_calibrate_model'), () => post('adminCalibrate', { id, scope: 'model' }), '', busy),
      button(tr('ui_reset_table'), () => post('adminResetCalibration', { id, scope: 'table' }), 'muted', busy || !t.calibrated),
      button(tr('ui_reset_model'), () => post('adminResetCalibration', { id, scope: 'model' }), 'muted', busy || !t.modelCalibrated),
      button(t.enabled ? tr('ui_disable') : tr('ui_enable'), () => post('adminToggle', { id })),
      button(tr('ui_delete'), () => openModal(tr('ui_delete'), el('div', { class: 'info', text: tr('ui_delete_confirm') }), [
        button(tr('ui_confirm'), () => { closeModal(); st.detail = null; post('adminDelete', { id }); }, 'danger'),
        button(tr('ui_cancel'), closeModal, 'muted'),
      ]), 'danger'),
    ]),
  ];
}

function renderAdminNew() {
  const f = st.form;
  const models = data.models[f.kind] || [];
  if (!models.find((m) => m.name === f.model)) f.model = models[0] ? models[0].name : '';
  const microFull = data.microCount >= data.microMax;
  if (f.source === 'micro') f.currency = 'cash';
  const labelInput = el('input', { value: f.label, maxlength: 60, oninput: (e) => { f.label = e.target.value; } });
  const valid = () => f.label.trim().length > 0 && !(f.source === 'micro' && microFull);
  const payload = (mode) => ({ mode, label: f.label.trim(), kind: f.kind, source: f.source, currency: f.currency, model: f.model });
  return [
    field(tr('ui_label'), labelInput),
    el('div', { class: 'field-row' }, [
      field(tr('ui_kind'), select([{ value: 'pvp', label: kindLabel('pvp') }, { value: 'pvd', label: kindLabel('pvd') }], f.kind, (v) => { f.kind = v; render(); })),
      field(tr('ui_source'), select([
        { value: 'public', label: tr('ui_source_public') },
        { value: 'micro', label: tr('ui_source_micro'), disabled: microFull },
      ], f.source, (v) => { f.source = v; render(); })),
    ]),
    el('div', { class: 'field-row' }, [
      field(tr('ui_currency'), select(data.currencies.map((c) => ({ value: c, label: tr(`ui_${c}`), disabled: f.source === 'micro' && c !== 'cash' })), f.currency, (v) => { f.currency = v; })),
      field(tr('ui_model'), select(models.map((m) => ({ value: m.name, label: m.label })), f.model, (v) => { f.model = v; })),
    ]),
    el('div', { class: 'note', text: tr('ui_micro_count', data.microCount, data.microMax) }),
    el('div', { class: 'btn-col' }, [
      button(tr('ui_place'), () => { if (valid()) post('adminCreate', payload('spawn')); }),
      button(tr('ui_bind'), () => { if (valid()) post('adminCreate', payload('bind')); }, 'muted'),
    ]),
  ];
}

function renderAdmin() {
  $('title').textContent = tr('ui_admin_title');
  $('subtitle').textContent = tr('ui_admin_subtitle');
  const tabs = $('tabs');
  tabs.classList.remove('hidden');
  tabs.replaceChildren(
    button(tr('ui_tab_tables'), () => { st.tab = 'tables'; st.detail = null; render(); }, st.tab === 'tables' ? 'active' : ''),
    button(tr('ui_tab_new'), () => { st.tab = 'new'; st.detail = null; render(); }, st.tab === 'new' ? 'active' : ''),
  );
  let detail = null;
  if (st.tab === 'tables' && st.detail != null) {
    detail = data.tables.find((t) => t.id === st.detail);
    if (!detail) st.detail = null;
  }
  $('btn-back').style.visibility = detail ? 'visible' : 'hidden';
  const nodes = st.tab === 'new' ? renderAdminNew() : detail ? renderAdminDetail(detail) : renderAdminList();
  $('content').replaceChildren(...nodes);
}

// ---------------------------------------------------------------- setup (game + tier picker)
function renderSetup() {
  $('title').textContent = data.label || '';
  $('subtitle').textContent = tr('ui_setup_subtitle');
  $('tabs').classList.add('hidden');
  $('btn-back').style.visibility = 'hidden';
  const nodes = [];
  if (!data.games.length) {
    nodes.push(el('div', { class: 'note', text: tr('ui_no_games') }));
    $('content').replaceChildren(...nodes);
    return;
  }
  if (data.games.length === 1) st.game = data.games[0].id;
  if (data.tiers.length === 1) st.tier = data.tiers[0].id;

  nodes.push(el('div', { class: 'section-label', text: tr('ui_game') }));
  nodes.push(el('div', { class: 'list' }, data.games.map((g) => row({
    icon: data.kind === 'pvp' ? 'P' : 'D', title: g.label, selected: st.game === g.id,
    onclick: () => { st.game = g.id; render(); },
  }))));

  nodes.push(el('div', { class: 'section-label', text: tr('ui_tier') }));
  if (data.fixedTier) nodes.push(el('div', { class: 'note', text: tr('ui_fixed_tier') }));
  nodes.push(el('div', { class: 'list' }, data.tiers.map((t) => {
    const bets = data.kind === 'pvp'
      ? tr('ui_blinds', money(t.smallBlind), money(t.bigBlind))
      : tr('ui_bets', money(t.bigBlind), money(t.bigBlind * data.maxBetMultiplier));
    return row({
      icon: t.label.charAt(0), title: t.label, desc: `${bets} · ${tr('ui_buyin', money(t.buyInMin), money(t.buyInMax))}`,
      pills: [{ text: t.stage }], selected: st.tier === t.id,
      onclick: () => { st.tier = t.id; render(); },
    });
  })));

  nodes.push(button(tr('ui_start'), () => post('configure', { game: st.game, tier: st.tier }), '', !(st.game && st.tier)));
  $('content').replaceChildren(...nodes);
}

// ---------------------------------------------------------------- shell
function render() {
  if (!view || !data) return;
  if (view === 'admin') renderAdmin();
  else if (view === 'setup') renderSetup();
}

function resetState() {
  st = { tab: 'tables', detail: null, game: null, tier: null,
    form: { label: '', kind: 'pvp', source: 'public', currency: 'cash', model: '' } };
}

window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'open':
      L = m.locale || L;
      view = m.view;
      data = m.data;
      resetState();
      closeModal();
      $('app').classList.remove('hidden');
      render();
      break;
    case 'update':
      if (view !== m.view) return;
      data = m.data;
      render();
      break;
    case 'close':
      view = null; data = null;
      closeModal();
      $('app').classList.add('hidden');
      break;
    case 'hide': $('app').classList.add('hidden'); break;
    case 'show': if (view) $('app').classList.remove('hidden'); break;
    case 'snippet': openSnippet(m.text || ''); break;
  }
});

$('btn-close').addEventListener('click', () => post('close'));
$('btn-back').addEventListener('click', () => { st.detail = null; render(); });
document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  if (modalOpen()) closeModal(); else post('close');
});
