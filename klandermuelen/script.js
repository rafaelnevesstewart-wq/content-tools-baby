(() => {
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Opening hours, index 0 = Sunday. Close time 24 = midnight.
  const HOURS = [
    { open: 11, close: 22 }, { open: 11, close: 18 }, { open: 10, close: 22 }, { open: 10, close: 22 },
    { open: 10, close: 24 }, { open: 10, close: 24 }, { open: 10, close: 24 },
  ];
  const fmt = h => (h === 24 ? '00' : String(h).padStart(2, '0')) + ':00';

  // ---- Language (NL/EN). Static text lives in data-en attributes in the HTML. ----
  const I18N = {
    nl: {
      title: 'Klander Muelen Concept',
      days: ['zondag', 'maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag'],
      short: ['zo', 'ma', 'di', 'wo', 'do', 'vr', 'za'],
      months: ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'],
      today: 'vandaag', tomorrow: 'morgen', ordinal: 'e',
      openUntil: t => `Nu open tot ${t}`, closesAt: t => `Nu open · sluit om ${t}`,
      opensToday: t => `Gesloten · vandaag open vanaf ${t}`, opensTomorrow: t => `Gesloten · morgen open vanaf ${t}`,
      noTimes: 'Geen tijden meer vandaag, kies een andere dag.',
      pickTime: 'Kies eerst een tijd.', fillFields: 'Vul de gemarkeerde velden in.',
      menuOpen: 'Sluit menu', menuClosed: 'Open menu', langBtn: 'EN', langLabel: 'Switch to English',
      demo: (g, d, t) => `Demo: aanvraag voor ${g} pers. op ${d} om ${t}. In de live-versie gaat dit naar het restaurant.`,
      demoToast: 'Demo: er is niets verstuurd.',
      mailOpened: (g, d, t) => `Je mailprogramma opent met je aanvraag voor ${g} pers. op ${d} om ${t}.`,
      mailToast: 'Bijna klaar, verstuur de e-mail om te bevestigen.',
      mail: { subject: 'Reservering', people: 'pers.', name: 'Naam', phone: 'Telefoon', guests: 'Gasten', date: 'Datum', time: 'Tijd', note: 'Opmerking' },
    },
    en: {
      title: 'Klander Muelen Concept',
      days: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      short: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      months: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
      today: 'today', tomorrow: 'tomorrow', ordinal: 'th',
      openUntil: t => `Open now until ${t}`, closesAt: t => `Open now · closes at ${t}`,
      opensToday: t => `Closed · opens today at ${t}`, opensTomorrow: t => `Closed · opens tomorrow at ${t}`,
      noTimes: 'No times left today, please choose another day.',
      pickTime: 'Please choose a time first.', fillFields: 'Please fill in the highlighted fields.',
      menuOpen: 'Close menu', menuClosed: 'Open menu', langBtn: 'NL', langLabel: 'Schakel naar Nederlands',
      demo: (g, d, t) => `Demo: request for ${g} ${g === 1 ? 'person' : 'people'} on ${d} at ${t}. In the live version this goes to the restaurant.`,
      demoToast: 'Demo: nothing was sent.',
      mailOpened: (g, d, t) => `Your e-mail app opens with your request for ${g} on ${d} at ${t}.`,
      mailToast: 'Almost done, send the e-mail to confirm.',
      mail: { subject: 'Booking', people: 'ppl', name: 'Name', phone: 'Phone', guests: 'Guests', date: 'Date', time: 'Time', note: 'Note' },
    },
  };
  // First visit follows the browser language; afterwards the visitor's choice is remembered.
  let lang = (navigator.language || 'nl').toLowerCase().startsWith('nl') ? 'nl' : 'en';
  try { lang = localStorage.getItem('km-lang') || lang; } catch {}
  const L = () => I18N[lang];
  const dateLabel = d => `${L().days[d.getDay()]} ${d.getDate()} ${L().months[d.getMonth()]}`;

  function applyLang() {
    document.documentElement.lang = lang;
    document.title = L().title;
    $$('[data-en]').forEach(el => {
      if (el.dataset.nl === undefined) el.dataset.nl = el.innerHTML;
      el.innerHTML = lang === 'en' ? el.dataset.en : el.dataset.nl;
    });
    for (const attr of ['aria-label', 'placeholder']) {
      $$(`[data-en-${attr}]`).forEach(el => {
        const key = 'nl' + attr.replace('-', '');
        if (el.dataset[key] === undefined) el.dataset[key] = el.getAttribute(attr);
        el.setAttribute(attr, lang === 'en' ? el.getAttribute(`data-en-${attr}`) : el.dataset[key]);
      });
    }
    const btn = $('#langToggle');
    btn.textContent = L().langBtn;
    btn.setAttribute('aria-label', L().langLabel);
    btn.lang = lang === 'en' ? 'nl' : 'en';
    $$('[data-suffix]').forEach(el => { el.dataset.suffix = L().ordinal; if (el.dataset.done) el.textContent = el.dataset.count + L().ordinal; });
  }

  // Current time in Dordrecht, regardless of the visitor's timezone.
  function nowInDordt() {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Europe/Amsterdam', weekday: 'short', hour: 'numeric', minute: 'numeric', hourCycle: 'h23',
    }).formatToParts(new Date());
    const get = t => parts.find(p => p.type === t).value;
    const dayIdx = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(get('weekday'));
    return { dayIdx, hours: +get('hour') + +get('minute') / 60 };
  }

  // ---- Theme ----
  const root = document.documentElement;
  try { const t = localStorage.getItem('km-theme'); if (t) root.dataset.theme = t; } catch {}
  $('#themeToggle').addEventListener('click', () => {
    const dark = root.dataset.theme ? root.dataset.theme === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
    root.dataset.theme = dark ? 'light' : 'dark';
    try { localStorage.setItem('km-theme', root.dataset.theme); } catch {}
  });

  applyLang();

  // ---- Open/closed status + hours table ----
  function renderStatus() {
    const { dayIdx, hours } = nowInDordt();
    const today = HOURS[dayIdx];
    const pill = $('#statusPill'), text = $('#statusText');
    const isOpen = hours >= today.open && hours < today.close;
    pill.classList.toggle('open', isOpen);
    pill.classList.toggle('closed', !isOpen);
    if (isOpen) {
      const left = today.close - hours;
      text.textContent = left <= 1 ? L().closesAt(fmt(today.close)) : L().openUntil(fmt(today.close));
    } else if (hours < today.open) {
      text.textContent = L().opensToday(fmt(today.open));
    } else {
      const next = HOURS[(dayIdx + 1) % 7];
      text.textContent = L().opensTomorrow(fmt(next.open));
    }
    const order = [1, 2, 3, 4, 5, 6, 0];
    $('#hoursBody').innerHTML = order.map(i =>
      `<tr class="${i === dayIdx ? 'today' : ''}"><td data-today="${L().today}">${L().days[i][0].toUpperCase() + L().days[i].slice(1)}</td><td>${fmt(HOURS[i].open)} – ${fmt(HOURS[i].close)}</td></tr>`
    ).join('');
  }
  renderStatus();
  setInterval(renderStatus, 60_000);

  // ---- Nav: scrolled state, hide on scroll down, progress bar, active link ----
  const nav = $('.nav'), progress = $('.progress'), fab = $('.fab');
  let lastY = 0;
  function onScroll() {
    const y = scrollY;
    const max = document.documentElement.scrollHeight - innerHeight;
    progress.style.transform = `scaleX(${max > 0 ? y / max : 0})`;
    nav.classList.toggle('scrolled', y > 30);
    nav.classList.toggle('hidden', y > lastY && y > 400 && !$('#navLinks').classList.contains('open'));
    const reserveTop = $('#reserveren').getBoundingClientRect().top;
    fab.classList.toggle('show', y > innerHeight * 0.8 && reserveTop > innerHeight * 0.6);
    lastY = y;
  }
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  const links = $$('.nav-links a[href^="#"]:not(.btn)');
  const sectionObs = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (e.isIntersecting) links.forEach(a => a.classList.toggle('active', a.getAttribute('href') === '#' + e.target.id));
    });
  }, { rootMargin: '-45% 0px -50% 0px' });
  $$('main section[id]').forEach(s => sectionObs.observe(s));

  // Mobile menu
  const burger = $('#burger'), navLinks = $('#navLinks');
  const setMenu = open => {
    navLinks.classList.toggle('open', open);
    burger.setAttribute('aria-expanded', open);
    burger.setAttribute('aria-label', open ? L().menuOpen : L().menuClosed);
    document.body.style.overflow = open ? 'hidden' : '';
  };
  burger.addEventListener('click', () => setMenu(!navLinks.classList.contains('open')));
  navLinks.addEventListener('click', e => { if (e.target.closest('a')) setMenu(false); });
  addEventListener('keydown', e => { if (e.key === 'Escape') setMenu(false); });

  // ---- Reveal on scroll + counters ----
  const revealObs = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (!e.isIntersecting) return;
      e.target.classList.add('in');
      $$('[data-count]', e.target).forEach(countUp);
      revealObs.unobserve(e.target);
    });
  }, { threshold: 0.15 });
  $$('.reveal').forEach(el => revealObs.observe(el));

  function countUp(el) {
    const target = +el.dataset.count, suffix = el.dataset.suffix || '';
    const start = el.hasAttribute('data-plain') ? target - 60 : 0;
    if (reduceMotion) { el.textContent = target + suffix; el.dataset.done = 1; return; }
    const t0 = performance.now(), dur = 1600;
    const step = t => {
      const p = Math.min((t - t0) / dur, 1), eased = 1 - Math.pow(1 - p, 4);
      el.textContent = Math.round(start + (target - start) * eased) + (el.dataset.suffix || '');
      if (p < 1) requestAnimationFrame(step); else el.dataset.done = 1;
    };
    requestAnimationFrame(step);
  }

  // ---- Hero parallax: photo drifts on scroll, balloons follow the pointer ----
  if (!reduceMotion) {
    const photo = $('.hero-photo'), balloons = $('.balloons');
    addEventListener('scroll', () => {
      if (scrollY < innerHeight) photo.style.translate = `0 ${scrollY * 0.25}px`;
    }, { passive: true });
    addEventListener('pointermove', e => {
      if (scrollY > innerHeight) return;
      const x = e.clientX / innerWidth - 0.5, y = e.clientY / innerHeight - 0.5;
      balloons.style.transform = `translate(${x * -30}px, ${y * -20}px)`;
    });
  }

  // Gallery tiles show their photo once the file exists; until then the emoji placeholder stays.
  [['.g1', 'img/hero.jpg'], ['.g2', 'img/interieur.jpg'], ['.g3', 'img/terras.jpg']].forEach(([sel, src]) => {
    const img = new Image();
    img.onload = () => $(sel)?.classList.add('has-photo');
    img.src = src;
  });

  // ---- Magnetic buttons ----
  if (!reduceMotion && matchMedia('(hover: hover)').matches) {
    $$('.magnetic').forEach(btn => {
      btn.addEventListener('pointermove', e => {
        const r = btn.getBoundingClientRect();
        btn.style.transform = `translate(${(e.clientX - r.left - r.width / 2) * 0.25}px, ${(e.clientY - r.top - r.height / 2) * 0.35}px)`;
      });
      btn.addEventListener('pointerleave', () => { btn.style.transform = ''; });
    });
  }

  // ---- Menu: tabs, search, spotlight + tilt ----
  const tabs = $$('.tab'), indicator = $('.tab-indicator'), dishes = $$('.dish');
  let filter = 'all';
  function moveIndicator() {
    const active = $('.tab.active');
    indicator.style.width = active.offsetWidth + 'px';
    indicator.style.transform = `translateX(${active.offsetLeft}px)`;
  }
  function applyFilter() {
    const q = $('#menuSearch').value.trim().toLowerCase();
    let shown = 0;
    dishes.forEach((d, i) => {
      const matchCat = filter === 'all' || d.dataset.cat.split(' ').includes(filter);
      const matchQ = !q || d.textContent.toLowerCase().includes(q) || (d.dataset.tags || '').includes(q);
      const show = matchCat && matchQ;
      d.classList.toggle('hide', !show);
      if (show) {
        d.classList.remove('pop'); void d.offsetWidth;
        d.style.animationDelay = `${shown * 50}ms`;
        d.classList.add('pop');
        shown++;
      }
    });
    $('#menuEmpty').hidden = shown > 0;
  }
  tabs.forEach(tab => tab.addEventListener('click', () => {
    tabs.forEach(t => { t.classList.toggle('active', t === tab); t.setAttribute('aria-selected', t === tab); });
    filter = tab.dataset.filter;
    moveIndicator();
    applyFilter();
  }));
  $('#menuSearch').addEventListener('input', applyFilter);
  addEventListener('resize', moveIndicator);
  document.fonts?.ready.then(moveIndicator);
  moveIndicator();

  // Dish photos: drop a file at the card's data-photo path (e.g. img/calamares.jpg) and it
  // replaces the emoji automatically. Cards without a photo keep their emoji.
  dishes.forEach(d => {
    if (!d.dataset.photo) return;
    const img = new Image();
    img.className = 'dish-photo';
    img.alt = '';
    img.onload = () => { d.querySelector('.dish-emoji')?.remove(); d.prepend(img); };
    img.src = d.dataset.photo;
  });

  if (matchMedia('(hover: hover)').matches) {
    dishes.forEach(d => {
      d.addEventListener('pointermove', e => {
        const r = d.getBoundingClientRect();
        const x = e.clientX - r.left, y = e.clientY - r.top;
        d.style.setProperty('--mx', x + 'px');
        d.style.setProperty('--my', y + 'px');
        if (!reduceMotion) d.style.transform = `perspective(800px) rotateX(${(y / r.height - 0.5) * -6}deg) rotateY(${(x / r.width - 0.5) * 6}deg) translateY(-4px)`;
      });
      d.addEventListener('pointerleave', () => { d.style.transform = ''; });
    });
    const tilt = $('.tilt');
    if (tilt && !reduceMotion) {
      tilt.addEventListener('pointermove', e => {
        const r = tilt.getBoundingClientRect();
        tilt.style.transform = `perspective(1000px) rotateX(${((e.clientY - r.top) / r.height - 0.5) * -5}deg) rotateY(${((e.clientX - r.left) / r.width - 0.5) * 5}deg)`;
      });
      tilt.addEventListener('pointerleave', () => { tilt.style.transform = ''; });
    }
  }

  // ---- Reservation widget ----
  const state = { guests: 2, date: null, time: null };
  const guestsOut = $('#guests');
  $$('.stepper button').forEach(b => b.addEventListener('click', () => {
    state.guests = Math.min(40, Math.max(1, state.guests + +b.dataset.step));
    guestsOut.textContent = state.guests;
    guestsOut.classList.remove('bump'); void guestsOut.offsetWidth; guestsOut.classList.add('bump');
    $('#groupNote').hidden = state.guests < 10;
  }));

  const daysEl = $('#days'), timesEl = $('#times');

  function radio(container, btn) {
    $$('.chip-btn', container).forEach(b => b.setAttribute('aria-checked', b === btn));
  }

  function renderDays() {
    const base = new Date();
    daysEl.innerHTML = '';
    for (let i = 0; i < 14; i++) {
      const d = new Date(base.getFullYear(), base.getMonth(), base.getDate() + i);
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'chip-btn'; b.setAttribute('role', 'radio');
      b.setAttribute('aria-checked', 'false');
      b.innerHTML = `<small>${i === 0 ? L().today : i === 1 ? L().tomorrow : L().short[d.getDay()]}</small><b>${d.getDate()}</b> ${L().months[d.getMonth()]}`;
      b.addEventListener('click', () => { state.date = d; radio(daysEl, b); renderTimes(); });
      daysEl.appendChild(b);
      if (state.date ? d.toDateString() === state.date.toDateString() : i === 0) { state.date = d; b.setAttribute('aria-checked', 'true'); }
    }
  }

  function renderTimes(keep) {
    const h = HOURS[state.date.getDay()];
    const isToday = state.date.toDateString() === new Date().toDateString();
    const now = nowInDordt().hours;
    timesEl.innerHTML = '';
    const prev = keep && state.time;
    state.time = null;
    // Last seating 1.5h before closing, but not after 21:30.
    const last = Math.min(h.close - 1.5, 21.5);
    for (let t = Math.max(h.open, 11.5); t <= last; t += 0.5) {
      const label = `${String(Math.floor(t)).padStart(2, '0')}:${t % 1 ? '30' : '00'}`;
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'chip-btn'; b.textContent = label;
      b.setAttribute('role', 'radio'); b.setAttribute('aria-checked', 'false');
      if (isToday && t <= now + 0.5) b.disabled = true;
      b.addEventListener('click', () => { state.time = label; radio(timesEl, b); });
      timesEl.appendChild(b);
    }
    // Preselect a sensible dinner time if available, else the first free slot.
    const pref = $$('.chip-btn:not(:disabled)', timesEl).find(b => b.textContent === (prev || '18:30')) || $('.chip-btn:not(:disabled)', timesEl);
    if (pref) { pref.click(); timesEl.scrollLeft = pref.offsetLeft - timesEl.clientWidth / 2 + pref.offsetWidth / 2; }
    else timesEl.innerHTML = `<p class="muted" style="margin:0">${L().noTimes}</p>`;
  }
  renderDays();
  renderTimes();
  daysEl.scrollLeft = 0;

  $('#langToggle').addEventListener('click', () => {
    lang = lang === 'nl' ? 'en' : 'nl';
    try { localStorage.setItem('km-lang', lang); } catch {}
    applyLang();
    renderStatus();
    const scroll = daysEl.scrollLeft;
    renderDays();
    renderTimes(true);
    daysEl.scrollLeft = scroll;
    $('#formMsg').textContent = '';
    requestAnimationFrame(moveIndicator);
  });

  const toast = (msg) => {
    const t = $('#toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.remove('show'), 4200);
  };

  $('#reserveForm').addEventListener('submit', e => {
    e.preventDefault();
    const form = e.currentTarget;
    let ok = true;
    $$('input[required]', form).forEach(inp => {
      const bad = !inp.value.trim();
      inp.classList.toggle('invalid', bad);
      if (bad) ok = false;
    });
    if (!state.time) { ok = false; toast(L().pickTime); }
    if (!ok) { $('#formMsg').textContent = L().fillFields; return; }

    const d = state.date;
    const when = dateLabel(d), m = L().mail;
    const body = [
      `${m.name}: ${form.name.value}`,
      `${m.phone}: ${form.phone.value}`,
      `${m.guests}: ${state.guests}`,
      `${m.date}: ${when}`,
      `${m.time}: ${state.time}`,
      form.note.value ? `${m.note}: ${form.note.value}` : '',
    ].filter(Boolean).join('\n');
    const subject = `${m.subject} ${when} ${state.time} · ${state.guests} ${m.people}`;
    // Concept preview: don't send real booking requests to the restaurant.
    if (document.querySelector('.concept-banner')) {
      $('#formMsg').textContent = L().demo(state.guests, when, state.time);
      toast(L().demoToast);
      return;
    }
    location.href = `mailto:info@klandermuelen.nl?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    $('#formMsg').textContent = L().mailOpened(state.guests, when, state.time);
    toast(L().mailToast);
  });

  $('#year').textContent = new Date().getFullYear();
})();
