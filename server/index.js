require('dotenv').config();

const crypto = require('node:crypto');
const express = require('express');
const bcrypt = require('bcryptjs');
const mysql = require('mysql2/promise');

const app = express();
const port = Number(process.env.API_PORT || 3000);
const cookieName = 'pt_session';
const cookieSecure = process.env.SESSION_COOKIE_SECURE === 'true';
const allowedOrigins = new Set(
    (process.env.FRONTEND_ORIGINS
        || 'http://localhost:5500,http://127.0.0.1:5500,http://localhost:5501,http://127.0.0.1:5501')
        .split(',')
        .map(origin => origin.trim())
        .filter(Boolean)
);

const pool = mysql.createPool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'pilipinas_travel',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

app.disable('x-powered-by');
app.use(express.json({ limit: '10kb' }));
app.use((req, res, next) => {
    const origin = req.get('Origin');
    if (origin && !allowedOrigins.has(origin)) {
        return res.status(403).json({ message: 'This website is not allowed to use the API.' });
    }

    if (origin) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
        res.setHeader('Access-Control-Allow-Credentials', 'true');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    }

    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
});

function normalizeEmail(value) {
    if (typeof value !== 'string') return null;
    const email = value.trim().toLowerCase();
    return email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
        ? email
        : null;
}

function getString(value, maxLength) {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    return trimmed.length > 0 && trimmed.length <= maxLength ? trimmed : null;
}

const ROLE_PRIORITY = ['ADMIN', 'STAFF', 'LOCAL_HOST', 'TRAVELER'];

async function getUserRoles(executor, userId) {
    const [rows] = await executor.execute(
        `SELECT r.role_name
           FROM user_roles ur
           JOIN roles r ON r.role_id = ur.role_id
          WHERE ur.user_id = ?`,
        [userId]
    );

    const roles = rows.map(row => String(row.role_name).toUpperCase());
    return [
        ...ROLE_PRIORITY.filter(role => roles.includes(role)),
        ...roles.filter(role => !ROLE_PRIORITY.includes(role)).sort()
    ];
}

function getPrimaryRole(roles) {
    return ROLE_PRIORITY.find(role => roles.includes(role)) || roles[0] || null;
}

function getSessionToken(req) {
    const cookieHeader = req.headers.cookie || '';
    const cookie = cookieHeader.split(';').map(part => part.trim())
        .find(part => part.startsWith(`${cookieName}=`));
    return cookie ? cookie.slice(cookieName.length + 1) : null;
}

function hashToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
}

function setSessionCookie(res, token, remember) {
    const attributes = [
        `${cookieName}=${encodeURIComponent(token)}`,
        'Path=/',
        'HttpOnly',
        'SameSite=Lax'
    ];
    if (remember) attributes.push('Max-Age=604800');
    if (cookieSecure) attributes.push('Secure');
    res.setHeader('Set-Cookie', attributes.join('; '));
}

function clearSessionCookie(res) {
    const attributes = [
        `${cookieName}=`,
        'Path=/',
        'HttpOnly',
        'SameSite=Lax',
        'Max-Age=0'
    ];
    if (cookieSecure) attributes.push('Secure');
    res.setHeader('Set-Cookie', attributes.join('; '));
}

function isPasswordValid(password) {
    return typeof password === 'string'
        && password.length >= 8
        && Buffer.byteLength(password, 'utf8') <= 72;
}

function isLockedUntil(value) {
    return value !== null && new Date(value).getTime() > Date.now();
}

async function createSession(connection, userId, remember) {
    const token = crypto.randomBytes(32).toString('base64url');
    const lifetime = remember ? 7 * 24 * 60 * 60 * 1000 : 12 * 60 * 60 * 1000;
    const expiresAt = new Date(Date.now() + lifetime);
    await connection.execute(
        'INSERT INTO auth_sessions (user_id, session_token_hash, expires_at) VALUES (?, ?, ?)',
        [userId, hashToken(token), expiresAt]
    );
    return token;
}

app.get('/api/health', async (req, res, next) => {
    try {
        await pool.query('SELECT 1');
        res.json({ status: 'ok' });
    } catch (error) {
        next(error);
    }
});

app.post('/api/auth/signup', async (req, res, next) => {
    const email = normalizeEmail(req.body?.email);
    const firstName = getString(req.body?.firstName, 80);
    const lastName = getString(req.body?.lastName, 80);
    const phoneInput = req.body?.phone;
    const phone = phoneInput === '' || phoneInput == null ? null : getString(phoneInput, 30);
    const password = req.body?.password;

    if (!email || !firstName || !lastName || (phoneInput != null && phoneInput !== '' && !phone)) {
        return res.status(400).json({ message: 'Enter a valid email, first name, and last name.' });
    }
    if (!isPasswordValid(password)) {
        return res.status(400).json({ message: 'Password must be at least 8 characters and no more than 72 UTF-8 bytes.' });
    }

    try {
        const passwordHash = await bcrypt.hash(password, 12);
        const [resultSets] = await pool.query(
            'CALL sp_register_user(?, ?, ?, ?, ?)',
            [email, passwordHash, firstName, lastName, phone]
        );
        const userId = resultSets[0]?.[0]?.user_id;
        if (!userId) throw new Error('Registration procedure did not return a user ID');
        res.status(201).json({ message: 'Account created. You can now log in.' });
    } catch (error) {
        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ message: 'An account with that email already exists.' });
        }
        next(error);
    }
});

app.post('/api/auth/login', async (req, res, next) => {
    const email = normalizeEmail(req.body?.email);
    const password = req.body?.password;
    const remember = req.body?.remember === true;
    if (!email || typeof password !== 'string' || password.length === 0
        || Buffer.byteLength(password, 'utf8') > 72) {
        return res.status(400).json({ message: 'Enter a valid email address and password.' });
    }

    let connection;
    try {
        connection = await pool.getConnection();
        await connection.beginTransaction();

        const [resultSets] = await connection.query(
            'CALL sp_get_login_credentials(?)',
            [email]
        );
        const user = resultSets[0]?.[0];
        if (!user || isLockedUntil(user.locked_until)) {
            await connection.rollback();
            return res.status(401).json({ message: 'Email or password is incorrect, or the account is temporarily locked.' });
        }

        const hasBcryptHash = typeof user.password_hash === 'string'
            && /^\$2[aby]\$\d\d\$/.test(user.password_hash);
        const passwordMatches = hasBcryptHash
            ? await bcrypt.compare(password, user.password_hash)
            : false;

        if (!passwordMatches || user.account_status !== 'ACTIVE') {
            const failedAttempts = Math.min(Number(user.failed_login_attempts) + 1, 255);
            await connection.execute(
                `UPDATE users
                    SET failed_login_attempts = ?,
                        locked_until = IF(? >= 5, DATE_ADD(NOW(), INTERVAL 15 MINUTE), locked_until)
                  WHERE user_id = ?`,
                [failedAttempts, failedAttempts, user.user_id]
            );
            await connection.commit();
            return res.status(401).json({ message: 'Email or password is incorrect, or the account is temporarily locked.' });
        }

        const roles = await getUserRoles(connection, user.user_id);
        const primaryRole = getPrimaryRole(roles);
        if (!primaryRole) {
            await connection.rollback();
            return res.status(403).json({
                message: 'This account has no assigned role. Ask an administrator to assign a role before logging in.'
            });
        }

        await connection.execute(
            'UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login_at = NOW() WHERE user_id = ?',
            [user.user_id]
        );
        const token = await createSession(connection, user.user_id, remember);
        await connection.query(
            'DELETE FROM auth_sessions WHERE expires_at <= NOW() LIMIT 500'
        );
        await connection.commit();

        setSessionCookie(res, token, remember);
        res.json({
            message: `Welcome back, ${user.first_name}.`,
            user: {
                id: user.user_id,
                firstName: user.first_name,
                lastName: user.last_name,
                roles,
                primaryRole
            }
        });
    } catch (error) {
        if (connection) {
            try {
                await connection.rollback();
            } catch (rollbackError) {
                console.error('Could not roll back failed login transaction:', rollbackError);
            }
        }
        next(error);
    } finally {
        if (connection) connection.release();
    }
});

app.get('/api/auth/me', async (req, res, next) => {
    const token = getSessionToken(req);
    if (!token) return res.status(401).json({ message: 'Not logged in.' });

    try {
        const [users] = await pool.execute(
            `SELECT u.user_id, u.email, u.first_name, u.last_name
               FROM auth_sessions s
               JOIN users u ON u.user_id = s.user_id
              WHERE s.session_token_hash = ?
                AND s.expires_at > NOW()
                AND u.account_status = 'ACTIVE'
              LIMIT 1`,
            [hashToken(token)]
        );
        if (!users[0]) return res.status(401).json({ message: 'Session expired. Please log in again.' });

        const roles = await getUserRoles(pool, users[0].user_id);
        const primaryRole = getPrimaryRole(roles);
        if (!primaryRole) {
            return res.status(403).json({ message: 'This account has no assigned role. Contact an administrator.' });
        }

        res.json({
            user: {
                id: users[0].user_id,
                email: users[0].email,
                firstName: users[0].first_name,
                lastName: users[0].last_name,
                roles,
                primaryRole
            }
        });
    } catch (error) {
        next(error);
    }
});

app.post('/api/auth/logout', async (req, res, next) => {
    const token = getSessionToken(req);
    try {
        if (token) {
            await pool.execute(
                'DELETE FROM auth_sessions WHERE session_token_hash = ?',
                [hashToken(token)]
            );
        }
        clearSessionCookie(res);
        res.json({ message: 'Logged out.' });
    } catch (error) {
        next(error);
    }
});

app.use((error, req, res, next) => {
    console.error('API request failed:', error);
    if (res.headersSent) return next(error);
    if (error instanceof SyntaxError && error.status === 400 && 'body' in error) {
        return res.status(400).json({ message: 'Request body must be valid JSON.' });
    }
    if (['ER_SP_DOES_NOT_EXIST', 'ER_NO_SUCH_TABLE', 'ER_BAD_FIELD_ERROR'].includes(error.code)) {
        return res.status(503).json({
            message: 'The authentication database is not fully installed or does not match this application. Run database/pilipinastravel.sql first, then database/authentication.sql.'
        });
    }
    res.status(500).json({ message: 'The server could not complete the request. Please try again.' });
});

async function start() {
    if (!process.env.DB_USER || !process.env.DB_PASSWORD) {
        throw new Error('Set DB_USER and DB_PASSWORD in your .env file before starting the API.');
    }
    await pool.query('SELECT 1');
    app.listen(port, () => {
        console.log(`Pilipinas Travel API listening on http://localhost:${port}`);
    });
}

start().catch(error => {
    console.error('Could not start the API:', error.message);
    process.exitCode = 1;
});
