function getAuthApiUrl() {
    const configuredUrl = document.querySelector('meta[name="auth-api-url"]')?.content.trim();
    if (configuredUrl) return configuredUrl.replace(/\/+$/, '');

    const hostname = window.location.hostname || 'localhost';
    const protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
    return `${protocol}//${hostname}:3000/api/auth`;
}

const AUTH_API_URL = getAuthApiUrl();
const statusElement = document.getElementById('dashboardStatus');
const logoutButton = document.getElementById('logoutButton');

const ROLE_CONTENT = {
    ADMIN: {
        title: 'Administrator Dashboard',
        description: 'Your account is authenticated with administrator access.',
        note: 'Use the links below to access the tourism modules included in this project. User-management screens and administrative APIs are not included in the current source code.'
    },
    STAFF: {
        title: 'Staff Dashboard',
        description: 'Your account is authenticated with tourism staff access.',
        note: 'The current project includes destination, experience, and itinerary pages. Staff-specific operational screens and protected management APIs still need to be developed.'
    },
    LOCAL_HOST: {
        title: 'Local Host Dashboard',
        description: 'Your account is authenticated as a registered local host.',
        note: 'Use the Experiences section to view the community experience content currently available in the project.'
    },
    TRAVELER: {
        title: 'Traveler Dashboard',
        description: 'Welcome to your Pilipinas Travel account.',
        note: 'Discover destinations, explore local experiences, and continue planning your trip.'
    }
};

function showStatus(message, isError = false) {
    statusElement.textContent = message;
    statusElement.classList.toggle('error', isError);
}

async function loadDashboard() {
    let response;
    try {
        response = await fetch(`${AUTH_API_URL}/me`, {
            method: 'GET',
            credentials: 'include',
            headers: { 'Accept': 'application/json' }
        });
    } catch {
        showStatus('Cannot reach the authentication server. Start the API and reload this page.', true);
        return;
    }

    const result = await response.json().catch(() => ({}));
    if (response.status === 401) {
        window.location.replace('home.html?login=1');
        return;
    }
    if (!response.ok) {
        showStatus(result.message || 'Could not verify your account.', true);
        return;
    }

    const user = result.user;
    const role = String(user.primaryRole || '').toUpperCase();
    const roleContent = ROLE_CONTENT[role];
    if (!roleContent) {
        showStatus('Your account role is not recognized. Contact an administrator.', true);
        return;
    }

    document.title = `Pilipinas Travel - ${roleContent.title}`;
    document.getElementById('dashboardTitle').textContent = roleContent.title;
    document.getElementById('dashboardDescription').textContent = roleContent.description;
    document.getElementById('accountName').textContent = `${user.firstName} ${user.lastName}`.trim();
    document.getElementById('accountEmail').textContent = user.email;
    document.getElementById('accountRole').textContent = role.replaceAll('_', ' ');
    document.getElementById('dashboardRoleNote').textContent = roleContent.note;

    const expectedHash = `#${role.toLowerCase().replaceAll('_', '-')}`;
    if (window.location.hash !== expectedHash) {
        history.replaceState(null, '', `${window.location.pathname}${expectedHash}`);
    }
    showStatus('Your session is active.');
}

logoutButton.addEventListener('click', async () => {
    logoutButton.disabled = true;
    showStatus('Signing out...');
    try {
        const response = await fetch(`${AUTH_API_URL}/logout`, {
            method: 'POST',
            credentials: 'include',
            headers: { 'Content-Type': 'application/json' },
            body: '{}'
        });
        if (!response.ok) throw new Error('The server could not end your session.');
        window.location.replace('home.html');
    } catch (error) {
        showStatus(error.message || 'Could not sign out. Please try again.', true);
        logoutButton.disabled = false;
    }
});

loadDashboard();
