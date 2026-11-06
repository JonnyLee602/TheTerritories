// Table panel (phase 4): draws any game's view. Uses tr / el / post / $ from script.js. Amounts are cents.
const tb = { view: null, feed: [], focus: false, offset: 0, total: 0, amount: null, sent: false, feedLines: 8, picked: [],
  seen: new Set(), seenNext: new Set(), feedQueue: [], freshFeed: 0, potShown: null };

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
// A card that wasn't on screen at the last draw eases in (keyed by where it sits and what it is)
function cardKeyed(c, big, key) {
  const e = cardEl(c, big);
  if (key) {
    const k = key + ':' + (!c || c.down ? 'x' : c.r + c.s);
    tb.seenNext.add(k);
    if (!tb.seen.has(k)) e.classList.add('deal-in');
  }
  return e;
}
const cardsEl = (list, big, key) => el('div', { class: 'cards' }, (list || []).map((c, i) => cardKeyed(c, big, key ? key + i : null)));

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
        s.cards && !s.hands ? cardsEl(s.cards, false, 's' + s.seat + '-') : null,
      ]),
      ...(s.hands || []).map((hd, hi) => el('div', { class: 'tb-hand' + (hd.active ? ' active' : '') }, [
        cardsEl(hd.cards, false, 's' + s.seat + 'h' + hi + '-'),
        hd.label ? el('span', { class: 'tb-seat-label', text: hd.label }) : null,
      ])),
      s.label ? el('div', { class: 'tb-seat-label', text: s.label }) : null,
    ]);
  }));
}

// Card picking (e.g. the draw in five-card draw): an action { id, pick = { max, aceMax? } } makes your own cards
// clickable; it's sent with a bitmask of the picked cards (card 1 = 1, card 2 = 2, card 3 = 4 …). aceMax: more cards
// may be picked when the one card kept is an ace.
const pickAction = (priv) => ((priv && priv.actions) || []).find((a) => a.pick);
function pickAllowed(pick, cards, picked) {
  if (picked.length <= pick.max) return true;
  if (!pick.aceMax || picked.length > pick.aceMax) return false;
  const kept = cards.filter((_, i) => !picked.includes(i));
  return kept.some((c) => c && c.r === 'A');
}
function togglePick(i) {
  const priv = tb.view && tb.view.private;
  const pa = pickAction(priv);
  if (!pa || tb.sent || !tb.focus) return;
  const next = tb.picked.includes(i) ? tb.picked.filter((x) => x !== i) : tb.picked.concat([i]);
  if (!pickAllowed(pa.pick, priv.cards || [], next)) return;
  tb.picked = next;
  renderTable();
}
function myCardsEl(priv) {
  const pa = pickAction(priv);
  if (!pa) return cardsEl(priv.cards, true, 'm');
  return el('div', { class: 'cards picking' }, priv.cards.map((c, i) => {
    const e = cardKeyed(c, true, 'm' + i);
    e.classList.add('pickable');
    if (tb.picked.includes(i)) e.classList.add('picked');
    e.addEventListener('click', () => togglePick(i));
    return e;
  }));
}

function renderActions(priv) {
  const acts = (priv && priv.actions) || [];
  if (!acts.length) return null;
  const locked = !tb.focus || tb.sent;
  const range = acts.find((a) => a.min != null && a.max != null);
  const simple = acts.filter((a) => a !== range);
  const nodes = simple.map((a) => {
    if (a.pick) {
      const n = tb.picked.length;
      const mask = tb.picked.reduce((m, i) => m + (1 << i), 0);
      return button(n === 0 ? tr('ui_act_stand_pat') : tr('ui_act_draw_n', String(n)), () => act(a.id, mask), '', locked);
    }
    return button(actLabel(a, a.amount), () => act(a.id, a.amount), a.id === 'fold' ? 'muted' : '', locked);
  });
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
  if (priv._chips != null) headPills.unshift(el('span', { class: 'pill good', text: tr('ui_chips_short', tbMoney(priv._chips)) }));

  const centre = [];
  if (pub.board && pub.board.length) centre.push(el('div', { class: 'section-label', text: tr('ui_board') }), cardsEl(pub.board, true, 'b'));
  if (pub.dealer && pub.dealer.length) {
    centre.push(el('div', { class: 'section-label', text: tr('ui_dealer') }), cardsEl(pub.dealer, true, 'd'));
    if (pub.dealerLabel) centre.push(el('div', { class: 'tb-seat-label', text: pub.dealerLabel }));
  }
  if (pub.pot != null) {
    centre.push(el('div', { class: 'tb-pot' }, [el('span', { class: 'section-label', text: tr('ui_pot') }),
      el('b', { id: 'tb-pot-val', text: ' ' + tbMoney(tb.potShown != null ? tb.potShown : pub.pot) })]));
  }
  centre.push(el('div', { class: 'tb-status', id: 'tb-status', text: statusText(pub, mySeat) }));
  centre.push(el('div', { class: 'bar tb-timer' + (pub.deadline ? '' : ' hidden') }, [el('div', { class: 'fill stat-good', id: 'tb-timer-fill' })]));

  const me = [];
  if (priv.cards && priv.cards.length) {
    const picking = !!pickAction(priv);
    me.push(el('div', { class: 'tb-mine' }, [picking ? null : el('div', { class: 'section-label', text: tr('ui_you') }), myCardsEl(priv)]));
    if (pickAction(priv) && tb.focus) me.push(el('div', { class: 'note', text: tr('ui_pick_hint') }));
  }
  const actions = renderActions(priv);
  if (actions) me.push(actions);

  const lines = tb.feed.slice(-tb.feedLines);
  const feed = el('div', { class: 'tb-feed', id: 'tb-feed' }, lines.map((t, i) => el('div', { text: t,
    class: i >= lines.length - tb.freshFeed ? 'feed-in' : null })));
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
  tb.seen = tb.seenNext;
  tb.seenNext = new Set();
  tb.freshFeed = 0;
  countPot(pub.pot);
}

// The pot figure counts up (or down) to its new value
let potAnim = null;
function countPot(target) {
  if (target == null) { tb.potShown = null; return; }
  const from = tb.potShown == null ? target : tb.potShown;
  if (from === target) { tb.potShown = target; return; }
  if (potAnim) cancelAnimationFrame(potAnim);
  const t0 = performance.now(), ms = 420;
  const step = (now) => {
    const p = Math.min(1, (now - t0) / ms);
    tb.potShown = Math.round(from + (target - from) * (1 - Math.pow(1 - p, 3)));
    const e = document.getElementById('tb-pot-val');
    if (e) e.textContent = ' ' + tbMoney(tb.potShown);
    potAnim = p < 1 ? requestAnimationFrame(step) : null;
  };
  potAnim = requestAnimationFrame(step);
}

setInterval(() => {
  if (!tb.feedQueue.length) return;
  tb.feed.push(tb.feedQueue.shift());
  if (tb.feed.length > 50) tb.feed.shift();
  tb.freshFeed = 1;
  if (tb.view) renderTable();
}, 380);

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
      const prevPhase = tb.view && tb.view.public && tb.view.public.phase;
      tb.view = m.view;
      const pub = m.view && m.view.public;
      if (pub && pub._now) {
        tb.offset = pub._now - Date.now() / 1000;
        tb.total = pub.deadline ? Math.max(1, pub.deadline - pub._now) : 0;
      }
      tb.sent = false;
      if (!pub || pub.turn !== prevTurn) tb.amount = null;
      if (!pub || pub.turn !== prevTurn || pub.phase !== prevPhase || !pickAction(m.view && m.view.private)) tb.picked = [];
      renderTable();
      break;
    }
    case 'tableFeed':
      // lines are paced: one every ~0.4 s, so a burst reads like people talking
      tb.feedQueue.push(m.text);
      break;
    case 'tableFocus':
      tb.focus = !!m.on;
      renderTable();
      break;
    case 'tableHide':
      tb.view = null; tb.feed = []; tb.feedQueue = []; tb.focus = false; tb.seen = new Set(); tb.potShown = null;
      renderTable();
      break;
  }
});

document.addEventListener('keydown', (e) => {
  // Esc on the table (no window open) gives the mouse back to the game
  if (e.key === 'Escape' && tb.focus && !view) post('tableBlur');
});
