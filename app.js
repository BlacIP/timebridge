/* TimeBridge UI — live clocks, any-zone converter, quick reference. */
(function () {
  'use strict';

  const DEFAULT_STATE = { from: 'America/Denver', to: 'Africa/Lagos' };
  const STORE_KEY = 'timebridge-zones';
  const THEME_KEY = 'timebridge-theme';
  const THEMES = {
    dark: { label: 'Use light theme', color: '#171412' },
    light: { label: 'Use dark theme', color: '#FFFFFF' },
  };

  const $ = (id) => document.getElementById(id);

  const els = {
    dstPill: $('dst-pill'),
    themeToggle: $('theme-toggle'),
    fromRow: $('from-row'), toRow: $('to-row'),
    fromName: $('from-name'), fromSub: $('from-sub'), fromAbbr: $('from-abbr'),
    fromTime: $('from-time'), fromDate: $('from-date'),
    toName: $('to-name'), toSub: $('to-sub'), toAbbr: $('to-abbr'),
    toTime: $('to-time'), toDate: $('to-date'),
    offsetNote: $('offset-note'),
    convTitle: $('conv-title'), swapBtn: $('swap-btn'),
    dateLabel: $('date-label'),
    fromTimeLabel: $('from-time-label'), toTimeLabel: $('to-time-label'),
    convDate: $('conv-date'),
    fromTimeInput: $('from-time-input'), toTimeInput: $('to-time-input'),
    convNote: $('conv-note-text'), dayBadge: $('day-badge'),
    copyBtn: $('copy-btn'),
    refThFrom: $('ref-th-from'), refThTo: $('ref-th-to'),
    refBody: $('ref-body'), refDateNote: $('ref-date-note'),
    picker: $('zone-picker'), zoneSearch: $('zone-search'),
    zoneList: $('zone-list'), pickerClose: $('picker-close'),
  };

  let state = loadState();
  let pickerTarget = null; // 'from' | 'to'
  let copyText = '';
  let copyResetTimer = null;
  let searchTimer = null;

  const pad = (n) => String(n).padStart(2, '0');

  function loadState() {
    try {
      const s = JSON.parse(localStorage.getItem(STORE_KEY));
      if (s && Zones.isValid(s.from) && Zones.isValid(s.to)) return { from: s.from, to: s.to };
    } catch { /* fall through to defaults */ }
    return { ...DEFAULT_STATE };
  }

  function saveState() {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(state)); } catch { /* private mode */ }
  }

  function loadTheme() {
    try {
      const saved = localStorage.getItem(THEME_KEY);
      if (saved === 'light' || saved === 'dark') return saved;
    } catch { /* private mode */ }
    return 'dark';
  }

  function applyTheme(theme) {
    const safeTheme = theme === 'light' ? 'light' : 'dark';
    document.documentElement.dataset.theme = safeTheme;
    const nextTheme = safeTheme === 'dark' ? 'light' : 'dark';
    const next = THEMES[nextTheme];
    els.themeToggle.setAttribute('aria-label', next.label);
    els.themeToggle.title = next.label;
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', THEMES[safeTheme].color);
    try { localStorage.setItem(THEME_KEY, safeTheme); } catch { /* private mode */ }
  }

  function toggleTheme() {
    applyTheme(document.documentElement.dataset.theme === 'light' ? 'dark' : 'light');
  }

  const abbr = (tz, date) => TZ.zoneAbbr(tz, date, Zones.abbrOverride(tz));
  const city = (tz) => Zones.cityName(tz);

  function genericName(tz, date) {
    const name = TZ.zoneName(tz, date, 'longGeneric');
    return /^GMT/i.test(name) ? Zones.regionName(tz) || name : name;
  }

  function utcLabel(offsetMin) {
    const sign = offsetMin < 0 ? '−' : '+';
    const a = Math.abs(offsetMin);
    const h = Math.floor(a / 60), m = a % 60;
    return `UTC${sign}${h}${m ? ':' + pad(m) : ''}`;
  }

  function offsetPhrase(diffMin) {
    const a = Math.abs(diffMin);
    const h = Math.floor(a / 60), m = a % 60;
    if (m) return `${h}h ${m}m`;
    return `${h} ${h === 1 ? 'hour' : 'hours'}`;
  }

  /* ---------- Live clocks ---------- */

  function renderClocks() {
    const now = new Date();
    const f = state.from, t = state.to;

    els.fromName.childNodes[0].textContent = city(f) + ' ';
    els.fromSub.textContent = genericName(f, now);
    els.fromAbbr.textContent = abbr(f, now);
    els.fromTime.textContent = TZ.formatTime(f, now);
    els.fromDate.textContent = TZ.formatDate(f, now);

    els.toName.childNodes[0].textContent = city(t) + ' ';
    els.toSub.textContent = genericName(t, now);
    els.toAbbr.textContent = abbr(t, now);
    els.toTime.textContent = TZ.formatTime(t, now);
    els.toDate.textContent = TZ.formatDate(t, now);

    const diffMin = (TZ.zoneOffsetMs(t, now) - TZ.zoneOffsetMs(f, now)) / 60000;
    els.offsetNote.textContent = diffMin === 0
      ? `${city(t)} and ${city(f)} are on the same time right now`
      : `${city(t)} is ${offsetPhrase(diffMin)} ${diffMin > 0 ? 'ahead of' : 'behind'} ${city(f)} right now`;

    els.dstPill.textContent = `${abbr(f, now)} · ${utcLabel(TZ.zoneOffsetMs(f, now) / 60000)}`;
  }

  /* ---------- Converter (bidirectional: edit either side) ---------- */

  function readFromInputs() {
    const d = els.convDate.value; // yyyy-mm-dd
    const t = els.fromTimeInput.value; // HH:MM
    if (!d || !t) return null;
    const [year, month, day] = d.split('-').map(Number);
    const [hour, minute] = t.split(':').map(Number);
    return { year, month, day, hour, minute };
  }

  // The instant currently described by the from-side inputs (or now).
  function currentInstant() {
    const wall = readFromInputs();
    return wall ? TZ.wallTimeToUtc(state.from, wall) : new Date();
  }

  // Single source of truth: an instant. Writes it back into whichever
  // side(s) didn't originate the edit, plus the note, badge and table.
  function syncFromInstant(instant, { setFrom = false, setTo = false } = {}) {
    const f = state.from, t = state.to;

    if (setFrom) {
      const w = TZ.wallTimeInZone(f, instant);
      els.convDate.value = `${w.year}-${pad(w.month)}-${pad(w.day)}`;
      els.fromTimeInput.value = `${pad(w.hour)}:${pad(w.minute)}`;
    }
    if (setTo) {
      const w = TZ.wallTimeInZone(t, instant);
      els.toTimeInput.value = `${pad(w.hour)}:${pad(w.minute)}`;
    }

    const dayDiff = TZ.calendarDayDiff(f, t, instant);
    els.convNote.textContent = `${TZ.formatDate(t, instant)} · ${abbr(t, instant)} in ${city(t)}`;
    els.dayBadge.hidden = dayDiff === 0;
    if (dayDiff !== 0) els.dayBadge.textContent = dayDiff > 0 ? '+1 day' : '−1 day';

    copyText = `${TZ.formatTime(f, instant)} ${abbr(f, instant)} (${city(f)}, ${TZ.formatDate(f, instant)})`
      + ` → ${TZ.formatTime(t, instant)} ${abbr(t, instant)} (${city(t)}, ${TZ.formatDate(t, instant)})`;

    renderReference();
  }

  function onFromEdited() {
    const wall = readFromInputs();
    if (!wall) return;
    syncFromInstant(TZ.wallTimeToUtc(state.from, wall), { setTo: true });
  }

  function onToEdited() {
    const t = els.toTimeInput.value;
    if (!t) return;
    // Interpret the new time on the to-zone calendar date currently shown.
    const base = TZ.wallTimeInZone(state.to, currentInstant());
    const [hour, minute] = t.split(':').map(Number);
    const instant = TZ.wallTimeToUtc(state.to, { ...base, hour, minute });
    syncFromInstant(instant, { setFrom: true });
  }

  function renderLabels() {
    els.convTitle.textContent = `${city(state.from)} ⇄ ${city(state.to)}`;
    els.dateLabel.textContent = `Date in ${city(state.from)}`;
    els.fromTimeLabel.textContent = `Time in ${city(state.from)}`;
    els.toTimeLabel.textContent = `Time in ${city(state.to)}`;
    els.refThFrom.textContent = city(state.from);
    els.refThTo.textContent = city(state.to);
  }

  function setDefaultInputs() {
    const now = TZ.wallTimeInZone(state.from, new Date());
    els.convDate.value = `${now.year}-${pad(now.month)}-${pad(now.day)}`;
    // Round up to the next half hour — a sensible meeting-time starting point.
    let mins = now.hour * 60 + now.minute;
    mins = Math.min(Math.ceil(mins / 30) * 30, 23 * 60 + 30);
    els.fromTimeInput.value = `${pad(Math.floor(mins / 60))}:${pad(mins % 60)}`;
  }

  function renderAll() {
    renderLabels();
    renderClocks();
    onFromEdited();
  }

  function swapZones() {
    const instant = currentInstant(); // keep the same moment across the swap
    state = { from: state.to, to: state.from };
    saveState();
    renderLabels();
    renderClocks();
    syncFromInstant(instant, { setFrom: true, setTo: true });
  }

  async function copyResult() {
    if (!copyText) return;
    try {
      await navigator.clipboard.writeText(copyText);
    } catch {
      const ta = document.createElement('textarea');
      ta.value = copyText;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
    }
    els.copyBtn.classList.add('copied');
    clearTimeout(copyResetTimer);
    copyResetTimer = setTimeout(() => els.copyBtn.classList.remove('copied'), 2000);
  }

  /* ---------- Quick reference table ---------- */

  function renderReference() {
    // Business hours in the "from" zone on the converter's selected date.
    const wall = readFromInputs();
    const today = TZ.wallTimeInZone(state.from, new Date());
    const base = wall || today;
    const isToday = base.year === today.year && base.month === today.month && base.day === today.day;

    const noon = TZ.wallTimeToUtc(state.from, { ...base, hour: 12, minute: 0 });
    els.refDateNote.textContent = `${city(state.from)} business hours · ${TZ.formatDate(state.from, noon)}`;

    const rows = [];
    for (let h = 7; h <= 18; h++) {
      const instant = TZ.wallTimeToUtc(state.from, { ...base, hour: h, minute: 0 });
      const dayDiff = TZ.calendarDayDiff(state.from, state.to, instant);
      const marker = dayDiff === 0 ? ''
        : `<span class="ref-day-marker">${dayDiff > 0 ? '+1d' : '−1d'}</span>`;
      const isNow = isToday && today.hour === h;
      rows.push(
        `<tr${isNow ? ' class="ref-now"' : ''}>` +
        `<td>${TZ.formatTime(state.from, instant)}</td>` +
        `<td class="ref-arrow-cell">→</td>` +
        `<td>${TZ.formatTime(state.to, instant)}${marker}</td>` +
        `</tr>`
      );
    }
    els.refBody.innerHTML = rows.join('');
  }

  /* ---------- Zone picker ---------- */

  function openPicker(slot) {
    pickerTarget = slot;
    els.zoneSearch.value = '';
    renderZoneList('');
    if (typeof els.picker.showModal === 'function') els.picker.showModal();
    else els.picker.setAttribute('open', '');
    els.zoneSearch.focus();
  }

  function closePicker() {
    if (typeof els.picker.close === 'function' && els.picker.open) els.picker.close();
    else els.picker.removeAttribute('open');
  }

  function renderZoneList(query) {
    const now = new Date();
    const selected = pickerTarget ? state[pickerTarget] : null;
    const results = Zones.search(query);
    const sections = results
      ? [[results.length ? 'Results' : 'No matches — try a city or zone name', results.slice(0, 80)]]
      : [['Popular', Zones.popular()], ['All time zones', Zones.all()]];

    const html = [];
    for (const [title, list] of sections) {
      html.push(`<p class="picker-section">${title}</p>`);
      for (const e of list) {
        const sel = e.id === selected;
        html.push(
          `<button type="button" class="zone-option${sel ? ' is-selected' : ''}" data-id="${e.id}">` +
          `<span class="zo-left"><span class="zo-city">${e.city}</span>` +
          `<span class="zo-sub">${e.region ? e.region + ' · ' : ''}${e.id}</span></span>` +
          `<span class="zo-right"><span class="zo-time">${TZ.formatTime(e.id, now)}</span>` +
          `<span class="zo-abbr">${abbr(e.id, now)}</span></span>` +
          `</button>`
        );
      }
    }
    els.zoneList.innerHTML = html.join('');
    els.zoneList.scrollTop = 0;
  }

  function chooseZone(id) {
    if (pickerTarget && Zones.isValid(id)) {
      state[pickerTarget] = id;
      saveState();
      renderAll();
    }
    closePicker();
  }

  /* ---------- Init ---------- */

  els.fromRow.addEventListener('click', () => openPicker('from'));
  els.toRow.addEventListener('click', () => openPicker('to'));
  els.themeToggle.addEventListener('click', toggleTheme);
  els.swapBtn.addEventListener('click', swapZones);
  els.convDate.addEventListener('input', onFromEdited);
  els.fromTimeInput.addEventListener('input', onFromEdited);
  els.toTimeInput.addEventListener('input', onToEdited);
  els.copyBtn.addEventListener('click', copyResult);
  els.pickerClose.addEventListener('click', closePicker);

  els.zoneSearch.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => renderZoneList(els.zoneSearch.value), 120);
  });

  els.zoneList.addEventListener('click', (ev) => {
    const btn = ev.target.closest('.zone-option');
    if (btn) chooseZone(btn.dataset.id);
  });

  // Click on the backdrop (outside the sheet) closes the dialog.
  els.picker.addEventListener('click', (ev) => {
    if (ev.target === els.picker) closePicker();
  });

  Zones.init();
  applyTheme(loadTheme());
  setDefaultInputs();
  renderAll();
  Zones.primeNames(); // background: index MST/MDT-style names for search

  // Deep link: ?picker=from or ?picker=to opens the corresponding picker.
  const wanted = new URLSearchParams(location.search).get('picker');
  if (wanted === 'from' || wanted === 'to') openPicker(wanted);

  // Tick on the next minute boundary, then every minute.
  setTimeout(function tick() {
    renderClocks();
    setTimeout(tick, 60000 - (Date.now() % 60000));
  }, 60000 - (Date.now() % 60000));

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) renderClocks();
  });

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    });
  }
})();
