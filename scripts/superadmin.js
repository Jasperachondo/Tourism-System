document.addEventListener('DOMContentLoaded', () => {
    const $ = (selector, root = document) => root.querySelector(selector);
    const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
    const today = $('[data-today]');
    if (today) {
        today.textContent = new Intl.DateTimeFormat('en', {
            day: '2-digit',
            month: 'long',
            year: 'numeric'
        }).format(new Date());
    }

    document.addEventListener('keydown', event => {
        if (event.key === 'Escape') {
            closeConfirm();
        }
    });

    const roleBar = $('#roleBar');
    if (roleBar) {
        const segments = $$('[data-count]', roleBar);
        const total = segments.reduce((sum, segment) => sum + Number(segment.dataset.count), 0);
        segments.forEach(segment => {
            segment.style.flex = `${Number(segment.dataset.count)} 1 0%`;
        });
        roleBar.setAttribute('aria-label', `Account role distribution across ${total.toLocaleString()} accounts`);
    }

    const toast = $('#toast');
    let toastTimer;
    const showToast = (message, isError = false) => {
        if (!toast) return;
        toast.textContent = message;
        toast.classList.toggle('err', isError);
        toast.classList.add('show');
        window.clearTimeout(toastTimer);
        toastTimer = window.setTimeout(() => toast.classList.remove('show'), 2800);
    };

    const confirmModal = $('#confirmModal');
    const confirmOk = $('#confirmOk');
    const confirmCancel = $('#confirmCancel');
    let confirmAction = null;
    const closeConfirm = () => {
        if (!confirmModal) return;
        confirmModal.classList.remove('open');
        confirmModal.setAttribute('aria-hidden', 'true');
        confirmAction = null;
    };
    const askForConfirmation = (title, message, label, action) => {
        if (!confirmModal) return;
        $('#confirmTitle').textContent = title;
        $('#confirmText').textContent = message;
        confirmOk.textContent = label;
        confirmAction = action;
        confirmModal.classList.add('open');
        confirmModal.setAttribute('aria-hidden', 'false');
        confirmCancel.focus();
    };

    confirmOk?.addEventListener('click', () => {
        const action = confirmAction;
        closeConfirm();
        action?.();
    });
    confirmCancel?.addEventListener('click', closeConfirm);
    confirmModal?.addEventListener('click', event => {
        if (event.target === confirmModal) closeConfirm();
    });

    const usersBody = $('#usersBody');
    if (!usersBody) return;

    const accounts = [
        { id: 1, name: 'Rafael Santos', email: 'rafael@pilipinastravel.ph', role: 'superadmin', status: 'Active', lastActive: 'Just now' },
        { id: 2, name: 'Elena Cruz', email: 'elena@pilipinastravel.ph', role: 'superadmin', status: 'Active', lastActive: 'Today, 09:18' },
        { id: 3, name: 'Maria Reyes', email: 'maria@pilipinastravel.ph', role: 'admin', status: 'Active', lastActive: 'Today, 09:42' },
        { id: 4, name: 'Luis Mendoza', email: 'luis@pilipinastravel.ph', role: 'admin', status: 'Active', lastActive: 'Today, 08:55' },
        { id: 5, name: 'Ana Garcia', email: 'ana.garcia@example.com', role: 'user', status: 'Active', lastActive: 'Yesterday' },
        { id: 6, name: 'Carlo Villanueva', email: 'carlo.villanueva@example.com', role: 'user', status: 'Deactivated', lastActive: '03 Nov 2026' }
    ];
    const totals = { accounts: 1248, users: 1234, admins: 12, superadmins: 2, deactivated: 18 };
    const currentAccountId = 1;
    const pageSize = 6;
    let selectedId = 4;
    let currentPage = 1;

    const roleClass = role => ({
        user: 'plain',
        admin: 'green',
        superadmin: 'amber'
    })[role];
    const setRolePill = (element, role, text = role) => {
        element.className = `badge ${roleClass(role)}`;
        element.textContent = text;
    };

    const updateStats = () => {
        $$('[data-stat]').forEach(element => {
            const value = totals[element.dataset.stat];
            if (value !== undefined) element.textContent = value.toLocaleString();
        });
    };

    const currentSelection = () => accounts.find(account => account.id === selectedId);
    const filteredAccounts = () => {
        const query = $('#searchInput').value.trim().toLowerCase();
        const role = $('#roleFilter').value;
        const status = $('#statusFilter').value;
        return accounts.filter(account => {
            const matchesQuery = `${account.name} ${account.email}`.toLowerCase().includes(query);
            const matchesRole = role === 'all' || account.role === role;
            const matchesStatus = status === 'all' || account.status.toLowerCase() === status;
            return matchesQuery && matchesRole && matchesStatus;
        });
    };

    const makeCell = (className, text) => {
        const cell = document.createElement('td');
        if (className) cell.className = className;
        cell.textContent = text;
        return cell;
    };

    const renderAccounts = () => {
        const filtered = filteredAccounts();
        const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize));
        currentPage = Math.min(currentPage, pageCount);
        const pageAccounts = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);
        usersBody.replaceChildren();

        pageAccounts.forEach(account => {
            const row = document.createElement('tr');
            row.dataset.id = account.id;
            row.className = 'selectable';
            row.classList.toggle('selected', account.id === selectedId);

            const accountCell = document.createElement('td');
            const name = document.createElement('span');
            name.className = 'account-name';
            name.textContent = account.name;
            const email = document.createElement('span');
            email.className = 'account-email';
            email.textContent = account.email;
            accountCell.append(name, email);
            row.append(accountCell);

            const roleCell = document.createElement('td');
            const rolePill = document.createElement('span');
            setRolePill(rolePill, account.role);
            roleCell.append(rolePill);
            row.append(roleCell);

            const statusCell = document.createElement('td');
            const status = document.createElement('span');
            status.className = `badge ${account.status === 'Active' ? 'green' : account.status === 'Deactivated' ? 'red' : 'amber'}`;
            status.textContent = account.status;
            statusCell.append(status);
            row.append(statusCell);

            row.append(makeCell('', account.lastActive));

            const actions = document.createElement('td');
            const actionLinks = document.createElement('div');
            actionLinks.className = 'account-actions';
            const selectButton = document.createElement('button');
            selectButton.type = 'button';
            selectButton.className = 'link-btn';
            selectButton.dataset.action = 'select';
            selectButton.textContent = '↗ Manage';
            const toggleButton = document.createElement('button');
            toggleButton.type = 'button';
            toggleButton.className = 'link-btn danger';
            toggleButton.dataset.action = 'toggle';
            toggleButton.textContent = account.status === 'Deactivated' ? '✓ Reactivate' : '⊘ Deactivate';
            actionLinks.append(selectButton, toggleButton);
            actions.append(actionLinks);
            row.append(actions);

            usersBody.append(row);
        });

        if (filtered.length === 0) {
            const row = document.createElement('tr');
            const cell = document.createElement('td');
            cell.className = 'empty';
            cell.colSpan = 5;
            cell.textContent = 'No accounts match your search.';
            row.append(cell);
            usersBody.append(row);
        }

        const first = filtered.length ? (currentPage - 1) * pageSize + 1 : 0;
        const last = Math.min(currentPage * pageSize, filtered.length);
        const suffix = filtered.length === accounts.length
            ? ` of ${totals.accounts.toLocaleString()} accounts`
            : ` of ${filtered.length.toLocaleString()} matching accounts`;
        $('#showingInfo').textContent = `Showing ${first}-${last}${suffix}`;

        const pager = $('#pager');
        pager.replaceChildren();
        const previous = document.createElement('button');
        previous.type = 'button';
        previous.textContent = 'Previous';
        previous.disabled = currentPage === 1;
        previous.addEventListener('click', () => { currentPage--; renderAccounts(); });
        const page = document.createElement('button');
        page.type = 'button';
        page.className = 'current';
        page.textContent = String(currentPage);
        page.setAttribute('aria-current', 'page');
        const next = document.createElement('button');
        next.type = 'button';
        next.textContent = 'Next';
        next.disabled = currentPage === pageCount;
        next.addEventListener('click', () => { currentPage++; renderAccounts(); });
        pager.append(previous, page, next);
    };

    const updateRolePanel = () => {
        const account = currentSelection();
        if (!account) return;
        $('#crName').textContent = account.name;
        $('#crEmail').textContent = account.email;
        setRolePill($('#crCurrent'), account.role, `Current: ${account.role}`);
        const roleSelect = $('#crSelect');
        roleSelect.value = account.role;
        $('#crDeactivate').textContent = account.status === 'Deactivated' ? 'Reactivate account' : 'Deactivate account';
        const roleMessage = $('#crMsg');
        const applyButton = $('#crApply');
        const changed = roleSelect.value !== account.role;
        applyButton.disabled = !changed;
        roleMessage.classList.remove('warn');
        if (changed) {
            roleMessage.textContent = `Unsaved change: ${account.role} → ${roleSelect.value}. Review carefully before applying.`;
            if (roleSelect.value === 'user') {
                roleMessage.textContent += ` ${account.name.split(' ')[0]} will lose management access.`;
                roleMessage.classList.add('warn');
            }
        } else {
            roleMessage.textContent = 'Choose a new role to review the change.';
        }
        $$('#roleChips [data-role]').forEach(chip => {
            chip.classList.toggle('on', chip.dataset.role === roleSelect.value);
        });
        renderAccounts();
    };

    const selectAccount = account => {
        selectedId = account.id;
        updateRolePanel();
    };

    const activeSuperadmins = () => accounts.filter(account =>
        account.role === 'superadmin' && account.status === 'Active'
    ).length;

    const setAccountStatus = account => {
        const wasDeactivated = account.status === 'Deactivated';
        if (!wasDeactivated && account.id === currentAccountId) {
            showToast('You cannot deactivate your own account.', true);
            return;
        }
        if (!wasDeactivated && account.role === 'superadmin' && activeSuperadmins() <= 1) {
            showToast('Keep at least one active superadmin.', true);
            return;
        }
        const nextStatus = wasDeactivated ? 'Active' : 'Deactivated';
        const apply = () => {
            account.status = nextStatus;
            totals.deactivated += wasDeactivated ? -1 : 1;
            account.lastActive = wasDeactivated ? 'Just now' : account.lastActive;
            updateStats();
            renderAccounts();
            updateRolePanel();
            showToast(`${account.name} ${wasDeactivated ? 'reactivated' : 'deactivated'} (demo only).`);
        };
        if (wasDeactivated) apply();
        else askForConfirmation(
            'Deactivate account?',
            `${account.name} will lose access. This demo does not revoke server sessions.`,
            'Deactivate',
            apply
        );
    };

    usersBody.addEventListener('click', event => {
        const row = event.target.closest('tr[data-id]');
        if (!row) return;
        const account = accounts.find(item => item.id === Number(row.dataset.id));
        if (!account) return;
        selectAccount(account);
        const action = event.target.closest('[data-action]')?.dataset.action;
        if (action === 'toggle') setAccountStatus(account);
    });

    ['searchInput', 'roleFilter', 'statusFilter'].forEach(id => {
        const control = $(`#${id}`);
        control.addEventListener(id === 'searchInput' ? 'input' : 'change', () => {
            currentPage = 1;
            renderAccounts();
        });
    });

    $('#crSelect').addEventListener('change', updateRolePanel);
    $$('#roleChips [data-role]').forEach(chip => {
        chip.addEventListener('click', () => {
            $('#crSelect').value = chip.dataset.role;
            updateRolePanel();
        });
    });

    $('#crApply').addEventListener('click', () => {
        const account = currentSelection();
        const nextRole = $('#crSelect').value;
        if (!account || nextRole === account.role) return;
        if (account.status === 'Active' && account.role === 'superadmin' &&
            nextRole !== 'superadmin' && activeSuperadmins() <= 1) {
            showToast('Keep at least one active superadmin.', true);
            return;
        }
        askForConfirmation(
            'Apply role change?',
            `${account.name}: ${account.role} → ${nextRole}.`,
            'Apply change',
            () => {
                totals[account.role === 'user' ? 'users' : account.role === 'admin' ? 'admins' : 'superadmins']--;
                totals[nextRole === 'user' ? 'users' : nextRole === 'admin' ? 'admins' : 'superadmins']++;
                account.role = nextRole;
                updateStats();
                updateRolePanel();
                showToast(`Role updated for ${account.name} (demo only).`);
            }
        );
    });

    $('#crDeactivate').addEventListener('click', () => {
        const account = currentSelection();
        if (account) setAccountStatus(account);
    });

    const createForm = $('#createForm');
    const fields = [
        { input: $('#cFirst'), error: $('#errFirst') },
        { input: $('#cLast'), error: $('#errLast') },
        { input: $('#cEmail'), error: $('#errEmail') }
    ];
    const clearCreateErrors = () => fields.forEach(({ input, error }) => {
        input.classList.remove('invalid');
        error.textContent = '';
    });
    fields.forEach(({ input, error }) => {
        input.addEventListener('input', () => {
            input.classList.remove('invalid');
            error.textContent = '';
        });
    });

    createForm.addEventListener('submit', event => {
        event.preventDefault();
        clearCreateErrors();
        const [first, last, email] = fields.map(({ input }) => input.value.trim());
        let valid = true;
        if (!first) {
            $('#errFirst').textContent = 'Enter a first name.';
            $('#cFirst').classList.add('invalid');
            valid = false;
        }
        if (!last) {
            $('#errLast').textContent = 'Enter a last name.';
            $('#cLast').classList.add('invalid');
            valid = false;
        }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            $('#errEmail').textContent = 'Enter a valid email address.';
            $('#cEmail').classList.add('invalid');
            valid = false;
        } else if (accounts.some(account => account.email.toLowerCase() === email.toLowerCase())) {
            $('#errEmail').textContent = 'An account already uses this email address.';
            $('#cEmail').classList.add('invalid');
            valid = false;
        }
        if (!valid) {
            showToast('Check the highlighted fields.', true);
            return;
        }

        const account = {
            id: Math.max(...accounts.map(item => item.id)) + 1,
            name: `${first} ${last}`,
            email,
            role: 'admin',
            status: 'Invited',
            lastActive: 'Never'
        };
        accounts.push(account);
        totals.accounts++;
        totals.admins++;
        updateStats();
        createForm.reset();
        currentPage = 1;
        $('#searchInput').value = '';
        $('#roleFilter').value = 'all';
        $('#statusFilter').value = 'all';
        renderAccounts();
        showToast(`Invitation prepared for ${email} (demo only).`);
    });

    $('#cancelCreate').addEventListener('click', () => {
        createForm.reset();
        clearCreateErrors();
    });
    $('#createAdminTop').addEventListener('click', () => {
        $('#cFirst').scrollIntoView({ behavior: 'smooth', block: 'center' });
        $('#cFirst').focus({ preventScroll: true });
    });

    updateStats();
    renderAccounts();
    updateRolePanel();
});
