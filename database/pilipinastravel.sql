-- =====================================================================
--  PILIPINAS TRAVEL TOURISM MANAGEMENT SYSTEM  --  MySQL 8.0+ (InnoDB)
--  Source analysed: Tourism-System-main.zip
--     (home.html, destinations.html, experiences.html, itineraries.html, about.html)
--  Run on a fresh server with the mysql client / MySQL Workbench.
--  The script uses DELIMITER $$ for triggers and procedures.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PART 1: DATABASE CREATION
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS pilipinas_travel
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE pilipinas_travel;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- PART 2 & 3: TABLES, CONSTRAINTS, INDEXES, FOREIGN KEYS
-- Policy: CHECK constraints are placed only on columns that are NOT part of a
-- foreign key (MySQL forbids mixing them with referential actions).
-- Financial / booking history uses ON DELETE RESTRICT (never cascades).
-- ---------------------------------------------------------------------

-- ===== J. USERS, ROLES, PERMISSIONS (backend; inferred, not shown in frontend) =====
CREATE TABLE roles (
  role_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  role_name    VARCHAR(30)  NOT NULL,
  description  VARCHAR(255) NULL,
  PRIMARY KEY (role_id),
  UNIQUE KEY uq_roles_role_name (role_name)
) ENGINE=InnoDB;

CREATE TABLE permissions (
  permission_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  permission_code  VARCHAR(50)  NOT NULL,
  description      VARCHAR(255) NULL,
  PRIMARY KEY (permission_id),
  UNIQUE KEY uq_permissions_code (permission_code)
) ENGINE=InnoDB;

CREATE TABLE role_permissions (
  role_id        INT UNSIGNED NOT NULL,
  permission_id  INT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  CONSTRAINT fk_role_permissions_role
    FOREIGN KEY (role_id) REFERENCES roles (role_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_role_permissions_permission
    FOREIGN KEY (permission_id) REFERENCES permissions (permission_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE users (
  user_id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  email                  VARCHAR(254) NOT NULL,
  password_hash          VARCHAR(255) NOT NULL COMMENT 'bcrypt/argon2 hash only. Never plaintext.',
  first_name             VARCHAR(80)  NOT NULL,
  last_name              VARCHAR(80)  NOT NULL,
  phone                  VARCHAR(30)  NULL,
  account_status         ENUM('PENDING_VERIFICATION','ACTIVE','SUSPENDED','DEACTIVATED')
                         NOT NULL DEFAULT 'PENDING_VERIFICATION',
  email_verified_at      DATETIME NULL,
  failed_login_attempts  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until           DATETIME NULL,
  last_login_at          DATETIME NULL,
  created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_email (email),            -- case-insensitive under utf8mb4_0900_ai_ci
  KEY idx_users_status (account_status),
  CONSTRAINT chk_users_email_format CHECK (email LIKE '%_@_%._%'),
  CONSTRAINT chk_users_password_hash_len CHECK (CHAR_LENGTH(password_hash) >= 20)
) ENGINE=InnoDB;

CREATE TABLE user_roles (
  user_id     INT UNSIGNED NOT NULL,
  role_id     INT UNSIGNED NOT NULL,
  granted_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, role_id),
  KEY idx_user_roles_role (role_id),
  CONSTRAINT fk_user_roles_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_user_roles_role
    FOREIGN KEY (role_id) REFERENCES roles (role_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE user_tokens (
  token_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     INT UNSIGNED NOT NULL,
  token_hash  CHAR(64) NOT NULL COMMENT 'SHA-256 of the token. The raw token is never stored.',
  purpose     ENUM('EMAIL_VERIFICATION','PASSWORD_RESET') NOT NULL,
  expires_at  DATETIME NOT NULL,
  used_at     DATETIME NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (token_id),
  UNIQUE KEY uq_user_tokens_hash (token_hash),
  KEY idx_user_tokens_user (user_id, purpose),
  CONSTRAINT fk_user_tokens_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE user_activity_log (
  log_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      INT UNSIGNED NULL,
  action       VARCHAR(60)  NOT NULL,
  entity_type  VARCHAR(40)  NULL,
  entity_id    BIGINT UNSIGNED NULL,
  ip_address   VARBINARY(16) NULL,
  details      JSON NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (log_id),
  KEY idx_activity_user_time (user_id, created_at),
  KEY idx_activity_entity (entity_type, entity_id),
  CONSTRAINT fk_activity_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ===== SHARED REFERENCE DATA =====
CREATE TABLE currencies (
  currency_code  CHAR(3) NOT NULL,
  currency_name  VARCHAR(60) NOT NULL,
  symbol         VARCHAR(5)  NULL,
  PRIMARY KEY (currency_code)
) ENGINE=InnoDB;

CREATE TABLE locations (
  location_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  parent_location_id  INT UNSIGNED NULL,
  location_name       VARCHAR(120) NOT NULL,
  location_type       ENUM('REGION','PROVINCE','CITY_MUNICIPALITY','AREA') NOT NULL,
  latitude            DECIMAL(9,6) NULL,
  longitude           DECIMAL(9,6) NULL,
  PRIMARY KEY (location_id),
  UNIQUE KEY uq_locations_name (parent_location_id, location_name, location_type),
  KEY idx_locations_name (location_name),
  KEY idx_locations_type (location_type),
  CONSTRAINT fk_locations_parent
    FOREIGN KEY (parent_location_id) REFERENCES locations (location_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_locations_lat CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
  CONSTRAINT chk_locations_lng CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT chk_locations_latlng_pair CHECK ((latitude IS NULL) = (longitude IS NULL))
) ENGINE=InnoDB;

CREATE TABLE site_settings (   -- About page / contact info (editable content)
  setting_key    VARCHAR(60) NOT NULL,
  setting_value  TEXT NOT NULL,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (setting_key)
) ENGINE=InnoDB;

CREATE TABLE host_profiles (
  host_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        INT UNSIGNED NOT NULL,
  display_name   VARCHAR(120) NOT NULL,
  bio            TEXT NULL,
  contact_phone  VARCHAR(30) NULL,
  location_id    INT UNSIGNED NULL,
  is_verified    BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at    DATETIME NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (host_id),
  UNIQUE KEY uq_host_profiles_user (user_id),
  KEY idx_host_profiles_location (location_id),
  CONSTRAINT fk_host_profiles_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_host_profiles_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ===== B. DESTINATIONS =====
CREATE TABLE destination_categories (
  category_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_name  VARCHAR(80) NOT NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_destination_categories_name (category_name)
) ENGINE=InnoDB;

CREATE TABLE destinations (
  destination_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id        INT UNSIGNED NOT NULL,
  location_id        INT UNSIGNED NULL,
  destination_name   VARCHAR(150) NOT NULL,
  short_description  VARCHAR(500) NULL,
  description        TEXT NULL,
  address            VARCHAR(255) NULL,
  image_url          VARCHAR(500) NULL,
  is_published       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (destination_id),
  UNIQUE KEY uq_destinations_name (destination_name),
  KEY idx_destinations_category (category_id),
  KEY idx_destinations_location (location_id),
  CONSTRAINT fk_destinations_category
    FOREIGN KEY (category_id) REFERENCES destination_categories (category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_destinations_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE destination_opening_hours (
  hours_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  destination_id  INT UNSIGNED NOT NULL,
  season_label    VARCHAR(60) NOT NULL DEFAULT 'Standard',
  day_scope       ENUM('ALL','MON','TUE','WED','THU','FRI','SAT','SUN') NOT NULL DEFAULT 'ALL'
                  COMMENT 'ALL = the frontend shows no per-day restriction',
  hours_type      ENUM('FIXED','SUNRISE_TO_SUNSET','ALL_DAY','CLOSED') NOT NULL,
  open_time       TIME NULL,
  close_time      TIME NULL,
  PRIMARY KEY (hours_id),
  UNIQUE KEY uq_opening_hours (destination_id, season_label, day_scope),
  CONSTRAINT fk_opening_hours_destination
    FOREIGN KEY (destination_id) REFERENCES destinations (destination_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_opening_hours_times CHECK (
    (hours_type = 'FIXED' AND open_time IS NOT NULL AND close_time IS NOT NULL AND open_time < close_time)
    OR (hours_type <> 'FIXED' AND open_time IS NULL AND close_time IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE destination_fees (
  fee_id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  destination_id  INT UNSIGNED NOT NULL,
  fee_label       VARCHAR(80) NOT NULL,
  amount          DECIMAL(10,2) NOT NULL,
  currency_code   CHAR(3) NOT NULL DEFAULT 'PHP',
  notes           VARCHAR(255) NULL,
  PRIMARY KEY (fee_id),
  UNIQUE KEY uq_destination_fees (destination_id, fee_label),
  KEY idx_destination_fees_currency (currency_code),
  CONSTRAINT fk_destination_fees_destination
    FOREIGN KEY (destination_id) REFERENCES destinations (destination_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_destination_fees_currency
    FOREIGN KEY (currency_code) REFERENCES currencies (currency_code) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_destination_fees_amount CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE accessibility_features (
  feature_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  feature_name  VARCHAR(100) NOT NULL,
  description   VARCHAR(255) NULL,
  PRIMARY KEY (feature_id),
  UNIQUE KEY uq_accessibility_feature_name (feature_name)
) ENGINE=InnoDB;

CREATE TABLE destination_accessibility_features (
  destination_id  INT UNSIGNED NOT NULL,
  feature_id      INT UNSIGNED NOT NULL,
  notes           VARCHAR(255) NULL,
  PRIMARY KEY (destination_id, feature_id),
  KEY idx_dest_access_feature (feature_id),
  CONSTRAINT fk_dest_access_destination
    FOREIGN KEY (destination_id) REFERENCES destinations (destination_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_dest_access_feature
    FOREIGN KEY (feature_id) REFERENCES accessibility_features (feature_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ===== C. EXPERIENCES & BOOKINGS =====
CREATE TABLE experience_categories (
  category_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_name  VARCHAR(80) NOT NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_experience_categories_name (category_name)
) ENGINE=InnoDB;

CREATE TABLE experiences (
  experience_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  host_id           INT UNSIGNED NULL COMMENT 'NULL until a verified host is assigned (no hosts are named in the frontend)',
  category_id       INT UNSIGNED NOT NULL,
  location_id       INT UNSIGNED NULL,
  title             VARCHAR(150) NOT NULL,
  description       TEXT NULL,
  meeting_point     VARCHAR(255) NULL,
  price_per_person  DECIMAL(10,2) NOT NULL,
  currency_code     CHAR(3) NOT NULL DEFAULT 'PHP',
  duration_minutes  SMALLINT UNSIGNED NOT NULL,
  rating_avg        DECIMAL(2,1) NULL COMMENT 'Cached aggregate. Seeded from the frontend; the app must maintain it.',
  review_count      INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cached aggregate (see rating_avg)',
  image_path        VARCHAR(255) NULL,
  is_published      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (experience_id),
  KEY idx_experiences_host (host_id),
  KEY idx_experiences_category (category_id),
  KEY idx_experiences_location (location_id),
  KEY idx_experiences_price (price_per_person),
  KEY idx_experiences_title (title),
  CONSTRAINT fk_experiences_host
    FOREIGN KEY (host_id) REFERENCES host_profiles (host_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_experiences_category
    FOREIGN KEY (category_id) REFERENCES experience_categories (category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_experiences_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_experiences_currency
    FOREIGN KEY (currency_code) REFERENCES currencies (currency_code) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_experiences_price CHECK (price_per_person >= 0),
  CONSTRAINT chk_experiences_duration CHECK (duration_minutes > 0),
  CONSTRAINT chk_experiences_rating CHECK (rating_avg IS NULL OR rating_avg BETWEEN 0 AND 5)
) ENGINE=InnoDB;

CREATE TABLE experience_schedules (
  schedule_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  experience_id    INT UNSIGNED NOT NULL,
  start_datetime   DATETIME NOT NULL,
  capacity         INT NOT NULL,
  booked_slots     INT NOT NULL DEFAULT 0 COMMENT 'Maintained by triggers on experience_bookings',
  remaining_slots  INT GENERATED ALWAYS AS (capacity - booked_slots) VIRTUAL,
  schedule_status  ENUM('OPEN','CLOSED','CANCELLED') NOT NULL DEFAULT 'OPEN',
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (schedule_id),
  UNIQUE KEY uq_schedule_experience_start (experience_id, start_datetime),
  KEY idx_schedule_start (start_datetime),
  CONSTRAINT fk_schedules_experience
    FOREIGN KEY (experience_id) REFERENCES experiences (experience_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_schedule_capacity CHECK (capacity > 0),
  CONSTRAINT chk_schedule_booked CHECK (booked_slots >= 0 AND booked_slots <= capacity)
) ENGINE=InnoDB;

CREATE TABLE experience_bookings (
  booking_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_reference  VARCHAR(20) NOT NULL,
  user_id            INT UNSIGNED NOT NULL,
  schedule_id        INT UNSIGNED NOT NULL,
  quantity           SMALLINT UNSIGNED NOT NULL,
  unit_price         DECIMAL(10,2) NOT NULL COMMENT 'Price per person at time of booking (historical snapshot)',
  currency_code      CHAR(3) NOT NULL,
  total_amount       DECIMAL(12,2) GENERATED ALWAYS AS (unit_price * quantity) STORED,
  booking_status     ENUM('PENDING','CONFIRMED','CANCELLED','COMPLETED') NOT NULL DEFAULT 'PENDING',
  payment_status     ENUM('UNPAID','PAID','FAILED','REFUNDED') NOT NULL DEFAULT 'UNPAID',
  payment_method     VARCHAR(30) NULL,
  payment_reference  VARCHAR(100) NULL COMMENT 'Payment-gateway reference only. Never card numbers or CVV.',
  paid_at            DATETIME NULL,
  cancelled_at       DATETIME NULL,
  special_requests   VARCHAR(500) NULL,
  booked_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (booking_id),
  UNIQUE KEY uq_exp_bookings_reference (booking_reference),
  KEY idx_exp_bookings_user (user_id, booked_at),
  KEY idx_exp_bookings_schedule (schedule_id),
  KEY idx_exp_bookings_status (booking_status, payment_status),
  CONSTRAINT fk_exp_bookings_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_exp_bookings_schedule
    FOREIGN KEY (schedule_id) REFERENCES experience_schedules (schedule_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_exp_bookings_currency
    FOREIGN KEY (currency_code) REFERENCES currencies (currency_code) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_exp_bookings_quantity CHECK (quantity > 0),
  CONSTRAINT chk_exp_bookings_unit_price CHECK (unit_price >= 0),
  CONSTRAINT chk_exp_bookings_paid CHECK (payment_status <> 'PAID' OR paid_at IS NOT NULL),
  CONSTRAINT chk_exp_bookings_cancelled CHECK (booking_status <> 'CANCELLED' OR cancelled_at IS NOT NULL)
) ENGINE=InnoDB;

CREATE TABLE experience_reviews (
  review_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id     INT UNSIGNED NOT NULL COMMENT 'Reviews are tied to a real booking',
  rating         TINYINT UNSIGNED NOT NULL,
  comment        TEXT NULL,
  review_status  ENUM('PUBLISHED','HIDDEN') NOT NULL DEFAULT 'PUBLISHED',
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (review_id),
  UNIQUE KEY uq_experience_reviews_booking (booking_id),
  CONSTRAINT fk_experience_reviews_booking
    FOREIGN KEY (booking_id) REFERENCES experience_bookings (booking_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_experience_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ===== D. TRAVEL PASSES =====
CREATE TABLE travel_passes (
  pass_id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  pass_name         VARCHAR(150) NOT NULL,
  description       TEXT NULL,
  discount_percent  DECIMAL(5,2) NULL,
  validity_days     SMALLINT UNSIGNED NOT NULL,
  image_path        VARCHAR(255) NULL,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (pass_id),
  UNIQUE KEY uq_travel_passes_name (pass_name),
  CONSTRAINT chk_travel_passes_discount CHECK (discount_percent IS NULL OR discount_percent BETWEEN 0 AND 100),
  CONSTRAINT chk_travel_passes_validity CHECK (validity_days > 0)
) ENGINE=InnoDB;

CREATE TABLE pass_inclusions (
  inclusion_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  pass_id         INT UNSIGNED NOT NULL,
  inclusion_type  ENUM('TRANSPORT_SERVICE','ACTIVITY_ACCESS','OTHER') NOT NULL,
  description     VARCHAR(255) NOT NULL,
  sort_order      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (inclusion_id),
  UNIQUE KEY uq_pass_inclusions (pass_id, description),
  CONSTRAINT fk_pass_inclusions_pass
    FOREIGN KEY (pass_id) REFERENCES travel_passes (pass_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pass_options (
  option_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  pass_id        INT UNSIGNED NOT NULL,
  option_label   VARCHAR(40) NOT NULL,
  duration_days  SMALLINT UNSIGNED NOT NULL,
  price          DECIMAL(10,2) NOT NULL,
  currency_code  CHAR(3) NOT NULL DEFAULT 'PHP',
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (option_id),
  UNIQUE KEY uq_pass_options_duration (pass_id, duration_days),
  KEY idx_pass_options_currency (currency_code),
  CONSTRAINT fk_pass_options_pass
    FOREIGN KEY (pass_id) REFERENCES travel_passes (pass_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pass_options_currency
    FOREIGN KEY (currency_code) REFERENCES currencies (currency_code) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_pass_options_duration CHECK (duration_days > 0),
  CONSTRAINT chk_pass_options_price CHECK (price >= 0)
) ENGINE=InnoDB;

CREATE TABLE pass_purchases (
  purchase_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  purchase_reference  VARCHAR(20) NOT NULL,
  user_id             INT UNSIGNED NOT NULL,
  option_id           INT UNSIGNED NOT NULL,
  quantity            SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  unit_price          DECIMAL(10,2) NOT NULL COMMENT 'Historical price snapshot',
  currency_code       CHAR(3) NOT NULL,
  total_amount        DECIMAL(12,2) GENERATED ALWAYS AS (unit_price * quantity) STORED,
  purchase_status     ENUM('PENDING','ACTIVE','EXPIRED','CANCELLED','REFUNDED') NOT NULL DEFAULT 'PENDING',
  payment_status      ENUM('UNPAID','PAID','FAILED','REFUNDED') NOT NULL DEFAULT 'UNPAID',
  payment_method      VARCHAR(30) NULL,
  payment_reference   VARCHAR(100) NULL COMMENT 'Payment-gateway reference only. Never card data.',
  paid_at             DATETIME NULL,
  valid_from          DATE NULL,
  valid_until         DATE NULL,
  purchased_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (purchase_id),
  UNIQUE KEY uq_pass_purchases_reference (purchase_reference),
  KEY idx_pass_purchases_user (user_id, purchased_at),
  KEY idx_pass_purchases_option (option_id),
  KEY idx_pass_purchases_status (purchase_status, payment_status),
  CONSTRAINT fk_pass_purchases_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pass_purchases_option
    FOREIGN KEY (option_id) REFERENCES pass_options (option_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pass_purchases_currency
    FOREIGN KEY (currency_code) REFERENCES currencies (currency_code) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_pass_purchases_quantity CHECK (quantity > 0),
  CONSTRAINT chk_pass_purchases_unit_price CHECK (unit_price >= 0),
  CONSTRAINT chk_pass_purchases_dates CHECK (valid_from IS NULL OR valid_until IS NULL OR valid_until >= valid_from),
  CONSTRAINT chk_pass_purchases_paid CHECK (payment_status <> 'PAID' OR paid_at IS NOT NULL)
) ENGINE=InnoDB;

-- ===== E. EVENTS =====
CREATE TABLE event_categories (
  category_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_name  VARCHAR(80) NOT NULL,
  filter_group   ENUM('FESTIVALS_MARKETS','MUSIC_PERFORMANCE','SPORTS') NOT NULL
                 COMMENT 'Maps to the 3 filter buttons on experiences.html',
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_event_categories_name (category_name)
) ENGINE=InnoDB;

CREATE TABLE events (
  event_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id   INT UNSIGNED NOT NULL,
  location_id   INT UNSIGNED NOT NULL,
  event_title   VARCHAR(150) NOT NULL,
  description   TEXT NULL,
  venue_name    VARCHAR(150) NULL,
  date_label    VARCHAR(40) NULL COMMENT 'Display text exactly as shown in the frontend (e.g. "Oct 14")',
  start_date    DATE NULL COMMENT 'Real date once known. The frontend shows no year.',
  end_date      DATE NULL,
  start_time    TIME NULL,
  end_time      TIME NULL,
  image_path    VARCHAR(255) NULL,
  event_status  ENUM('DRAFT','PUBLISHED','CANCELLED') NOT NULL DEFAULT 'PUBLISHED',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (event_id),
  KEY idx_events_category (category_id),
  KEY idx_events_location (location_id),
  KEY idx_events_start (start_date),
  KEY idx_events_title (event_title),
  CONSTRAINT fk_events_category
    FOREIGN KEY (category_id) REFERENCES event_categories (category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_events_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_events_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
) ENGINE=InnoDB;

-- ===== F. LOCAL DIRECTORY =====
CREATE TABLE establishment_categories (
  category_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_name  VARCHAR(80) NOT NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_establishment_categories_name (category_name)
) ENGINE=InnoDB;

CREATE TABLE cuisine_service_categories (
  cuisine_service_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  cuisine_service_name  VARCHAR(80) NOT NULL,
  PRIMARY KEY (cuisine_service_id),
  UNIQUE KEY uq_cuisine_service_name (cuisine_service_name)
) ENGINE=InnoDB;

CREATE TABLE establishments (
  establishment_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id       INT UNSIGNED NOT NULL,
  location_id       INT UNSIGNED NOT NULL,
  establishment_name VARCHAR(150) NOT NULL,
  description       TEXT NULL,
  address           VARCHAR(255) NULL,
  price_range       ENUM('BUDGET','MID_RANGE','LUXURY') NULL,
  contact_phone     VARCHAR(30) NULL,
  website_url       VARCHAR(255) NULL,
  rating_avg        DECIMAL(2,1) NULL COMMENT 'Cached aggregate. Seeded from the frontend; the app must maintain it.',
  review_count      INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cached aggregate (see rating_avg)',
  image_path        VARCHAR(255) NULL,
  is_published      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (establishment_id),
  UNIQUE KEY uq_establishments_name_location (establishment_name, location_id),
  KEY idx_establishments_category (category_id),
  KEY idx_establishments_location (location_id),
  KEY idx_establishments_price (price_range),
  CONSTRAINT fk_establishments_category
    FOREIGN KEY (category_id) REFERENCES establishment_categories (category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_establishments_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_establishments_rating CHECK (rating_avg IS NULL OR rating_avg BETWEEN 0 AND 5)
) ENGINE=InnoDB;

CREATE TABLE establishment_cuisine_services (
  establishment_id   INT UNSIGNED NOT NULL,
  cuisine_service_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (establishment_id, cuisine_service_id),
  KEY idx_est_cuisine_service (cuisine_service_id),
  CONSTRAINT fk_est_cuisine_establishment
    FOREIGN KEY (establishment_id) REFERENCES establishments (establishment_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_est_cuisine_service
    FOREIGN KEY (cuisine_service_id) REFERENCES cuisine_service_categories (cuisine_service_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE establishment_reviews (
  review_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  establishment_id  INT UNSIGNED NOT NULL,
  user_id           INT UNSIGNED NOT NULL,
  rating            TINYINT UNSIGNED NOT NULL,
  comment           TEXT NULL,
  review_status     ENUM('PUBLISHED','HIDDEN') NOT NULL DEFAULT 'PUBLISHED',
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (review_id),
  UNIQUE KEY uq_est_reviews_user (establishment_id, user_id),
  KEY idx_est_reviews_user (user_id),
  CONSTRAINT fk_est_reviews_establishment
    FOREIGN KEY (establishment_id) REFERENCES establishments (establishment_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_est_reviews_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_est_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ===== H. MAP & TRANSPORT =====
CREATE TABLE map_layers (
  layer_id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  layer_code           VARCHAR(30) NOT NULL COMMENT 'Matches data-layer attribute in itineraries.html',
  layer_name           VARCHAR(80) NOT NULL,
  marker_color         CHAR(7) NULL,
  is_default_visible   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (layer_id),
  UNIQUE KEY uq_map_layers_code (layer_code),
  UNIQUE KEY uq_map_layers_name (layer_name)
) ENGINE=InnoDB;

CREATE TABLE map_points (
  point_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  layer_id        INT UNSIGNED NOT NULL,
  location_id     INT UNSIGNED NULL,
  destination_id  INT UNSIGNED NULL,
  point_name      VARCHAR(150) NOT NULL,
  description     VARCHAR(500) NULL,
  address         VARCHAR(255) NULL,
  latitude        DECIMAL(9,6) NOT NULL,
  longitude       DECIMAL(9,6) NOT NULL,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (point_id),
  KEY idx_map_points_layer (layer_id),
  KEY idx_map_points_location (location_id),
  KEY idx_map_points_destination (destination_id),
  KEY idx_map_points_coords (latitude, longitude),
  CONSTRAINT fk_map_points_layer
    FOREIGN KEY (layer_id) REFERENCES map_layers (layer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_map_points_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_map_points_destination
    FOREIGN KEY (destination_id) REFERENCES destinations (destination_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_map_points_lat CHECK (latitude  BETWEEN -90  AND 90),
  CONSTRAINT chk_map_points_lng CHECK (longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB;

CREATE TABLE transport_routes (
  route_id                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  route_name               VARCHAR(150) NOT NULL,
  destination_location_id  INT UNSIGNED NULL,
  description              VARCHAR(500) NULL,
  is_active                BOOLEAN NOT NULL DEFAULT TRUE,
  created_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (route_id),
  UNIQUE KEY uq_transport_routes_name (route_name),
  KEY idx_transport_routes_destination (destination_location_id),
  CONSTRAINT fk_transport_routes_location
    FOREIGN KEY (destination_location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE transport_route_fares (
  fare_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  route_id       INT UNSIGNED NOT NULL,
  trip_type      ENUM('ONE_WAY','ROUND_TRIP') NOT NULL,
  amount         DECIMAL(10,2) NOT NULL,
  currency_code  CHAR(3) NOT NULL DEFAULT 'PHP',
  PRIMARY KEY (fare_id),
  UNIQUE KEY uq_route_fares (route_id, trip_type),
  KEY idx_route_fares_currency (currency_code),
  CONSTRAINT fk_route_fares_route
    FOREIGN KEY (route_id) REFERENCES transport_routes (route_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_route_fares_currency
    FOREIGN KEY (currency_code) REFERENCES currencies (currency_code) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_route_fares_amount CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE transport_route_stops (
  stop_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  route_id      INT UNSIGNED NOT NULL,
  stop_order    SMALLINT UNSIGNED NOT NULL,
  stop_name     VARCHAR(150) NOT NULL,
  map_point_id  INT UNSIGNED NULL COMMENT 'Optional link once the stop has map coordinates',
  PRIMARY KEY (stop_id),
  UNIQUE KEY uq_route_stops_order (route_id, stop_order),
  KEY idx_route_stops_point (map_point_id),
  CONSTRAINT fk_route_stops_route
    FOREIGN KEY (route_id) REFERENCES transport_routes (route_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_route_stops_point
    FOREIGN KEY (map_point_id) REFERENCES map_points (point_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_route_stops_order CHECK (stop_order >= 1)
) ENGINE=InnoDB;

-- ===== I. SAFETY & ADVISORIES (editable content) =====
CREATE TABLE safety_advisory_categories (
  category_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_name  VARCHAR(80) NOT NULL,
  description    VARCHAR(255) NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_safety_categories_name (category_name)
) ENGINE=InnoDB;

CREATE TABLE safety_advisories (
  advisory_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id       INT UNSIGNED NOT NULL,
  title             VARCHAR(150) NOT NULL,
  body              TEXT NOT NULL,
  is_important      BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Highlighted "important" card in the frontend',
  advisory_status   ENUM('DRAFT','PUBLISHED','ARCHIVED') NOT NULL DEFAULT 'PUBLISHED',
  effective_from    DATE NULL,
  effective_until   DATE NULL,
  updated_by        INT UNSIGNED NULL,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (advisory_id),
  UNIQUE KEY uq_safety_advisories_title (category_id, title),
  KEY idx_safety_advisories_status (advisory_status),
  KEY idx_safety_advisories_updated_by (updated_by),
  CONSTRAINT fk_safety_advisories_category
    FOREIGN KEY (category_id) REFERENCES safety_advisory_categories (category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_safety_advisories_user
    FOREIGN KEY (updated_by) REFERENCES users (user_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_safety_advisories_dates CHECK (effective_until IS NULL OR effective_from IS NULL OR effective_until >= effective_from)
) ENGINE=InnoDB;

CREATE TABLE safety_advisory_locations (   -- no rows for an advisory = applies generally
  advisory_id  INT UNSIGNED NOT NULL,
  location_id  INT UNSIGNED NOT NULL,
  PRIMARY KEY (advisory_id, location_id),
  KEY idx_advisory_locations_location (location_id),
  CONSTRAINT fk_advisory_locations_advisory
    FOREIGN KEY (advisory_id) REFERENCES safety_advisories (advisory_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_advisory_locations_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE emergency_contacts (
  contact_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  advisory_id   INT UNSIGNED NULL,
  location_id   INT UNSIGNED NULL,
  contact_name  VARCHAR(150) NOT NULL,
  phone_number  VARCHAR(30) NOT NULL,
  availability  VARCHAR(80) NULL,
  notes         VARCHAR(255) NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (contact_id),
  KEY idx_emergency_contacts_advisory (advisory_id),
  KEY idx_emergency_contacts_location (location_id),
  CONSTRAINT fk_emergency_contacts_advisory
    FOREIGN KEY (advisory_id) REFERENCES safety_advisories (advisory_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_emergency_contacts_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ===== G. CURATED ITINERARIES =====
CREATE TABLE itinerary_interests (
  interest_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  interest_name  VARCHAR(80) NOT NULL,
  PRIMARY KEY (interest_id),
  UNIQUE KEY uq_itinerary_interests_name (interest_name)
) ENGINE=InnoDB;

CREATE TABLE curated_itineraries (
  itinerary_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  interest_id    INT UNSIGNED NULL,
  location_id    INT UNSIGNED NULL,
  title          VARCHAR(150) NOT NULL,
  summary        TEXT NULL,
  duration_days  SMALLINT UNSIGNED NOT NULL,
  difficulty     ENUM('EASY','MODERATE','DIFFICULT') NULL,
  travel_style   VARCHAR(60) NULL,
  image_url      VARCHAR(500) NULL,
  is_published   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (itinerary_id),
  UNIQUE KEY uq_curated_itineraries_title (title),
  KEY idx_curated_itineraries_interest (interest_id),
  KEY idx_curated_itineraries_location (location_id),
  KEY idx_curated_itineraries_duration (duration_days),
  CONSTRAINT fk_curated_itineraries_interest
    FOREIGN KEY (interest_id) REFERENCES itinerary_interests (interest_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_curated_itineraries_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_curated_itineraries_duration CHECK (duration_days > 0)
) ENGINE=InnoDB;

CREATE TABLE curated_itinerary_days (
  day_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  itinerary_id  INT UNSIGNED NOT NULL,
  day_number    SMALLINT UNSIGNED NOT NULL,
  title         VARCHAR(150) NULL,
  PRIMARY KEY (day_id),
  UNIQUE KEY uq_curated_days (itinerary_id, day_number),
  CONSTRAINT fk_curated_days_itinerary
    FOREIGN KEY (itinerary_id) REFERENCES curated_itineraries (itinerary_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_curated_days_number CHECK (day_number >= 1)
) ENGINE=InnoDB;

CREATE TABLE curated_itinerary_stops (
  stop_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  day_id          INT UNSIGNED NOT NULL,
  stop_order      SMALLINT UNSIGNED NOT NULL,
  time_slot       ENUM('MORNING','AFTERNOON','EVENING') NULL,
  title           VARCHAR(150) NULL,
  description     TEXT NULL,
  destination_id  INT UNSIGNED NULL,
  experience_id   INT UNSIGNED NULL,
  location_id     INT UNSIGNED NULL,
  PRIMARY KEY (stop_id),
  UNIQUE KEY uq_curated_stops_order (day_id, stop_order),
  KEY idx_curated_stops_destination (destination_id),
  KEY idx_curated_stops_experience (experience_id),
  KEY idx_curated_stops_location (location_id),
  CONSTRAINT fk_curated_stops_day
    FOREIGN KEY (day_id) REFERENCES curated_itinerary_days (day_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_curated_stops_destination
    FOREIGN KEY (destination_id) REFERENCES destinations (destination_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_curated_stops_experience
    FOREIGN KEY (experience_id) REFERENCES experiences (experience_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_curated_stops_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_curated_stops_order CHECK (stop_order >= 1),
  CONSTRAINT chk_curated_stops_content CHECK (title IS NOT NULL OR description IS NOT NULL)
) ENGINE=InnoDB;

-- ===== G. USER TRIP PLANNER ("My Trip") =====
CREATE TABLE trip_plans (
  trip_id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id              INT UNSIGNED NOT NULL,
  source_itinerary_id  INT UNSIGNED NULL COMMENT 'Curated itinerary this trip was copied from, if any',
  trip_title           VARCHAR(150) NOT NULL,
  start_date           DATE NULL,
  end_date             DATE NULL,
  trip_status          ENUM('DRAFT','PLANNED','ONGOING','COMPLETED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  offline_exported_at  DATETIME NULL COMMENT 'Last "Export Offline Guide (PDF)"',
  notes                TEXT NULL,
  created_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (trip_id),
  KEY idx_trip_plans_user (user_id, trip_status),
  KEY idx_trip_plans_source (source_itinerary_id),
  KEY idx_trip_plans_dates (start_date, end_date),
  CONSTRAINT fk_trip_plans_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_trip_plans_source
    FOREIGN KEY (source_itinerary_id) REFERENCES curated_itineraries (itinerary_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_trip_plans_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
) ENGINE=InnoDB;

CREATE TABLE trip_days (
  trip_day_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  trip_id      INT UNSIGNED NOT NULL,
  day_number   SMALLINT UNSIGNED NOT NULL,
  trip_date    DATE NULL,
  title        VARCHAR(150) NULL,
  PRIMARY KEY (trip_day_id),
  UNIQUE KEY uq_trip_days_number (trip_id, day_number),
  UNIQUE KEY uq_trip_days_date (trip_id, trip_date),
  CONSTRAINT fk_trip_days_trip
    FOREIGN KEY (trip_id) REFERENCES trip_plans (trip_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_trip_days_number CHECK (day_number >= 1)
) ENGINE=InnoDB;

CREATE TABLE trip_activities (
  activity_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  trip_day_id     INT UNSIGNED NOT NULL,
  sort_order      SMALLINT UNSIGNED NOT NULL,
  time_slot       ENUM('MORNING','AFTERNOON','EVENING') NULL,
  start_time      TIME NULL,
  title           VARCHAR(150) NOT NULL,
  notes           TEXT NULL,
  destination_id  INT UNSIGNED NULL,
  experience_id   INT UNSIGNED NULL,
  booking_id      INT UNSIGNED NULL,
  location_id     INT UNSIGNED NULL,
  PRIMARY KEY (activity_id),
  UNIQUE KEY uq_trip_activities_order (trip_day_id, sort_order),
  KEY idx_trip_activities_destination (destination_id),
  KEY idx_trip_activities_experience (experience_id),
  KEY idx_trip_activities_booking (booking_id),
  KEY idx_trip_activities_location (location_id),
  CONSTRAINT fk_trip_activities_day
    FOREIGN KEY (trip_day_id) REFERENCES trip_days (trip_day_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_trip_activities_destination
    FOREIGN KEY (destination_id) REFERENCES destinations (destination_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_trip_activities_experience
    FOREIGN KEY (experience_id) REFERENCES experiences (experience_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_trip_activities_booking
    FOREIGN KEY (booking_id) REFERENCES experience_bookings (booking_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_trip_activities_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_trip_activities_order CHECK (sort_order >= 1)
) ENGINE=InnoDB;

CREATE TABLE trip_booking_tickets (      -- purchased tour tickets stored in a trip
  trip_id     INT UNSIGNED NOT NULL,
  booking_id  INT UNSIGNED NOT NULL,
  added_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (trip_id, booking_id),
  KEY idx_trip_booking_tickets_booking (booking_id),
  CONSTRAINT fk_trip_tickets_trip
    FOREIGN KEY (trip_id) REFERENCES trip_plans (trip_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_trip_tickets_booking
    FOREIGN KEY (booking_id) REFERENCES experience_bookings (booking_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE trip_pass_purchases (       -- purchased travel passes attached to a trip
  trip_id      INT UNSIGNED NOT NULL,
  purchase_id  INT UNSIGNED NOT NULL,
  added_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (trip_id, purchase_id),
  KEY idx_trip_pass_purchases_purchase (purchase_id),
  CONSTRAINT fk_trip_passes_trip
    FOREIGN KEY (trip_id) REFERENCES trip_plans (trip_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_trip_passes_purchase
    FOREIGN KEY (purchase_id) REFERENCES pass_purchases (purchase_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE saved_locations (           -- "Saved Locations" list (itineraries.html)
  user_id      INT UNSIGNED NOT NULL,
  location_id  INT UNSIGNED NOT NULL,
  saved_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, location_id),
  KEY idx_saved_locations_location (location_id),
  CONSTRAINT fk_saved_locations_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_saved_locations_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE saved_destinations (
  user_id         INT UNSIGNED NOT NULL,
  destination_id  INT UNSIGNED NOT NULL,
  saved_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, destination_id),
  KEY idx_saved_destinations_destination (destination_id),
  CONSTRAINT fk_saved_destinations_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_saved_destinations_destination
    FOREIGN KEY (destination_id) REFERENCES destinations (destination_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE saved_curated_itineraries ( -- "Save Path" button (destinations.html)
  user_id       INT UNSIGNED NOT NULL,
  itinerary_id  INT UNSIGNED NOT NULL,
  saved_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, itinerary_id),
  KEY idx_saved_itineraries_itinerary (itinerary_id),
  CONSTRAINT fk_saved_itineraries_user
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_saved_itineraries_itinerary
    FOREIGN KEY (itinerary_id) REFERENCES curated_itineraries (itinerary_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TRIGGERS AND PROCEDURES (booking integrity)
-- ---------------------------------------------------------------------
DELIMITER $$

-- Reject new active bookings on schedules that are not OPEN.
CREATE TRIGGER trg_exp_bookings_bi
BEFORE INSERT ON experience_bookings
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20);
  IF NEW.booking_status IN ('PENDING','CONFIRMED') THEN
    SELECT schedule_status INTO v_status
      FROM experience_schedules WHERE schedule_id = NEW.schedule_id;
    IF v_status IS NULL OR v_status <> 'OPEN' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Schedule is not open for booking';
    END IF;
  END IF;
END$$

-- Slots are held by PENDING / CONFIRMED / COMPLETED bookings. CHECK chk_schedule_booked
-- (booked_slots <= capacity) makes the increment fail atomically if capacity is exceeded.
CREATE TRIGGER trg_exp_bookings_ai
AFTER INSERT ON experience_bookings
FOR EACH ROW
BEGIN
  IF NEW.booking_status IN ('PENDING','CONFIRMED','COMPLETED') THEN
    UPDATE experience_schedules
       SET booked_slots = booked_slots + NEW.quantity
     WHERE schedule_id = NEW.schedule_id;
  END IF;
END$$

CREATE TRIGGER trg_exp_bookings_au
AFTER UPDATE ON experience_bookings
FOR EACH ROW
BEGIN
  DECLARE v_old_active TINYINT DEFAULT 0;
  DECLARE v_new_active TINYINT DEFAULT 0;
  IF OLD.booking_status IN ('PENDING','CONFIRMED','COMPLETED') THEN SET v_old_active = 1; END IF;
  IF NEW.booking_status IN ('PENDING','CONFIRMED','COMPLETED') THEN SET v_new_active = 1; END IF;
  IF OLD.schedule_id <> NEW.schedule_id OR OLD.quantity <> NEW.quantity OR v_old_active <> v_new_active THEN
    IF v_old_active = 1 THEN
      UPDATE experience_schedules SET booked_slots = booked_slots - OLD.quantity
       WHERE schedule_id = OLD.schedule_id;
    END IF;
    IF v_new_active = 1 THEN
      UPDATE experience_schedules SET booked_slots = booked_slots + NEW.quantity
       WHERE schedule_id = NEW.schedule_id;
    END IF;
  END IF;
END$$

-- Protect transaction history: bookings and purchases are cancelled/refunded, never deleted.
CREATE TRIGGER trg_exp_bookings_bd
BEFORE DELETE ON experience_bookings
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bookings cannot be deleted. Set booking_status to CANCELLED instead';
END$$

CREATE TRIGGER trg_pass_purchases_bd
BEFORE DELETE ON pass_purchases
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pass purchases cannot be deleted. Set purchase_status to CANCELLED or REFUNDED instead';
END$$

-- Transactional booking: locks the schedule row, snapshots the current price, creates the booking.
CREATE PROCEDURE sp_book_experience (
  IN  p_user_id          INT UNSIGNED,
  IN  p_schedule_id      INT UNSIGNED,
  IN  p_quantity         SMALLINT UNSIGNED,
  IN  p_special_requests VARCHAR(500),
  OUT p_booking_id       INT UNSIGNED
)
BEGIN
  DECLARE v_price     DECIMAL(10,2);
  DECLARE v_currency  CHAR(3);
  DECLARE v_status    VARCHAR(20);
  DECLARE v_start     DATETIME;
  DECLARE v_published TINYINT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_quantity IS NULL OR p_quantity < 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be at least 1';
  END IF;

  START TRANSACTION;

  SELECT e.price_per_person, e.currency_code, s.schedule_status, s.start_datetime, e.is_published
    INTO v_price, v_currency, v_status, v_start, v_published
    FROM experience_schedules s
    JOIN experiences e ON e.experience_id = s.experience_id
   WHERE s.schedule_id = p_schedule_id
     FOR UPDATE;

  IF v_price IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Schedule not found';
  END IF;
  IF v_published = 0 OR v_status <> 'OPEN' OR v_start <= NOW() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Experience schedule is not available for booking';
  END IF;

  -- The trigger raises the capacity CHECK error here if there are not enough slots left.
  INSERT INTO experience_bookings
    (booking_reference, user_id, schedule_id, quantity, unit_price, currency_code, special_requests)
  VALUES
    (CONCAT('EXP-', UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12))),
     p_user_id, p_schedule_id, p_quantity, v_price, v_currency, p_special_requests);

  SET p_booking_id = LAST_INSERT_ID();
  COMMIT;
END$$

-- Transactional pass purchase: snapshots the current option price.
CREATE PROCEDURE sp_purchase_pass (
  IN  p_user_id      INT UNSIGNED,
  IN  p_option_id    INT UNSIGNED,
  IN  p_quantity     SMALLINT UNSIGNED,
  OUT p_purchase_id  INT UNSIGNED
)
BEGIN
  DECLARE v_price     DECIMAL(10,2);
  DECLARE v_currency  CHAR(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_quantity IS NULL OR p_quantity < 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be at least 1';
  END IF;

  START TRANSACTION;

  SELECT o.price, o.currency_code
    INTO v_price, v_currency
    FROM pass_options o
    JOIN travel_passes p ON p.pass_id = o.pass_id
   WHERE o.option_id = p_option_id AND o.is_active = 1 AND p.is_active = 1
     FOR SHARE;

  IF v_price IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pass option not found or inactive';
  END IF;

  INSERT INTO pass_purchases
    (purchase_reference, user_id, option_id, quantity, unit_price, currency_code)
  VALUES
    (CONCAT('PAS-', UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12))),
     p_user_id, p_option_id, p_quantity, v_price, v_currency);

  SET p_purchase_id = LAST_INSERT_ID();
  COMMIT;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- VIEWS (read models for the frontend)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_destination_cards AS
SELECT d.destination_id,
       d.destination_name,
       c.category_name,
       l.location_name,
       h.hours_type,
       h.open_time,
       h.close_time,
       (SELECT GROUP_CONCAT(CONCAT(f.fee_label, ': ', f.amount, ' ', f.currency_code) SEPARATOR '; ')
          FROM destination_fees f WHERE f.destination_id = d.destination_id) AS fees,
       (SELECT GROUP_CONCAT(af.feature_name SEPARATOR ', ')
          FROM destination_accessibility_features daf
          JOIN accessibility_features af ON af.feature_id = daf.feature_id
         WHERE daf.destination_id = d.destination_id) AS accessibility,
       d.image_url
  FROM destinations d
  JOIN destination_categories c ON c.category_id = d.category_id
  LEFT JOIN locations l ON l.location_id = d.location_id
  LEFT JOIN destination_opening_hours h
         ON h.destination_id = d.destination_id AND h.season_label = 'Standard' AND h.day_scope = 'ALL'
 WHERE d.is_published = 1;

CREATE OR REPLACE VIEW v_experience_cards AS
SELECT e.experience_id,
       e.title,
       ec.category_name,
       e.price_per_person,
       e.currency_code,
       e.duration_minutes,
       e.rating_avg,
       e.review_count,
       hp.display_name AS host_name,
       (SELECT MIN(s.start_datetime)
          FROM experience_schedules s
         WHERE s.experience_id = e.experience_id
           AND s.schedule_status = 'OPEN'
           AND s.start_datetime > NOW()
           AND s.booked_slots < s.capacity) AS next_available,
       e.image_path
  FROM experiences e
  JOIN experience_categories ec ON ec.category_id = e.category_id
  LEFT JOIN host_profiles hp ON hp.host_id = e.host_id
 WHERE e.is_published = 1;

CREATE OR REPLACE VIEW v_pass_pricing AS
SELECT p.pass_id,
       p.pass_name,
       p.discount_percent,
       p.validity_days,
       o.option_id,
       o.option_label,
       o.duration_days,
       o.price,
       o.currency_code
  FROM travel_passes p
  JOIN pass_options o ON o.pass_id = p.pass_id
 WHERE p.is_active = 1 AND o.is_active = 1;

-- ---------------------------------------------------------------------
-- PART 4: SAMPLE DATA (taken from the HTML files; see notes in comments)
-- IDs are explicit so that the foreign keys below are readable and deterministic.
-- ---------------------------------------------------------------------

-- Roles / permissions (backend design, NOT shown in the frontend)
INSERT INTO roles (role_id, role_name, description) VALUES
  (1, 'ADMIN',      'Platform administrator'),
  (2, 'TRAVELER',   'Registered traveler'),
  (3, 'LOCAL_HOST', 'Verified local tour host'),
  (4, 'STAFF',      'Tourism operations staff');

INSERT INTO permissions (permission_id, permission_code, description) VALUES
  (1, 'USER_MANAGE',            'Manage user accounts and roles'),
  (2, 'CONTENT_MANAGE',         'Manage destinations, events, directory, map, advisories and itineraries'),
  (3, 'BOOKING_MANAGE_ALL',     'View and manage all bookings and purchases'),
  (4, 'EXPERIENCE_MANAGE_OWN',  'Create and manage own experiences and schedules'),
  (5, 'TRIP_MANAGE_OWN',        'Create and manage own trip plans and saved items'),
  (6, 'BOOKING_CREATE',         'Book experiences and purchase passes'),
  (7, 'REVIEW_CREATE',          'Write reviews');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
  FROM roles r CROSS JOIN permissions p
 WHERE r.role_name = 'ADMIN'
    OR (r.role_name = 'TRAVELER'   AND p.permission_code IN ('TRIP_MANAGE_OWN','BOOKING_CREATE','REVIEW_CREATE'))
    OR (r.role_name = 'LOCAL_HOST' AND p.permission_code IN ('TRIP_MANAGE_OWN','BOOKING_CREATE','REVIEW_CREATE','EXPERIENCE_MANAGE_OWN'))
    OR (r.role_name = 'STAFF'      AND p.permission_code IN ('CONTENT_MANAGE','BOOKING_MANAGE_ALL'));

-- Currencies (PHP everywhere; USD because the Coron route fare is shown as "$499")
INSERT INTO currencies (currency_code, currency_name, symbol) VALUES
  ('PHP', 'Philippine Peso', '₱'),
  ('USD', 'US Dollar',       '$');

-- Locations. Parent links are set only where the HTML states containment
-- (e.g. "Iriga City, Bicol Region", "Lipa, Batangas", "Coron, Palawan").
INSERT INTO locations (location_id, parent_location_id, location_name, location_type) VALUES
  (1,  NULL, 'Bicol Region',   'REGION'),
  (2,  NULL, 'Batangas',       'PROVINCE'),
  (3,  NULL, 'Cavite',         'PROVINCE'),
  (4,  NULL, 'Rizal',          'PROVINCE'),
  (5,  NULL, 'Palawan',        'PROVINCE'),
  (6,  NULL, 'Bohol',          'PROVINCE'),
  (7,  NULL, 'Aklan',          'PROVINCE'),
  (8,  1,    'Catanduanes',    'PROVINCE'),
  (9,  1,    'Camarines Sur',  'PROVINCE'),
  (10, NULL, 'Albay',          'PROVINCE'),
  (11, 1,    'Iriga City',     'CITY_MUNICIPALITY'),
  (12, 2,    'Lipa',           'CITY_MUNICIPALITY'),
  (13, 3,    'Silang',         'CITY_MUNICIPALITY'),
  (14, 4,    'Binangonan',     'CITY_MUNICIPALITY'),
  (15, NULL, 'Manila',         'CITY_MUNICIPALITY'),
  (16, NULL, 'Puerto Princesa','CITY_MUNICIPALITY'),
  (17, NULL, 'Vigan',          'CITY_MUNICIPALITY'),
  (18, NULL, 'Donsol',         'CITY_MUNICIPALITY'),
  (19, NULL, 'Caramoan',       'CITY_MUNICIPALITY'),
  (20, 7,    'Boracay',        'AREA'),
  (21, 5,    'Coron',          'CITY_MUNICIPALITY'),
  (22, 6,    'Chocolate Hills','AREA');

-- About page contact information
INSERT INTO site_settings (setting_key, setting_value) VALUES
  ('contact_office_address', 'Quezon City, Metro Manila, Philippines'),
  ('contact_email',          'travel@pilipinastravel.ph'),
  ('contact_phone',          '+63 92 8123 4567'),
  ('contact_operating_hours','Monday-Friday, 9:00 AM-5:00 PM PHT');

-- B. Destinations (destinations.html)
INSERT INTO destination_categories (category_id, category_name) VALUES
  (1, 'Cultural Sites'), (2, 'Natural Parks'), (3, 'Historic Landmarks');

INSERT INTO destinations (destination_id, category_id, location_id, destination_name, image_url) VALUES
  (1, 1, 15, 'Fort Santiago',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Fort_Santiago%2C_Intramuros%2C_Manila.jpg'),
  (2, 2, 16, 'Puerto Princesa Subterranean River',
      'https://commons.wikimedia.org/wiki/Special:FilePath/PUERTO_PRINCESA_UNDERGROUND_RIVER.jpg'),
  (3, 3, 17, 'Historic City of Vigan',
      'https://commons.wikimedia.org/wiki/Special:FilePath/Calle_Crisologo_Vigan_City.jpg');

INSERT INTO destination_opening_hours (destination_id, hours_type, open_time, close_time) VALUES
  (1, 'FIXED',             '08:30:00', '17:00:00'),
  (2, 'SUNRISE_TO_SUNSET', NULL,       NULL),
  (3, 'FIXED',             '09:00:00', '19:30:00');

INSERT INTO destination_fees (destination_id, fee_label, amount, currency_code) VALUES
  (1, 'General Admission', 0.00,  'PHP'),   -- "Free Admission"
  (2, 'Ecosystem Fee',     50.00, 'PHP'),   -- "₱50 Ecosystem Fee"
  (3, 'General Admission', 0.00,  'PHP');   -- "Free admission"

INSERT INTO accessibility_features (feature_id, feature_name) VALUES
  (1, 'Ramped Paths'), (2, 'All-terrain Wheelchair Paths'), (3, 'Walkable Paths');

INSERT INTO destination_accessibility_features (destination_id, feature_id) VALUES
  (1, 1), (2, 2), (3, 3);

-- C. Experiences (experiences.html). Categories are inferred; see the notes in the answer.
INSERT INTO experience_categories (category_id, category_name) VALUES
  (1, 'Water Sports'), (2, 'Workshops'), (3, 'Hikes'), (4, 'Adventure');

INSERT INTO experiences
  (experience_id, host_id, category_id, location_id, title, price_per_person, currency_code,
   duration_minutes, rating_avg, review_count, image_path) VALUES
  (1, NULL, 4, NULL, 'ATV Ride near Mayon Volcano',        2500.00, 'PHP', 270, 4.9, 180, 'img/atv.jpg'),
  (2, NULL, 1, 18,   'Swim with Whale Sharks in Donsol',   1320.00, 'PHP',  30, 5.0,  90, 'img/whale sharks.jpeg'),
  (3, NULL, 1, 19,   'Island Hopping in Caramoan',         1850.00, 'PHP',  45, 4.8, 210, 'img/island hopping.jpg');
-- No schedules/bookings: "3 Slots Left Today", "Available Tomorrow", "Available Saturday" are relative labels.

-- D. Travel passes (experiences.html)
INSERT INTO travel_passes (pass_id, pass_name, discount_percent, validity_days) VALUES
  (1, 'Cagsawa Ruins Explorer Pass',   35.00, 7),
  (2, 'Caramoan Island Hopping Pass',  40.00, 5);

INSERT INTO pass_inclusions (pass_id, inclusion_type, description, sort_order) VALUES
  (1, 'TRANSPORT_SERVICE', 'Unlimited Rail & Coaster Service',   1),
  (1, 'ACTIVITY_ACCESS',   'Access to ATV and Hot Spring Resort', 2),
  (2, 'TRANSPORT_SERVICE', 'Coaster/Van Service',                1),
  (2, 'ACTIVITY_ACCESS',   'Free Other Water Activities',        2);

INSERT INTO pass_options (pass_id, option_label, duration_days, price, currency_code) VALUES
  (1, '1-Day',  1,  899.00, 'PHP'),
  (1, '3-Days', 3, 1299.00, 'PHP'),
  (1, '1 Week', 7, 1999.00, 'PHP'),
  (2, '1-Day',  1,  999.00, 'PHP'),
  (2, '3-Days', 3, 1499.00, 'PHP'),
  (2, '1 Week', 7, 1999.00, 'PHP');

-- E. Events (experiences.html "Live Calendar"). The frontend shows no year, so start_date stays NULL.
INSERT INTO event_categories (category_id, category_name, filter_group) VALUES
  (1, 'Local Festival',        'FESTIVALS_MARKETS'),
  (2, 'Market',                'FESTIVALS_MARKETS'),
  (3, 'Music & Performance',   'MUSIC_PERFORMANCE'),
  (4, 'Sports',                'SPORTS');

INSERT INTO events (event_id, category_id, location_id, event_title, date_label, image_path) VALUES
  (1, 1, 11, 'Tinagba Festival', 'Oct 14', 'img/tinagba.jpeg'),
  (2, 1, 9,  'Kaogma Festival',  'Oct 19', 'img/kaogma.jpg'),
  (3, 1, 8,  'Abaca Festival',   'Oct 22', 'img/abaca.jpeg');

-- F. Local directory (experiences.html "Stay & Eat Directory")
INSERT INTO establishment_categories (category_id, category_name) VALUES
  (1, 'Eco Stays & Hotels'), (2, 'Restaurants & Cafes'), (3, 'Villa');

INSERT INTO cuisine_service_categories (cuisine_service_id, cuisine_service_name) VALUES
  (1, 'Filipino'), (2, 'Bakery'), (3, 'Farm-to-Table');

INSERT INTO establishments
  (establishment_id, category_id, location_id, establishment_name, price_range, rating_avg, review_count, image_path) VALUES
  (1, 1, 12, 'The Farm at San Benito', NULL, 4.9, 184, 'img/theFarm.jpg'),
  (2, 2, 13, 'Cafe Agapita',           NULL, 4.8, 250, 'img/agapita.jpeg'),
  (3, 3, 14, 'The Beach Villa',        NULL, 4.7, 112, 'img/theBeach.jpeg');
-- price_range is NULL: the frontend only prints "Price Point: Php" (no tier).
-- No cuisine assignments and no review rows: the frontend does not state them.

-- H. Map layers (itineraries.html "Points of Interests" toggles)
INSERT INTO map_layers (layer_id, layer_code, layer_name, marker_color, is_default_visible, sort_order) VALUES
  (1, 'historical', 'Historical Attractions',    '#c86b3d', TRUE,  1),
  (2, 'transit',    'Public Transit Terminals',  '#c86b3d', TRUE,  2),
  (3, 'visitor',    'Official Visitor Centers',  '#6b6055', FALSE, 3),
  (4, 'medical',    'Emergency Medical Stations','#c86b3d', TRUE,  4);
-- map_points intentionally empty: no coordinates are provided and none are invented.

-- H. Transport routes ("Scheduled Pathways")
INSERT INTO transport_routes (route_id, route_name, destination_location_id) VALUES
  (1, 'Chocolate Hills, Bohol', 22),
  (2, 'Boracay, Aklan',         20),
  (3, 'Coron, Palawan',         21);

INSERT INTO transport_route_fares (route_id, trip_type, amount, currency_code) VALUES
  (1, 'ROUND_TRIP', 799.00, 'PHP'),
  (2, 'ONE_WAY',    699.00, 'PHP'),
  (3, 'ONE_WAY',    499.00, 'USD');   -- the frontend shows "$499"

INSERT INTO transport_route_stops (route_id, stop_order, stop_name) VALUES
  (1, 1, 'Tagbilaran City'),
  (1, 2, 'Blood Compact Shrine'),
  (1, 3, 'Philippine Tarsier Sanctuary'),
  (1, 4, 'Bilar Man-Made Forest'),
  (1, 5, 'Chocolate Hills'),
  (2, 1, 'Caticlan Airport'),
  (2, 2, 'Caticlan Jetty Port'),
  (2, 3, 'Boracay Port'),
  (2, 4, 'D''Mall'),
  (2, 5, 'White Beach'),
  (2, 6, 'Puka Shell Beach'),
  (3, 1, 'Busuanga Airport'),
  (3, 2, 'Coron Town'),
  (3, 3, 'Lualhati Park'),
  (3, 4, 'Mt. Tapyas'),
  (3, 5, 'Maquinit Hot Spring');

-- I. Safety advisories (itineraries.html). Text is editable content.
INSERT INTO safety_advisory_categories (category_id, category_name) VALUES
  (1, 'Customs & Etiquette'),
  (2, 'Weather Advisory'),
  (3, 'Entry Requirements'),
  (4, 'Local Exchange'),
  (5, 'Emergency Support');

INSERT INTO safety_advisories (advisory_id, category_id, title, body, is_important) VALUES
  (1, 1, 'Heritage Courtesies',
      'When visiting active monastic grounds or ancient ruins, keep shoulders covered. Always request consent before taking photographs of resident artisans and town elders.', FALSE),
  (2, 2, 'High-Altitude Changes',
      'The Eldorado Highlands experience rapid temperature drops post-sunset. Visitors are strongly advised to carry thermal outer layers and waterproof utility gear.', TRUE),
  (3, 3, 'Visa & Compliance',
      'Travelers staying under 30 days are eligible for stamp-upon-arrival entry. Ensure passport validity extends a minimum of six months past your scheduled return departure date.', FALSE),
  (4, 4, 'Currency & Tipping',
      'While city passes are digitally integrated, mountain villages strictly operate via cash local currency. Keep small denominations handy; tipping is appreciated but not mandatory.', FALSE),
  (5, 5, 'Municipal Hotline Hub',
      'In case of medical emergencies or mountain trail misdirection, connect immediately to our active rescue coordinators. Dial 112 from any regional cell connection.', TRUE);

INSERT INTO emergency_contacts (advisory_id, contact_name, phone_number, notes) VALUES
  (5, 'Municipal Hotline Hub', '112', 'Dial 112 from any regional cell connection.');

-- G. Curated itineraries (destinations.html "Pre-Planned Regional Expeditions" + itineraries.html sample)
INSERT INTO itinerary_interests (interest_id, interest_name) VALUES
  (1, 'Eco-Tourism'), (2, 'Culinary & Crafts');

INSERT INTO curated_itineraries
  (itinerary_id, interest_id, location_id, title, duration_days, difficulty, image_url) VALUES
  (1, 1, NULL, 'Eco-Treasures of the Ridge & Coast', 5, 'MODERATE',
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80'),
  (2, 2, NULL, 'The Slow Bread & Craft Route', 3, 'EASY',
      'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=800&q=80'),
  (3, NULL, 20, 'Sample 3-Day Boracay, Aklan Exploration', 3, NULL, NULL);

INSERT INTO curated_itinerary_days (day_id, itinerary_id, day_number, title) VALUES
  (1, 1, 1, NULL), (2, 1, 2, NULL), (3, 1, 3, NULL),
  (4, 2, 1, NULL), (5, 2, 2, NULL), (6, 2, 3, NULL),
  (7, 3, 1, 'Transit & The Central Hub'),
  (8, 3, 2, 'The Iconic White Beach'),
  (9, 3, 3, 'The Iconic White Beach');

-- Only Days 1-3 of the 5-day Eco itinerary are listed in the frontend, so only those are stored.
INSERT INTO curated_itinerary_stops (day_id, stop_order, time_slot, title, description) VALUES
  (1, 1, NULL, 'Valley Hike', NULL),
  (2, 1, NULL, 'Bird Sanctuary', NULL),
  (3, 1, NULL, 'Coastal Kayaking', NULL),
  (4, 1, NULL, 'Sourdough Mill', NULL),
  (5, 1, NULL, 'Woodcarver Atelier', NULL),
  (6, 1, NULL, 'Vineyard Dinner', NULL),
  (7, 1, 'MORNING',   NULL, 'Arrive at the airport, collect your bags, and take a quick van ride to the jetty.'),
  (7, 2, 'AFTERNOON', NULL, 'Complete the short boat crossing and prepare to head to your accommodation. Walk around the vibrant outdoor mall to pick up any forgotten beach essentials or grab a quick coffee.'),
  (7, 3, 'EVENING',   NULL, 'Enjoy a relaxed dinner in the area before getting some rest after a long travel day.'),
  (8, 1, 'MORNING',   NULL, 'Hit the beach early for a workout or a quiet walk along the shore.'),
  (8, 2, 'AFTERNOON', NULL, 'Rent a paddleboard, go snorkeling, or grab a fresh fruit shake from a beachfront vendor.'),
  (8, 3, 'EVENING',   NULL, 'Secure a spot on the sand to watch the iconic Boracay sunset, followed by dinner and enjoying the island''s lively beachfront nightlife.'),
  (9, 1, 'MORNING',   NULL, 'Swim in the clear waters and relax away from the busy central stations.'),
  (9, 2, 'AFTERNOON', NULL, 'Head back toward the port area for a relaxed coffee break before the return journey.'),
  (9, 3, 'EVENING',   NULL, 'Begin your return sequence: ride back to the Boracay Jetty Port, ferry over to the Caticlan Jetty Port, and head back to the airport for your flight home.');

-- No users, hosts, bookings, purchases, trips or saved items are seeded (none exist in the project).

-- ---------------------------------------------------------------------
-- PART 5: VALIDATION QUERIES
-- ---------------------------------------------------------------------

-- 5.1 All tables created (expected: 54 base tables)
SELECT COUNT(*) AS base_table_count
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA = 'pilipinas_travel' AND TABLE_TYPE = 'BASE TABLE';

-- 5.2 Every table has a primary key (expected: 0 rows)
SELECT t.TABLE_NAME
  FROM information_schema.TABLES t
  LEFT JOIN information_schema.TABLE_CONSTRAINTS tc
         ON tc.TABLE_SCHEMA = t.TABLE_SCHEMA AND tc.TABLE_NAME = t.TABLE_NAME
        AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
 WHERE t.TABLE_SCHEMA = 'pilipinas_travel' AND t.TABLE_TYPE = 'BASE TABLE'
   AND tc.CONSTRAINT_NAME IS NULL;

-- 5.3 Foreign keys with their ON DELETE / ON UPDATE rules
SELECT k.TABLE_NAME, k.CONSTRAINT_NAME, k.COLUMN_NAME,
       k.REFERENCED_TABLE_NAME, k.REFERENCED_COLUMN_NAME,
       r.DELETE_RULE, r.UPDATE_RULE
  FROM information_schema.KEY_COLUMN_USAGE k
  JOIN information_schema.REFERENTIAL_CONSTRAINTS r
    ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
 WHERE k.TABLE_SCHEMA = 'pilipinas_travel' AND k.REFERENCED_TABLE_NAME IS NOT NULL
 ORDER BY k.TABLE_NAME, k.CONSTRAINT_NAME;

-- 5.4 Destinations with hours, fees and accessibility
SELECT * FROM v_destination_cards ORDER BY destination_name;

-- 5.5 Experiences (and any bookings / remaining slots)
SELECT * FROM v_experience_cards ORDER BY price_per_person;

SELECT e.title, s.start_datetime, s.capacity, s.booked_slots, s.remaining_slots,
       COUNT(b.booking_id) AS bookings
  FROM experiences e
  LEFT JOIN experience_schedules s ON s.experience_id = e.experience_id
  LEFT JOIN experience_bookings b  ON b.schedule_id = s.schedule_id
 GROUP BY e.experience_id, e.title, s.schedule_id, s.start_datetime, s.capacity, s.booked_slots, s.remaining_slots;

-- 5.6 Travel passes, inclusions and prices
SELECT * FROM v_pass_pricing ORDER BY pass_id, duration_days;

SELECT p.pass_name, i.inclusion_type, i.description
  FROM travel_passes p JOIN pass_inclusions i ON i.pass_id = p.pass_id
 ORDER BY p.pass_id, i.sort_order;

-- 5.7 Events and establishments (with region/province resolved through the location hierarchy)
SELECT ev.event_title, ec.category_name, ev.date_label, loc.location_name AS location, parent.location_name AS region
  FROM events ev
  JOIN event_categories ec ON ec.category_id = ev.category_id
  JOIN locations loc       ON loc.location_id = ev.location_id
  LEFT JOIN locations parent ON parent.location_id = loc.parent_location_id
 ORDER BY ev.event_id;

SELECT es.establishment_name, ecat.category_name, loc.location_name AS town,
       parent.location_name AS province, es.rating_avg, es.review_count
  FROM establishments es
  JOIN establishment_categories ecat ON ecat.category_id = es.category_id
  JOIN locations loc                 ON loc.location_id = es.location_id
  LEFT JOIN locations parent         ON parent.location_id = loc.parent_location_id
 ORDER BY es.establishment_id;

-- 5.8 Transportation routes, fares and ordered stops
SELECT r.route_name, f.trip_type, f.amount, f.currency_code
  FROM transport_routes r JOIN transport_route_fares f ON f.route_id = r.route_id
 ORDER BY r.route_id;

SELECT r.route_name, GROUP_CONCAT(s.stop_name ORDER BY s.stop_order SEPARATOR ' -> ') AS route_stops
  FROM transport_routes r JOIN transport_route_stops s ON s.route_id = r.route_id
 GROUP BY r.route_id, r.route_name
 ORDER BY r.route_id;

-- 5.9 Map layers, safety advisories, curated itineraries
SELECT layer_code, layer_name, is_default_visible FROM map_layers ORDER BY sort_order;

SELECT c.category_name, a.title, a.is_important
  FROM safety_advisories a JOIN safety_advisory_categories c ON c.category_id = a.category_id
 ORDER BY a.advisory_id;

SELECT ci.title, ci.duration_days, ci.difficulty, d.day_number, d.title AS day_title,
       s.stop_order, s.time_slot, COALESCE(s.title, LEFT(s.description, 40)) AS stop
  FROM curated_itineraries ci
  JOIN curated_itinerary_days d  ON d.itinerary_id = ci.itinerary_id
  JOIN curated_itinerary_stops s ON s.day_id = d.day_id
 ORDER BY ci.itinerary_id, d.day_number, s.stop_order;

-- 5.10 User trip plans and saved locations (empty until users exist)
SELECT u.email, tp.trip_title, tp.trip_status, td.day_number, td.trip_date, ta.time_slot, ta.title
  FROM trip_plans tp
  JOIN users u            ON u.user_id = tp.user_id
  LEFT JOIN trip_days td  ON td.trip_id = tp.trip_id
  LEFT JOIN trip_activities ta ON ta.trip_day_id = td.trip_day_id
 ORDER BY tp.trip_id, td.day_number, ta.sort_order;

SELECT u.email, l.location_name, sl.saved_at
  FROM saved_locations sl
  JOIN users u     ON u.user_id = sl.user_id
  JOIN locations l ON l.location_id = sl.location_id;

-- 5.11 Orphan checks (every result should be 0)
SELECT COUNT(*) AS orphan_destinations
  FROM destinations d LEFT JOIN destination_categories c ON c.category_id = d.category_id
 WHERE c.category_id IS NULL;
SELECT COUNT(*) AS orphan_route_stops
  FROM transport_route_stops s LEFT JOIN transport_routes r ON r.route_id = s.route_id
 WHERE r.route_id IS NULL;

-- 5.12 Optional end-to-end booking test (run manually; ROLLBACK leaves no data behind).
-- It temporarily creates a user and a schedule, books 2 of 2 slots, and proves a third booking fails.
-- START TRANSACTION;
--   INSERT INTO users (email, password_hash, first_name, last_name)
--   VALUES ('test@example.com', '$2y$10$abcdefghijklmnopqrstuvabcdefghijklmnopqrstuvabcdefghi', 'Test', 'User');
--   SET @u := LAST_INSERT_ID();
--   INSERT INTO experience_schedules (experience_id, start_datetime, capacity)
--   VALUES (1, DATE_ADD(NOW(), INTERVAL 7 DAY), 2);
--   SET @s := LAST_INSERT_ID();
--   CALL sp_book_experience(@u, @s, 2, NULL, @b);      -- succeeds
--   SELECT schedule_id, capacity, booked_slots, remaining_slots FROM experience_schedules WHERE schedule_id = @s;
--   CALL sp_book_experience(@u, @s, 1, NULL, @b2);     -- fails: chk_schedule_booked
-- ROLLBACK;
