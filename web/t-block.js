/**
 * t-block.js — interactive timeclock widget for markdown note apps
 *
 * Renders ```t ... ``` code fences as live timer dashboards.
 * Requires a running /api/t/* endpoint (t-server.py or nb-web).
 *
 * Usage (with marked.js):
 *   import { registerTBlock, renderTBlocks } from './t-block.js';
 *   registerTBlock(marked, { apiBase: 'http://localhost:5001' });
 *   // after marked.parse(), call:
 *   await renderTBlocks(document.querySelector('.content'));
 *
 * Usage (manual, no marked):
 *   // Create <div class="nb-t-block" data-period="today"></div> in your HTML, then:
 *   await renderTBlocks(container);
 */

const DEFAULT_API = '';   // same origin by default; set to 'http://localhost:5001' for standalone

function _esc(s) {
    return String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function _fmt(s) {
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    return h > 0 ? `${h}h ${String(m).padStart(2,'0')}m` : `${m}m`;
}

const _timers = new Map();

export function registerTBlock(marked, { apiBase = DEFAULT_API } = {}) {
    marked.use({ renderer: {
        code({ text, lang }) {
            if (lang !== 't') return false;
            const period = text.trim().replace(/"/g, '&quot;');
            return `<div class="nb-t-block" data-period="${period}" data-api="${_esc(apiBase)}"><span class="nb-t-spin">⟳</span></div>`;
        }
    }});
}

export async function renderTBlocks(container, { apiBase = DEFAULT_API } = {}) {
    for (const el of container.querySelectorAll('.nb-t-block'))
        await loadTBlock(el, apiBase);
}

export async function loadTBlock(el, apiBase) {
    const base   = el.dataset.api || apiBase || DEFAULT_API;
    const period = el.dataset.period || 'today';
    const id     = _timers.get(el);
    if (id) { clearInterval(id); _timers.delete(el); }
    el.innerHTML = '<span class="nb-t-spin">⟳</span>';
    try {
        const [status, report] = await Promise.all([
            fetch(`${base}/api/t/status`).then(r => r.json()),
            period
                ? fetch(`${base}/api/t/report?period=${encodeURIComponent(period)}`).then(r => r.json())
                : Promise.resolve(null),
        ]);
        _buildBlock(el, status, report, period, base);
    } catch(e) {
        el.innerHTML = `<span class="nb-t-error">⚠ ${_esc(e.message)}</span>`;
    }
}

function _buildBlock(el, status, report, period, base) {
    el.innerHTML = '';

    // ── status row ──
    const hdr = document.createElement('div');
    hdr.className = 'nb-t-header';

    const statusEl = document.createElement('div');
    statusEl.className = 'nb-t-status';

    if (status.state === 'in') {
        const elapsed = status.elapsed_seconds || 0;
        statusEl.innerHTML =
            `<span class="nb-t-dot nb-t-dot-in">⏱</span>` +
            `<span class="nb-t-account">${_esc(status.account)}</span>` +
            (status.desc ? `<span class="nb-t-desc">${_esc(status.desc)}</span>` : '') +
            `<span class="nb-t-elapsed">${_fmt(elapsed)}</span>`;
    } else if (status.state === 'out') {
        statusEl.innerHTML =
            `<span class="nb-t-dot nb-t-dot-out">◌</span>` +
            `<span class="nb-t-out-label">OUT</span>` +
            `<span class="nb-t-desc">${_esc(status.account)} · ${_esc(status.last_out)}</span>`;
    } else {
        statusEl.innerHTML = `<span class="nb-t-dot nb-t-dot-out">○</span><span class="nb-t-desc">No entries</span>`;
    }

    // ── action buttons ──
    const acts = document.createElement('div');
    acts.className = 'nb-t-actions';

    if (status.state === 'in') {
        const outBtn = document.createElement('button');
        outBtn.className = 'nb-t-btn nb-t-out-btn';
        outBtn.title = 'Clock out'; outBtn.textContent = '◼ Out';
        outBtn.addEventListener('click', async () => {
            outBtn.disabled = true;
            const d = await fetch(`${base}/api/t/out`, { method: 'POST' }).then(r => r.json()).catch(() => ({}));
            if (d.success) loadTBlock(el, base); else outBtn.disabled = false;
        });
        acts.appendChild(outBtn);
    } else {
        const inBtn = document.createElement('button');
        inBtn.className = 'nb-t-btn nb-t-in-btn';
        inBtn.title = 'Clock in'; inBtn.textContent = '⏱ In';
        inBtn.addEventListener('click', () => _showClockInForm(el, status, inBtn, base));
        acts.appendChild(inBtn);
    }

    const refBtn = document.createElement('button');
    refBtn.className = 'nb-t-btn';
    refBtn.title = 'Refresh'; refBtn.textContent = '↻';
    refBtn.addEventListener('click', () => loadTBlock(el, base));
    acts.appendChild(refBtn);

    hdr.append(statusEl, acts);
    el.appendChild(hdr);

    // ── time report ──
    if (report?.rows?.length) {
        const rpt = document.createElement('div');
        rpt.className = 'nb-t-report';
        report.rows.forEach(row => {
            const r = document.createElement('div');
            r.className = 'nb-t-row';
            r.innerHTML = `<span class="nb-t-r-acct">${_esc(row.account)}</span><span class="nb-t-r-time">${_fmt(row.seconds)}</span>`;
            rpt.appendChild(r);
        });
        const tot = document.createElement('div');
        tot.className = 'nb-t-row nb-t-total';
        tot.innerHTML = `<span class="nb-t-r-acct">${_esc(period || 'today')} total</span><span class="nb-t-r-time">${_fmt(report.total_seconds)}</span>`;
        rpt.appendChild(tot);
        el.appendChild(rpt);
    }

    // ── live elapsed ticker ──
    if (status.state === 'in') {
        const startMs = Date.now() - (status.elapsed_seconds || 0) * 1000;
        const tid = setInterval(() => {
            const elapsedEl = el.querySelector('.nb-t-elapsed');
            if (!elapsedEl || !el.isConnected) { clearInterval(tid); _timers.delete(el); return; }
            elapsedEl.textContent = _fmt(Math.floor((Date.now() - startMs) / 1000));
        }, 30000);
        _timers.set(el, tid);
    }
}

async function _showClockInForm(el, status, trigger, base) {
    const existing = el.querySelector('.nb-t-clock-in-form');
    if (existing) { existing.remove(); trigger?.classList.remove('active'); return; }
    trigger?.classList.add('active');

    const accounts = await fetch(`${base}/api/t/accounts`)
        .then(r => r.json()).then(d => d.accounts || []).catch(() => []);

    const form = document.createElement('div');
    form.className = 'nb-t-clock-in-form';

    const sel = document.createElement('select');
    sel.className = 'nb-t-acct-sel';
    accounts.forEach(a => {
        const opt = document.createElement('option');
        opt.value = a; opt.textContent = a; sel.appendChild(opt);
    });
    if (!accounts.length) {
        const opt = document.createElement('option');
        opt.value = ''; opt.textContent = 'No recent accounts'; sel.appendChild(opt);
    }
    if (status.account) {
        const match = [...sel.options].find(o => o.value === status.account);
        if (match) match.selected = true;
    }

    const customInput = document.createElement('input');
    customInput.type = 'text'; customInput.className = 'nb-t-custom-acct';
    customInput.placeholder = 'or type account…';

    const descInput = document.createElement('input');
    descInput.type = 'text'; descInput.className = 'nb-t-desc-input';
    descInput.placeholder = 'description (optional)';

    const goBtn = document.createElement('button');
    goBtn.className = 'nb-t-btn nb-t-in-btn'; goBtn.textContent = '⏱ In';

    const cancelBtn = document.createElement('button');
    cancelBtn.className = 'nb-t-btn'; cancelBtn.textContent = '✕';

    form.append(sel, customInput, descInput, goBtn, cancelBtn);
    el.appendChild(form);
    customInput.focus();

    const doClockIn = async () => {
        const account = customInput.value.trim() || sel.value;
        if (!account) { customInput.focus(); return; }
        goBtn.disabled = true;
        const d = await fetch(`${base}/api/t/in`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ account, desc: descInput.value.trim() }),
        }).then(r => r.json()).catch(() => ({}));
        if (d.success) loadTBlock(el, base);
        else { goBtn.disabled = false; if (d.error) alert(d.error); }
    };

    goBtn.addEventListener('click', doClockIn);
    [customInput, descInput].forEach(i =>
        i.addEventListener('keydown', e => { if (e.key === 'Enter') doClockIn(); }));
    cancelBtn.addEventListener('click', () => { form.remove(); trigger?.classList.remove('active'); });
}
