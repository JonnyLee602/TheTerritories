const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-groups';
const $ = id => document.getElementById(id);
const app = $('app'), view = $('view');

let L = {};             // locale strings from Lua
let mode = null;        // 'gang' | 'posse'
let gangData = null;    // gang menu data
let posseData = null;   // posse snapshot
let stack = [];         // sub-view history for the back button
let timerHandle = null;
let posseDeadline = 0;

const post = (name, body = {}) => fetch(`https://${resource}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
});
const postJson = (name, body) => post(name, body).then(r => r.json()).catch(() => null);
const t = (key, ...args) => { let s = L[key] || key; args.forEach(a => { s = s.replace('%s', a); }); return s; };
const money = n => '$' + Math.floor(Number(n) || 0).toLocaleString('en-US');

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

function button(label, onClick, cls = '') {
  const b = el('button', 'wood-btn ' + cls, label);
  b.addEventListener('click', onClick);
  return b;
}

function row({ icon = '✦', title, desc, pill, onClick, right, dot }) {
  const r = el('div', 'row' + (onClick ? '' : ' static'));
  r.appendChild(el('span', 'badge-icon', icon));
  const text = el('div', 'row-text');
  const tt = el('div', 'row-title');
  if (dot !== undefined) tt.appendChild(el('span', 'dot' + (dot ? ' on' : '')));
  tt.appendChild(document.createTextNode(title));
  text.appendChild(tt);
  if (desc) text.appendChild(el('div', 'row-desc', desc));
  r.appendChild(text);
  if (pill) r.appendChild(el('span', 'pill', pill));
  if (right) r.appendChild(right);
  if (onClick) r.addEventListener('click', onClick);
  return r;
}

function header(title, subtitle) {
  $('title').textContent = title || '';
  $('subtitle').textContent = subtitle || '';
  $('back').style.visibility = stack.length ? 'visible' : 'hidden';
}

function show(render) { view.innerHTML = ''; render(); }

function push(render) { stack.push(current); current = render; show(render); }
let current = null;

function back() {
  if (!stack.length) return;
  current = stack.pop();
  show(current);
}

/* ------------------------------------------------------------------ */
/* dialogs                                                             */
/* ------------------------------------------------------------------ */
let dialogOk = null;
function openDialog({ title, text, input, okLabel, onOk }) {
  $('dialog-title').textContent = title;
  $('dialog-text').textContent = text || '';
  const inp = $('dialog-input');
  inp.classList.toggle('hidden', !input);
  inp.value = '';
  inp.placeholder = L.ui_amount || '';
  $('dialog-ok').textContent = okLabel || L.ui_confirm;
  $('dialog-cancel').textContent = L.ui_cancel;
  dialogOk = () => { onOk(input ? Math.floor(Number(inp.value)) : true); closeDialog(); };
  $('dialog').classList.remove('hidden');
  if (input) setTimeout(() => inp.focus(), 50);
}
function closeDialog() { $('dialog').classList.add('hidden'); dialogOk = null; }
$('dialog-ok').addEventListener('click', () => dialogOk && dialogOk());
$('dialog-cancel').addEventListener('click', closeDialog);
$('dialog-input').addEventListener('keydown', e => { if (e.key === 'Enter' && dialogOk) dialogOk(); });

/* ------------------------------------------------------------------ */
/* gang                                                                */
/* ------------------------------------------------------------------ */
function gangMain() {
  header(gangData.label, L.ui_gang_subtitle);
  if (gangData.atLocation) {
    const s = el('div', 'stat-line');
    s.appendChild(el('span', '', L.ui_balance));
    s.appendChild(el('strong', '', money(gangData.balance)));
    view.appendChild(s);
  }
  view.appendChild(row({ icon: '☰', title: L.ui_members, onClick: () => push(gangMembers) }));
  view.appendChild(row({ icon: '+', title: L.ui_recruit, onClick: () => push(gangRecruit) }));
  if (gangData.atLocation) {
    view.appendChild(row({ icon: '▣', title: L.ui_stash, onClick: () => post('gangStash') }));
    const acts = el('div', 'actions');
    acts.appendChild(button(L.ui_deposit, () => moneyDialog('deposit')));
    acts.appendChild(button(L.ui_withdraw, () => moneyDialog('withdraw')));
    view.appendChild(acts);
  }
}

function moneyDialog(kind) {
  const max = kind === 'deposit' ? gangData.cash : gangData.balance;
  openDialog({
    title: kind === 'deposit' ? L.ui_deposit : L.ui_withdraw,
    text: (kind === 'deposit' ? L.ui_your_cash : L.ui_balance) + ': ' + money(max),
    input: true,
    onOk: amount => { if (amount >= 1) post('gangMoney', { mode: kind, amount }); }
  });
}

async function gangMembers() {
  header(gangData.label, L.ui_members);
  const data = await postJson('gangMembers');
  if (current !== gangMembers) return;
  view.innerHTML = '';
  const list = el('div', 'list');
  (data && data.members || []).forEach(m => {
    list.appendChild(row({
      icon: '✦', title: m.name + (m.isSelf ? ` (${L.ui_you})` : ''), dot: m.online,
      desc: `${m.gradeName} (${m.gradeLevel})`,
      onClick: m.isSelf ? null : () => push(() => gangMember(m, data.grades))
    }));
  });
  if (!list.children.length) list.appendChild(el('div', 'empty', L.ui_no_members));
  view.appendChild(list);
}

function gangMember(m, grades) {
  header(m.name, `${m.gradeName} (${m.gradeLevel})`);
  const list = el('div', 'list');
  grades.forEach(g => {
    const isCurrent = g.level === m.gradeLevel;
    const r = row({
      icon: String(g.level), title: t('ui_set_rank', g.name),
      desc: isCurrent ? L.ui_current : '',
      onClick: (!isCurrent && g.allowed) ? () => { post('gangSetGrade', { citizenid: m.citizenid, grade: g.level }); back(); } : null
    });
    if (isCurrent || !g.allowed) r.classList.add('disabled');
    list.appendChild(r);
  });
  view.appendChild(list);
  const acts = el('div', 'actions');
  acts.appendChild(button(L.ui_remove, () => openDialog({
    title: L.ui_remove, text: t('ui_remove_confirm', m.name),
    onOk: () => { post('gangFire', { citizenid: m.citizenid }); back(); }
  }), 'danger'));
  view.appendChild(acts);
}

async function gangRecruit() {
  header(gangData.label, L.ui_recruit);
  const players = await postJson('gangNearby');
  if (current !== gangRecruit) return;
  view.innerHTML = '';
  const list = el('div', 'list');
  (players || []).forEach(p => {
    list.appendChild(row({ icon: '+', title: p.name, pill: L.ui_recruit_btn, onClick: () => post('gangRecruit', { source: p.source }) }));
  });
  if (!list.children.length) list.appendChild(el('div', 'empty', L.ui_no_nearby));
  view.appendChild(list);
}

/* ------------------------------------------------------------------ */
/* posse                                                               */
/* ------------------------------------------------------------------ */
function fmtTime(sec) {
  sec = Math.max(0, Math.floor(sec));
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
  return (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(s).padStart(2, '0');
}

function tickTimer() {
  const node = document.querySelector('.timer strong');
  if (!node) return;
  const left = (posseDeadline - Date.now()) / 1000;
  node.textContent = fmtTime(left);
  node.parentElement.classList.toggle('warn', left <= 300);
}

function posseView() {
  header(L.ui_posse_title, L.ui_posse_subtitle);
  if (!posseData || posseData.none) {
    view.appendChild(el('div', 'empty', L.ui_posse_none));
    return;
  }
  const p = posseData;
  const timer = el('div', 'stat-line timer');
  timer.appendChild(el('span', '', L.ui_time_left));
  timer.appendChild(el('strong', '', fmtTime(p.remaining)));
  view.appendChild(timer);
  const size = el('div', 'stat-line');
  size.appendChild(el('span', '', L.ui_size));
  size.appendChild(el('strong', '', `${p.members.length} / ${p.max}`));
  view.appendChild(size);

  const list = el('div', 'list');
  p.members.forEach(m => {
    let right = null;
    if (p.isLeader && !m.isSelf) {
      right = el('div', 'mini-btns');
      const lead = button(L.ui_make_leader, e => { e.stopPropagation(); post('posseSetLeader', { citizenid: m.citizenid }); });
      lead.disabled = !m.online;
      right.appendChild(lead);
      right.appendChild(button(L.ui_kick, e => { e.stopPropagation(); post('posseKick', { citizenid: m.citizenid }); }, 'danger'));
    }
    list.appendChild(row({
      icon: m.isLeader ? '★' : '✦', title: m.name + (m.isSelf ? ` (${L.ui_you})` : ''), dot: m.online,
      pill: m.isLeader ? L.ui_leader : null, right
    }));
  });
  view.appendChild(list);

  const acts = el('div', 'actions');
  acts.appendChild(button(L.ui_leave, () => openDialog({ title: L.ui_leave, text: L.ui_leave_confirm, onOk: () => post('posseLeave') })));
  if (p.isLeader) acts.appendChild(button(L.ui_disband, () => openDialog({ title: L.ui_disband, text: L.ui_disband_confirm, onOk: () => post('posseDisband') }), 'danger'));
  view.appendChild(acts);
  tickTimer();
}

function setPosse(data) {
  posseData = data;
  posseDeadline = Date.now() + ((data && data.remaining) || 0) * 1000;
}

/* ------------------------------------------------------------------ */
/* invite card                                                         */
/* ------------------------------------------------------------------ */
let inviteTimer = null;
function openInvite(d) {
  $('invite-title').textContent = d.kind === 'gang' ? t('ui_invite_gang', d.label) : L.ui_invite_posse;
  $('invite-text').textContent = d.from || '';
  $('invite-accept').textContent = L.ui_accept;
  $('invite-decline').textContent = L.ui_decline;
  let left = d.timeout || 30;
  $('invite-count').textContent = left + 's';
  clearInterval(inviteTimer);
  inviteTimer = setInterval(() => {
    left -= 1;
    $('invite-count').textContent = Math.max(0, left) + 's';
    if (left <= 0) answerInvite(false);
  }, 1000);
  $('invite').classList.remove('hidden');
}
function closeInvite() { clearInterval(inviteTimer); $('invite').classList.add('hidden'); }
function answerInvite(accept) { closeInvite(); post('inviteAnswer', { accept }); }
$('invite-accept').addEventListener('click', () => answerInvite(true));
$('invite-decline').addEventListener('click', () => answerInvite(false));

/* ------------------------------------------------------------------ */
/* messages from Lua                                                   */
/* ------------------------------------------------------------------ */
function closeAll() {
  app.classList.add('hidden');
  closeDialog();
  clearInterval(timerHandle);
  mode = null; stack = []; current = null;
}

window.addEventListener('message', ({ data }) => {
  if (data.locale) L = data.locale;
  switch (data.action) {
    case 'open':
      mode = data.view; stack = [];
      if (mode === 'gang') { gangData = data.data; current = gangMain; }
      else { setPosse(data.data); current = posseView; clearInterval(timerHandle); timerHandle = setInterval(tickTimer, 1000); }
      $('close').title = L.ui_cancel || ''; $('back').title = L.ui_back || '';
      show(current);
      app.classList.remove('hidden');
      break;
    case 'update':
      if (data.view === 'gang' && mode === 'gang') { gangData = data.data; if (current === gangMain) show(gangMain); }
      if (data.view === 'posse' && mode === 'posse') { setPosse(data.data); closeDialog(); show(posseView); }
      break;
    case 'close': closeAll(); break;
    case 'invite': openInvite(data.data || {}); break;
    case 'closeInvite': closeInvite(); break;
  }
});

$('close').addEventListener('click', () => post('close'));
$('back').addEventListener('click', back);
document.addEventListener('keydown', e => {
  if (e.key !== 'Escape') return;
  if (!$('dialog').classList.contains('hidden')) return closeDialog();
  if (!$('invite').classList.contains('hidden')) return answerInvite(false);
  if (mode) post('close');
});
