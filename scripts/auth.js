function getAuthApiUrl() {
    const configuredUrl = document.querySelector('meta[name="auth-api-url"]')?.content.trim();
    if (configuredUrl) return configuredUrl.replace(/\/+$/, '');

    // Keep the API host aligned with the hostname used to open the frontend.
    // This avoids localhost/127.0.0.1 cookie and CORS mismatches.
    const hostname = window.location.hostname || 'localhost';
    const protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
    return `${protocol}//${hostname}:3000/api/auth`;
}

const AUTH_API_URL = getAuthApiUrl();

const ROLE_DASHBOARD_URLS = {
    ADMIN: 'dashboard.html#admin',
    STAFF: 'dashboard.html#staff',
    LOCAL_HOST: 'dashboard.html#local-host',
    TRAVELER: 'dashboard.html#traveler'
};

async function submitAuthRequest(path, values) {
    let response;
    try {
        response = await fetch(`${AUTH_API_URL}/${path}`, {
            method: 'POST',
            credentials: 'include',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(values)
        });
    } catch {
        throw new Error('Could not reach the authentication server. Start it with npm start and try again.');
    }

    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
        throw new Error(result.message || 'The request failed. Please try again.');
    }
    return result;
}

function showAuthStatus(element, message, type) {
    if (!element) return;
    element.textContent = message;
    element.className = `auth-status ${type}`;
}

/* ---------- Login modal (home.html) ---------- */
const loginModal = document.getElementById('loginModal');

function openLogin() {
    if (!loginModal) return;
    loginModal.classList.add('open');
    loginModal.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
    const email = document.getElementById('loginEmail');
    if (email) setTimeout(() => email.focus(), 100);
}

function closeLogin() {
    if (!loginModal) return;
    loginModal.classList.remove('open');
    loginModal.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
}

if (loginModal) {
    if (new URLSearchParams(window.location.search).get('login') === '1') {
        openLogin();
    }

    ['openLogin', 'heroLogin'].forEach(id => {
        const btn = document.getElementById(id);
        if (btn) btn.addEventListener('click', openLogin);
    });

    const closeBtn = document.getElementById('closeLogin');
    if (closeBtn) closeBtn.addEventListener('click', closeLogin);

    // click on the dark overlay closes the modal
    loginModal.addEventListener('click', (e) => {
        if (e.target === loginModal) closeLogin();
    });

    // Esc closes the modal
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') closeLogin();
    });

    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        const status = document.getElementById('loginStatus');
        loginForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const submitButton = loginForm.querySelector('button[type="submit"]');
            submitButton.disabled = true;
            showAuthStatus(status, '', '');
            try {
                const result = await submitAuthRequest('login', {
                    email: document.getElementById('loginEmail').value,
                    password: document.getElementById('loginPassword').value,
                    remember: document.getElementById('remember').checked
                });
                document.getElementById('loginPassword').value = '';
                const destination = ROLE_DASHBOARD_URLS[result.user?.primaryRole] || 'dashboard.html';
                window.location.assign(destination);
            } catch (error) {
                showAuthStatus(status, error.message, 'error');
            } finally {
                submitButton.disabled = false;
            }
        });
    }
}

/* ---------- Show / Hide password (both pages) ---------- */
document.querySelectorAll('.toggle-pw').forEach(btn => {
    btn.addEventListener('click', () => {
        const input = document.getElementById(btn.dataset.target);
        const showing = input.type === 'text';
        input.type = showing ? 'password' : 'text';
        btn.textContent = showing ? 'Show' : 'Hide';
    });
});

/* ---------- Sign up page ---------- */
const signupForm = document.getElementById('signupForm');

if (signupForm) {
    const pw = document.getElementById('password');
    const confirmPw = document.getElementById('confirmPassword');
    const bars = document.querySelectorAll('#strength .strength-bars span');
    const label = document.getElementById('strengthLabel');
    const matchMsg = document.getElementById('matchMsg');
    const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];

    function getStrength(value) {
        let score = 0;
        if (value.length >= 8) score++;
        if (/[A-Z]/.test(value) && /[a-z]/.test(value)) score++;
        if (/\d/.test(value)) score++;
        if (/[^A-Za-z0-9]/.test(value)) score++;
        return value ? Math.max(score, 1) : 0;
    }

    pw.addEventListener('input', () => {
        const score = getStrength(pw.value);
        bars.forEach((bar, i) => bar.classList.toggle('filled', i < score));
        label.textContent = labels[score];
    });

    function checkMatch() {
        matchMsg.textContent =
            confirmPw.value && pw.value !== confirmPw.value ? 'Passwords do not match.' : '';
    }
    confirmPw.addEventListener('input', checkMatch);
    pw.addEventListener('input', checkMatch);

    const status = document.getElementById('signupStatus');
    signupForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        if (pw.value !== confirmPw.value) {
            matchMsg.textContent = 'Passwords do not match.';
            confirmPw.focus();
            return;
        }
        matchMsg.textContent = '';
        const submitButton = signupForm.querySelector('button[type="submit"]');
        submitButton.disabled = true;
        showAuthStatus(status, '', '');
        try {
            const result = await submitAuthRequest('signup', {
                firstName: document.getElementById('firstName').value,
                lastName: document.getElementById('lastName').value,
                email: document.getElementById('email').value,
                phone: document.getElementById('phone').value,
                password: pw.value
            });
            pw.value = '';
            confirmPw.value = '';
            showAuthStatus(status, result.message, 'success');
        } catch (error) {
            showAuthStatus(status, error.message, 'error');
        } finally {
            submitButton.disabled = false;
        }
    });
}