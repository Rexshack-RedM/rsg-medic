const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-medic';
let L = {};
let menuData = null;
let buyItem = null;

const $ = (id) => document.getElementById(id);
const t = (key, ...args) => {
    let s = L[key] || key;
    args.forEach((a) => { s = s.replace(/%s/, a); });
    return s;
};
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => null);
}

function applyStrings() {
    document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
    $('field-refresh').title = t('ui_refresh');
}

function fmtTime(sec) {
    const m = Math.floor(sec / 60), s = sec % 60;
    return `${m}:${String(s).padStart(2, '0')}`;
}

/* ---------- death screen ---------- */
function deathUpdate(d) {
    const ready = d.remaining <= 0;
    $('death-label').textContent = ready ? t('ui_respawn_ready') : t('ui_respawn_in');
    $('death-time').textContent = ready ? '' : fmtTime(d.remaining);
    const pct = d.total > 0 ? Math.max(0, Math.min(100, (1 - d.remaining / d.total) * 100)) : 100;
    const fill = $('death-fill');
    fill.style.width = pct + '%';
    fill.className = 'fill ' + (ready ? 'stat-good' : pct > 50 ? 'stat-warn' : 'stat-bad');
    $('death-medics').textContent = d.medics;
    $('key-respawn').classList.toggle('disabled', !ready);

    const alert = $('key-alert');
    const noMedics = d.medics <= 0;
    const idleText = d.autoMedic
        ? (d.autoMedicCost > 0 ? t('ui_automedic_key_cost', d.autoMedicCost) : t('ui_automedic_key'))
        : t('ui_alert_key');
    alert.textContent = amActive ? t('ui_am_key_active') : d.alertWait > 0 ? t('ui_alert_wait', d.alertWait) : idleText;
    alert.classList.toggle('disabled', amActive || d.alertWait > 0 || (noMedics && !d.autoMedic));
}

/* ---------- travelling doctor status ---------- */
let amActive = false;
let amHideTimer = null;
const AM_STEPS = { dispatched: 1, riding: 2, arrived: 3, walking: 3, treating: 4 };

function autoMedicStatus(d) {
    const box = $('am-status');
    clearTimeout(amHideTimer);
    if (d.stage === 'hide') {
        // keep a final message on screen briefly
        if (box.classList.contains('bad') || box.classList.contains('good')) {
            amHideTimer = setTimeout(() => box.classList.add('hidden'), 4000);
        } else box.classList.add('hidden');
        amActive = false;
        return;
    }
    box.classList.remove('hidden', 'bad', 'good');
    const step = AM_STEPS[d.stage] || 0;
    amActive = step > 0;
    box.querySelectorAll('.am-steps span').forEach((el) => {
        const n = +el.dataset.step;
        el.classList.toggle('done', n < step);
        el.classList.toggle('current', n === step);
    });
    let text = t('ui_am_' + d.stage), pct = 0;
    if (d.stage === 'riding') { text = t('ui_am_riding', d.distance); pct = d.progress; }
    if (d.stage === 'treating') pct = d.progress;
    if (d.stage === 'arrived' || d.stage === 'walking') pct = 1;
    if (d.stage === 'cancelled' || d.stage === 'failed') box.classList.add('bad');
    $('am-text').textContent = text;
    $('am-dist').textContent = d.stage === 'riding' ? `${d.distance}m` : '';
    $('am-fill').style.width = Math.round((pct || 0) * 100) + '%';
}

/* ---------- doctor's office ---------- */
function renderMenu(d) {
    menuData = d;
    $('menu-title').textContent = d.location;
    $('duty-state').textContent = d.onduty ? t('ui_duty_on') : t('ui_duty_off');
    $('duty-btn').textContent = d.onduty ? t('ui_go_off_duty') : t('ui_go_on_duty');
    $('boss-row').classList.toggle('hidden', !d.isBoss);
    $('stash-row').classList.toggle('disabled', !d.onduty);

    $('supplies').innerHTML = d.items.map((i) => `
        <div class="row ${d.onduty ? '' : 'disabled'}" data-item="${esc(i.item)}">
            <div class="badge-icon">✚</div>
            <div class="row-body"><div class="row-title">${esc(i.label)}</div></div>
            <span class="pill">$${esc(i.price)}</span>
        </div>`).join('');
    $('menu').classList.remove('hidden');
}

function openBuy(item) {
    buyItem = menuData.items.find((i) => i.item === item);
    if (!buyItem) return;
    $('modal-title').textContent = `${t('ui_buy')} ${buyItem.label}`;
    $('modal-amount').max = menuData.maxAmount;
    $('modal-amount').value = 1;
    updateTotal();
    $('modal-wrap').classList.remove('hidden');
    $('modal-amount').focus();
}

function updateTotal() {
    const amt = clampAmount();
    $('modal-total').textContent = `$${(buyItem.price * amt).toFixed(2).replace(/\.00$/, '')}`;
}

function clampAmount() {
    const v = Math.floor(Number($('modal-amount').value) || 1);
    return Math.max(1, Math.min(menuData.maxAmount || 50, v));
}

function closeModal() { $('modal-wrap').classList.add('hidden'); buyItem = null; }

/* ---------- field menu ---------- */
function renderField(patients) {
    const box = $('patients');
    if (!patients.length) {
        box.innerHTML = `<div class="empty">${esc(t('ui_no_patients'))}</div>`;
    } else {
        box.innerHTML = patients.map((p) => {
            const cls = p.health > 66 ? 'stat-good' : p.health > 33 ? 'stat-warn' : 'stat-bad';
            const status = p.dead
                ? `<span class="pill bad">${esc(t('ui_unconscious'))}</span>`
                : `<div class="track small"><div class="fill ${cls}" style="width:${p.health}%"></div></div>`;
            const btn = p.dead
                ? `<button class="wood-btn" data-act="revive" data-id="${p.id}">${esc(t('ui_revive'))}</button>`
                : `<button class="wood-btn" data-act="treat" data-id="${p.id}" ${p.health >= 100 ? 'disabled' : ''}>${esc(t('ui_treat'))}</button>`;
            return `
            <div class="row static">
                <div class="badge-icon">${p.dead ? '✝' : '♥'}</div>
                <div class="row-body">
                    <div class="row-title">${esc(p.name)}</div>
                    <div class="row-desc">#${p.id} · ${p.dist}m</div>
                    ${status}
                </div>
                <div class="row-actions">${btn}</div>
            </div>`;
        }).join('');
    }
    $('field').classList.remove('hidden');
}

/* ---------- close ---------- */
function closeAll(notify = true) {
    closeModal();
    $('menu').classList.add('hidden');
    $('field').classList.add('hidden');
    if (notify) post('close');
}

/* ---------- events ---------- */
window.addEventListener('message', (e) => {
    const d = e.data;
    switch (d.action) {
        case 'death':
            editPreview = false;
            $('death').classList.toggle('hidden', !d.show);
            if (d.show) $('death-fee').textContent = `$${d.fee}`;
            break;
        case 'deathUpdate': deathUpdate(d); break;
        case 'automedic': autoMedicStatus(d); break;
        case 'editMode': setEditMode(d.enabled, false); break;
        case 'menu': $('field').classList.add('hidden'); renderMenu(d.data); break;
        case 'field': $('menu').classList.add('hidden'); renderField(d.patients || []); break;
        case 'closeAll': closeAll(false); break;
    }
});

document.addEventListener('click', (e) => {
    if (e.target.closest('[data-close]')) return closeAll();

    const supply = e.target.closest('#supplies .row');
    if (supply && !supply.classList.contains('disabled')) return openBuy(supply.dataset.item);

    if (e.target.closest('#stash-row:not(.disabled)')) { closeAll(false); return post('stash'); }
    if (e.target.closest('#boss-row')) { closeAll(false); return post('boss'); }

    const act = e.target.closest('[data-act]');
    if (act && !act.disabled) { closeAll(false); return post('action', { kind: act.dataset.act, id: Number(act.dataset.id) }); }
});

$('duty-btn').addEventListener('click', () => post('toggleDuty'));
$('field-refresh').addEventListener('click', () => post('refreshField'));
$('modal-amount').addEventListener('input', updateTotal);
$('modal-cancel').addEventListener('click', closeModal);
$('modal-confirm').addEventListener('click', () => {
    if (!buyItem) return;
    post('buy', { item: buyItem.item, amount: clampAmount() });
    closeModal();
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (document.body.classList.contains('editing')) return setEditMode(false, true);
    if (!$('modal-wrap').classList.contains('hidden')) return closeModal();
    if (!$('menu').classList.contains('hidden') || !$('field').classList.contains('hidden')) closeAll();
});

/* ---------- movable panels ---------- */
const POS_KEY = (id) => 'rsg-medic-pos-' + id;
const store = {
    get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } },
    set(k, v) { try { v === null ? localStorage.removeItem(k) : localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} },
};

function placePanel(el, x, y) {
    x = Math.max(0, Math.min(window.innerWidth - el.offsetWidth, x));
    y = Math.max(0, Math.min(window.innerHeight - 40, y));
    el.classList.add('moved');
    el.style.left = x + 'px';
    el.style.top = y + 'px';
}

function restorePanel(el) {
    const p = store.get(POS_KEY(el.id));
    if (p) placePanel(el, p.x, p.y);
}

function makeDraggable(el) {
    const handle = el.querySelector('.panel-header');
    if (!handle) return;
    restorePanel(el);
    handle.addEventListener('mousedown', (e) => {
        if (e.button !== 0 || e.target.closest('button, .circle-btn, input')) return;
        const r = el.getBoundingClientRect();
        const dx = e.clientX - r.left, dy = e.clientY - r.top;
        const move = (ev) => placePanel(el, ev.clientX - dx, ev.clientY - dy);
        const up = () => {
            document.removeEventListener('mousemove', move);
            document.removeEventListener('mouseup', up);
            if (el.classList.contains('moved')) store.set(POS_KEY(el.id), { x: parseInt(el.style.left), y: parseInt(el.style.top) });
        };
        document.addEventListener('mousemove', move);
        document.addEventListener('mouseup', up);
        e.preventDefault();
    });
    handle.addEventListener('dblclick', () => { // reset to default spot
        store.set(POS_KEY(el.id), null);
        el.classList.remove('moved');
        el.style.left = el.style.top = '';
    });
}
['death', 'menu', 'field'].forEach((id) => makeDraggable($(id)));

let editPreview = false;
function setEditMode(on, notify) {
    document.body.classList.toggle('editing', on);
    $('edit-hint').classList.toggle('hidden', !on);
    const death = $('death');
    if (on && death.classList.contains('hidden')) { editPreview = true; death.classList.remove('hidden'); }
    if (!on && editPreview) { editPreview = false; death.classList.add('hidden'); }
    if (!on && notify) post('editDone');
}
$('edit-done').addEventListener('click', () => setEditMode(false, true));

function loadStrings(tries = 0) {
    post('ready').then((strings) => {
        if (strings) { L = strings; applyStrings(); }
        else if (tries < 10) setTimeout(() => loadStrings(tries + 1), 1000);
    });
}
loadStrings();
