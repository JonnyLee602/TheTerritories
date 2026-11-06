const $ = (id) => document.getElementById(id);
const panel = $('reup');
let endsAt = 0;
let timer = null;

function esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function tick() {
    const left = Math.max(0, Math.round((endsAt - Date.now()) / 1000));
    $('r-left').textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
    $('r-left').parentElement.classList.toggle('urgent', left <= 60);
}

function select(idx) {
    document.querySelectorAll('#r-options .opt').forEach((el, i) => el.classList.toggle('sel', i + 1 === idx));
}

function show(d) {
    if (d.position) {
        panel.style.top = d.position.top || '';
        panel.style.right = d.position.right || '';
    }
    $('r-title').textContent = d.title || '';
    $('r-name').textContent = d.name || '';
    $('r-closes').textContent = d.text.closes;
    // the hint carries <kbd> markup from the locale; everything player-made is escaped
    $('r-hint').innerHTML = esc(d.text.hint).replace(/\[([^\]]+)\]/g, '<kbd>$1</kbd>');
    $('r-options').innerHTML = (d.options || [])
        .map((o) => `<div class="opt${o.fits ? '' : ' off'}">${esc(o.label)}</div>`).join('');
    select(d.idx);
    $('r-hold').style.width = '0%';
    endsAt = Date.now() + (d.left || 0) * 1000;
    tick();
    clearInterval(timer);
    timer = setInterval(tick, 250);
    panel.classList.remove('hidden');
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'show') show(d);
    else if (d.action === 'update') {
        select(d.idx);
        $('r-hold').style.width = `${Math.round((d.hold || 0) * 100)}%`;
    } else if (d.action === 'hide') {
        panel.classList.add('hidden');
        clearInterval(timer);
    }
});
