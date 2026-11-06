const $ = (id) => document.getElementById(id);
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'grumpy-backroom';
const panel = $('reup');
let endsAt = 0;
let timer = null;
let options = [];
let idx = null;
let busy = false;
let payLabel = 'Pay';

function post(name, body) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {}),
    }).catch(() => {});
}

function esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function tick() {
    const left = Math.max(0, Math.round((endsAt - Date.now()) / 1000));
    $('r-left').textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
    $('r-left').parentElement.classList.toggle('urgent', left <= 60);
}

function render() {
    document.querySelectorAll('#r-options .opt').forEach((el, i) => el.classList.toggle('sel', i + 1 === idx));
    const o = idx && options[idx - 1];
    const pay = $('r-pay');
    pay.disabled = !o || busy;
    pay.textContent = o ? `${payLabel} $${o.price}` : payLabel;
}

function show(d) {
    if (d.position) {
        panel.style.top = d.position.top || '';
        panel.style.right = d.position.right || '';
    }
    $('r-title').textContent = d.title || '';
    $('r-name').textContent = d.name || '';
    $('r-closes').textContent = d.text.closes;
    $('r-hint').textContent = d.text.hint;
    $('r-later').textContent = d.text.later;
    payLabel = d.text.pay;
    options = d.options || [];
    $('r-options').innerHTML = options
        .map((o, i) => `<div class="opt${o.fits ? '' : ' off'}" data-i="${i + 1}">${esc(o.label)}</div>`).join('');
    idx = d.idx || null;
    busy = false;
    render();
    endsAt = Date.now() + (d.left || 0) * 1000;
    tick();
    clearInterval(timer);
    timer = setInterval(tick, 250);
    panel.classList.remove('hidden');
}

function close() {
    post('reupClose');
}

$('r-options').addEventListener('click', (e) => {
    const el = e.target.closest('.opt');
    if (!el || el.classList.contains('off') || busy) return;
    idx = Number(el.dataset.i);
    render();
});

$('r-options').addEventListener('dblclick', (e) => {
    const el = e.target.closest('.opt');
    if (el && !el.classList.contains('off')) $('r-pay').click();
});

$('r-pay').addEventListener('click', () => {
    if (!idx || busy) return;
    busy = true;
    render();
    post('reupPay', { idx });
});

$('r-later').addEventListener('click', close);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !panel.classList.contains('hidden')) close();
});

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'show') show(d);
    else if (d.action === 'ready') { busy = false; render(); }
    else if (d.action === 'hide') {
        panel.classList.add('hidden');
        clearInterval(timer);
    }
});
