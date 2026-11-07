-- Authentication routines for database/pilipinastravel.sql (MySQL 8.0+).
-- Run this after the main schema script has created the tables and seeded roles.
--
-- The API hashes passwords with bcrypt before calling sp_register_user and
-- verifies submitted passwords against the hash returned by
-- sp_get_login_credentials. Never send password_hash to a browser.

USE pilipinas_travel;

-- Keep the role catalog current on both fresh and already-existing databases.
INSERT INTO roles (role_name, description)
VALUES ('STAFF', 'Tourism operations staff')
ON DUPLICATE KEY UPDATE description = 'Tourism operations staff';

-- Grant the same operational permissions to STAFF on existing installations.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
  FROM roles r
  JOIN permissions p ON p.permission_code IN ('CONTENT_MANAGE', 'BOOKING_MANAGE_ALL')
 WHERE r.role_name = 'STAFF'
   AND NOT EXISTS (
       SELECT 1
         FROM role_permissions rp
        WHERE rp.role_id = r.role_id
          AND rp.permission_id = p.permission_id
   );

-- Existing accounts created before role assignment was enforced are treated as
-- regular travelers. Explicit ADMIN/STAFF/LOCAL_HOST assignments are preserved.
INSERT INTO user_roles (user_id, role_id)
SELECT u.user_id, r.role_id
  FROM users u
  JOIN roles r ON r.role_name = 'TRAVELER'
 WHERE NOT EXISTS (
       SELECT 1 FROM user_roles ur WHERE ur.user_id = u.user_id
 );

CREATE TABLE IF NOT EXISTS auth_sessions (
  session_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id           INT UNSIGNED NOT NULL,
  session_token_hash CHAR(64) NOT NULL,
  expires_at        DATETIME NOT NULL,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (session_id),
  UNIQUE KEY uq_auth_sessions_token_hash (session_token_hash),
  KEY idx_auth_sessions_user_expiry (user_id, expires_at),
  CONSTRAINT fk_auth_sessions_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP PROCEDURE IF EXISTS sp_register_user;
DROP PROCEDURE IF EXISTS sp_get_login_credentials;

DELIMITER $$

CREATE PROCEDURE sp_register_user (
  IN p_email         VARCHAR(254),
  IN p_password_hash VARCHAR(255),
  IN p_first_name    VARCHAR(80),
  IN p_last_name     VARCHAR(80),
  IN p_phone         VARCHAR(30)
)
BEGIN
  DECLARE v_role_id INT UNSIGNED;
  DECLARE v_user_id INT UNSIGNED;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_email IS NULL OR TRIM(p_email) NOT LIKE '%_@_%._%' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A valid email address is required';
  END IF;
  IF p_password_hash IS NULL OR CHAR_LENGTH(p_password_hash) < 20 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A password hash is required';
  END IF;
  IF p_first_name IS NULL OR TRIM(p_first_name) = ''
     OR p_last_name IS NULL OR TRIM(p_last_name) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'First and last names are required';
  END IF;

  SET v_role_id = (
    SELECT role_id FROM roles WHERE role_name = 'TRAVELER' LIMIT 1
  );
  IF v_role_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The TRAVELER role has not been seeded';
  END IF;

  START TRANSACTION;

  -- Accounts are immediately usable because this project has no email
  -- verification flow yet. Do not mark the email as verified.
  INSERT INTO users
    (email, password_hash, first_name, last_name, phone, account_status)
  VALUES
    (LOWER(TRIM(p_email)), p_password_hash, TRIM(p_first_name), TRIM(p_last_name),
     NULLIF(TRIM(p_phone), ''), 'ACTIVE');

  SET v_user_id = LAST_INSERT_ID();

  INSERT INTO user_roles (user_id, role_id)
  VALUES (v_user_id, v_role_id);

  COMMIT;

  SELECT v_user_id AS user_id;
END$$

CREATE PROCEDURE sp_get_login_credentials (
  IN p_email VARCHAR(254)
)
BEGIN
  IF p_email IS NULL OR TRIM(p_email) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email address is required';
  END IF;

  SELECT user_id, password_hash, account_status, failed_login_attempts,
         locked_until, first_name, last_name
    FROM users
   WHERE email = LOWER(TRIM(p_email))
   LIMIT 1
   FOR UPDATE;
END$$

DELIMITER ;

-- Application flow:
--   Sign-up: hash the password in the server, then CALL sp_register_user(...).
--   Login:   CALL sp_get_login_credentials(email), verify the password hash
--            in the server, and reject non-ACTIVE or currently locked accounts.
--            On successful verification, update last_login_at and reset
--            failed_login_attempts/locked_until for that user.
