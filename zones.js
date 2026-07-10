/* Zone catalog + search for the picker. Uses Intl.supportedValuesOf when
 * available, with a curated fallback for older browsers. */
(function (global) {
  'use strict';

  const POPULAR = [
    'America/Denver', 'Africa/Lagos', 'America/Phoenix', 'America/New_York',
    'America/Chicago', 'America/Los_Angeles', 'Europe/London', 'Europe/Paris',
    'Asia/Dubai', 'Asia/Kolkata', 'Asia/Calcutta', 'Asia/Manila', 'Asia/Singapore', 'Asia/Tokyo',
    'Australia/Sydney', 'Africa/Johannesburg', 'Africa/Nairobi', 'UTC',
  ];

  // Extra search terms per zone: abbreviations (both standard & daylight,
  // so "MST" finds Denver even in July), countries, nicknames.
  const ALIASES = {
    'America/Denver': 'MST MDT mountain time provo utah usa united states',
    'America/Edmonton': 'MST MDT mountain time canada',
    'America/Phoenix': 'MST arizona no dst usa united states',
    'America/Los_Angeles': 'PST PDT pacific time usa united states california',
    'America/Vancouver': 'PST PDT pacific time canada',
    'America/Anchorage': 'AKST AKDT alaska usa',
    'Pacific/Honolulu': 'HST hawaii usa',
    'America/New_York': 'EST EDT eastern time usa united states',
    'America/Toronto': 'EST EDT eastern time canada',
    'America/Chicago': 'CST CDT central time usa united states',
    'America/Mexico_City': 'CST mexico',
    'America/Sao_Paulo': 'BRT brazil brasilia',
    'America/Argentina/Buenos_Aires': 'ART argentina',
    'Europe/London': 'GMT BST britain uk england united kingdom',
    'Europe/Dublin': 'IST GMT ireland',
    'Europe/Paris': 'CET CEST central european france',
    'Europe/Berlin': 'CET CEST central european germany',
    'Europe/Madrid': 'CET CEST spain',
    'Europe/Rome': 'CET CEST italy',
    'Europe/Amsterdam': 'CET CEST netherlands',
    'Europe/Lisbon': 'WET WEST portugal',
    'Europe/Athens': 'EET EEST greece',
    'Europe/Istanbul': 'TRT turkey',
    'Europe/Moscow': 'MSK russia',
    'Africa/Lagos': 'WAT nigeria west africa naija abuja',
    'Africa/Accra': 'GMT ghana',
    'Africa/Abidjan': 'GMT ivory coast cote divoire',
    'Africa/Johannesburg': 'SAST south africa',
    'Africa/Nairobi': 'EAT kenya east africa',
    'Africa/Cairo': 'EET egypt',
    'Africa/Casablanca': 'morocco',
    'Africa/Kinshasa': 'WAT congo drc',
    'Africa/Addis_Ababa': 'EAT ethiopia',
    'Asia/Dubai': 'GST gulf uae emirates abu dhabi',
    'Asia/Riyadh': 'AST saudi arabia',
    'Asia/Jerusalem': 'IST israel',
    'Asia/Karachi': 'PKT pakistan',
    'Asia/Kolkata': 'IST india mumbai delhi bangalore calcutta',
    'Asia/Calcutta': 'IST india mumbai delhi bangalore kolkata',
    'America/Buenos_Aires': 'ART argentina',
    'Asia/Dhaka': 'BST bangladesh',
    'Asia/Bangkok': 'ICT thailand',
    'Asia/Jakarta': 'WIB indonesia',
    'Asia/Shanghai': 'CST china beijing',
    'Asia/Hong_Kong': 'HKT hong kong',
    'Asia/Singapore': 'SGT',
    'Asia/Manila': 'PHT philippines',
    'Asia/Tokyo': 'JST japan',
    'Asia/Seoul': 'KST korea',
    'Australia/Sydney': 'AEST AEDT eastern australia melbourne',
    'Australia/Brisbane': 'AEST queensland australia',
    'Australia/Adelaide': 'ACST ACDT australia',
    'Australia/Perth': 'AWST western australia',
    'Pacific/Auckland': 'NZST NZDT new zealand',
    'UTC': 'UTC universal coordinated zulu',
  };

  // Zones whose Intl short name is a "GMT+X" string but that have a
  // well-known letter abbreviation worth showing instead.
  const ABBR_OVERRIDES = { 'Africa/Lagos': 'WAT', 'Africa/Kinshasa': 'WAT' };
  const CITY_OVERRIDES = { 'America/Denver': 'Provo' };
  const REGION_OVERRIDES = { 'America/Denver': 'Utah' };

  const FALLBACK_ZONES = Object.keys(ALIASES);

  let entries = null; // [{id, city, region, search, primed}]

  function cityName(id) {
    if (CITY_OVERRIDES[id]) return CITY_OVERRIDES[id];
    const p = id.split('/');
    return p[p.length - 1].replace(/_/g, ' ');
  }

  function regionName(id) {
    if (REGION_OVERRIDES[id]) return REGION_OVERRIDES[id];
    const p = id.split('/');
    if (p.length === 1) return '';
    return (p.length === 3 ? p[1] : p[0]).replace(/_/g, ' ');
  }

  function listIds() {
    let ids;
    try {
      ids = Intl.supportedValuesOf('timeZone').slice();
    } catch {
      ids = FALLBACK_ZONES.slice();
    }
    if (!ids.includes('UTC')) ids.push('UTC');
    return ids;
  }

  function init() {
    if (entries) return entries;
    entries = listIds().map((id) => {
      const city = cityName(id);
      const region = regionName(id);
      const terms = [city, region, id.replace(/[_/]/g, ' '), ALIASES[id] || ''];
      return { id, city, region, search: terms.join(' ').toLowerCase(), primed: false };
    });
    entries.sort((a, b) => a.city.localeCompare(b.city));
    return entries;
  }

  // Add each zone's live short + long names to its search terms so queries
  // like "MDT" or "West Africa" match. Chunked to keep the UI responsive.
  function primeNames() {
    const list = init();
    const now = new Date();
    let i = 0;
    (function step() {
      const end = Math.min(i + 40, list.length);
      for (; i < end; i++) {
        const e = list[i];
        if (e.primed) continue;
        try {
          e.search += (' ' + TZ.zoneName(e.id, now, 'short')
            + ' ' + TZ.zoneName(e.id, now, 'long')).toLowerCase();
        } catch { /* skip zones Intl can't format */ }
        e.primed = true;
      }
      if (i < list.length) setTimeout(step, 0);
    })();
  }

  function all() { return init(); }

  function popular() {
    const byId = new Map(init().map((e) => [e.id, e]));
    return [...new Set(POPULAR.map((id) => byId.get(id)).filter(Boolean))];
  }

  function isValid(id) {
    return typeof id === 'string' && init().some((e) => e.id === id);
  }

  function search(query) {
    const q = query.trim().toLowerCase();
    if (!q) return null;
    const hits = init().filter((e) => e.search.includes(q));
    const score = (e) => {
      let s = 2;
      if (e.city.toLowerCase().startsWith(q)) s = 0;
      else if ((' ' + e.search + ' ').includes(' ' + q + ' ')) s = 1;
      return s - (POPULAR.includes(e.id) ? 0.5 : 0); // well-known zones first
    };
    return hits.sort((a, b) => score(a) - score(b) || a.city.localeCompare(b.city));
  }

  function abbrOverride(id) { return ABBR_OVERRIDES[id]; }

  const Zones = { init, primeNames, all, popular, search, cityName, regionName, isValid, abbrOverride };

  if (typeof module !== 'undefined' && module.exports) module.exports = Zones;
  else global.Zones = Zones;
})(typeof window !== 'undefined' ? window : globalThis);
