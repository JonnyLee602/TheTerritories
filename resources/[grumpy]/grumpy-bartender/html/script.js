const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-bartender';
const $ = (id) => document.getElementById(id);
let S = {};          // locale strings
let editor = null;   // editor payload
let deleteArmed = false;

const post = (name, body = {}) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
        .catch(() => {});

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function applyStrings() {
    document.querySelectorAll('[data-t]').forEach((el) => { el.textContent = S[el.dataset.t] || el.dataset.t; });
    document.querySelectorAll('[data-ph]').forEach((el) => { el.placeholder = S[el.dataset.ph] || ''; });
    $('editor-back').title = S.ui_back || '';
}

/* ---------------- Editor ---------------- */
function renderEditor() {
    const e = editor, f = e.form;
    $('editor-title').textContent = e.isNew ? S.ui_editor_new : S.ui_editor_edit;
    $('f-label').value = f.label || '';
    $('f-model').innerHTML = e.models.map((m) => `<option value="${esc(m)}">${esc(m)}</option>`).join('');
    $('f-model').value = f.model;
    $('f-animation').innerHTML = e.animations.map((a) => `<option value="${esc(a)}">${esc(a)}</option>`).join('');
    $('f-animation').value = f.animation;
    $('f-store').value = f.store || '';
    $('f-hotel').innerHTML = `<option value="">${esc(S.ui_none)}</option>` +
        e.hotels.map((h) => `<option value="${esc(h.key)}">${esc(h.label)}</option>`).join('');
    $('f-hotel').value = f.hotel || '';
    $('f-lottery').checked = !!f.lottery;
    $('f-loyalty').checked = !!f.loyalty;
    $('f-blip').checked = !!f.blip;
    $('btn-place').classList.toggle('hidden', !e.isNew);
    ['btn-save', 'btn-move', 'btn-delete'].forEach((id) => $(id).classList.toggle('hidden', e.isNew));
    $('editor-back').classList.toggle('show', !!e.fromManager);
    $('f-createshop').checked = false;
    renderShopControls();
    deleteArmed = false;
    $('btn-delete').textContent = S.ui_delete;
}

// Bar shop controls: checkbox on a new bartender, button on an existing one without a store
function renderShopControls() {
    const e = editor;
    if (!e) return;
    const hasStore = $('f-store').value.trim() !== '';
    $('createshop-wrap').classList.toggle('hidden', !(e.barShop && e.isNew));
    $('btn-create-shop').classList.toggle('hidden', !(e.barShop && !e.isNew && !hasStore));
    const auto = !!e.autoStore && hasStore;
    $('store-auto').classList.toggle('hidden', !auto);
    $('store-hint').classList.toggle('hidden', auto);
    $('f-store').disabled = e.isNew && $('f-createshop').checked;
}

$('f-store').oninput = renderShopControls;
$('f-createshop').onchange = () => { if ($('f-createshop').checked) $('f-store').value = ''; renderShopControls(); };
$('btn-create-shop').onclick = () => post('editorCreateShop');

function readForm() {
    return {
        label: $('f-label').value.trim(),
        model: $('f-model').value,
        animation: $('f-animation').value,
        store: $('f-store').value,
        hotel: $('f-hotel').value,
        lottery: $('f-lottery').checked,
        loyalty: $('f-loyalty').checked,
        blip: $('f-blip').checked,
        createShop: !!(editor && editor.isNew && $('f-createshop').checked),
    };
}

$('btn-place').onclick = () => post('editorPlace', { form: readForm() });
$('btn-save').onclick = () => post('editorSave', { form: readForm() });
$('btn-move').onclick = () => post('editorMove');
$('editor-back').onclick = () => post('editorBack');
$('btn-delete').onclick = () => {
    if (!deleteArmed) { deleteArmed = true; $('btn-delete').textContent = S.ui_confirm_delete; return; }
    post('editorDelete');
};

/* ---------------- Manager ---------------- */
let manager = null;
let openEntry = null;      // expanded row key
let armed = null;          // action key waiting for a confirm click

function svcTags(s) {
    const tags = [];
    if (s.store) tags.push(`${S.ui_svc_store} #${s.store}`);
    if (s.hotel) tags.push(`${S.ui_svc_hotel} #${s.hotel}`);
    if (s.lottery) tags.push(S.ui_svc_lottery);
    if (s.loyalty) tags.push(S.ui_svc_loyalty);
    if (s.blip) tags.push(S.ui_blip);
    return tags.length ? tags : [S.ui_services_none];
}

function actionBtn(label, onClick, muted = false) {
    const b = document.createElement('button');
    b.className = `wood-btn small${muted ? ' muted' : ''}`;
    b.textContent = label;
    b.onclick = (ev) => { ev.stopPropagation(); onClick(b); };
    return b;
}

// Two-click confirm for destructive actions
function confirmBtn(key, label, confirmLabel, onConfirm) {
    return actionBtn(armed === key ? confirmLabel : label, () => {
        if (armed !== key) { armed = key; renderManager(); return; }
        armed = null;
        onConfirm();
    }, true);
}

function entry(key, headHtml, actions) {
    const el = document.createElement('div');
    el.className = `entry${openEntry === key ? ' open' : ''}`;
    el.innerHTML = `<div class="entry-head">${headHtml}</div>`;
    const bar = document.createElement('div');
    bar.className = 'entry-actions';
    actions.forEach((a) => bar.appendChild(a));
    el.appendChild(bar);
    el.onclick = () => { openEntry = openEntry === key ? null : key; armed = null; renderManager(); };
    return el;
}

function renderManager() {
    if (!manager) return;
    const q = $('m-search').value.trim().toLowerCase();
    const list = $('m-list');
    list.innerHTML = '';
    const rows = manager.bartenders.filter((b) =>
        !q || `${b.label} ${b.id} ${b.model} ${b.services.hotel || ''}`.toLowerCase().includes(q));
    if (rows.length === 0) list.innerHTML = `<div class="empty">${esc(S.ui_no_bartenders)}</div>`;
    rows.forEach((b) => {
        const head = `<div class="badge-icon">&#9783;</div>
            <div class="row-text">
                <div class="row-title">${esc(b.label)}</div>
                <div class="entry-meta">${esc(b.id)} · ${esc(b.model)} · ${esc(b.animation)}</div>
                <div class="tags">${svcTags(b.services).map((t) => `<span class="pill">${esc(t)}</span>`).join('')}</div>
            </div>
            ${b.static ? `<span class="pill">${esc(S.ui_static)}</span>` : ''}`;
        const actions = [];
        if (!b.static) actions.push(actionBtn(S.ui_edit, () => post('managerEdit', { id: b.id })));
        actions.push(actionBtn(S.ui_teleport, () => post('managerTeleport', { id: b.id })));
        actions.push(actionBtn(S.ui_duplicate, () => post('managerDuplicate', { id: b.id })));
        if (!b.static) actions.push(confirmBtn(`del:${b.id}`, S.ui_delete, S.ui_confirm_delete, () => post('managerDelete', { id: b.id })));
        list.appendChild(entry(`b:${b.id}`, head, actions));
    });
}

$('m-search').oninput = () => { openEntry = null; renderManager(); };
$('m-new').onclick = () => post('managerNew');

/* ---------------- Open / close ---------------- */
function show(view) {
    $('app').classList.remove('hidden');
    $('editor').classList.toggle('hidden', view !== 'editor');
    $('manager').classList.toggle('hidden', view !== 'manager');
}

function hideAll() {
    $('app').classList.add('hidden');
    editor = null; manager = null; openEntry = null; armed = null;
}

window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    if (m.action === 'open') {
        S = m.strings || S;
        applyStrings();
        if (m.view === 'editor') { editor = m.data; renderEditor(); }
        if (m.view === 'manager') { manager = m.data; armed = null; renderManager(); }
        show(m.view);
    } else if (m.action === 'update') {
        if (m.view === 'manager' && manager) { manager = m.data; armed = null; renderManager(); }
        if (m.view === 'editor' && editor && m.data) {
            $('f-store').value = m.data.store ?? '';
            editor.autoStore = !!m.data.autoStore;
            renderShopControls();
        }
    } else if (m.action === 'close') {
        hideAll();
    }
});

document.querySelectorAll('[data-close]').forEach((b) => { b.onclick = () => post('close'); });
document.addEventListener('keyup', (e) => { if (e.key === 'Escape') post('close'); });
