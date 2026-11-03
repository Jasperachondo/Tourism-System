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
        loginForm.addEventListener('submit', (e) => {
            e.preventDefault();
            // TODO: replace with real login logic
            alert('Logged in!');
            closeLogin();
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

    signupForm.addEventListener('submit', (e) => {
        e.preventDefault();
        if (pw.value !== confirmPw.value) {
            matchMsg.textContent = 'Passwords do not match.';
            confirmPw.focus();
            return;
        }
        // TODO: replace with real sign up logic
        alert('Account created!');
    });
}