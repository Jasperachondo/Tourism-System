document.addEventListener('DOMContentLoaded', () => {
    const body = document.body;
    const role = body.dataset.role || 'admin';
    const page = body.dataset.page;
    const crumb = body.dataset.crumb || '';
    const isSuper = role === 'superadmin';
    const user = isSuper ? { name: 'Rafael Santos', init: 'RS', label: 'Superadmin' }
                         : { name: 'Maria Reyes', init: 'MR', label: 'Admin' };

    /* ---------- Build sidebar / topbar / footer ---------- */
    const nav = [
        ['Overview', isSuper ? 'superadmin-overview.html' : 'admin-overview.html', 'overview', '▦'],
        ['Content management', 'admin-content.html', 'content', '◎'],
        ['Bookings & inquiries', 'admin-bookings.html', 'bookings', '▤']
    ];
    if (isSuper) nav.push(['Users & admins', 'superadmin-users.html', 'users', '☻']);

    const accessText = isSuper ? 'Oversee tourism content, accounts, and role administration.'
                               : 'Care for destinations, local establishments, and reservations.';

    body.insertAdjacentHTML('afterbegin', `
    <aside class="sidebar">
        <div>
            <a href="home.html" class="brand"><span class="brand-mark">✦</span><span class="serif">Pilipinas Travel</span></a>
            <div class="tagline">Tourism Management</div>
        </div>
        <div>
            <div class="side-label">${isSuper ? 'System' : 'Admin'} workspace</div>
            <nav class="side-nav">
                ${nav.map(n => `<a href="${n[1]}" class="${n[2] === page ? 'active' : ''}"><span class="ico">${n[3]}</span>${n[0]}</a>`).join('')}
            </nav>
        </div>
        <div class="access-box"><strong>${user.label} access</strong><p>${accessText}</p></div>
        <div class="side-bottom">
            <a href="home.html" class="view-site"><span>↗</span> View travel website</a>
            <div class="side-user">
                <div class="avatar">${user.init}</div>
                <div class="who">${user.name}<small>${user.label}</small></div>
                <a href="home.html" title="Log out" aria-label="Log out">⇥</a>
            </div>
        </div>
    </aside>`);

    const main = document.querySelector('main');
    main.classList.add('content');
    const wrap = document.createElement('div');
    wrap.className = 'admin-main';
    wrap.innerHTML = `
    <div class="topbar">
        <div class="crumbs">${user.label} <span class="sep">/</span> <b>${crumb}</b></div>
        <div class="top-right"><span>04 November 2026</span><span aria-label="Notifications">🔔</span><span class="role-pill">${user.label}</span></div>
    </div>`;
    body.insertBefore(wrap, main);
    wrap.appendChild(main);
    wrap.insertAdjacentHTML('beforeend', `<footer class="admin-foot"><span>Pilipinas Travel · Tourism management</span><span>Wander intentionally. Support sustainably.</span></footer>`);

    /* ---------- Helpers ---------- */
    const $ = (s, r = document) => r.querySelector(s);
    const $$ = (s, r = document) => [...r.querySelectorAll(s)];

    const toast = document.createElement('div');
    toast.className = 'toast';
    body.appendChild(toast);
    let toastTimer;
    window.showToast = msg => {
        toast.textContent = msg;
        toast.classList.add('show');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => toast.classList.remove('show'), 2600);
    };

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay';
    overlay.innerHTML = `<div class="modal-box" role="dialog" aria-modal="true">
        <h3 id="mTitle"></h3><p id="mText"></p>
        <div class="btns"><button class="btn btn-sm btn-light" id="mCancel" type="button">Cancel</button>
        <button class="btn btn-sm btn-danger" id="mOk" type="button">Confirm</button></div></div>`;
    body.appendChild(overlay);
    let onConfirm = null;
    const closeModal = () => overlay.classList.remove('open');
    window.confirmDialog = (title, text, okLabel, cb) => {
        $('#mTitle').textContent = title;
        $('#mText').textContent = text;
        $('#mOk').textContent = okLabel || 'Confirm';
        onConfirm = cb;
        overlay.classList.add('open');
    };
    $('#mCancel').onclick = closeModal;
    $('#mOk').onclick = () => { closeModal(); if (onConfirm) onConfirm(); };
    overlay.addEventListener('click', e => { if (e.target === overlay) closeModal(); });
    document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });

    /* ---------- Tabs ---------- */
    $$('[data-tabs]').forEach(group => {
        const btns = $$('[data-tab]', group);
        btns.forEach(b => b.addEventListener('click', () => {
            btns.forEach(x => x.classList.toggle('active', x === b));
            $$('[data-panel]').forEach(p => p.classList.toggle('active', p.dataset.panel === b.dataset.tab));
        }));
    });

    /* ---------- Table search + select filters ---------- */
    $$('table[data-filterable]').forEach(table => {
        const id = table.id;
        const search = $(`input[data-filter-for="${id}"]`);
        const selects = $$(`select[data-filter-for="${id}"]`);
        const empty = $(`#${id}-empty`);
        const run = () => {
            const q = search ? search.value.trim().toLowerCase() : '';
            let shown = 0;
            $$('tbody tr', table).forEach(tr => {
                let ok = tr.textContent.toLowerCase().includes(q);
                selects.forEach(s => { if (s.value && ok) ok = (tr.dataset[s.dataset.key] || '') === s.value; });
                tr.hidden = !ok;
                if (ok) shown++;
            });
            if (empty) empty.hidden = shown > 0;
            const count = $(`#${id}-count`);
            if (count) count.textContent = shown;
        };
        if (search) search.addEventListener('input', run);
        selects.forEach(s => s.addEventListener('change', run));
        table._refilter = run;
    });

    /* ---------- Delete confirmation (data-delete) ---------- */
    $$('[data-delete]').forEach(btn => btn.addEventListener('click', e => {
        e.preventDefault();
        const name = btn.dataset.delete;
        confirmDialog('Delete listing?', `"${name}" will be removed. Review existing reservations before removing a published item. This cannot be undone.`, 'Delete', () => {
            const row = btn.closest('tr, .item');
            if (row) row.remove();
            showToast(`${name} deleted`);
            if (btn.dataset.redirect) setTimeout(() => location.href = btn.dataset.redirect, 900);
        });
    }));

    /* ---------- Pagination demo (single page) ---------- */
    $$('.pager button:not(.current)').forEach(b => b.addEventListener('click', () => showToast('No more pages in this demo')));

    /* ---------- Generic form validation (data-validate) ---------- */
    const validate = form => {
        let ok = true;
        $$('[required]', form).forEach(el => {
            if (el.closest('[hidden]')) return;
            const field = el.closest('.field');
            let msg = '';
            if (!el.value.trim()) msg = 'This field is required.';
            else if (el.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(el.value)) msg = 'Enter a valid email address.';
            if (field) {
                field.classList.toggle('invalid', !!msg);
                let err = $('.error', field);
                if (!err) { err = document.createElement('div'); err.className = 'error'; field.appendChild(err); }
                err.textContent = msg;
            }
            if (msg) ok = false;
        });
        return ok;
    };
    $$('form[data-validate]').forEach(f => f.addEventListener('input', e => {
        const field = e.target.closest('.field');
        if (field && field.classList.contains('invalid') && e.target.value.trim()) {
            field.classList.remove('invalid');
            const err = $('.error', field); if (err) err.textContent = '';
        }
    }));

    /* ---------- Add / edit item form ---------- */
    const itemForm = $('#itemForm');
    if (itemForm) {
        const types = $$('.type-card input');
        const labels = { destination: 'Destination', stay: 'Stay', eatery: 'Eatery' };
        const names = { destination: 'e.g. Fort Santiago', stay: 'e.g. A locally owned eco-lodge', eatery: 'e.g. A family-run kitchen in Silang' };
        const cats = {
            destination: ['Cultural Sites', 'Natural Parks', 'Historic Landmarks', 'Beaches & Islands'],
            stay: ['Eco Stays & Hotels', 'Villa', 'Boutique Resort', 'Homestay'],
            eatery: ['Restaurants & Cafes', 'Street Food', 'Bars & Kitchens']
        };
        const applyType = () => {
            if (!types.length) return;
            const t = (types.find(x => x.checked) || types[0]).value;
            types.forEach(x => x.closest('.type-card').classList.toggle('checked', x.checked));
            $$('.type-section').forEach(s => s.hidden = s.dataset.type !== t);
            const nl = $('#nameLabel'); if (nl) nl.textContent = labels[t] + ' name *';
            const ni = $('#itemName'); if (ni && !ni.dataset.locked) ni.placeholder = names[t];
            const cat = $('#itemCategory');
            if (cat && !cat.dataset.locked) cat.innerHTML = `<option value="">Select ${labels[t].toLowerCase()} category</option>` + cats[t].map(c => `<option>${c}</option>`).join('');
            const pub = $('#publishBtn'); if (pub) pub.textContent = 'Publish ' + labels[t].toLowerCase();
            const nb = $('#newBadge'); if (nb) nb.textContent = 'New ' + labels[t].toLowerCase();
        };
        types.forEach(x => x.addEventListener('change', applyType));
        applyType();

        // cover image upload preview
        const file = $('#coverFile'), drop = $('#dropZone');
        if (file && drop) {
            drop.addEventListener('click', () => file.click());
            drop.addEventListener('dragover', e => e.preventDefault());
            drop.addEventListener('drop', e => { e.preventDefault(); if (e.dataTransfer.files[0]) { file.files = e.dataTransfer.files; file.dispatchEvent(new Event('change')); } });
            file.addEventListener('change', () => {
                const f = file.files[0]; if (!f) return;
                if (!/image\/(jpeg|png)/.test(f.type)) { showToast('Please choose a JPG or PNG image'); file.value = ''; return; }
                if (f.size > 5 * 1024 * 1024) { showToast('Image must be 5 MB or smaller'); file.value = ''; return; }
                drop.innerHTML = `<img src="${URL.createObjectURL(f)}" alt="Cover preview"><b>${f.name}</b><span>Click to replace</span>`;
            });
        }
        // visibility hint
        const vis = $('#visibility');
        if (vis) vis.addEventListener('change', () => {
            const hint = $('#visHint');
            if (hint) hint.textContent = vis.value === 'Draft' ? 'Drafts stay private until you choose to publish them.' : 'Published items appear on the travel website once saved.';
        });

        const status = $('#saveStatus');
        $('#saveDraft')?.addEventListener('click', () => { if (status) status.textContent = 'Draft saved just now.'; showToast('Draft saved'); });
        $('#cancelBtn')?.addEventListener('click', e => { e.preventDefault(); location.href = 'admin-content.html'; });
        itemForm.addEventListener('submit', e => {
            e.preventDefault();
            if (!validate(itemForm)) { showToast('Please fill in the required fields'); return; }
            showToast(itemForm.dataset.mode === 'edit' ? 'Changes saved' : 'Listing published');
            if (status) status.textContent = 'Saved just now.';
            setTimeout(() => location.href = 'admin-content.html', 1000);
        });
    }

    /* ---------- Bookings ---------- */
    const bTable = $('#bookingsTable');
    if (bTable) {
        const badgeClass = { Pending: 'amber', Confirmed: 'green', Completed: 'green', Cancelled: 'red' };
        const counts = { pending: $('#cPending'), confirmed: $('#cConfirmed') };
        const rows = $$('tbody tr', bTable);
        let current = null;
        const select = tr => {
            current = tr;
            rows.forEach(r => r.classList.toggle('selected', r === tr));
            const d = tr.dataset;
            $('#sRef').textContent = d.ref;
            $('#sTitle').textContent = d.pkg;
            $('#sMeta').textContent = d.meta;
            $('#sGuest').textContent = `${d.guest} · ${d.headcount}`;
            $('#sContact').textContent = d.contact;
            $('#sImg').src = d.img;
            $('#sBase').textContent = d.base; $('#sAir').textContent = d.air; $('#sIns').textContent = d.ins;
            $('#sTotal').textContent = d.total;
            $('#sNotes').textContent = 'Special Requests: ' + d.notes;
            const b = $('#sStatus'); b.textContent = d.status; b.className = 'badge ' + badgeClass[d.status];
            const btn = $('#confirmBtn'); btn.disabled = d.status !== 'Pending';
            btn.style.opacity = btn.disabled ? .5 : 1;
        };
        rows.forEach(r => r.addEventListener('click', () => select(r)));
        $('#confirmBtn').addEventListener('click', () => {
            if (!current || current.dataset.status !== 'Pending') return;
            current.dataset.status = 'Confirmed';
            const b = $('.badge', current); b.textContent = 'Confirmed'; b.className = 'badge green';
            counts.pending.textContent = +counts.pending.textContent - 1;
            counts.confirmed.textContent = +counts.confirmed.textContent + 1;
            select(current);
            showToast(`${current.dataset.ref} confirmed`);
        });
        // status stat-cards filter the table
        $$('.stat.filter').forEach(card => card.addEventListener('click', () => {
            const on = card.classList.contains('on');
            $$('.stat.filter').forEach(c => c.classList.remove('on'));
            const sel = $('#statusFilter');
            if (on) sel.value = ''; else { card.classList.add('on'); sel.value = card.dataset.status || ''; }
            sel.dispatchEvent(new Event('change'));
        }));
        $('#statusFilter').addEventListener('change', e => {
            $$('.stat.filter').forEach(c => c.classList.toggle('on', !!e.target.value && c.dataset.status === e.target.value));
        });
        $('#exportBtn')?.addEventListener('click', () => {
            const lines = [['Reference', 'Guest', 'Package', 'Check-in/out', 'Headcount', 'Total', 'Status']];
            rows.filter(r => !r.hidden).forEach(r => lines.push([r.dataset.ref, r.dataset.guest, r.dataset.pkg, r.dataset.dates, r.dataset.headcount, r.dataset.total, r.dataset.status]));
            const csv = lines.map(l => l.map(v => `"${v}"`).join(',')).join('\n');
            const a = document.createElement('a');
            a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
            a.download = 'reservations.csv'; a.click();
        });
        select(rows[0]);

        // inquiries
        const inq = $$('.inq-item');
        inq.forEach(i => i.addEventListener('click', () => {
            inq.forEach(x => x.classList.remove('sel'));
            i.classList.add('sel');
            $('#iWhen').textContent = `${i.dataset.id} · ${i.dataset.when}`;
            $('#iMsg').textContent = `“${i.dataset.msg}”`;
            $('#iMail').textContent = i.dataset.mail;
            $('#inqDetail').dataset.active = i.dataset.id;
        }));
        const markReplied = () => {
            const id = $('#inqDetail').dataset.active;
            const item = inq.find(i => i.dataset.id === id);
            if (!item) return;
            const b = $('.badge', item); b.textContent = 'Replied'; b.className = 'badge green';
            showToast(`${id} marked as replied`);
        };
        $('#markReplied').addEventListener('click', markReplied);
        $('#replyBtn').addEventListener('click', () => {
            const id = $('#inqDetail').dataset.active;
            const item = inq.find(i => i.dataset.id === id);
            if (item) location.href = `mailto:${item.dataset.mail}?subject=Re: Your Pilipinas Travel inquiry`;
        });
    }

    /* ---------- Users & admins (superadmin) ---------- */
    const uTable = $('#usersTable');
    if (uTable) {
        const roleClass = { superadmin: '', admin: '', user: 'plain' };
        let target = uTable.querySelector('tr.selected');
        const rolePick = $('#newRole');
        const applyBtn = $('#applyRole');
        const renderTarget = () => {
            if (!target) return;
            $('#rName').textContent = target.dataset.name;
            $('#rMail').textContent = target.dataset.mail;
            $('#rCurrent').textContent = 'Current: ' + target.dataset.role;
            rolePick.value = target.dataset.role;
            updateNote();
        };
        const updateNote = () => {
            const chips = $$('.role-chips span');
            chips.forEach(c => c.classList.toggle('on', c.textContent === rolePick.value));
            const cur = target.dataset.role, nw = rolePick.value;
            const note = $('#roleNote');
            if (cur === nw) note.textContent = 'No role change selected.';
            else note.textContent = `Unsaved change: ${cur} → ${nw}.` + (nw === 'user' ? ` ${target.dataset.name.split(' ')[0]} will lose management access. Review carefully before applying.` : '');
            applyBtn.disabled = cur === nw; applyBtn.style.opacity = applyBtn.disabled ? .5 : 1;
        };
        const rows = () => $$('tbody tr', uTable);
        const pickRow = tr => { rows().forEach(r => r.classList.remove('selected')); tr.classList.add('selected'); target = tr; renderTarget(); };
        uTable.addEventListener('click', e => {
            const tr = e.target.closest('tr'); if (!tr || !tr.dataset.name) return;
            const act = e.target.closest('[data-act]');
            if (act) {
                e.preventDefault();
                if (act.dataset.act === 'role') pickRow(tr);
                else toggleActive(tr);
            } else pickRow(tr);
        });
        const toggleActive = tr => {
            const deactivated = tr.dataset.status === 'Deactivated';
            const apply = () => {
                tr.dataset.status = deactivated ? 'Active' : 'Deactivated';
                const st = $('.status-cell .badge', tr);
                st.textContent = tr.dataset.status; st.className = 'badge ' + (deactivated ? 'green' : 'red');
                const link = $('[data-act="toggle"]', tr); if (link) link.textContent = deactivated ? 'Deactivate' : 'Reactivate';
                showToast(`${tr.dataset.name} ${deactivated ? 'reactivated' : 'deactivated'}`);
            };
            if (deactivated) apply();
            else confirmDialog('Deactivate account?', `${tr.dataset.name} will be signed out and lose access. Active sessions are revoked.`, 'Deactivate', apply);
        };
        $('#deactivateLink').addEventListener('click', e => { e.preventDefault(); if (target.dataset.status !== 'Deactivated') toggleActive(target); });
        $$('.role-chips span').forEach(c => c.addEventListener('click', () => { rolePick.value = c.textContent; updateNote(); }));
        rolePick.addEventListener('change', updateNote);
        applyBtn.addEventListener('click', () => {
            const nw = rolePick.value;
            if (target.dataset.role === 'superadmin' && nw !== 'superadmin' && $$('tbody tr[data-role="superadmin"]', uTable).length < 2) {
                showToast('Keep at least one active superadmin'); return;
            }
            confirmDialog('Apply role change?', `${target.dataset.name}: ${target.dataset.role} → ${nw}.`, 'Apply', () => {
                target.dataset.role = nw;
                const rb = $('.role-cell .badge', target);
                rb.textContent = nw; rb.className = 'badge ' + (roleClass[nw]);
                renderTarget(); showToast('Role updated');
            });
        });
        $('#createAdminForm').addEventListener('submit', e => {
            e.preventDefault();
            if (!validate(e.target)) return;
            showToast(`Invitation sent to ${$('#caEmail').value}`);
            e.target.reset();
        });
        $('#caCancel').addEventListener('click', () => $('#createAdminForm').reset());
        $('#createAdminTop').addEventListener('click', () => { $('#caFirst').scrollIntoView({ behavior: 'smooth', block: 'center' }); $('#caFirst').focus(); });
        renderTarget();
    }

    /* ---------- Misc ---------- */
    $$('[data-toast]').forEach(b => b.addEventListener('click', () => showToast(b.dataset.toast)));
});