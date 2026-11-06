const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-pob';
const IMG = 'nui://rsg-inventory/html/images/';
const $ = (id) => document.getElementById(id);
const app = $('app'), panel = $('panel'), content = $('content'), tabsEl = $('tabs');

const post = (name, body = {}) => fetch(`https://${RES}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
}).then(r => r.json()).catch(() => null);

let L = {};
const t = (key, ...args) => { let s = L[key] || key; args.forEach(a => { s = s.replace('%s', a); }); return s; };
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => '$' + Number(n || 0).toFixed(2);
const img = (name) => !name ? '' : (/^https?:\/\//.test(name) || name.startsWith('nui://') ? name : IMG + name);
const date = (ts) => ts ? new Date(ts * 1000).toLocaleString() : '-';

let S = { view: null, data: null, tab: null, edit: null, recipe: null, ledger: [], ledgerPage: 0 };

/* ------------------------------------------------------------------ chrome */
function setHeader(title, subtitle, back) {
  $('title').textContent = title || '';
  $('subtitle').textContent = subtitle || '';
  $('back').classList.toggle('invisible', !back);
  $('back').onclick = back || null;
}
function setTabs(list, active, onPick) {
  tabsEl.innerHTML = '';
  tabsEl.classList.toggle('hidden', !list || list.length < 2);
  (list || []).forEach(([key, label]) => {
    const b = document.createElement('div');
    b.className = 'tab' + (key === active ? ' active' : '');
    b.textContent = label;
    b.onclick = () => onPick(key);
    tabsEl.appendChild(b);
  });
}
function el(html) { const d = document.createElement('div'); d.innerHTML = html.trim(); return d.firstElementChild; }
function add(html) { const e = el(html); content.appendChild(e); return e; }
function clear() { content.innerHTML = ''; }

function modal(html, onBind) {
  $('modal').innerHTML = html;
  $('modal-wrap').classList.remove('hidden');
  if (onBind) onBind($('modal'));
}
function closeModal() { $('modal-wrap').classList.add('hidden'); $('modal').innerHTML = ''; }
function confirmBox(text, onYes) {
  modal(`<div class="modal-title">${esc(t('ui_confirm'))}</div><div class="ink-divider"></div><div class="muted" style="text-align:center">${esc(text)}</div>
    <div class="modal-actions"><button class="wood-btn" id="m-yes">${esc(t('ui_yes'))}</button><button class="wood-btn muted" id="m-no">${esc(t('ui_cancel'))}</button></div>`,
    m => { m.querySelector('#m-yes').onclick = () => { closeModal(); onYes(); }; m.querySelector('#m-no').onclick = closeModal; });
}
function promptBox(title, label, type, onOk, value = '') {
  modal(`<div class="modal-title">${esc(title)}</div><div class="ink-divider"></div>
    <label class="field">${esc(label)}<input id="m-in" type="${type}" value="${esc(value)}"></label>
    <div class="modal-actions"><button class="wood-btn" id="m-ok">${esc(t('ui_ok'))}</button><button class="wood-btn muted" id="m-no">${esc(t('ui_cancel'))}</button></div>`,
    m => {
      const i = m.querySelector('#m-in'); i.focus();
      m.querySelector('#m-ok').onclick = () => { const v = i.value; closeModal(); onOk(v); };
      m.querySelector('#m-no').onclick = closeModal;
    });
}

/* ------------------------------------------------------------------ sign */
function renderSign(d) {
  panel.classList.remove('wide');
  setHeader(d.label, d.type);
  setTabs(null);
  clear();
  if (!d.owned) {
    add(`<div class="muted" style="text-align:center">${esc(t('ui_for_sale_text'))}</div>`);
    add(`<div class="big">${money(d.price)}</div>`);
    const b = add(`<div class="btn-row"><button class="wood-btn">${esc(t('ui_buy_business'))}</button></div>`);
    b.querySelector('button').onclick = () => confirmBox(t('ui_buy_confirm', d.label, money(d.price)), () => post('buy', { id: d.id }));
    return;
  }
  add(`<div class="stat"><span>${esc(t('ui_owner'))}</span><span>${esc(d.owner)}</span></div>`);
  if (d.employee) { add(`<div class="empty">${esc(t('ui_already_employee'))}</div>`); return; }
  if (d.applied) add(`<div class="muted">${esc(t('ui_already_applied'))}</div>`);
  add(`<div class="section-title">${esc(t('ui_apply_title'))}</div>`);
  const ta = add(`<textarea maxlength="${d.maxLength}" placeholder="${esc(t('ui_apply_placeholder'))}"></textarea>`);
  const b = add(`<div class="btn-row"><button class="wood-btn">${esc(t('ui_send_application'))}</button></div>`);
  b.querySelector('button').onclick = () => post('apply', { id: d.id, message: ta.value });
}

/* ------------------------------------------------------------------ manager */
function managerTabs(d) {
  const p = d.perms, tabs = [['overview', t('ui_tab_overview')]];
  if (d.shop) tabs.push(['stock', t('ui_tab_stock')]);
  if (d.staff) tabs.push(['staff', t('ui_tab_staff')]);
  if (d.applications) tabs.push(['applications', t('ui_tab_applications') + (d.applications.length ? ` (${d.applications.length})` : '')]);
  if (p.ledger) tabs.push(['ledger', t('ui_tab_ledger')]);
  if (p.rename || d.appearance || (d.hotel && p.hotelRate) || (d.trainingPrices && p.prices) || d.wages) tabs.push(['settings', t('ui_tab_settings')]);
  if (p.recipes && (d.recipeRules || (d.typeRecipes && d.typeRecipes.length))) tabs.push(['recipes', t('ui_tab_recipes')]);
  if (d.backroom) tabs.push(['backroom', t('ui_tab_backroom')]);
  if (d.gambling) tabs.push(['gambling', t('ui_tab_gambling')]);
  return tabs;
}
const mgr = (op, extra) => post('manager', Object.assign({ op, id: S.data.id }, extra));

function renderManager(d) {
  panel.classList.add('wide');
  setHeader(d.label, `${d.typeLabel} · ${d.gradeLabel}`);
  const tabs = managerTabs(d);
  if (!tabs.find(x => x[0] === S.tab)) S.tab = 'overview';
  setTabs(tabs, S.tab, (k) => { S.tab = k; S.recipe = null; renderManager(S.data); });
  clear();
  ({ overview: mOverview, stock: mStock, staff: mStaff, applications: mApps, ledger: mLedger, settings: mSettings, recipes: mRecipes, backroom: mBackroom, gambling: mGambling })[S.tab](d);
}

function mOverview(d) {
  add(`<div class="stat"><span>${esc(t('ui_owner'))}</span><span>${esc(d.owner || '-')}</span></div>`);
  add(`<div class="stat"><span>${esc(t('ui_your_grade'))}</span><span>${esc(d.gradeLabel)}</span></div>`);
  const duty = add(`<div class="row"><div class="row-text"><div class="row-title">${esc(t(d.onDuty ? 'ui_on_duty' : 'ui_off_duty'))}</div>
    <div class="row-desc">${esc(t('ui_duty_hint'))}</div></div><button class="wood-btn">${esc(t(d.onDuty ? 'ui_clock_out' : 'ui_clock_in'))}</button></div>`);
  duty.querySelector('button').onclick = () => mgr('duty');
  if (d.balance !== undefined) {
    add(`<div class="section-title">${esc(t('ui_account'))}</div>`);
    add(`<div class="big">${money(d.balance)}</div>`);
  }
  if (d.perms.deposit || d.perms.withdraw) {
    const r = add(`<div class="row"><input type="number" min="0" step="0.01" placeholder="${esc(t('ui_amount'))}">
      ${d.perms.deposit ? `<button class="wood-btn" data-a="deposit">${esc(t('ui_deposit'))}</button>` : ''}
      ${d.perms.withdraw ? `<button class="wood-btn" data-a="withdraw">${esc(t('ui_withdraw'))}</button>` : ''}</div>`);
    r.querySelectorAll('button').forEach(b => b.onclick = () => mgr('money', { action: b.dataset.a, amount: r.querySelector('input').value }));
    if (d.withdrawLeft !== undefined && d.withdrawLeft !== null) add(`<div class="muted">${esc(t('ui_withdraw_left', money(d.withdrawLeft)))}</div>`);
  }
  if (d.tax) {
    add(`<div class="section-title">${esc(t('ui_tax'))}</div>`);
    add(`<div class="stat"><span>${esc(t('ui_tax_amount'))}</span><span>${money(d.tax.amount)}</span></div>`);
    add(`<div class="stat"><span>${esc(t('ui_tax_due'))}</span><span>${esc(date(d.tax.due))}</span></div>`);
    if (d.tax.owedSince) {
      const until = d.tax.owedSince + d.tax.graceDays * 86400;
      add(`<div class="row"><span class="pill bad">${esc(t('ui_tax_overdue'))}</span><div class="row-desc">${esc(t('ui_tax_repossess', date(until)))}</div></div>`);
    }
  }
}

function mStock(d) {
  if (!d.stock.length) { add(`<div class="empty">${esc(t('ui_no_stock'))}</div>`); }
  add(`<div class="muted">${esc(t('ui_stock_hint', money(d.priceRange.min), money(d.priceRange.max)))}</div>`);
  d.stock.forEach(s => {
    const status = s.price == null ? `<span class="pill warn">${esc(t('ui_hidden'))}</span>` : (s.qty > 0 ? `<span class="pill ok">${esc(t('ui_for_sale'))}</span>` : `<span class="pill">${esc(t('ui_sold_out'))}</span>`);
    const r = add(`<div class="row"><span class="badge-icon"><img src="${esc(img(s.item + '.png'))}" onerror="this.style.display='none'"></span>
      <div class="row-text"><div class="row-title">${esc(s.label)}</div><div class="row-desc">${esc(t('ui_in_stock', s.qty))}</div></div>${status}
      <div class="row-actions">
        ${d.perms.prices ? `<input class="small" type="number" min="0" step="0.01" value="${s.price ?? ''}" placeholder="$"><button class="wood-btn small" data-op="price">${esc(t('ui_set'))}</button>` : (s.price != null ? `<span>${money(s.price)}</span>` : '')}
        ${d.perms.takeStock && s.qty > 0 ? `<button class="wood-btn small muted" data-op="take">${esc(t('ui_take_out'))}</button>` : ''}
      </div></div>`);
    const p = r.querySelector('[data-op=price]');
    if (p) p.onclick = () => mgr('price', { item: s.item, price: r.querySelector('input').value });
    const tk = r.querySelector('[data-op=take]');
    if (tk) tk.onclick = () => promptBox(t('ui_take_out'), t('ui_quantity_max', s.qty), 'number', (v) => mgr('takeStock', { item: s.item, qty: v }), 1);
  });
}

function gradeSelect(d, current) {
  return `<select>${d.grades.filter(g => g.level < d.grade).map(g => `<option value="${g.level}" ${g.level === current ? 'selected' : ''}>${esc(g.label)}</option>`).join('')}</select>`;
}

function mStaff(d) {
  if (d.perms.hire) {
    const r = add(`<div class="btn-row"><button class="wood-btn">${esc(t('ui_hire_nearby'))}</button></div>`);
    r.querySelector('button').onclick = async () => {
      const list = await post('nearby', { id: d.id }) || [];
      if (!list.length) return modal(`<div class="modal-title">${esc(t('ui_hire_nearby'))}</div><div class="ink-divider"></div><div class="empty">${esc(t('ui_nobody_near'))}</div><div class="modal-actions"><button class="wood-btn" id="m-no">${esc(t('ui_ok'))}</button></div>`, m => m.querySelector('#m-no').onclick = closeModal);
      modal(`<div class="modal-title">${esc(t('ui_hire_nearby'))}</div><div class="ink-divider"></div><div class="content" id="m-list"></div><div class="modal-actions"><button class="wood-btn muted" id="m-no">${esc(t('ui_cancel'))}</button></div>`, m => {
        m.querySelector('#m-no').onclick = closeModal;
        list.forEach(p => { const row = el(`<div class="row click"><div class="row-text"><div class="row-title">${esc(p.name)}</div></div><span class="pill">${esc(t('ui_hire'))}</span></div>`);
          row.onclick = () => { closeModal(); mgr('hire', { target: p.src }); }; m.querySelector('#m-list').appendChild(row); });
      });
    };
  }
  if (!d.staff.length) add(`<div class="empty">${esc(t('ui_no_staff'))}</div>`);
  d.staff.forEach(s => {
    const manageable = s.grade < d.grade && s.grade < d.grades.length - 1;
    const r = add(`<div class="row"><div class="row-text"><div class="row-title">${esc(s.name)}</div>
      <div class="row-desc">${esc(s.gradeLabel)} · ${esc(s.online ? (s.onDuty ? t('ui_on_duty') : t('ui_online')) : t('ui_offline'))}</div></div>
      <div class="row-actions">${manageable && d.perms.setGrade ? gradeSelect(d, s.grade) + `<button class="wood-btn small" data-op="grade">${esc(t('ui_set'))}</button>` : ''}
      ${manageable && d.perms.fire ? `<button class="wood-btn small muted" data-op="fire">${esc(t('ui_fire'))}</button>` : ''}</div></div>`);
    const g = r.querySelector('[data-op=grade]');
    if (g) g.onclick = () => mgr('grade', { cid: s.cid, grade: Number(r.querySelector('select').value) });
    const f = r.querySelector('[data-op=fire]');
    if (f) f.onclick = () => confirmBox(t('ui_fire_confirm', s.name), () => mgr('fire', { cid: s.cid }));
  });
}

function mApps(d) {
  if (!d.applications.length) add(`<div class="empty">${esc(t('ui_no_applications'))}</div>`);
  d.applications.forEach(a => {
    const r = add(`<div class="row"><div class="row-text"><div class="row-title">${esc(a.name)}</div><div class="row-desc">${esc(a.message)}</div>
      <div class="muted">${esc(date(a.created_at))}</div></div><div class="row-actions">
      ${d.perms.hire ? `<button class="wood-btn small" data-a="1">${esc(t('ui_accept'))}</button>` : ''}
      <button class="wood-btn small muted" data-a="0">${esc(t('ui_reject'))}</button></div></div>`);
    r.querySelectorAll('button').forEach(b => b.onclick = () => mgr('application', { appId: a.id, accept: b.dataset.a === '1' }));
  });
}

/* ------------------------------------------------------------------ back room (owner only) */
function launderRows(rows, showSeized) {
  if (!rows || !rows.length) { add(`<div class="empty">${esc(t('ui_br_no_records'))}</div>`); return; }
  rows.forEach(r => add(`<div class="row"><div class="row-text"><div class="row-title">${money(r.dirty)} → ${money(r.clean)}${r.name ? ' · ' + esc(r.name) : ''}</div>
    <div class="muted">${esc(date(r.ts))}</div></div>${showSeized && r.seized ? `<span class="pill bad">${esc(t('ui_br_seized'))}</span>` : ''}</div>`));
}

function mGambling(d) {
  const g = d.gambling;
  add(`<div class="muted" style="text-align:center">${esc(t('ui_gt_pitch'))}</div>`);
  add(`<div class="stat"><span>${esc(t('ui_gt_balance'))}</span><span>${money(g.balance)}</span></div>`);
  g.tables.forEach(x => {
    const desc = t(x.kind === 'pvp' ? 'ui_gt_desc_pvp' : 'ui_gt_desc_pvd');
    const count = t('ui_gt_count', x.placed, x.max) + (x.carried ? ' · ' + t('ui_gt_carried', x.carried) : '');
    const r = add(`<div class="row"><div class="row-text"><div class="row-title">${esc(x.label)} · ${money(x.price)}</div>
      <div class="muted">${esc(desc)}</div><div class="muted">${esc(count)}</div></div>
      <button class="wood-btn small"${x.canBuy ? '' : ' disabled'}>${esc(t('ui_gt_buy'))}</button></div>`);
    r.querySelector('button').onclick = () => confirmBox(t('ui_gt_buy_confirm', x.label, money(x.price)), () => mgr('buyTable', { kind: x.kind }));
  });
  add(`<div class="muted">${esc(t('ui_gt_paid_from'))}</div>`);
  add(`<div class="muted">${esc(t(g.backroom ? 'ui_gt_note_backroom' : 'ui_gt_note'))}</div>`);
}

function mBackroom(d) {
  const b = d.backroom;
  if (!b.owned) {
    add(`<div class="muted" style="text-align:center">${esc(t('ui_br_pitch', b.cut))}</div>`);
    add(`<div class="big">${money(b.price)}</div>`);
    add(`<div class="muted" style="text-align:center">${esc(t('ui_br_paid_from'))}</div>`);
    const r = add(`<div class="btn-row"><button class="wood-btn">${esc(t('ui_br_buy'))}</button></div>`);
    r.querySelector('button').onclick = () => confirmBox(t('ui_br_buy_confirm', money(b.price)), () => mgr('buyBackroom'));
    return;
  }
  add(`<div class="muted">${esc(t('ui_br_note', b.cut))}</div>`);
  add(`<div class="stat"><span>${esc(t('ui_br_dirty'))}</span><span>${money(b.dirty)}</span></div>`);
  add(`<div class="stat"><span>${esc(t('ui_br_allowance', b.windowDays))}</span><span>${money(b.allowance)}</span></div>`);
  add(`<div class="stat"><span>${esc(t('ui_br_left'))}</span><span>${money(b.left)}</span></div>`);
  const max = Math.floor(Math.min(Number(b.dirty || 0), Number(b.left || 0)) * 100) / 100;
  const r = add(`<div class="row"><input type="number" min="${b.min}" max="${max}" step="0.01" placeholder="${esc(t('ui_br_amount'))}">
    <button class="wood-btn small muted" data-a="max">${esc(t('ui_br_max'))}</button><button class="wood-btn" data-a="go">${esc(t('ui_br_wash'))}</button></div>`);
  const input = r.querySelector('input');
  const out = add(`<div class="stat"><span>${esc(t('ui_br_receive'))}</span><span>${money(0)}</span></div>`);
  const upd = () => {
    const v = Number(input.value || 0);
    out.lastElementChild.textContent = money(Math.max(0, Math.round(v * (1 - b.cut / 100) * 100) / 100));
    r.querySelector('[data-a=go]').disabled = !(v >= b.min && v <= max);
  };
  input.oninput = upd;
  r.querySelector('[data-a=max]').onclick = () => { input.value = max.toFixed(2); upd(); };
  r.querySelector('[data-a=go]').onclick = () => mgr('launder', { amount: input.value });
  upd();
  add(`<div class="section-title">${esc(t('ui_br_history'))}</div>`);
  launderRows(b.rows, true);
}

/* ------------------------------------------------------------------ law audit */
function renderAudit(d) {
  panel.classList.add('wide');
  setHeader(t('ui_audit_title', d.label), t('ui_audit_owner', d.owner));
  setTabs(null);
  clear();
  add(`<div class="muted">${esc(t('ui_audit_note', d.lookbackDays))}</div>`);
  add(`<div class="stat"><span>${esc(t('ui_audit_backroom'))}</span><span>${esc(t(d.backroom ? 'ui_yes' : 'ui_no'))}</span></div>`);
  add(`<div class="stat"><span>${esc(t('ui_account'))}</span><span>${money(d.balance)}</span></div>`);
  add(`<div class="stat"><span>${esc(t('ui_audit_open'))}</span><span>${money(d.openTotal)}</span></div>`);
  if (d.canSeize) {
    const r = add(`<div class="btn-row"><button class="wood-btn">${esc(t('ui_audit_seize', money(Math.min(d.openTotal, d.balance))))}</button></div>`);
    r.querySelector('button').onclick = () => confirmBox(t('ui_audit_seize_confirm', d.label), () => post('audit', { op: 'seize', id: d.id }));
  }
  add(`<div class="section-title">${esc(t('ui_audit_records'))}</div>`);
  if (!d.rows.length) { add(`<div class="empty">${esc(t('ui_audit_clean'))}</div>`); return; }
  launderRows(d.rows, true);
}

async function mLedger(d) {
  const page = S.ledgerPage || 0;
  const rows = await post('ledger', { id: d.id, page }) || [];
  if (S.tab !== 'ledger') return;
  ledgerList(rows, page, (p) => { S.ledgerPage = p; renderManager(S.data); }, d.ledgerPage);
}

function ledgerList(rows, page, onPage, pageSize) {
  if (!rows.length) add(`<div class="empty">${esc(t('ui_no_entries'))}</div>`);
  rows.forEach(r => {
    const amt = Number(r.amount || 0);
    add(`<div class="row"><div class="row-text"><div class="row-title">${esc(t('ui_kind_' + r.kind) !== 'ui_kind_' + r.kind ? t('ui_kind_' + r.kind) : r.kind)}${r.who_name ? ' · ' + esc(r.who_name) : ''}</div>
      <div class="row-desc">${esc(r.note || '')}</div><div class="muted">${esc(date(r.ts))}</div></div>
      ${amt !== 0 ? `<span class="pill ${amt > 0 ? 'ok' : 'bad'}">${amt > 0 ? '+' : ''}${money(amt)}</span>` : ''}</div>`);
  });
  const nav = add(`<div class="btn-row"><button class="wood-btn small muted" data-p="-1" ${page <= 0 ? 'disabled' : ''}>‹ ${esc(t('ui_newer'))}</button>
    <button class="wood-btn small muted" data-p="1" ${rows.length < pageSize ? 'disabled' : ''}>${esc(t('ui_older'))} ›</button></div>`);
  nav.querySelectorAll('button').forEach(b => b.onclick = () => onPage(Math.max(0, page + Number(b.dataset.p))));
}

function mSettings(d) {
  const p = d.perms;
  if (p.rename) {
    add(`<div class="section-title">${esc(t('ui_business_name'))}</div>`);
    const r = add(`<div class="row"><input maxlength="40" value="${esc(d.label)}"><button class="wood-btn">${esc(t('ui_rename'))}</button></div>`);
    r.querySelector('button').onclick = () => mgr('rename', { label: r.querySelector('input').value });
  }
  if (d.appearance) {
    const a = d.appearance;
    const opt = (list, v) => list.map(o => `<option value="${esc(o.value)}" ${o.value === v ? 'selected' : ''}>${esc(o.label)}</option>`).join('');
    add(`<div class="section-title">${esc(t('ui_appearance'))}</div>`);
    const f = add(`<div class="form">
      <label class="field full">${esc(t('ui_npc_model'))}<select data-k="model">${opt(a.models, a.model)}</select></label>
      <label class="field">${esc(t('ui_blip_icon'))}<select data-k="sprite">${opt(a.sprites, a.sprite)}</select></label>
      <label class="field">${esc(t('ui_blip_color'))}<select data-k="color">${opt(a.colors, a.color)}</select></label>
      <label class="field full"><span><input type="checkbox" data-k="enabled" style="width:auto" ${a.enabled ? 'checked' : ''}> ${esc(t('ui_show_blip'))}</span></label>
      <div class="btn-row full"><button class="wood-btn">${esc(t('ui_save'))}</button></div></div>`);
    f.querySelector('button').onclick = () => mgr('appearance', { data: {
      model: f.querySelector('[data-k=model]').value, sprite: f.querySelector('[data-k=sprite]').value,
      color: f.querySelector('[data-k=color]').value, enabled: f.querySelector('[data-k=enabled]').checked } });
  }
  if (d.hotel && p.hotelRate) {
    add(`<div class="section-title">${esc(t('ui_hotel_rate'))}</div>`);
    add(`<div class="muted">${esc(t('ui_hotel_rooms', d.rooms, money(d.hotelMax)))}</div>`);
    const r = add(`<div class="row"><input type="number" min="0" step="0.01" value="${d.hotelRate}"><button class="wood-btn">${esc(t('ui_set'))}</button></div>`);
    r.querySelector('button').onclick = () => mgr('hotelRate', { rate: r.querySelector('input').value });
  }
  if (d.trainingPrices && p.prices) {
    add(`<div class="section-title">${esc(t('ui_training_prices'))}</div>`);
    add(`<div class="muted">${esc(t('ui_training_split'))}</div>`);
    d.trainingPrices.forEach(s => {
      const r = add(`<div class="row"><div class="row-text"><div class="row-title">${esc(s.label)}</div></div>
        <input class="small" type="number" min="${d.trainingRange.min}" max="${d.trainingRange.max}" step="0.01" value="${s.price}"><button class="wood-btn small">${esc(t('ui_set'))}</button></div>`);
      r.querySelector('button').onclick = () => mgr('trainPrice', { stat: s.stat, price: r.querySelector('input').value });
    });
  }
  if (d.wages) {
    add(`<div class="section-title">${esc(t('ui_wages'))}</div>`);
    add(`<div class="muted">${esc(t('ui_wages_hint', d.wageInterval, money(d.wageMax)))}</div>`);
    const box = add(`<div class="form"></div>`);
    d.wages.forEach(w => box.appendChild(el(`<label class="field">${esc(w.label)}<input type="number" min="0" max="${d.wageMax}" step="0.01" data-l="${w.level}" value="${w.amount}"></label>`)));
    const b = add(`<div class="btn-row"><button class="wood-btn">${esc(t('ui_save_wages'))}</button></div>`);
    b.querySelector('button').onclick = () => {
      const wages = {};
      box.querySelectorAll('input').forEach(i => { wages[i.dataset.l] = Number(i.value || 0); });
      mgr('wages', { wages });
    };
  }
}

/* ------------------------------------------------------------------ recipes (manager) */
const statusPill = (s) => {
  const cls = { approved: 'ok', rejected: 'bad', pending: 'warn', retired: '' }[s] ?? '';
  return `<span class="pill ${cls}">${esc(t('ui_status_' + s))}</span>`;
};

function mRecipes(d) {
  if (S.recipe) return recipeForm(d);
  if (d.typeRecipes && d.typeRecipes.length) {
    add(`<div class="section-title">${esc(t('ui_standard_recipes'))}</div>`);
    add(`<div class="muted">${esc(d.typeRecipes.map(r => `${r.amount}x ${r.label}`).join(', '))}</div>`);
  }
  if (!d.recipeRules) return;
  add(`<div class="section-title">${esc(t('ui_custom_recipes'))}</div>`);
  const b = add(`<div class="btn-row"><button class="wood-btn" ${d.recipes.filter(r => r.status === 'pending' || r.status === 'approved').length >= d.recipeRules.max ? 'disabled' : ''}>${esc(t('ui_new_recipe'))}</button></div>`);
  b.querySelector('button').onclick = () => { S.recipe = { label: '', description: '', base: d.recipeRules.bases[0]?.name, ingredients: [], amount: 1, time: d.recipeRules.time.min, gallery: '', file: null, error: '' }; renderManager(d); };
  if (!d.recipes.length) add(`<div class="empty">${esc(t('ui_no_custom'))}</div>`);
  d.recipes.forEach(r => {
    const row = add(`<div class="row"><span class="badge-icon">${r.image ? `<img src="${esc(img(r.image))}" onerror="this.style.display='none'">` : '✦'}</span>
      <div class="row-text"><div class="row-title">${esc(r.label)} <span class="muted">(${esc(r.base)})</span></div>
      <div class="row-desc">${esc(r.description)}</div><div class="muted">${esc(r.ingredients.map(i => `${i.amount}x ${i.label}`).join(', '))} → ${r.amount}x</div></div>
      <div class="row-actions">${statusPill(r.status)}${r.imageStatus === 'pending' ? `<span class="pill warn">${esc(t('ui_image_pending'))}</span>` : ''}
      ${r.status !== 'retired' ? `<button class="wood-btn small muted">${esc(t('ui_remove'))}</button>` : ''}</div></div>`);
    const del = row.querySelector('button');
    if (del) del.onclick = () => confirmBox(t(r.status === 'approved' ? 'ui_retire_confirm' : 'ui_remove_confirm', r.label), () => mgr('delRecipe', { recipe: r.id }));
  });
}

function recipeForm(d) {
  const R = d.recipeRules, f = S.recipe;
  setHeader(t('ui_new_recipe'), d.label, () => { S.recipe = null; renderManager(d); });
  const opt = (list, v) => list.map(o => `<option value="${esc(o.name)}" ${o.name === v ? 'selected' : ''}>${esc(o.label)}</option>`).join('');
  const form = add(`<div class="form">
    <label class="field">${esc(t('ui_item_name'))}<input data-k="label" maxlength="${R.nameMax}" value="${esc(f.label)}"></label>
    <label class="field">${esc(t('ui_base_item'))}<select data-k="base">${opt(R.bases, f.base)}</select></label>
    <label class="field full">${esc(t('ui_description'))}<input data-k="description" maxlength="${R.descMax}" value="${esc(f.description)}"></label>
    <label class="field">${esc(t('ui_output_amount'))}<input data-k="amount" type="number" min="1" max="${R.maxOutput}" value="${f.amount}"></label>
    <label class="field">${esc(t('ui_craft_seconds'))}<input data-k="time" type="number" min="${R.time.min / 1000}" max="${R.time.max / 1000}" step="0.5" value="${f.time / 1000}"></label>
  </div>`);
  form.querySelectorAll('[data-k]').forEach(i => i.oninput = () => {
    const k = i.dataset.k;
    f[k] = k === 'amount' ? Number(i.value) : k === 'time' ? Math.round(Number(i.value) * 1000) : i.value;
  });
  add(`<div class="section-title">${esc(t('ui_ingredients'))} (${f.ingredients.length}/${R.maxIngredients})</div>`);
  f.ingredients.forEach((ing, idx) => {
    const r = add(`<div class="row"><select>${opt(R.ingredients, ing.name)}</select><input class="small" type="number" min="1" max="${R.maxAmount}" value="${ing.amount}"><button class="wood-btn small muted">✕</button></div>`);
    r.querySelector('select').onchange = (e) => { ing.name = e.target.value; };
    r.querySelector('input').oninput = (e) => { ing.amount = Number(e.target.value); };
    r.querySelector('button').onclick = () => { f.ingredients.splice(idx, 1); renderManager(d); };
  });
  if (f.ingredients.length < R.maxIngredients) {
    const a = add(`<div class="btn-row"><button class="wood-btn small">${esc(t('ui_add_ingredient'))}</button></div>`);
    a.querySelector('button').onclick = () => { f.ingredients.push({ name: R.ingredients[0]?.name, amount: 1 }); renderManager(d); };
  }
  add(`<div class="section-title">${esc(t('ui_image'))}</div>`);
  const gallery = [...R.bases, ...R.ingredients];
  const g = add(`<div class="row"><img class="preview-img" id="r-prev" src="${esc(f.file ? f.preview : img((gallery.find(x => x.name === (f.gallery || f.base)) || {}).image))}">
    <div class="row-text"><label class="field">${esc(t('ui_gallery_image'))}<select data-k="gallery"><option value="">${esc(t('ui_use_base_image'))}</option>${opt(gallery, f.gallery)}</select></label></div></div>`);
  g.querySelector('select').onchange = (e) => { f.gallery = e.target.value; f.file = null; renderManager(d); };
  if (R.images) {
    const u = add(`<div class="dropzone">${esc(t('ui_upload_hint', R.maxKB))}<br><input type="file" accept="${R.types.join(',')}" style="margin-top:6px"></div>`);
    u.querySelector('input').onchange = (e) => setFile(e.target.files[0], R, d);
  }
  if (f.error) add(`<div class="pill bad" style="text-align:center">${esc(f.error)}</div>`);
  const b = add(`<div class="btn-row"><button class="wood-btn" id="r-send">${esc(t('ui_submit_recipe'))}</button><button class="wood-btn muted" id="r-cancel">${esc(t('ui_cancel'))}</button></div>`);
  b.querySelector('#r-cancel').onclick = () => { S.recipe = null; renderManager(d); };
  b.querySelector('#r-send').onclick = () => submitRecipe(d, b.querySelector('#r-send'));
}

function setFile(file, R, d) {
  const f = S.recipe;
  if (!file) return;
  if (!R.types.includes(file.type)) { f.error = t('ui_bad_image_type'); return renderManager(d); }
  if (file.size > R.maxKB * 1024) { f.error = t('ui_image_too_big', R.maxKB); return renderManager(d); }
  f.error = ''; f.file = file; f.gallery = '';
  const reader = new FileReader();
  reader.onload = () => { f.preview = reader.result; renderManager(d); };
  reader.readAsDataURL(file);
}

// Ctrl+V an image into the recipe form (file pickers may not open in game)
window.addEventListener('paste', (e) => {
  if (S.view !== 'manager' || !S.recipe || !S.data.recipeRules || !S.data.recipeRules.images) return;
  for (const item of (e.clipboardData || {}).items || []) {
    if (item.kind === 'file') { setFile(item.getAsFile(), S.data.recipeRules, S.data); break; }
  }
});

async function submitRecipe(d, btn) {
  const f = S.recipe;
  btn.disabled = true;
  let imageId = null;
  try {
    if (f.file) {
      const pre = await post('presign', { id: d.id });
      if (!pre || !pre.url) throw new Error(t('ui_upload_failed'));
      const fd = new FormData();
      fd.append('file', f.file, f.file.name || 'image.png');
      const res = await fetch(pre.url, { method: 'POST', body: fd });
      const j = await res.json().catch(() => null);
      imageId = j && j.data && j.data.id;
      if (!imageId) throw new Error(t('ui_upload_failed'));
    }
  } catch (err) {
    f.error = err.message || t('ui_upload_failed');
    return renderManager(d);
  }
  const r = await post('submitRecipe', { id: d.id, recipe: {
    label: f.label, description: f.description, base: f.base, amount: f.amount, time: f.time,
    ingredients: f.ingredients, gallery: f.gallery || null, imageId } });
  if (r && r.ok) { S.recipe = null; } else { btn.disabled = false; }
}

/* ------------------------------------------------------------------ crafting */
function renderCraft(d) {
  panel.classList.remove('wide');
  setHeader(t('ui_crafting'), d.business);
  setTabs(null);
  clear();
  if (!d.recipes.length) add(`<div class="empty">${esc(t('ui_no_recipes'))}</div>`);
  d.recipes.forEach(r => {
    const ings = r.ingredients.map(i => `<span style="color:${i.have >= i.amount ? 'var(--rdr-cost-ok)' : 'var(--rdr-cost-over)'}">${i.amount}x ${esc(i.label)} (${i.have})</span>`).join(', ');
    const row = add(`<div class="row ${r.canCraft ? '' : 'disabled'}"><span class="badge-icon"><img src="${esc(img(r.image))}" onerror="this.style.display='none'"></span>
      <div class="row-text"><div class="row-title">${r.amount}x ${esc(r.label)}</div><div class="row-desc">${ings}</div><div class="muted">${(r.time / 1000).toFixed(1)}s</div></div>
      <input class="small" type="number" min="1" max="10" value="1"><button class="wood-btn small" ${r.canCraft ? '' : 'disabled'}>${esc(t('ui_craft'))}</button></div>`);
    row.querySelector('button').onclick = () => post('craft', { key: r.key, count: Number(row.querySelector('input').value || 1) });
  });
}

/* ------------------------------------------------------------------ training */
function renderTraining(d) {
  panel.classList.remove('wide');
  setHeader(t('ui_training'), d.horse);
  setTabs(null);
  clear();
  add(`<div class="muted">${esc(t(d.trainers > 0 ? 'ui_trainers_on_duty' : 'ui_no_trainers', d.trainers))}</div>`);
  if (d.pending) {
    add(`<div class="empty">${esc(t('ui_request_waiting'))}</div>`);
    const b = add(`<div class="btn-row"><button class="wood-btn muted">${esc(t('ui_cancel_request'))}</button></div>`);
    b.querySelector('button').onclick = () => post('cancelTraining', { id: d.id });
    return;
  }
  d.stats.forEach(s => {
    const r = add(`<div class="row click"><div class="row-text"><div class="row-title">${esc(s.label)}</div></div><span class="pill">${s.price > 0 ? money(s.price) : esc(t('ui_free'))}</span></div>`);
    r.onclick = () => post('requestTraining', { id: d.id, stat: s.stat });
  });
}

function renderTrainer(d) {
  panel.classList.remove('wide');
  setHeader(t('ui_training_requests'), '');
  setTabs(null);
  clear();
  if (!d.requests.length) add(`<div class="empty">${esc(t('ui_no_requests'))}</div>`);
  d.requests.forEach(q => {
    const r = add(`<div class="row click"><div class="row-text"><div class="row-title">${esc(q.name)} · ${esc(q.horse)}</div>
      <div class="row-desc">${esc(q.stat)} · ${q.price > 0 ? esc(t('ui_you_earn', money(q.earn))) : esc(t('ui_free'))}</div></div><span class="pill">${esc(t('ui_accept'))}</span></div>`);
    r.onclick = () => post('acceptTraining', { id: d.id, src: q.src });
  });
}

/* ------------------------------------------------------------------ government */
function renderGov(d) {
  panel.classList.add('wide');
  setHeader(t('ui_gov_title'), t('ui_gov_sub'));
  setTabs(null);
  clear();
  add(`<div class="big">${money(d.balance)}</div>`);
  const r = add(`<div class="row"><input type="number" min="0" step="0.01" placeholder="${esc(t('ui_amount'))}">
    <button class="wood-btn" data-a="deposit">${esc(t('ui_deposit'))}</button><button class="wood-btn" data-a="withdraw">${esc(t('ui_withdraw'))}</button></div>`);
  r.querySelectorAll('button').forEach(b => b.onclick = () => post('gov', { op: 'money', action: b.dataset.a, amount: r.querySelector('input').value }));
  add(`<div class="section-title">${esc(t('ui_tab_ledger'))}</div>`);
  ledgerList(d.ledger || [], d.page || 0, (p) => post('gov', { op: 'page', page: p }), 50);
}

/* ------------------------------------------------------------------ admin */
const POINTS = (type) => {
  const list = [['npc', t('ui_pt_npc')], ['manager', t('ui_pt_manager')]];
  if (type && type.hotel) list.push(['door', t('ui_pt_door')], ['interior', t('ui_pt_interior')]);
  if (type && type.stable) list.push(['preview', t('ui_pt_preview')]);
  return list;
};
const fmt = (p) => p ? `${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}${p.w !== undefined ? ' · ' + Math.round(p.w) + '°' : ''}` : t('ui_not_set');

function renderAdmin(d) {
  panel.classList.add('wide');
  if (S.edit) return adminEditor(d);
  setHeader(t('ui_admin_title'), t('ui_admin_sub'));
  if (!['list', 'recipes'].includes(S.tab)) S.tab = 'list';
  setTabs([['list', t('ui_tab_businesses')], ['recipes', t('ui_tab_approvals') + (d.recipes.length ? ` (${d.recipes.length})` : '')]], S.tab, (k) => { S.tab = k; renderAdmin(d); });
  clear();
  if (S.tab === 'recipes') return adminRecipes(d);
  const top = add(`<div class="btn-row"><button class="wood-btn" id="a-new">${esc(t('ui_new_business'))}</button><button class="wood-btn muted" id="a-gov">${esc(t('ui_gov_account', money(d.gov)))}</button></div>`);
  top.querySelector('#a-new').onclick = () => { const ty = d.types[0]; S.edit = { id: null, type: ty.key, label: '', price: ty.price, npcModel: ty.npcModel, rooms: ty.hotel ? 5 : 0, points: { craft: [], stash: [] } }; renderAdmin(d); };
  top.querySelector('#a-gov').onclick = () => post('admin', { op: 'gov' });
  if (!d.businesses.length) add(`<div class="empty">${esc(t('ui_no_businesses'))}</div>`);
  d.businesses.forEach(b => {
    const r = add(`<div class="row"><div class="row-text"><div class="row-title">#${b.id} ${esc(b.label)} <span class="muted">${esc(b.typeLabel)}</span></div>
      <div class="row-desc">${b.owner ? esc(t('ui_owned_by', b.owner)) : esc(t('ui_for_sale_price', money(b.price)))} · ${esc(t('ui_balance', money(b.balance)))}${b.taxOwedSince ? ' · ' + esc(t('ui_tax_overdue')) : ''}</div></div>
      <div class="row-actions"><button class="wood-btn small" data-op="edit">${esc(t('ui_edit'))}</button><button class="wood-btn small muted" data-op="tp">${esc(t('ui_teleport'))}</button>
      <button class="wood-btn small muted" data-op="owner">${esc(t('ui_set_owner'))}</button>
      ${b.owner ? `<button class="wood-btn small muted" data-op="reset">${esc(t('ui_reset_owner'))}</button>` : ''}
      <button class="wood-btn small muted" data-op="del">${esc(t('ui_delete'))}</button></div></div>`);
    r.querySelector('[data-op=edit]').onclick = () => { S.edit = JSON.parse(JSON.stringify({ id: b.id, type: b.type, label: b.label, price: b.price, npcModel: b.npcModel, rooms: b.rooms, points: b.points })); renderAdmin(d); };
    r.querySelector('[data-op=tp]').onclick = () => post('admin', { op: 'teleport', id: b.id });
    r.querySelector('[data-op=owner]').onclick = () => promptBox(t('ui_set_owner'), t('ui_server_id'), 'number', (v) => post('admin', { op: 'owner', id: b.id, target: v }));
    const rs = r.querySelector('[data-op=reset]');
    if (rs) rs.onclick = () => confirmBox(t('ui_reset_confirm', b.label), () => post('admin', { op: 'reset', id: b.id }));
    r.querySelector('[data-op=del]').onclick = () => confirmBox(t('ui_delete_confirm', b.label), () => post('admin', { op: 'delete', id: b.id }));
  });
}

function adminRecipes(d) {
  if (!d.recipes.length) add(`<div class="empty">${esc(t('ui_nothing_waiting'))}</div>`);
  d.recipes.forEach(r => {
    const row = add(`<div class="row">${r.image ? `<img class="preview-img" src="${esc(img(r.image))}">` : ''}<div class="row-text">
      <div class="row-title">${esc(r.label)} <span class="muted">${esc(r.business)}</span></div><div class="row-desc">${esc(r.description)}</div>
      <div class="muted">${esc(r.base)} · ${esc(r.ingredients)} → ${r.amount}x · ${(r.time / 1000).toFixed(1)}s</div></div>
      <div class="row-actions">${r.status === 'pending'
        ? `<button class="wood-btn small" data-w="item" data-a="1">${esc(t('ui_approve'))}</button><button class="wood-btn small muted" data-w="item" data-a="0">${esc(t('ui_reject'))}</button>`
        : `<button class="wood-btn small" data-w="image" data-a="1">${esc(t('ui_approve_image'))}</button><button class="wood-btn small muted" data-w="image" data-a="0">${esc(t('ui_reject_image'))}</button>`}
      </div></div>`);
    row.querySelectorAll('button').forEach(b => b.onclick = () => post('admin', { op: 'decide', recipe: r.id, what: b.dataset.w, approve: b.dataset.a === '1' }));
  });
}

function adminEditor(d) {
  const e = S.edit, type = d.types.find(x => x.key === e.type) || d.types[0];
  setHeader(e.id ? t('ui_edit_business', e.label) : t('ui_new_business'), type.label, () => { S.edit = null; adminDraft = null; renderAdmin(d); });
  setTabs(null);
  clear();
  if (S.draftRestored) add(`<div class="muted">${esc(t('ui_draft_restored'))}</div>`);
  const typeOpts = d.types.map(x => `<option value="${x.key}" ${x.key === e.type ? 'selected' : ''}>${esc(x.label)}</option>`).join('');
  const f = add(`<div class="form">
    <label class="field">${esc(t('ui_type'))}<select data-k="type" ${e.id ? 'disabled' : ''}>${typeOpts}</select></label>
    <label class="field">${esc(t('ui_business_name'))}<input data-k="label" maxlength="40" value="${esc(e.label)}"></label>
    <label class="field">${esc(t('ui_price'))}<input data-k="price" type="number" min="0" max="${d.limits.maxPrice}" value="${e.price}"></label>
    <label class="field">${esc(t('ui_npc_model'))}<input data-k="npcModel" maxlength="60" value="${esc(e.npcModel)}"></label>
    ${type.hotel ? `<label class="field">${esc(t('ui_rooms', type.hotel.maxRooms))}<input data-k="rooms" type="number" min="1" max="${type.hotel.maxRooms}" value="${e.rooms || 1}"></label>` : ''}
  </div>`);
  f.querySelectorAll('[data-k]').forEach(i => i.oninput = i.onchange = () => {
    const k = i.dataset.k;
    e[k] = (k === 'price' || k === 'rooms') ? Number(i.value) : i.value;
    if (k === 'type') { const ty = d.types.find(x => x.key === e.type); e.npcModel = ty.npcModel; e.price = ty.price; e.rooms = ty.hotel ? 5 : 0; renderAdmin(d); }
  });

  add(`<div class="section-title">${esc(t('ui_points'))}</div>`);
  add(`<div class="muted">${esc(t('ui_points_hint'))}</div>`);
  POINTS(type).forEach(([key, label]) => pointRow(label, e.points[key], (p) => { e.points[key] = p; renderAdmin(d); }, MARKER_POINTS.has(key) ? 'marker' : 'ped'));
  const sr = add(`<div class="point row ${e.points.sign ? '' : 'missing'}"><div class="row-text"><div class="row-title">${esc(t('ui_pt_sign'))}</div><div class="coords">${esc(fmt(e.points.sign))}</div></div>
    <button class="wood-btn small">${esc(t('ui_place_sign'))}</button></div>`);
  sr.querySelector('button').onclick = async () => { const p = await post('adminPlaceSign', { current: e.points.sign || null }); if (p) { e.points.sign = p; renderAdmin(d); } };

  if (type.crafting) listPoints(d, 'craft', t('ui_pt_craft'), d.limits.maxCraft, 1, d.craftProps || []);
  listPoints(d, 'stash', t('ui_pt_stash'), d.limits.maxStash, 0, null);

  const b = add(`<div class="btn-row"><button class="wood-btn">${esc(t('ui_save'))}</button><button class="wood-btn muted">${esc(t('ui_cancel'))}</button></div>`);
  const [save, cancel] = b.querySelectorAll('button');
  cancel.onclick = () => { S.edit = null; adminDraft = null; renderAdmin(d); };
  save.onclick = () => { post('admin', { op: 'save', id: e.id, data: e }); };
}

// Every point is placed with rsg-gizmo (you can walk while placing):
//   'ped'    = a ghost of the business NPC (NPC, hotel door/room, stable preview: where someone stands)
//   'marker' = a small marker aimed at the object itself (manager desk, crafting stations, stashes)
const MARKER_POINTS = new Set(['manager']);
const placePoint = (label, current, kind) => post('adminPlacePoint', {
  label, kind, current: current || null, model: S.edit && S.edit.npcModel, type: S.edit && S.edit.type,
});
// crafting station with its own stove / table (Config.CraftProps)
const placeProp = (model, current) => post('adminPlaceProp', { model, current: current || null });
const propLabel = (props, p) => {
  const f = p && p.prop && props && props.find(x => x.model === p.prop.model);
  return f ? f.label : (p && p.prop ? p.prop.model : '');
};
const propSelect = (props, selected) => el(`<select class="prop-select">${props.map(x =>
  `<option value="${esc(x.model)}" ${x.model === selected ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}</select>`);

function pointRow(label, p, onSet, kind, props) {
  const extra = p && p.prop ? ' · ' + t('ui_prop', propLabel(props, p)) : '';
  const r = add(`<div class="point row ${p ? '' : 'missing'}"><div class="row-text"><div class="row-title">${esc(label)}</div><div class="coords">${esc(fmt(p) + extra)}</div></div>
    <button class="wood-btn small">${esc(t('ui_place'))}</button></div>`);
  r.querySelector('button').onclick = async () => { const c = await placePoint(label, p, kind); if (c) onSet(c); };
  return r;
}

function listPoints(d, key, label, max, min, props) {
  const e = S.edit;
  const withProps = !!(props && props.length);
  e.points[key] = e.points[key] || [];
  add(`<div class="section-title">${esc(label)} (${e.points[key].length}/${max}${min ? ', ' + t('ui_min', min) : ''})</div>`);
  if (withProps) add(`<div class="muted">${esc(t('ui_craft_prop_hint'))}</div>`);
  e.points[key].forEach((p, i) => {
    const set = (np) => { e.points[key][i] = np; renderAdmin(d); };
    const r = pointRow(`${label} ${i + 1}`, p, set, 'marker', props);
    if (withProps) {
      const sel = propSelect(props, p.prop && p.prop.model);
      const pb = el(`<button class="wood-btn small">${esc(t('ui_place_prop'))}</button>`);
      pb.onclick = async () => { const c = await placeProp(sel.value, p); if (c) set(c); };
      r.appendChild(sel); r.appendChild(pb);
      if (p.prop) {
        const rb = el(`<button class="wood-btn small muted">${esc(t('ui_remove_prop'))}</button>`);
        rb.onclick = () => set({ x: p.x, y: p.y, z: p.z, w: p.w });
        r.appendChild(rb);
      }
    }
    const x = el(`<button class="wood-btn small muted">✕</button>`);
    x.onclick = () => { e.points[key].splice(i, 1); renderAdmin(d); };
    r.appendChild(x);
  });
  if (e.points[key].length < max) {
    const a = add(`<div class="btn-row"><button class="wood-btn small">${esc(t('ui_add_here', label))}</button></div>`);
    a.querySelector('button').onclick = async () => { const c = await placePoint(label, null, 'marker'); if (c) { e.points[key].push(c); renderAdmin(d); } };
    if (withProps) {
      const sel = propSelect(props, null);
      const pb = el(`<button class="wood-btn small">${esc(t('ui_add_with_prop', label))}</button>`);
      pb.onclick = async () => { const c = await placeProp(sel.value, null); if (c) { e.points[key].push(c); renderAdmin(d); } };
      a.appendChild(sel); a.appendChild(pb);
    }
  }
}

/* ------------------------------------------------------------------ routing */
const RENDER = { sign: renderSign, manager: renderManager, craft: renderCraft, training: renderTraining, trainer: renderTrainer, gov: renderGov, admin: renderAdmin, audit: renderAudit };

function render() { const fn = RENDER[S.view]; if (fn && S.data) fn(S.data); }

// Unsaved /pob editor work survives closing the menu: /pob reopens straight into it.
// Only Save, Cancel or the back arrow drop it.
let adminDraft = null;

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') {
    if (data.locale) L = data.locale;
    const same = S.view === data.view;
    if (!same && S.view === 'admin' && S.edit) adminDraft = S.edit; // e.g. jumping to the government account
    S.view = data.view; S.data = data.data;
    if (!same) {
      S.tab = null; S.edit = null; S.recipe = null; S.ledgerPage = 0; S.draftRestored = false;
      if (S.view === 'admin' && adminDraft) { S.edit = adminDraft; S.draftRestored = true; }
    }
    closeModal();
    app.classList.remove('hidden');
    render();
  } else if (data.action === 'update' && data.view === S.view) {
    S.data = data.data;
    if (S.data && S.data.closeEditor) { S.edit = null; adminDraft = null; S.draftRestored = false; }
    render();
  } else if (data.action === 'close') {
    app.classList.add('hidden'); closeModal();
    if (S.view === 'admin' && S.edit) adminDraft = S.edit;
    S.view = null; S.data = null; S.edit = null; S.recipe = null;
  } else if (data.action === 'hide') {
    app.classList.add('hidden');
  } else if (data.action === 'show') {
    app.classList.remove('hidden');
  }
});

$('close').addEventListener('click', () => post('close'));
document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  if (!$('modal-wrap').classList.contains('hidden')) return closeModal();
  if (S.recipe) { S.recipe = null; return render(); }
  post('close'); // closing the editor with Esc keeps it as a draft (see adminDraft)
});
