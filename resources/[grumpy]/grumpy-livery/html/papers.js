// grumpy-livery: horse papers card (Check Papers). No NUI focus; hides itself after `seconds`.
(function () {
  const root = document.getElementById('papersCard');
  if (!root) return;
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  let timer = null;

  function row(label, value) {
    return value ? `<div class="pc-row"><span class="pc-label">${esc(label)}</span><span class="pc-value">${esc(value)}</span></div>` : '';
  }

  function show(card, seconds, s) {
    s = s || {};
    const head = card.hasPapers ? s.title : s.none;
    root.innerHTML = `
      <div class="pc-head">${esc(head)}</div>
      <div class="pc-name">${esc(card.name)}</div>
      <div class="pc-divider"><span>&#10022;</span></div>
      ${row(s.breed, card.breed)}
      ${row(s.sex, card.sex)}
      ${row(s.age, card.stage)}
      ${card.hasPapers ? row(s.owner, card.owner) + row(s.registered, card.registered) : `<div class="pc-none">${esc(s.noneText)}</div>`}
      <div class="pc-foot">${esc(s.shownBy)} ${esc(card.shownBy)}</div>`;
    root.classList.toggle('pc-unpapered', !card.hasPapers);
    root.classList.remove('hidden');
    clearTimeout(timer);
    timer = setTimeout(() => root.classList.add('hidden'), Math.max(3, Number(seconds) || 15) * 1000);
  }

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'papersCard' && d.card) show(d.card, d.seconds, d.strings);
  });
})();
