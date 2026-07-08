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
    installFab: $('install-fab'), installDialog: $('install-dialog'),
    installTitle: $('install-title'), installBack: $('install-back'),
    installClose: $('install-close'), installChoice: $('install-choice'),
    platformIos: $('platform-ios'), platformAndroid: $('platform-android'),
    hintIos: $('hint-ios'), hintAndroid: $('hint-android'),
    installPanelIos: $('install-panel-ios'), installPanelAndroid: $('install-panel-android'),
    installNative: $('install-native'),
    ptr: $('ptr'), ptrText: $('ptr-text'),
  };

  let state = loadState();
  let pickerTarget = null; // 'from' | 'to'
  let copyText = '';
  let copyResetTimer = null;
  let searchTimer = null;

  const pad = (n) => String(n).padStart(2, '0');

  // Count a custom event in GoatCounter (no-op if analytics is blocked or offline).
  function track(name) {
    try {
      if (window.goatcounter) window.goatcounter.count({ path: name, event: true });
    } catch { /* analytics must never break the app */ }
  }

  // The zone this device's clock is set to (e.g. Africa/Lagos), if we know it.
  function deviceZone() {
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      return tz && Zones.isValid(tz) ? tz : null;
    } catch { return null; }
  }

  function loadState() {
    try {
      const s = JSON.parse(localStorage.getItem(STORE_KEY));
      if (s && Zones.isValid(s.from) && Zones.isValid(s.to)) return { from: s.from, to: s.to };
    } catch { /* fall through to defaults */ }
    // First visit: convert into the visitor's own zone when we can detect it.
    const dz = deviceZone();
    if (dz && dz !== DEFAULT_STATE.from) return { from: DEFAULT_STATE.from, to: dz };
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
    const dz = deviceZone();
    if (!results && dz) {
      html.push(
        '<p class="picker-section">My location</p>',
        `<button type="button" class="zone-option zone-option--location${dz === selected ? ' is-selected' : ''}" data-id="${dz}">` +
        '<span class="zo-left"><span class="zo-city">' +
        '<svg class="zo-pin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>' +
        `${city(dz)} — where I am</span>` +
        `<span class="zo-sub">Detected from this device · ${dz}</span></span>` +
        `<span class="zo-right"><span class="zo-time">${TZ.formatTime(dz, now)}</span>` +
        `<span class="zo-abbr">${abbr(dz, now)}</span></span>` +
        '</button>'
      );
    }
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

  /* ---------- Save-to-phone guide ---------- */

  const INSTALL_TITLES = {
    choice: 'Save to your phone',
    ios: 'Save on iPhone',
    android: 'Save on Android',
  };

  let deferredInstall = null; // captured beforeinstallprompt (Android/Chrome)

  function isInstalled() {
    return window.matchMedia('(display-mode: standalone)').matches
      || navigator.standalone === true;
  }

  function showInstallView(view) {
    els.installChoice.hidden = view !== 'choice';
    els.installPanelIos.hidden = view !== 'ios';
    els.installPanelAndroid.hidden = view !== 'android';
    els.installBack.hidden = view === 'choice';
    els.installTitle.textContent = INSTALL_TITLES[view];
  }

  function openInstall() {
    showInstallView('choice');
    if (typeof els.installDialog.showModal === 'function') els.installDialog.showModal();
    else els.installDialog.setAttribute('open', '');
    track('save-guide-opened');
  }

  function closeInstall() {
    if (typeof els.installDialog.close === 'function' && els.installDialog.open) els.installDialog.close();
    else els.installDialog.removeAttribute('open');
  }

  function initInstallGuide() {
    if (isInstalled()) {
      els.installFab.hidden = true;
      return;
    }

    // Mark the button matching this device so the choice is obvious.
    const ua = navigator.userAgent;
    const onIOS = /iPhone|iPad|iPod/.test(ua)
      || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1); // iPadOS
    if (onIOS) els.hintIos.hidden = false;
    else if (/Android/i.test(ua)) els.hintAndroid.hidden = false;

    els.installFab.addEventListener('click', openInstall);
    els.installClose.addEventListener('click', closeInstall);
    els.installBack.addEventListener('click', () => showInstallView('choice'));
    els.platformIos.addEventListener('click', () => showInstallView('ios'));
    els.platformAndroid.addEventListener('click', () => showInstallView('android'));
    els.installDialog.addEventListener('click', (ev) => {
      if (ev.target === els.installDialog) closeInstall();
    });

    // Chrome on Android offers a real install prompt — surface it as one tap.
    window.addEventListener('beforeinstallprompt', (ev) => {
      ev.preventDefault();
      deferredInstall = ev;
      els.installNative.hidden = false;
    });

    els.installNative.addEventListener('click', async () => {
      if (!deferredInstall) return;
      deferredInstall.prompt();
      const choice = await deferredInstall.userChoice;
      deferredInstall = null;
      els.installNative.hidden = true;
      if (choice.outcome === 'accepted') closeInstall();
    });

    window.addEventListener('appinstalled', () => {
      els.installFab.hidden = true;
      closeInstall();
      track('app-installed');
    });
  }

  /* ---------- Pull to refresh ----------
   * The installed app has no browser reload button, so a swipe down from
   * the top of the page re-fetches the latest version (online only). */

  function initPullToRefresh() {
    const READY_AT = 58; // damped pull distance (px) that arms the refresh
    const damp = (dy) => Math.min(dy * 0.45, 90);
    const scrollTop = () => (document.scrollingElement || document.documentElement).scrollTop;
    let startY = null;
    let show = 0;
    let refreshing = false;

    const setPos = (y) => { els.ptr.style.transform = `translate(-50%, ${y - 64}px)`; };
    const retract = () => {
      els.ptr.classList.remove('is-dragging', 'is-ready');
      els.ptr.style.transform = '';
      els.ptrText.textContent = 'Pull to refresh';
    };

    document.addEventListener('touchstart', (ev) => {
      if (refreshing || ev.touches.length !== 1) return;
      if (document.querySelector('dialog[open]') || ev.target.closest('dialog, input')) return;
      if (scrollTop() > 1) return;
      startY = ev.touches[0].clientY;
      show = 0;
    }, { passive: true });

    document.addEventListener('touchmove', (ev) => {
      if (refreshing || startY === null) return;
      const dy = ev.touches[0].clientY - startY;
      if (dy <= 0 && show === 0) { startY = null; return; } // normal scroll up
      if (scrollTop() > 1) { startY = null; retract(); return; }
      ev.preventDefault();
      show = damp(Math.max(dy, 0));
      els.ptr.classList.add('is-dragging');
      els.ptr.classList.toggle('is-ready', show >= READY_AT);
      els.ptrText.textContent = show >= READY_AT ? 'Release to refresh' : 'Pull to refresh';
      setPos(show);
    }, { passive: false });

    function finish() {
      if (refreshing || startY === null) return;
      startY = null;
      if (show < READY_AT) { retract(); return; }
      if (!navigator.onLine) {
        els.ptr.classList.remove('is-dragging', 'is-ready');
        els.ptrText.textContent = 'You’re offline';
        setPos(72);
        setTimeout(retract, 1200);
        return;
      }
      refreshing = true;
      els.ptr.classList.remove('is-dragging', 'is-ready');
      els.ptr.classList.add('is-refreshing');
      els.ptrText.textContent = 'Refreshing…';
      setPos(72);
      setTimeout(() => location.reload(), 350);
    }
    document.addEventListener('touchend', finish);
    document.addEventListener('touchcancel', finish);
  }

  /* ---------- Init ---------- */

  els.fromRow.addEventListener('click', () => openPicker('from'));
  els.toRow.addEventListener('click', () => openPicker('to'));
  els.themeToggle.addEventListener('click', toggleTheme);
  els.swapBtn.addEventListener('click', swapZones);
  document.getElementById('swap-rows-btn').addEventListener('click', swapZones);

  // Clicking a date/time input opens the browser's dropdown picker
  // (calendar / time list) while keeping the field typeable.
  for (const input of [els.convDate, els.fromTimeInput, els.toTimeInput]) {
    input.addEventListener('click', () => {
      if (typeof input.showPicker === 'function') {
        try { input.showPicker(); } catch { /* already open, or gesture rules */ }
      }
    });
  }
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
  initInstallGuide();
  initPullToRefresh();
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
      // When an updated service worker takes over, reload once so the page
      // picks up the new assets immediately instead of showing a stale build.
      let hadController = !!navigator.serviceWorker.controller;
      navigator.serviceWorker.addEventListener('controllerchange', () => {
        if (hadController) location.reload();
        hadController = true;
      });
      navigator.serviceWorker.register('sw.js', { updateViaCache: 'none' }).catch(() => {});
    });
  }
})();
