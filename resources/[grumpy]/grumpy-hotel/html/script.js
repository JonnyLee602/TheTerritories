const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-hotel';
const $ = (id) => document.getElementById(id);
let S = {};            // locale strings
let view = null;       // open main view
let door = null, rental = null, room = null, admin = null;
let knockOpen = false;
let selectedRoom = null;
let armed = null;      // key of a destructive button waiting for its confirm click
let timers = [];

const post = (name, body = {}) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
        .then((r) => r.json()).catch(() => null);

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const t = (k) => S[k] || k;
const fmt = (k, ...a) => { let i = 0; return t(k).replace(/%s/g, () => a[i++] ?? ''); };
const money = (n) => `$${Number(n || 0).toFixed(2).replace(/\.00$/, '')}`;

function applyStrings() {
    document.querySelectorAll('[data-t]').forEach((el) => { el.textContent = t(el.dataset.t); });
}

function fmtTime(sec) {
    sec = Math.max(0, Math.floor(sec));
    const d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
    if (d > 0) return `${d}d ${h}h`;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
}

function fillSelect(sel, count) {
    const keep = Number(sel.value);
    sel.innerHTML = '';
    for (let i = 1; i <= count; i++) sel.insertAdjacentHTML('beforeend', `<option value="${i}">${i}</option>`);
    if (keep && keep <= count) sel.value = keep;
}

function btn(label, onClick, cls = '') {
    const b = document.createElement('button');
    b.className = `wood-btn small ${cls}`;
    b.textContent = label;
    b.onclick = (ev) => { ev.stopPropagation(); onClick(b); };
    return b;
}

// Two-click confirm for destructive actions; rerender() redraws the current view
function confirmBtn(key, label, confirmLabel, onConfirm, rerender) {
    return btn(armed === key ? confirmLabel : label, () => {
        if (armed !== key) { armed = key; rerender(); return; }
        armed = null;
        onConfirm();
    }, 'muted');
}

function clearTimers() { timers.forEach(clearInterval); timers = []; }

/* ---------------- Door ---------------- */
const statusPill = (e) => {
    if (e.status === 'available') return `<span class="pill available">${esc(t('ui_available'))}</span>`;
    if (e.status === 'mine') return `<span class="pill mine">${esc(t('ui_your_room'))}</span>`;
    if (e.status === 'locked') return `<span class="pill locked">${esc(t('ui_locked'))}</span>`;
    if (e.status === 'key') return `<span class="pill key">${esc(e.name)}</span>`;
    return `<span class="pill taken">${esc(e.name)}</span>`;
};

function renderDoor() {
    $('door-title').textContent = door.label;
    const list = $('door-list');
    list.innerHTML = '';
    door.rooms.forEach((e) => {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `<div class="badge-icon">${e.room}</div>
            <div class="row-text"><div class="row-title">${esc(fmt('ui_room', e.room))}</div><div class="row-desc">${statusPill(e)}</div></div>`;
        const actions = document.createElement('div');
        actions.className = 'row-actions';
        if (e.canEnter) {
            const label = e.warrant ? t('ui_enter_warrant') : e.status === 'mine' ? t('ui_enter_yours') : t('ui_enter');
            actions.appendChild(btn(label, () => post('doorEnter', { room: e.room })));
        }
        if (e.canKnock) actions.appendChild(btn(t('ui_knock'), () => post('doorKnock', { room: e.room })));
        if (e.canWarrant && !e.warrant) actions.appendChild(btn(t('ui_issue_warrant'), () => post('doorWarrant', { room: e.room }), 'muted'));
        row.appendChild(actions);
        list.appendChild(row);
    });
}

/* ---------------- Rental ---------------- */
function renderRental() {
    const r = rental;
    clearTimers();
    $('rental-title').textContent = r.label;
    $('rental-sub').textContent = fmt('ui_free_rooms', r.free, r.total);
    $('rental-price').textContent = `${money(r.price)} ${t('ui_per_day')} · ${fmt('ui_max_days', r.maxDays)} · ${t('ui_cash')}`;

    // My rental
    const m = r.mine;
    $('mine').classList.toggle('hidden', !m);
    if (m) {
        $('mine-room').textContent = fmt('ui_room', m.room);
        const grace = m.state === 'grace';
        let left = grace ? m.graceIn : m.expiresIn;
        const paint = () => {
            $('mine-time').innerHTML = grace
                ? `<span class="pill grace">${esc(t('ui_expired'))}</span> ${esc(t('ui_grace_in'))} ${esc(fmtTime(left))}`
                : `${esc(t('ui_expires_in'))} ${esc(fmtTime(left))}`;
        };
        paint();
        timers.push(setInterval(() => { left -= 60; paint(); }, 60000));
        $('mine-key').textContent = `${t('ui_key_holder')}: ${m.keyName || t('ui_no_key')}`;
        $('btn-revoke').classList.toggle('hidden', !m.keyName);
        $('btn-revoke').textContent = armed === 'revoke' ? t('ui_confirm_revoke') : t('ui_revoke');
        $('btn-checkout').textContent = armed === 'checkout' ? t('ui_confirm_checkout') : t('ui_checkout');
        $('btn-extend').textContent = grace ? t('ui_renew') : t('ui_extend');
        const can = m.canExtend > 0;
        $('extend-wrap').classList.toggle('hidden', !can);
        $('btn-extend').classList.toggle('hidden', !can);
        $('extend-max').classList.toggle('hidden', can);
        if (can) { fillSelect($('extend-days'), m.canExtend); updateTotals(); }
    }

    // Rooms
    const canRent = !m;
    if (selectedRoom && !r.rooms.some((e) => e.room === selectedRoom && e.status === 'available')) selectedRoom = null;
    const list = $('rental-list');
    list.innerHTML = '';
    r.rooms.forEach((e) => {
        const selectable = canRent && e.status === 'available';
        const row = document.createElement('div');
        row.className = `row${selectable ? ' clickable' : ' disabled'}${selectedRoom === e.room ? ' selected' : ''}`;
        row.innerHTML = `<div class="badge-icon">${e.room}</div>
            <div class="row-text"><div class="row-title">${esc(fmt('ui_room', e.room))}</div></div>${statusPill(e)}`;
        if (selectable) row.onclick = () => { selectedRoom = e.room; renderRental(); };
        list.appendChild(row);
    });
    $('rental-note').classList.toggle('hidden', canRent && r.free > 0);
    $('rental-note').textContent = canRent ? '' : t('ui_already_renting');
    if (canRent && r.free > 0 && !selectedRoom) { $('rental-note').classList.remove('hidden'); $('rental-note').textContent = t('ui_select_room'); }

    $('rent-wrap').classList.toggle('hidden', !(canRent && selectedRoom));
    if (canRent && selectedRoom) { fillSelect($('rent-days'), r.maxDays); updateTotals(); }
}

function updateTotals() {
    if (!rental) return;
    $('rent-total').textContent = `${t('ui_total')}: ${money(rental.price * Number($('rent-days').value || 1))}`;
    $('extend-total').textContent = `${t('ui_total')}: ${money(rental.price * Number($('extend-days').value || 1))}`;
}
$('rent-days').onchange = updateTotals;
$('extend-days').onchange = updateTotals;
$('btn-rent').onclick = () => { if (selectedRoom) post('rentalRent', { room: selectedRoom, days: Number($('rent-days').value) }); };
$('btn-extend').onclick = () => post('rentalExtend', { days: Number($('extend-days').value) });
$('btn-checkout').onclick = () => {
    if (armed !== 'checkout') { armed = 'checkout'; renderRental(); return; }
    armed = null; post('rentalCheckout');
};
$('btn-revoke').onclick = () => {
    if (armed !== 'revoke') { armed = 'revoke'; renderRental(); return; }
    armed = null; post('rentalRevokeKey');
};

/* ---------------- Room ---------------- */
function renderRoom() {
    const r = room;
    clearTimers();
    $('room-title').textContent = fmt('ui_room', r.room);
    $('room-sub').textContent = r.label;
    $('room-renter').textContent = `${t('ui_rented_by')}: ${r.renter || '-'}`;
    let left = r.expiresIn;
    const paint = () => { $('room-time').textContent = `${t('ui_expires_in')} ${fmtTime(left)}`; };
    paint();
    timers.push(setInterval(() => { left -= 60; paint(); }, 60000));
    $('room-role').textContent = t(`ui_role_${r.role}`);

    const isRenter = r.role === 'renter';
    $('room-key-wrap').classList.toggle('hidden', !isRenter);
    $('room-key').textContent = r.keyName || t('ui_no_key');
    $('btn-room-revoke').classList.toggle('hidden', !(isRenter && r.hasKeyHolder));
    $('btn-room-revoke').textContent = armed === 'roomRevoke' ? t('ui_confirm_revoke') : t('ui_revoke');

    const list = $('room-occupants');
    list.innerHTML = '';
    if (r.occupants.length === 0) list.innerHTML = `<div class="empty">${esc(t('ui_nobody'))}</div>`;
    const host = r.role === 'renter' || r.role === 'key';
    r.occupants.forEach((o) => {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `<div class="badge-icon">&#9823;</div>
            <div class="row-text"><div class="row-title">${esc(o.name)}</div><div class="row-desc">${esc(t(`ui_role_${o.role}`))}</div></div>`;
        const actions = document.createElement('div');
        actions.className = 'row-actions';
        if (isRenter && o.role === 'visitor' && !r.hasKeyHolder) actions.appendChild(btn(t('ui_give_key'), () => post('roomGiveKey', { src: o.src })));
        const canKick = host && (o.role === 'visitor' || (o.role === 'key' && isRenter));
        if (canKick) actions.appendChild(btn(t('ui_show_out'), () => post('roomKick', { src: o.src }), 'muted'));
        row.appendChild(actions);
        list.appendChild(row);
    });
    $('btn-stash').classList.toggle('hidden', !r.canStash || r.stashPoint);
}
$('btn-stash').onclick = () => post('roomStash');
$('btn-leave').onclick = () => post('roomLeave');
$('btn-room-revoke').onclick = () => {
    if (armed !== 'roomRevoke') { armed = 'roomRevoke'; renderRoom(); return; }
    armed = null; post('roomRevokeKey');
};

/* ---------------- Knock ---------------- */
let knockTimer = null;
function showKnock(d) {
    knockOpen = true;
    $('knock-name').textContent = d.name;
    $('knock').classList.remove('hidden');
    $('app').classList.remove('hidden');
    const total = d.timeout * 1000, start = Date.now();
    clearInterval(knockTimer);
    knockTimer = setInterval(() => {
        const pct = Math.max(0, 100 - ((Date.now() - start) / total) * 100);
        $('knock-bar').style.width = `${pct}%`;
        if (pct <= 0) clearInterval(knockTimer);
    }, 100);
}
function hideKnock() {
    knockOpen = false;
    clearInterval(knockTimer);
    $('knock').classList.add('hidden');
    if (!view) $('app').classList.add('hidden');
}
$('btn-let-in').onclick = () => post('knockAnswer', { allow: true });
$('btn-ignore').onclick = () => post('knockAnswer', { allow: false });

/* ---------------- Admin ---------------- */
let adminView = 'list';    // list | renters | editor
let adminHotel = null;     // hotel id for renters / editor (null = new)
let openEntry = null;
let draft = null;          // editor form

const pt = (p) => (p ? `${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}  (${Math.round(p.w || 0)}°)` : t('ui_not_set'));

function renderAdmin() {
    if (!admin) return;
    const hotel = admin.hotels.find((h) => h.id === adminHotel);
    if (adminView !== 'list' && adminView !== 'editor' && !hotel) adminView = 'list';
    $('admin-list-view').classList.toggle('hidden', adminView !== 'list');
    $('admin-renters-view').classList.toggle('hidden', adminView !== 'renters');
    $('admin-editor-view').classList.toggle('hidden', adminView !== 'editor');
    $('admin-back').classList.toggle('show', adminView !== 'list');

    if (adminView === 'list') {
        $('admin-title').textContent = t('ui_admin_title');
        const list = $('admin-list');
        list.innerHTML = '';
        if (admin.hotels.length === 0) list.innerHTML = `<div class="empty">${esc(t('ui_no_hotels'))}</div>`;
        admin.hotels.forEach((h) => {
            const el = document.createElement('div');
            el.className = `entry${openEntry === h.id ? ' open' : ''}`;
            el.innerHTML = `<div class="entry-head"><div class="badge-icon">${h.id}</div>
                <div class="row-text"><div class="row-title">${esc(h.label)}</div>
                <div class="entry-meta">${esc(fmt('ui_free_rooms', h.free, h.rooms))} · ${money(h.price)} ${esc(t('ui_per_day'))} · ${esc(fmt('ui_max_days', h.maxDays))}</div></div></div>`;
            const bar = document.createElement('div');
            bar.className = 'entry-actions';
            bar.appendChild(btn(t('ui_edit'), () => openEditor(h)));
            bar.appendChild(btn(`${t('ui_renters')} (${h.rentals.length})`, () => { adminHotel = h.id; adminView = 'renters'; armed = null; renderAdmin(); }));
            bar.appendChild(btn(t('ui_tp_door'), () => post('adminTeleport', { id: h.id, which: 'door' })));
            bar.appendChild(btn(t('ui_tp_interior'), () => post('adminTeleport', { id: h.id, which: 'interior' })));
            bar.appendChild(confirmBtn(`del:${h.id}`, t('ui_delete'), t('ui_confirm_delete'), () => post('adminDelete', { id: h.id }), renderAdmin));
            el.appendChild(bar);
            el.onclick = () => { openEntry = openEntry === h.id ? null : h.id; armed = null; renderAdmin(); };
            list.appendChild(el);
        });
    } else if (adminView === 'renters') {
        $('admin-title').textContent = hotel.label;
        const list = $('renters-list');
        list.innerHTML = '';
        if (hotel.rentals.length === 0) list.innerHTML = `<div class="empty">${esc(t('ui_no_renters'))}</div>`;
        hotel.rentals.forEach((r) => {
            const el = document.createElement('div');
            el.className = 'entry open';
            const state = r.state === 'grace' ? `<span class="pill grace">${esc(t('ui_state_grace'))}</span>` : `<span class="pill">${esc(fmtTime(r.expiresIn))}</span>`;
            const meta = [r.citizenid, r.online ? null : t('ui_offline'), r.keyName ? `${t('ui_key')}: ${r.keyName}` : null,
                r.occupants > 0 ? fmt('ui_inside', r.occupants) : null].filter(Boolean).join(' · ');
            el.innerHTML = `<div class="entry-head"><div class="badge-icon">${r.room}</div>
                <div class="row-text"><div class="row-title">${esc(fmt('ui_room', r.room))} · ${esc(r.name)}</div>
                <div class="entry-meta">${esc(meta)}</div></div>${state}</div>`;
            const bar = document.createElement('div');
            bar.className = 'entry-actions';
            bar.appendChild(confirmBtn(`evict:${hotel.id}:${r.room}`, t('ui_evict'), t('ui_confirm_evict'),
                () => post('adminEvict', { id: hotel.id, room: r.room }), renderAdmin));
            el.appendChild(bar);
            list.appendChild(el);
        });
    } else {
        $('admin-title').textContent = adminHotel ? t('ui_editor_edit') : t('ui_editor_new');
        $('f-door').textContent = pt(draft.door);
        $('f-interior').textContent = pt(draft.interior);
        $('f-stash').textContent = draft.stash ? pt(draft.stash) : t('ui_stash_none');
        $('btn-clear-stash').classList.toggle('hidden', !draft.stash);
    }
}

function openEditor(h) {
    adminHotel = h ? h.id : null;
    draft = h
        ? { label: h.label, rooms: h.rooms, price: h.price, maxDays: h.maxDays, blip: h.blip, door: h.door, interior: h.interior, stash: h.stash || null }
        : { label: '', rooms: 4, price: 2, maxDays: 7, blip: true, door: null, interior: null, stash: null };
    $('f-label').value = draft.label;
    $('f-rooms').value = draft.rooms;
    $('f-rooms').max = admin.limits.maxRooms;
    $('f-price').value = draft.price;
    $('f-price').max = admin.limits.maxRate;
    $('f-days').value = draft.maxDays;
    $('f-days').max = admin.limits.maxDays;
    $('f-blip').checked = !!draft.blip;
    adminView = 'editor';
    armed = null;
    renderAdmin();
}

$('btn-new-hotel').onclick = () => openEditor(null);
$('admin-back').onclick = () => { adminView = 'list'; armed = null; renderAdmin(); };
$('btn-cap-door').onclick = async () => { const p = await post('adminPlace', { which: 'door', current: draft.door }); if (p) { draft.door = p; renderAdmin(); } };
$('btn-cap-interior').onclick = async () => { const p = await post('adminPlace', { which: 'interior', current: draft.interior }); if (p) { draft.interior = p; renderAdmin(); } };
$('btn-cap-stash').onclick = async () => {
    // start the ghost at the current stash, else at the interior point so it spawns inside the room
    const p = await post('adminPlace', { which: 'stash', current: draft.stash || draft.interior });
    if (p) { draft.stash = p; renderAdmin(); }
};
$('btn-clear-stash').onclick = () => { draft.stash = null; renderAdmin(); };
$('btn-save').onclick = () => {
    post('adminSave', {
        id: adminHotel,
        form: {
            label: $('f-label').value.trim(), rooms: Number($('f-rooms').value), price: Number($('f-price').value),
            maxDays: Number($('f-days').value), blip: $('f-blip').checked, door: draft.door, interior: draft.interior,
            stash: draft.stash,
        },
    });
};

/* ---------------- Open / close ---------------- */
const VIEWS = ['door', 'rental', 'room', 'admin'];
function show(v) {
    view = v;
    $('app').classList.remove('hidden');
    VIEWS.forEach((id) => $(id).classList.toggle('hidden', id !== v));
}

function hideAll() {
    clearTimers();
    view = null; door = null; rental = null; room = null; admin = null; selectedRoom = null; armed = null; openEntry = null;
    VIEWS.forEach((id) => $(id).classList.add('hidden'));
    if (!knockOpen) $('app').classList.add('hidden');
}

function render(v) {
    if (v === 'door') renderDoor();
    if (v === 'rental') renderRental();
    if (v === 'room') renderRoom();
    if (v === 'admin') renderAdmin();
}

function setData(v, d) {
    if (v === 'door') door = d;
    if (v === 'rental') rental = d;
    if (v === 'room') room = d;
    if (v === 'admin') {
        // after saving a new hotel, go back to the list; keep editing an existing one
        if (admin && adminView === 'editor' && adminHotel === null && d.hotels.length > admin.hotels.length) adminView = 'list';
        admin = d;
    }
}

window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    if (m.strings) { S = m.strings; applyStrings(); }
    if (m.action === 'open') {
        armed = null; selectedRoom = null;
        if (m.view === 'admin') { adminView = 'list'; openEntry = null; }
        setData(m.view, m.data);
        show(m.view);
        render(m.view);
    } else if (m.action === 'update') {
        if (m.view !== view) return;
        armed = null;
        setData(m.view, m.data);
        render(m.view);
    } else if (m.action === 'close') {
        hideAll();
    } else if (m.action === 'knock') {
        showKnock(m.data);
    } else if (m.action === 'knockClose') {
        hideKnock();
    } else if (m.action === 'hide') {          // rsg-gizmo placing: keep every form value, just get out of the way
        $('app').classList.add('hidden');
    } else if (m.action === 'show') {
        if (view) $('app').classList.remove('hidden');
    }
});

document.querySelectorAll('[data-close]').forEach((b) => { b.onclick = () => post('close'); });
document.addEventListener('keyup', (e) => {
    if (e.key !== 'Escape') return;
    if (view) post('close');
    else if (knockOpen) post('knockAnswer', { allow: false });
});
