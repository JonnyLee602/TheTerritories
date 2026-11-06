// Table panel (phase 4): draws any game's view. Uses tr / el / post / $ from script.js. Amounts are cents.
const tb = { view: null, feed: [], focus: false, offset: 0, total: 0, amount: null, sent: false, feedLines: 8 };

const SUITS = { c: '♣', d: '♦', h: '♥', s: '♠' };
const tbMoney = (c) => '$' + (Number(c || 0) / 100).toFixed(2);

function cardEl(c, big) {
  if (!c || c.down) return el('div', { class: 'card back' + (big ? ' big' : '') });
  const red = c.s === 'h' || c.s === 'd';
  return el('div', { class: 'card' + (red ? ' red' : '') + (big ? ' big' : '') }, [
    el('span', { class: 'rank', text: c.r === 'T' ? '10' : c.r }),
    el('span', { class: 'suit', text: SUITS[c.s] || '' }),
  ]);
}
const cardsEl = (list, big) => el('div', { class: 'cards' }, (list || []).map((c) => cardEl(c, big)));

function actLabel(a, amount) {
  const name = L['ui_act_' + a.id] || (a.id.charAt(0).toUpperCase() + a.id.slice(1));
  return amount != null ? name + ' ' + tbMoney(amount) : name;
}

function renderSeats(pub, mySeat) {
  const results = {};
  for (const r of pub.results || []) results[r.seat] = (results[r.seat] || 0) + r.amount;
  return el('div', { class: 'tb-seats' }, (pub.seats || []).map((s) => {
    const pills = [];
    if (s.dealer) pills.push(el('span', { class: 'pill dealer-btn', text: 'D' }));
    if (s.folded) pills.push(el('span', { class: 'pill', text: tr('ui_folded') }));
    if (s.allin) pills.push(el('span', { class: 'pill warn', text: tr('ui_allin') }));
    if (results[s.seat]) pills.push(el('span', { class: 'pill good', text: tr('ui_won', tbMoney(results[s.seat])) }));
    const money = [];
    if (s.stack != null) money.push(tbMoney(s.stack));
    if (s.bet) money.push(tr('ui_bet_short') + ' ' + tbMoney(s.bet));
    const cls = 'tb-seat' + (pub.turn === s.seat ? ' turn' : '') + (s.seat === mySeat ? ' me' : '') + (s.folded ? ' folded' : '');
    return el('div', { class: cls }, [
      el('div', { class: 'tb-seat-top' }, [
        el('div', { class: 'tb-seat-name', text: s.seat === mySeat ? tr('ui_you') : (s.name || ('#' + s.seat)) }),
        el('div', { class: 'pills' }, pills),
      ]),
      el('div', { class: 'tb-seat-bottom' }, [
        el('div', { class: 'tb-seat-money', text: money.join(' · ') }),
        s.cards && !s.hands ? cardsEl(s.cards, false) : null,
      ]),
      ...(s.hands || []).map((hd) => el('div', { class: 'tb-hand' + (hd.active ? ' active' : '') }, [
        cardsEl(hd.cards, false),
        hd.label ? el('span', { class: 'tb-seat-label', text: hd.label }) : null,
      ])),
      s.label ? el('div', { class: 'tb-seat-label', text: s.label }) : null,
    ]);
  }));
}

function renderActions(priv) {
  const acts = (priv && priv.actions) || [];
  if (!acts.length) return null;
  const locked = !tb.focus || tb.sent;
  const range = acts.find((a) => a.min != null && a.max != null);
  const simple = acts.filter((a) => a !== range);
  const nodes = simple.map((a) => button(actLabel(a, a.amount), () => act(a.id, a.amount), a.id === 'fold' ? 'muted' : '', locked));
  if (range) {
    const step = Math.max(1, range.step || 1);
    if (tb.amount == null || tb.amount < range.min || tb.amount > range.max) tb.amount = range.min;
    const main = button(actLabel(range, tb.amount), () => act(range.id, tb.amount), '', locked);
    const slider = el('input', { type: 'range', min: range.min, max: range.max, step, value: tb.amount, disabled: locked,
      oninput: (e) => { tb.amount = Number(e.target.value); main.textContent = actLabel(range, tb.amount); } });
    const set = (v) => () => { tb.amount = v; renderTable(); };
    nodes.push(el('div', { class: 'tb-range' }, [
      button(tr('ui_min'), set(range.min), 'muted small', locked), slider, button(tr('ui_max'), set(range.max), 'muted small', locked), main,
    ]));
  }
  return el('div', { class: 'tb-actions' + (locked ? ' locked' : '') }, nodes);
}

function act(id, amount) {
  if (tb.sent || !tb.focus) return;
  tb.sent = true;
  post('act', { id, amount });
  renderTable();
}

function statusText(pub, mySeat) {
  if (pub.phase === 'waiting') return tr('ui_waiting');
  if (pub.turn != null) {
    if (pub.turn === mySeat) return tr('ui_your_turn');
    const s = (pub.seats || []).find((x) => x.seat === pub.turn);
    return tr('ui_to_act', s ? s.name : '#' + pub.turn);
  }
  return '';
}

function renderTable() {
  const root = $('table');
  const v = tb.view;
  if (!v || !v.public) { root.classList.add('hidden'); return; }
  root.classList.remove('hidden');
  root.classList.toggle('focused', tb.focus);
  const pub = v.public, priv = v.private || {}, info = pub._table || {}, mySeat = v.seat;

  const headPills = [];
  if (info.tierLabel) headPills.push(el('span', { class: 'pill', text: info.tierLabel }));
  if (info.kind === 'pvp' && info.smallBlind != null) headPills.push(el('span', { class: 'pill', text: tr('ui_blinds_short', tbMoney(info.smallBlind), tbMoney(info.bigBlind)) }));
  if (info.currency === 'bloodmoney') headPills.push(el('span', { class: 'pill warn', text: tr('ui_bloodmoney') }));

  const centre = [];
  if (pub.board && pub.board.length) centre.push(el('div', { class: 'section-label', text: tr('ui_board') }), cardsEl(pub.board, true));
  if (pub.dealer && pub.dealer.length) {
    centre.push(el('div', { class: 'section-label', text: tr('ui_dealer') }), cardsEl(pub.dealer, true));
    if (pub.dealerLabel) centre.push(el('div', { class: 'tb-seat-label', text: pub.dealerLabel }));
  }
  if (pub.pot != null) centre.push(el('div', { class: 'tb-pot' }, [el('span', { class: 'section-label', text: tr('ui_pot') }), el('b', { text: ' ' + tbMoney(pub.pot) })]));
  centre.push(el('div', { class: 'tb-status', id: 'tb-status', text: statusText(pub, mySeat) }));
  centre.push(el('div', { class: 'bar tb-timer' + (pub.deadline ? '' : ' hidden') }, [el('div', { class: 'fill stat-good', id: 'tb-timer-fill' })]));

  const me = [];
  if (priv.cards && priv.cards.length) me.push(el('div', { class: 'tb-mine' }, [el('div', { class: 'section-label', text: tr('ui_you') }), cardsEl(priv.cards, true)]));
  const actions = renderActions(priv);
  if (actions) me.push(actions);

  const feed = el('div', { class: 'tb-feed' }, tb.feed.slice(-tb.feedLines).map((t) => el('div', { text: t })));
  root.replaceChildren(el('div', { class: 'tb-panel' }, [
    el('div', { class: 'tb-head' }, [
      el('div', {}, [el('div', { class: 'tb-title', text: info.label || '' }), el('div', { class: 'subtitle', text: info.game || '' })]),
      el('div', { class: 'pills' }, headPills),
    ]),
    el('div', { class: 'ink-divider' }),
    el('div', { class: 'tb-main' }, [el('div', { class: 'tb-centre' }, centre), renderSeats(pub, mySeat)]),
    me.length ? el('div', { class: 'tb-me' }, me) : null,
    feed,
    tb.focus ? el('div', { class: 'note tb-hint', text: tr('ui_esc_hint') }) : null,
  ]));
  tickTimer();
}

function tickTimer() {
  const v = tb.view;
  const fill = $('tb-timer-fill');
  if (!v || !v.public || !v.public.deadline || !fill) return;
  const left = Math.max(0, v.public.deadline - (Date.now() / 1000 + tb.offset));
  const pct = tb.total > 0 ? Math.min(100, (left / tb.total) * 100) : 0;
  fill.style.width = pct + '%';
  fill.className = 'fill ' + (pct > 50 ? 'stat-good' : pct > 20 ? 'stat-warn' : 'stat-bad');
}
setInterval(tickTimer, 250);

window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'table': {
      if (m.locale) L = m.locale;
      if (m.feedLines) tb.feedLines = m.feedLines;
      const prevTurn = tb.view && tb.view.public && tb.view.public.turn;
      tb.view = m.view;
      const pub = m.view && m.view.public;
      if (pub && pub._now) {
        tb.offset = pub._now - Date.now() / 1000;
        tb.total = pub.deadline ? Math.max(1, pub.deadline - pub._now) : 0;
      }
      tb.sent = false;
      if (!pub || pub.turn !== prevTurn) tb.amount = null;
      renderTable();
      break;
    }
    case 'tableFeed':
      tb.feed.push(m.text);
      if (tb.feed.length > 50) tb.feed.shift();
      renderTable();
      break;
    case 'tableFocus':
      tb.focus = !!m.on;
      renderTable();
      break;
    case 'tableHide':
      tb.view = null; tb.feed = []; tb.focus = false;
      renderTable();
      break;
  }
});

document.addEventListener('keydown', (e) => {
  // Esc on the table (no window open) gives the mouse back to the game
  if (e.key === 'Escape' && tb.focus && !view) post('tableBlur');
});
