/* Pure timezone helpers built on the Intl API — no libraries, DST-safe. */
(function (global) {
  'use strict';

  // Intl.DateTimeFormat construction is expensive; cache formatters per zone+style.
  const fmtCache = new Map();
  function formatter(key, options) {
    let f = fmtCache.get(key);
    if (!f) {
      f = new Intl.DateTimeFormat('en-US', options);
      fmtCache.set(key, f);
    }
    return f;
  }

  function partsIn(timeZone, date, withSeconds) {
    const key = (withSeconds ? 'ps:' : 'p:') + timeZone;
    const dtf = formatter(key, {
      timeZone, hour12: false,
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit',
      ...(withSeconds ? { second: '2-digit' } : {}),
    });
    const p = {};
    for (const part of dtf.formatToParts(date)) p[part.type] = part.value;
    return p;
  }

  // Milliseconds the zone is ahead of UTC at the given instant.
  function zoneOffsetMs(timeZone, date) {
    const p = partsIn(timeZone, date, true);
    const asUTC = Date.UTC(p.year, p.month - 1, p.day, p.hour % 24, p.minute, p.second);
    return asUTC - Math.floor(date.getTime() / 1000) * 1000;
  }

  // The UTC instant corresponding to a wall-clock time in a zone.
  // Iterates twice so times near a DST switch resolve correctly.
  function wallTimeToUtc(timeZone, { year, month, day, hour, minute }) {
    const guess = Date.UTC(year, month - 1, day, hour, minute);
    let offset = zoneOffsetMs(timeZone, new Date(guess));
    offset = zoneOffsetMs(timeZone, new Date(guess - offset));
    return new Date(guess - offset);
  }

  // Calendar fields of an instant as seen in a zone.
  function wallTimeInZone(timeZone, date) {
    const p = partsIn(timeZone, date, false);
    return {
      year: +p.year, month: +p.month, day: +p.day,
      hour: +p.hour % 24, minute: +p.minute,
    };
  }

  // Zone name at an instant. style: 'short' → "MDT", 'long' → "Mountain
  // Daylight Time", 'longGeneric' → "Mountain Time".
  function zoneName(timeZone, date, style) {
    style = style || 'short';
    let dtf;
    try {
      dtf = formatter('n:' + style + ':' + timeZone, { timeZone, timeZoneName: style });
    } catch {
      dtf = formatter('n:long:' + timeZone, { timeZone, timeZoneName: 'long' });
    }
    const part = dtf.formatToParts(date).find((x) => x.type === 'timeZoneName');
    return part ? part.value : '';
  }

  // Short zone name, e.g. "MDT" / "MST". Falls back to the provided label
  // when Intl only returns a "GMT+1"-style string.
  function zoneAbbr(timeZone, date, fallback) {
    const abbr = zoneName(timeZone, date, 'short');
    return /^GMT/i.test(abbr) && fallback ? fallback : (abbr || fallback || '');
  }

  function formatTime(timeZone, date) {
    return formatter('t:' + timeZone, {
      timeZone, hour: 'numeric', minute: '2-digit', hour12: true,
    }).format(date);
  }

  function formatDate(timeZone, date) {
    return formatter('d:' + timeZone, {
      timeZone, weekday: 'short', month: 'short', day: 'numeric',
    }).format(date);
  }

  // Whole days the wall-clock date in zoneB is ahead of zoneA (-1, 0 or +1).
  function calendarDayDiff(zoneA, zoneB, date) {
    const a = wallTimeInZone(zoneA, date);
    const b = wallTimeInZone(zoneB, date);
    const utcA = Date.UTC(a.year, a.month - 1, a.day);
    const utcB = Date.UTC(b.year, b.month - 1, b.day);
    return Math.round((utcB - utcA) / 86400000);
  }

  const TZ = {
    zoneOffsetMs, wallTimeToUtc, wallTimeInZone,
    zoneName, zoneAbbr, formatTime, formatDate, calendarDayDiff,
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = TZ;
  else global.TZ = TZ;
})(typeof window !== 'undefined' ? window : globalThis);
