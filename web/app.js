(() => {
'use strict';

const RES = (window.GetParentResourceName && window.GetParentResourceName()) || 'vexxd_radio';
const $ = (s) => document.querySelector(s);

const state = {
  open: false,
  channel: 0,
  volume: 50,
  preMute: 50,
  entry: '',
  tuning: null,
  labels: {},
  min: 1,
  max: 999,
  keySounds: true,
  radioSounds: true,
  tx: false,
  rx: false,
  clock: '--:--',
  decimals: 0,
  slots: 0,
  presets: [],
  note: '',
};

const T = {
  ui_no_channel: 'NO CHANNEL', ui_enter: 'ENTER CHANNEL', ui_tuning: 'TUNING', ui_channel: 'CHANNEL',
  ui_unknown: 'UNKNOWN', ui_radio: 'Radio', ui_more: '+%s more',
  ui_soft_down: '\u25C0 CH', ui_soft_off: 'OFF', ui_soft_up: 'CH \u25B6',
  ui_del: 'DEL', ui_clr: 'CLR', ui_ent: 'ENT', ui_saved: 'SAVED P%s',
};
const fmt = (s, v) => String(s).replace('%s', v);

function applyStrings(strings) {
  if (!strings) return;
  Object.assign(T, strings);
}

const intDigits = () => Math.max(3, String(Math.floor(state.max)).length);

function roundCh(n) {
  const m = Math.pow(10, state.decimals);
  return Math.round(n * m) / m;
}

function fmtCh(n) {
  if (!n) return '---';
  const whole = Math.floor(n);
  const head = String(whole).padStart(intDigits(), '0');
  if (n === whole) return head;
  return head + '.' + String(n).split('.')[1];
}

const labelFor = (n) => state.labels[String(n)] || state.labels[String(Math.floor(n))];
const presetOf = (n) => state.presets.indexOf(n) + 1;

let noteTimer = null;
function note(text, slot) {
  state.note = text;
  state.noteSlot = slot || 0;
  render();
  clearTimeout(noteTimer);
  noteTimer = setTimeout(() => { state.note = ''; render(); }, 1400);
}

const list = { show: false, channel: 0, label: null, members: [], me: 0, position: 'top-right', max: 12 };
const talking = new Set();
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function nameOf(id) {
  const m = list.members.find((x) => x.id === id);
  return m ? m.name : null;
}

function incoming() {
  const names = [];
  talking.forEach((id) => { if (id !== list.me) names.push(nameOf(id) || T.ui_unknown); });
  return names;
}

function hexRgb(hex) {
  const m = /^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i.exec(String(hex || ''));
  return m ? [1, 2, 3].map((i) => parseInt(m[i], 16)) : null;
}

const mixRgb = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t));
const css = (c, alpha) => (alpha === undefined ? `rgb(${c.join(',')})` : `rgba(${c.join(',')},${alpha})`);

let appliedColors = '';
function applyColors(el) {
  const key = `${list.color}|${list.talkColor}`;
  if (key === appliedColors) return;
  appliedColors = key;
  const c = hexRgb(list.color);
  if (c) {
    el.style.setProperty('--lc', css(c));
    el.style.setProperty('--lc-rgb', c.join(','));
    el.style.setProperty('--lc-text', css(mixRgb(c, [228, 232, 238], 0.55)));
    el.style.setProperty('--lc-hi', css(mixRgb(c, [255, 255, 255], 0.82)));
    el.style.setProperty('--lc-dim', css(mixRgb(c, [150, 156, 166], 0.6)));
    el.style.setProperty('--lc-bg1', css(mixRgb(c, [6, 8, 12], 0.82), 0.92));
    el.style.setProperty('--lc-bg2', css(mixRgb(c, [4, 5, 8], 0.9), 0.92));
  }
  const t = hexRgb(list.talkColor);
  if (t) {
    el.style.setProperty('--tk', css(t));
    el.style.setProperty('--tk-rgb', t.join(','));
  }
}

const lastTalk = new Map();
let listTimer = null;
const HOLD_MS = 1200;

function headerHtml(count) {
  const h = list.header || 'both';
  if (h === 'none') return '';
  const label = esc(list.label || T.ui_radio);
  const ch = `<em>${esc(list.channel)}</em>`;
  const title = h === 'label' ? label : h === 'channel' ? ch : `${label} ${ch}`;
  const icon = '<svg viewBox="0 0 24 24"><path d="M7 2h2v5h8a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zm1 8v3h8v-3zm1 6a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3zm6 0a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z"/></svg>';
  return `<div class="rl-head">${icon}<b>${title}</b>${count !== null ? `<span class="rl-count">${count}</span>` : ''}</div>`;
}

function rowHtml(m) {
  return `
      <div class="rl-row${talking.has(m.id) ? ' talk' : ''}${m.id === list.me ? ' me' : ''}" data-id="${m.id}">
        <span class="rl-wave"><i></i><i></i><i></i><i></i></span>
        <span class="rl-name">${esc(m.name)}</span>
      </div>`;
}

function renderList() {
  const el = $('#radiolist');
  if (!list.show || !list.channel) { el.hidden = true; return; }
  el.className = 'rl pos-' + (list.position || 'top-right');
  applyColors(el);

  if (list.mode === 'talking') {
    const now = Date.now();
    const live = list.members.filter((m) => m.id !== list.me && (talking.has(m.id) || (lastTalk.get(m.id) || 0) > now));
    if (!live.length) { el.hidden = true; return; }
    el.innerHTML = headerHtml(null) + live.slice(0, list.max || 12).map(rowHtml).join('');
    el.hidden = false;
    return;
  }

  const shown = list.members.slice(0, list.max || 12);
  const extra = list.members.length - shown.length;
  el.innerHTML = headerHtml(list.members.length) + shown.map(rowHtml).join('') +
    (extra > 0 ? `<div class="rl-more">${esc(fmt(T.ui_more, extra))}</div>` : '');
  el.hidden = false;
}

function setTalking(id, on) {
  if (on) { talking.add(id); lastTalk.delete(id); } else if (talking.delete(id)) { lastTalk.set(id, Date.now() + HOLD_MS); }
  if (list.mode === 'talking') {
    renderList();
    if (!on) { clearTimeout(listTimer); listTimer = setTimeout(renderList, HOLD_MS + 30); }
  } else {
    const row = document.querySelector(`#radiolist .rl-row[data-id="${id}"]`);
    if (row) row.classList.toggle('talk', on);
  }
  if (state.open) render();
}

function flash() {
  const lcd = $('#lcd');
  lcd.classList.remove('flash');
  void lcd.offsetWidth;
  lcd.classList.add('flash');
}

async function post(endpoint, body) {
  try {
    const res = await fetch(`https://${RES}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body || {}),
    });
    return await res.json();
  } catch {
    return { ok: false };
  }
}

let actx = null;

function ctx() {
  if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)();
  if (actx.state === 'suspended') actx.resume();
  return actx;
}

function tone(freq, dur, gain, type = 'sine') {
  const c = ctx();
  const start = c.currentTime;
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = type;
  o.frequency.value = freq;
  g.gain.setValueAtTime(0, start);
  g.gain.linearRampToValueAtTime(gain, start + 0.004);
  g.gain.setValueAtTime(gain, start + dur - 0.008);
  g.gain.linearRampToValueAtTime(0, start + dur);
  o.connect(g);
  g.connect(c.destination);
  o.start(start);
  o.stop(start + dur + 0.01);
}

const customSounds = { key_up: null, key_down: null };

async function loadCustomSound(name) {
  for (const ext of ['ogg', 'mp3', 'wav']) {
    try {
      const res = await fetch(`sounds/${name}.${ext}`);
      if (!res.ok) continue;
      const data = await res.arrayBuffer();
      if (!data.byteLength) continue;
      customSounds[name] = await ctx().decodeAudioData(data);
      return;
    } catch { }
  }
}

loadCustomSound('key_up');
loadCustomSound('key_down');

function playBuffer(buffer, gain) {
  const c = ctx();
  const src = c.createBufferSource();
  const g = c.createGain();
  src.buffer = buffer;
  g.gain.value = gain;
  src.connect(g);
  g.connect(c.destination);
  src.start();
}

const level = () => (state.radioSounds ? state.volume / 100 : 0);

function talkStart() {
  const L = level();
  if (!L) return;
  if (customSounds.key_up) return playBuffer(customSounds.key_up, L);
  tone(1400, 0.09, 0.12 * L);
}

function talkStop() {
  const L = level();
  if (!L) return;
  if (customSounds.key_down) return playBuffer(customSounds.key_down, L);
  tone(850, 0.09, 0.12 * L);
}

function beep(freq = 1450, dur = 0.035) {
  if (!state.keySounds) return;
  try { tone(freq, dur, 0.035, 'square'); } catch { }
}


function render() {
  const lcd = $('#lcd');
  const chEl = $('#lcd-ch');
  const label = $('#lcd-label');

  lcd.classList.toggle('on', state.channel > 0);
  $('#bezel').classList.toggle('lit', state.channel > 0);
  chEl.classList.toggle('entering', !!state.entry);
  chEl.classList.toggle('tuning', state.tuning !== null && !state.entry);

  let shown;
  if (state.entry) {
    shown = state.entry.includes('.') ? state.entry : (state.entry + '___').slice(0, Math.max(3, state.entry.length));
    label.textContent = T.ui_enter;
  } else if (state.tuning !== null) {
    shown = fmtCh(state.tuning);
    label.textContent = labelFor(state.tuning) || T.ui_tuning;
  } else if (state.channel) {
    shown = fmtCh(state.channel);
    const rx = state.rx && !state.tx ? incoming() : [];
    label.textContent = rx.length
      ? `\u25B8 ${rx[0]}${rx.length > 1 ? ` +${rx.length - 1}` : ''}`
      : (labelFor(state.channel) || T.ui_channel);
    label.classList.toggle('rxname', rx.length > 0);
  } else {
    shown = '---';
    label.textContent = T.ui_no_channel;
  }
  if (state.note) label.textContent = state.note;
  chEl.textContent = shown;
  chEl.classList.toggle('long', shown.length > 4);
  chEl.classList.toggle('longer', shown.length > 5);

  const p = state.channel && !state.entry && state.tuning === null ? presetOf(state.channel) : 0;
  const z = state.note && state.noteSlot ? state.noteSlot : p;
  $('#zone').textContent = z ? 'P' + z : 'Z1';

  const typing = !!state.entry;
  $('#soft-down').textContent = typing ? T.ui_del : T.ui_soft_down;
  $('#soft-off').textContent = typing ? T.ui_clr : T.ui_soft_off;
  $('#soft-up').textContent = typing ? T.ui_ent : T.ui_soft_up;

  const lit = Math.round(state.volume / 20);
  document.querySelectorAll('#vol-bars i').forEach((el, i) => el.classList.toggle('on', i < lit));
  document.querySelector('.vol').classList.toggle('muted', state.volume === 0);

  $('#clock').textContent = state.clock;
  $('#pill-tx').classList.toggle('on', state.tx);
  $('#pill-rx').classList.toggle('on', state.rx && !state.tx);

  const led = $('#led');
  led.classList.toggle('tx', state.tx);
  led.classList.toggle('rx', state.rx && !state.tx);

  lcd.classList.toggle('rxon', state.rx && !state.tx && state.channel > 0);
  lcd.classList.toggle('txon', state.tx && state.channel > 0);
  $('#bezel').classList.toggle('rx', state.rx && !state.tx && state.channel > 0);
  $('#bezel').classList.toggle('tx', state.tx && state.channel > 0);
  if (!state.channel || state.entry || state.tuning !== null) label.classList.remove('rxname');
}

async function join(value) {
  const ch = roundCh(Number(value));
  state.entry = '';
  state.tuning = null;
  if (!ch || ch < state.min || ch > state.max) { beep(420, 0.12); render(); return; }
  const res = await post('join', { channel: ch });
  state.channel = res.channel ?? state.channel;
  beep(res.ok ? 1900 : 420, res.ok ? 0.05 : 0.12);
  render();
}

async function leave() {
  state.entry = '';
  state.tuning = null;
  await post('leave', {});
  state.channel = 0;
  state.rx = false;
  beep(700, 0.06);
  render();
}

let stepTimer = null;
function step(delta) {
  const base = Math.floor(state.tuning ?? (state.channel || state.min - (delta > 0 ? 1 : 0)));
  let next = base + delta;
  if (next > state.max) next = state.min;
  if (next < state.min) next = state.max;
  state.tuning = next;
  state.entry = '';
  beep(1300, 0.02);
  render();
  clearTimeout(stepTimer);
  stepTimer = setTimeout(() => join(next), 350);
}

let volTimer = null;
function setVolume(v) {
  state.volume = Math.max(0, Math.min(100, v));
  render();
  clearTimeout(volTimer);
  volTimer = setTimeout(() => post('volume', { value: state.volume }), 120);
}

function changeVolume(delta) {
  setVolume(state.volume + delta);
  beep(900 + state.volume * 8, 0.02);
}

function toggleMute() {
  if (state.volume > 0) {
    state.preMute = state.volume;
    setVolume(0);
    beep(500, 0.05);
  } else {
    setVolume(state.preMute || 50);
    beep(1500, 0.05);
  }
}

function nextPreset() {
  const saved = state.presets.map((c, i) => ({ c, i })).filter((x) => x.c > 0);
  if (!saved.length) { beep(900); return; }
  const at = presetOf(state.channel) - 1;
  const next = saved.find((x) => x.i > at) || saved[0];
  join(next.c);
}

function confirm() {
  if (state.entry) return join(state.entry);
  if (state.tuning !== null) {
    clearTimeout(stepTimer);
    return join(state.tuning);
  }
  nextPreset();
}

function validEntry(v) {
  const re = state.decimals > 0
    ? new RegExp(`^\\d{0,${intDigits()}}(\\.\\d{0,${state.decimals}})?$`)
    : new RegExp(`^\\d{0,${intDigits()}}$`);
  return re.test(v);
}

function pressKey(key) {
  if (key === 'clr') {
    beep(900);
    state.entry = state.entry.slice(0, -1);
  } else if (key === 'ent') {
    return confirm();
  } else if (key === 'dot' || /^\d$/.test(key)) {
    const next = state.entry + (key === 'dot' ? (state.entry ? '.' : '0.') : key);
    if (!validEntry(next)) { beep(500, 0.05); return; }
    beep();
    state.tuning = null;
    state.entry = next;
  }
  render();
}

function savePreset(slot) {
  if (!state.channel) { beep(420, 0.12); return; }
  state.presets[slot - 1] = state.channel;
  post('savePreset', { slot });
  beep(1900, 0.05);
  setTimeout(() => beep(2300, 0.05), 90);
  note(fmt(T.ui_saved, slot), slot);
}

function setKeypadMode() {
  const k = document.querySelector('.keypad [data-key="clr"], .keypad [data-key="dot"]');
  if (state.decimals > 0) {
    k.dataset.key = 'dot';
    k.classList.add('key-dot');
    k.innerHTML = '.<small>DOT</small>';
  } else {
    k.dataset.key = 'clr';
    k.classList.remove('key-dot');
    k.innerHTML = '\u2715<small>CLR</small>';
  }
}

function close() {
  state.open = false;
  $('#radio').hidden = true;
  document.body.classList.remove('radio-open');
  post('close', {});
}

$('#radio').addEventListener('pointerdown', (e) => {
  if (e.target.closest('button, .knob')) flash();
});

let holdTimer = null;
let held = false;
const keypad = document.querySelector('.keypad');

keypad.addEventListener('pointerdown', (e) => {
  const k = e.target.closest('[data-key]');
  held = false;
  clearTimeout(holdTimer);
  if (!k || state.entry) return;
  const slot = Number(k.dataset.key);
  if (!slot || slot > state.slots) return;
  holdTimer = setTimeout(() => { held = true; savePreset(slot); }, 650);
});
['pointerup', 'pointerleave', 'pointercancel'].forEach((ev) => keypad.addEventListener(ev, () => clearTimeout(holdTimer)));

keypad.addEventListener('click', (e) => {
  const k = e.target.closest('[data-key]');
  if (!k) return;
  if (held) { held = false; return; }
  pressKey(k.dataset.key);
});

document.querySelector('.softkeys').addEventListener('click', (e) => {
  const s = e.target.closest('[data-soft]');
  if (!s) return;
  const soft = s.dataset.soft;
  if (state.entry) {
    if (soft === 'down') pressKey('clr');
    else if (soft === 'off') { state.entry = ''; beep(900); render(); }
    else confirm();
    return;
  }
  if (soft === 'up') step(1);
  else if (soft === 'down') step(-1);
  else leave();
});

document.querySelector('.navrow').addEventListener('click', (e) => {
  const n = e.target.closest('[data-nav]');
  if (!n) return;
  switch (n.dataset.nav) {
    case 'up': step(1); break;
    case 'down': step(-1); break;
    case 'left': changeVolume(-10); break;
    case 'right': changeVolume(10); break;
    case 'ok': confirm(); break;
    case 'off': leave(); break;
    case 'mute': toggleMute(); break;
  }
});

$('#knob-ch').addEventListener('wheel', (e) => { e.preventDefault(); step(e.deltaY < 0 ? 1 : -1); }, { passive: false });
$('#knob-vol').addEventListener('wheel', (e) => { e.preventDefault(); changeVolume(e.deltaY < 0 ? 10 : -10); }, { passive: false });

const input = $('#lcd-input');
input.addEventListener('focus', () => post('typing', { value: true }));
input.addEventListener('blur', () => post('typing', { value: false }));
input.addEventListener('input', () => {
  let v = input.value.replace(state.decimals > 0 ? /[^\d.]/g : /\D/g, '');
  while (v && !validEntry(v)) v = v.slice(0, -1);
  input.value = v;
  state.entry = input.value;
  state.tuning = null;
  render();
});
input.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    e.preventDefault();
    const v = input.value;
    input.value = '';
    input.blur();
    join(v);
  } else if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    input.value = '';
    state.entry = '';
    input.blur();
    render();
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape' || !state.open || document.activeElement === input) return;
  e.preventDefault();
  close();
});

window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'open': {
      state.open = true;
      state.channel = d.channel || 0;
      if (typeof d.volume === 'number') state.volume = d.volume;
      state.labels = d.labels || {};
      state.min = d.min || 1;
      state.max = d.max || 999;
      state.decimals = Math.max(0, Math.min(2, d.decimals || 0));
      state.slots = d.presets || 0;
      input.maxLength = intDigits() + (state.decimals ? state.decimals + 1 : 0);
      input.inputMode = state.decimals ? 'decimal' : 'numeric';
      setKeypadMode();
      state.keySounds = d.sounds !== false;
      applyStrings(d.strings);
      state.entry = '';
      state.tuning = null;
      document.documentElement.style.setProperty('--scale', d.scale || 1);
      $('#radio').hidden = false;
      document.body.classList.add('radio-open');
      const lcd = $('#lcd');
      lcd.classList.remove('boot');
      void lcd.offsetWidth;
      lcd.classList.add('boot');
      render();
      break;
    }

    case 'close':
      state.open = false;
      if (document.activeElement === input) input.blur();
      $('#radio').hidden = true;
      document.body.classList.remove('radio-open');
      break;

    case 'clock':
      state.clock = `${String(d.h).padStart(2, '0')}:${String(d.m).padStart(2, '0')}`;
      if (state.open) $('#clock').textContent = state.clock;
      break;

    case 'tx': {
      const on = !!d.value;
      if (typeof d.vol === 'number') state.volume = d.vol;
      state.radioSounds = d.sfx !== false;
      if (on !== state.tx) (on ? talkStart : talkStop)();
      state.tx = on;
      if (state.open) render();
      break;
    }

    case 'channel':
      state.channel = d.channel || 0;
      if (!state.channel) state.rx = false;
      if (state.open) render();
      break;

    case 'presets':
      state.presets = Array.isArray(d.list) ? d.list.map(Number) : [];
      if (state.open) render();
      break;

    case 'rx':
      state.rx = !!d.value;
      if (state.open) render();
      break;

    case 'list':
      list.show = !!d.show;
      list.channel = d.channel || 0;
      list.label = d.label || null;
      list.members = Array.isArray(d.members) ? d.members : [];
      list.me = d.me || 0;
      list.position = d.position || 'top-right';
      list.max = d.max || 12;
      list.color = d.color || null;
      list.talkColor = d.talkColor || null;
      list.header = d.header || 'both';
      list.mode = d.mode || 'full';
      applyStrings(d.strings);
      if (!list.channel) talking.clear();
      renderList();
      if (state.open) render();
      break;

    case 'talk':
      setTalking(Number(d.id), !!d.value);
      break;

    case 'talkReset':
      talking.clear();
      lastTalk.clear();
      if (list.mode === 'talking') renderList();
      document.querySelectorAll('#radiolist .rl-row.talk').forEach((r) => r.classList.remove('talk'));
      if (state.open) render();
      break;
  }
});

})();
