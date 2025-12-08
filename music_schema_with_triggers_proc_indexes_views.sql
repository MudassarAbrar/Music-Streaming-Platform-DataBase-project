-- ====== OPTIONAL: DROP TABLES IN CORRECT ORDER (Oracle) ======
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE play_events CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE playlist_tracks CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE playlists CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE tracks CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE albums CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE users CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE genres CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE roles CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/



-- ====== TABLE: ROLES ======
CREATE TABLE roles (  
    id            NUMBER(10),  
    name          VARCHAR2(50)    NOT NULL UNIQUE,  
    created_at    DATE            DEFAULT SYSDATE NOT NULL,  
    updated_at    DATE            DEFAULT SYSDATE NOT NULL,  
    CONSTRAINT pk_roles PRIMARY KEY (id)  
);

-- Sequence for ROLES table
CREATE SEQUENCE roles_seq
 START WITH 1
 INCREMENT BY 1
 NOMAXVALUE
 NOCACHE;

-- ====== TABLE: GENRES ======
CREATE TABLE genres (  
    id            NUMBER(10),  
    name          VARCHAR2(50)    NOT NULL UNIQUE,  
    created_at    DATE            DEFAULT SYSDATE NOT NULL,  
    updated_at    DATE            DEFAULT SYSDATE NOT NULL,  
    CONSTRAINT pk_genres PRIMARY KEY (id)  
);

-- Sequence for GENRES table
CREATE SEQUENCE genres_seq
 START WITH 1
 INCREMENT BY 1
 NOMAXVALUE
 NOCACHE;

-- ====== TABLE: USERS ======
CREATE TABLE users (  
    id               NUMBER(10),  
    role_id          NUMBER(10)       NOT NULL,  
    password_hash    VARCHAR2(255)    NOT NULL,  
    display_name     VARCHAR2(100),  
    email            VARCHAR2(255)    NOT NULL,  
    created_at       DATE             DEFAULT SYSDATE NOT NULL,  
    updated_at       DATE             DEFAULT SYSDATE NOT NULL,  
    deleted_at       DATE,  
    CONSTRAINT pk_users PRIMARY KEY (id),  
    CONSTRAINT uq_users_email UNIQUE (email),  
    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id) REFERENCES roles(id)
);

-- Sequence for USERS table
CREATE SEQUENCE users_seq
 START WITH 1
 INCREMENT BY 1
 NOMAXVALUE
 NOCACHE;

-- ====== TABLE: ALBUMS ======
CREATE TABLE albums (  
    id              NUMBER(10),  
    user_id         NUMBER(10)      NOT NULL, -- Artist who created the album  
    title           VARCHAR2(255)   NOT NULL,  
    release_date    DATE            NOT NULL,  
    cover_art_url   VARCHAR2(255),  
    created_at      DATE            DEFAULT SYSDATE NOT NULL,  
    updated_at      DATE            DEFAULT SYSDATE NOT NULL,  
    deleted_at      DATE,  
    CONSTRAINT pk_albums PRIMARY KEY (id),  
    CONSTRAINT fk_albums_user  
        FOREIGN KEY (user_id) REFERENCES users(id)
            ON DELETE CASCADE
);

-- Sequence for ALBUMS table
CREATE SEQUENCE albums_seq
 START WITH 1
 INCREMENT BY 1
 NOMAXVALUE
 NOCACHE;

-- ====== TABLE: TRACKS ======
CREATE TABLE tracks (  
    id               NUMBER(10),  
    user_id          NUMBER(10)      NOT NULL, -- Artist who uploaded the track  
    album_id         NUMBER(10),             -- Nullable: singles not part of album  
    genre_id         NUMBER(10)      NOT NULL,  
    title            VARCHAR2(255)   NOT NULL,  
    duration_seconds NUMBER(10)      NOT NULL,  
    explicit_flag    NUMBER(1)       DEFAULT 0 NOT NULL,  
    created_at       DATE            DEFAULT SYSDATE NOT NULL,  
    updated_at       DATE            DEFAULT SYSDATE NOT NULL,  
    deleted_at       DATE,  
    CONSTRAINT pk_tracks PRIMARY KEY (id),  
    CONSTRAINT fk_tracks_user  
        FOREIGN KEY (user_id) REFERENCES users(id)
            ON DELETE CASCADE,
    CONSTRAINT fk_tracks_album  
        FOREIGN KEY (album_id) REFERENCES albums(id)
            ON DELETE SET NULL,
    CONSTRAINT fk_tracks_genre  
        FOREIGN KEY (genre_id) REFERENCES genres(id),
    CONSTRAINT chk_tracks_duration  
        CHECK (duration_seconds > 0),  
    CONSTRAINT chk_tracks_explicit_flag  
        CHECK (explicit_flag IN (0,1))  
);

-- Sequence for TRACKS table
CREATE SEQUENCE tracks_seq
 START WITH 1
 INCREMENT BY 1
 NOMAXVALUE
 NOCACHE;

-- ====== TABLE: PLAYLISTS ======
CREATE TABLE playlists (  
    id            NUMBER(10),  
    user_id       NUMBER(10)      NOT NULL, -- Listener who owns the playlist  
    name          VARCHAR2(150)   NOT NULL,  
    is_private    NUMBER(1)       DEFAULT 1 NOT NULL,
    last_position NUMBER(10)      DEFAULT 0 NOT NULL,
    created_at    DATE            DEFAULT SYSDATE NOT NULL,  
    updated_at    DATE            DEFAULT SYSDATE NOT NULL,  
    deleted_at    DATE,  
    CONSTRAINT pk_playlists PRIMARY KEY (id),  
    CONSTRAINT fk_playlists_user  
        FOREIGN KEY (user_id) REFERENCES users(id)
            ON DELETE CASCADE,
    CONSTRAINT uq_playlists_user_name  
        UNIQUE (user_id, name),  
    CONSTRAINT chk_playlists_is_private  
        CHECK (is_private IN (0,1))  
);

-- Sequence for PLAYLISTS table
CREATE SEQUENCE playlists_seq
 START WITH 1
 INCREMENT BY 1
 NOMAXVALUE
 NOCACHE;

-- ====== TABLE: PLAYLIST_TRACKS (junction) ======
CREATE TABLE playlist_tracks (  
    playlist_id NUMBER(10)      NOT NULL,  
    track_id    NUMBER(10)      NOT NULL,  
    position    NUMBER(10)      NOT NULL,  
    added_at    DATE            DEFAULT SYSDATE NOT NULL,  
    created_at  DATE            DEFAULT SYSDATE NOT NULL,  
    updated_at  DATE            DEFAULT SYSDATE NOT NULL,  
    CONSTRAINT pk_playlist_tracks  
        PRIMARY KEY (playlist_id, track_id),  
    CONSTRAINT fk_pt_playlist  
        FOREIGN KEY (playlist_id) REFERENCES playlists(id)  
            ON DELETE CASCADE,  
    CONSTRAINT fk_pt_track  
        FOREIGN KEY (track_id) REFERENCES tracks(id)
            ON DELETE CASCADE,
    CONSTRAINT uq_pt_playlist_position  
        UNIQUE (playlist_id, position),  
    CONSTRAINT chk_pt_position  
        CHECK (position >= 1)  
);

-- Trigger to auto-assign position using playlists.last_position
CREATE OR REPLACE TRIGGER trg_playlist_tracks_position
BEFORE INSERT ON playlist_tracks
FOR EACH ROW
DECLARE
    v_next_pos NUMBER;
BEGIN
    IF :NEW.position IS NULL THEN
        -- Atomic update to parent table to get next sequence number
        -- This locks the playlist row to prevent race conditions
        UPDATE playlists
        SET last_position = last_position + 1,
            updated_at = SYSDATE
        WHERE id = :NEW.playlist_id
        RETURNING last_position INTO v_next_pos;
        
        :NEW.position := v_next_pos;
    END IF;
END;
/

-- ====== TABLE: PLAY_EVENTS ======
CREATE TABLE play_events (  
    id            NUMBER(10),  
    user_id       NUMBER(10)      NOT NULL,  
    track_id      NUMBER(10)      NOT NULL,  
    played_at     TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    created_at    DATE            DEFAULT SYSDATE NOT NULL,  
    updated_at    DATE            DEFAULT SYSDATE NOT NULL,  
    CONSTRAINT pk_play_events PRIMARY KEY (id),  
    CONSTRAINT fk_pe_user  
        FOREIGN KEY (user_id) REFERENCES users(id)
            ON DELETE CASCADE,
    CONSTRAINT fk_pe_track  
        FOREIGN KEY (track_id) REFERENCES tracks(id)
            ON DELETE CASCADE
);

-- Sequence for PLAY_EVENTS table
CREATE SEQUENCE play_events_seq
 START WITH 1
 INCREMENT BY 1
 NOMAXVALUE
 NOCACHE;

-- ====== TABLE: LIKES ======
CREATE TABLE likes (
    user_id    NUMBER(10) NOT NULL,
    track_id   NUMBER(10) NOT NULL,
    liked_at   DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_likes PRIMARY KEY (user_id, track_id),
    CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_likes_track FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- ====== TABLE: FOLLOWS ======
CREATE TABLE follows (
    follower_id  NUMBER(10) NOT NULL,
    followed_id  NUMBER(10) NOT NULL,
    created_at   DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_follows PRIMARY KEY (follower_id, followed_id),
    CONSTRAINT fk_follows_follower FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_follows_followed FOREIGN KEY (followed_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_no_self_follow CHECK (follower_id != followed_id)
);

------------------------------------------------------------
-- RBAC HELPER FUNCTION
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_current_role
RETURN NUMBER
AS
    v_role NUMBER;
    v_user_id VARCHAR2(255);
BEGIN
    -- Retrieve the application-level user ID from context.
    -- If NULL (e.g., during seed script execution), we assume ADMIN (3)
    -- to allow the script to run without errors.
    v_user_id := SYS_CONTEXT('MYAPP', 'CURRENT_USER_ID');
    
    IF v_user_id IS NULL THEN
        RETURN 3; -- Default to Admin
    END IF;

    BEGIN
        SELECT role_id INTO v_role
        FROM users
        WHERE id = TO_NUMBER(v_user_id);
    EXCEPTION WHEN NO_DATA_FOUND THEN
        RETURN 3; -- Default to Admin if user not found
    END;

    RETURN v_role;
END;
/

------------------------------------------------------------
-- RBAC PROTECTION TRIGGERS
-- Roles: 1=Listener, 2=Artist, 3=Admin
------------------------------------------------------------

-- 1. ALBUMS: Block Listeners. Artists can only touch their own.
CREATE OR REPLACE TRIGGER trg_protect_albums
BEFORE INSERT OR UPDATE ON albums
FOR EACH ROW
DECLARE
    r NUMBER := get_current_role();
    v_current_uid NUMBER;
BEGIN
    IF r = 3 THEN RETURN; END IF; -- Admin bypass

    IF r = 1 THEN -- Listener
        RAISE_APPLICATION_ERROR(-20020, 'Listeners are not allowed to add or modify albums.');
    END IF;
    
    IF r = 2 THEN -- Artist
        v_current_uid := TO_NUMBER(SYS_CONTEXT('MYAPP', 'CURRENT_USER_ID'));
        -- Allow if they are checking their own data.
        -- If INSERTING, :NEW.user_id must match context.
        -- If UPDATING, :OLD.user_id must match context (and they shouldn't change ownership).
        IF INSERTING AND :NEW.user_id != v_current_uid THEN
             RAISE_APPLICATION_ERROR(-20025, 'Artists can only add albums for themselves.');
        END IF;
        IF UPDATING AND :OLD.user_id != v_current_uid THEN
             RAISE_APPLICATION_ERROR(-20025, 'Artists cannot modify albums they do not own.');
        END IF;
    END IF;
END;
/

-- 2. TRACKS: Block Listeners. Artists can only touch their own.
CREATE OR REPLACE TRIGGER trg_protect_tracks
BEFORE INSERT OR UPDATE ON tracks
FOR EACH ROW
DECLARE
    r NUMBER := get_current_role();
    v_current_uid NUMBER;
BEGIN
    IF r = 3 THEN RETURN; END IF; -- Admin bypass

    IF r = 1 THEN -- Listener
        RAISE_APPLICATION_ERROR(-20021, 'Listeners cannot add or modify tracks.');
    END IF;

    IF r = 2 THEN -- Artist
        v_current_uid := TO_NUMBER(SYS_CONTEXT('MYAPP', 'CURRENT_USER_ID'));
        IF INSERTING AND :NEW.user_id != v_current_uid THEN
             RAISE_APPLICATION_ERROR(-20026, 'Artists can only add tracks for themselves.');
        END IF;
        IF UPDATING AND :OLD.user_id != v_current_uid THEN
             RAISE_APPLICATION_ERROR(-20026, 'Artists cannot modify tracks they do not own.');
        END IF;
    END IF;
END;
/

-- 3. USERS: Block Listeners and Artists from modifying table.
-- (Replaces "trg_protect_artists" and "trg_protect_users_from_artist")
CREATE OR REPLACE TRIGGER trg_protect_users
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
DECLARE
    r NUMBER := get_current_role();
BEGIN
    IF r = 3 THEN RETURN; END IF; -- Admin bypass

    -- Both Listeners (1) and Artists (2) are blocked from modifying the users table directly.
    RAISE_APPLICATION_ERROR(-20023, 'Only Admins can modify the users table.');
END;
/

-- 4. PLAYLISTS: Block Artists (per request). Listeners allowed.
CREATE OR REPLACE TRIGGER trg_protect_playlists
BEFORE INSERT OR UPDATE ON playlists
FOR EACH ROW
DECLARE
    r NUMBER := get_current_role();
BEGIN
    IF r = 3 THEN RETURN; END IF; -- Admin bypass

    IF r = 2 THEN -- Artist
        RAISE_APPLICATION_ERROR(-20027, 'Artists are not allowed to manage playlists.');
    END IF;
    -- Listeners (1) are allowed.
END;
/

-- 5. GENRES: Block everyone except Admin.
CREATE OR REPLACE TRIGGER trg_protect_genres
BEFORE INSERT OR UPDATE ON genres
FOR EACH ROW
DECLARE
    r NUMBER := get_current_role();
BEGIN
    IF r = 3 THEN RETURN; END IF; -- Admin bypass
    
    RAISE_APPLICATION_ERROR(-20028, 'Only Admins can manage genres.');
END;
/

------------------------------------------------------------
-- ROLES (3 rows needed for users.role_id FK)
------------------------------------------------------------
INSERT ALL
  INTO roles (name) VALUES ('Listener')
  INTO roles (name) VALUES ('Artist')
  INTO roles (name) VALUES ('Admin')
SELECT 1 FROM dual;



------------------------------------------------------------
-- GENRES (7 rows)
------------------------------------------------------------
INSERT ALL
  INTO genres (name) VALUES ('Pop')
  INTO genres (name) VALUES ('Rock')
  INTO genres (name) VALUES ('Hip Hop')
  INTO genres (name) VALUES ('Jazz')
  INTO genres (name) VALUES ('Classical')
  INTO genres (name) VALUES ('Electronic')
  INTO genres (name) VALUES ('Indie')
SELECT 1 FROM dual;

-- USERS (50 rows total)
--   First 10: Artists  (role_id = 2)
--   Next 40: Listeners (role_id = 1)
-- Identity will give them ids:
--   1-10  = artists
--   11-50 = listeners

INSERT ALL
  -- Artists (10) & Listeners (40)
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_01', 'Artist 1', 'artist1@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_02', 'Artist 2', 'artist2@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_03', 'Artist 3', 'artist3@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_04', 'Artist 4', 'artist4@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_05', 'Artist 5', 'artist5@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_06', 'Artist 6', 'artist6@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_07', 'Artist 7', 'artist7@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_08', 'Artist 8', 'artist8@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_09', 'Artist 9', 'artist9@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_10', 'Artist 10', 'artist10@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_11', 'Listener 11', 'listener11@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_12', 'Listener 12', 'listener12@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_13', 'Listener 13', 'listener13@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_14', 'Listener 14', 'listener14@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_15', 'Listener 15', 'listener15@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_16', 'Listener 16', 'listener16@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_17', 'Listener 17', 'listener17@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_18', 'Listener 18', 'listener18@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_19', 'Listener 19', 'listener19@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_20', 'Listener 20', 'listener20@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_21', 'Listener 21', 'listener21@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_22', 'Listener 22', 'listener22@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_23', 'Listener 23', 'listener23@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_24', 'Listener 24', 'listener24@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_25', 'Listener 25', 'listener25@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_26', 'Listener 26', 'listener26@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_27', 'Listener 27', 'listener27@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_28', 'Listener 28', 'listener28@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_29', 'Listener 29', 'listener29@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_30', 'Listener 30', 'listener30@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_31', 'Listener 31', 'listener31@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_32', 'Listener 32', 'listener32@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_33', 'Listener 33', 'listener33@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_34', 'Listener 34', 'listener34@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_35', 'Listener 35', 'listener35@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_36', 'Listener 36', 'listener36@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_37', 'Listener 37', 'listener37@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_38', 'Listener 38', 'listener38@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_39', 'Listener 39', 'listener39@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_40', 'Listener 40', 'listener40@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_41', 'Listener 41', 'listener41@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_42', 'Listener 42', 'listener42@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_43', 'Listener 43', 'listener43@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_44', 'Listener 44', 'listener44@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_45', 'Listener 45', 'listener45@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_46', 'Admin 46', 'admin46@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_47', 'Admin 47', 'admin47@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_48', 'Admin 48', 'admin48@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_49', 'Admin 49', 'admin49@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_50', 'Admin 50', 'admin50@musicapp.com')
SELECT 1 FROM dual;



------------------------------------------------------------
-- ALBUMS (50 rows)
-- Albums 1-50 (by identity) will be associated to artists 1–10 (cycling)
-- role id bhi add kri h
------------------------------------------------------------
INSERT ALL
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 1', TO_DATE('2023-01-01','YYYY-MM-DD'), 'ALBUM_01_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 2', TO_DATE('2023-01-02','YYYY-MM-DD'), 'ALBUM_02_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 3', TO_DATE('2023-01-03','YYYY-MM-DD'), 'ALBUM_03_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 4', TO_DATE('2023-01-04','YYYY-MM-DD'), 'ALBUM_04_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 5', TO_DATE('2023-01-05','YYYY-MM-DD'), 'ALBUM_05_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 6', TO_DATE('2023-01-06','YYYY-MM-DD'), 'ALBUM_06_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 7', TO_DATE('2023-01-07','YYYY-MM-DD'), 'ALBUM_07_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 8', TO_DATE('2023-01-08','YYYY-MM-DD'), 'ALBUM_08_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 9', TO_DATE('2023-01-09','YYYY-MM-DD'), 'ALBUM_09_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 10', TO_DATE('2023-01-10','YYYY-MM-DD'), 'ALBUM_10_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 11', TO_DATE('2023-01-11','YYYY-MM-DD'), 'ALBUM_11_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 12', TO_DATE('2023-01-12','YYYY-MM-DD'), 'ALBUM_12_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 13', TO_DATE('2023-01-13','YYYY-MM-DD'), 'ALBUM_13_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 14', TO_DATE('2023-01-14','YYYY-MM-DD'), 'ALBUM_14_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 15', TO_DATE('2023-01-15','YYYY-MM-DD'), 'ALBUM_15_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 16', TO_DATE('2023-01-16','YYYY-MM-DD'), 'ALBUM_16_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 17', TO_DATE('2023-01-17','YYYY-MM-DD'), 'ALBUM_17_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 18', TO_DATE('2023-01-18','YYYY-MM-DD'), 'ALBUM_18_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 19', TO_DATE('2023-01-19','YYYY-MM-DD'), 'ALBUM_19_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 20', TO_DATE('2023-01-20','YYYY-MM-DD'), 'ALBUM_20_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 21', TO_DATE('2023-01-21','YYYY-MM-DD'), 'ALBUM_21_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 22', TO_DATE('2023-01-22','YYYY-MM-DD'), 'ALBUM_22_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 23', TO_DATE('2023-01-23','YYYY-MM-DD'), 'ALBUM_23_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 24', TO_DATE('2023-01-24','YYYY-MM-DD'), 'ALBUM_24_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 25', TO_DATE('2023-01-25','YYYY-MM-DD'), 'ALBUM_25_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 26', TO_DATE('2023-01-26','YYYY-MM-DD'), 'ALBUM_26_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 27', TO_DATE('2023-01-27','YYYY-MM-DD'), 'ALBUM_27_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 28', TO_DATE('2023-01-28','YYYY-MM-DD'), 'ALBUM_28_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 29', TO_DATE('2023-01-29','YYYY-MM-DD'), 'ALBUM_29_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 30', TO_DATE('2023-01-30','YYYY-MM-DD'), 'ALBUM_30_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 31', TO_DATE('2023-01-31','YYYY-MM-DD'), 'ALBUM_31_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 32', TO_DATE('2023-02-01','YYYY-MM-DD'), 'ALBUM_32_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 33', TO_DATE('2023-02-02','YYYY-MM-DD'), 'ALBUM_33_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 34', TO_DATE('2023-02-03','YYYY-MM-DD'), 'ALBUM_34_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 35', TO_DATE('2023-02-04','YYYY-MM-DD'), 'ALBUM_35_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 36', TO_DATE('2023-02-05','YYYY-MM-DD'), 'ALBUM_36_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 37', TO_DATE('2023-02-06','YYYY-MM-DD'), 'ALBUM_37_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 38', TO_DATE('2023-02-07','YYYY-MM-DD'), 'ALBUM_38_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 39', TO_DATE('2023-02-08','YYYY-MM-DD'), 'ALBUM_39_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 40', TO_DATE('2023-02-09','YYYY-MM-DD'), 'ALBUM_40_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 41', TO_DATE('2023-02-10','YYYY-MM-DD'), 'ALBUM_41_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 42', TO_DATE('2023-02-11','YYYY-MM-DD'), 'ALBUM_42_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 43', TO_DATE('2023-02-12','YYYY-MM-DD'), 'ALBUM_43_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 44', TO_DATE('2023-02-13','YYYY-MM-DD'), 'ALBUM_44_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 45', TO_DATE('2023-02-14','YYYY-MM-DD'), 'ALBUM_45_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 46', TO_DATE('2023-02-15','YYYY-MM-DD'), 'ALBUM_46_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 47', TO_DATE('2023-02-16','YYYY-MM-DD'), 'ALBUM_47_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 48', TO_DATE('2023-02-17','YYYY-MM-DD'), 'ALBUM_48_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 49', TO_DATE('2023-02-18','YYYY-MM-DD'), 'ALBUM_49_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 50', TO_DATE('2023-02-19','YYYY-MM-DD'), 'ALBUM_50_COVER')
SELECT 1 FROM dual;



------------------------------------------------------------
-- TRACKS (50 rows)
-- Tracks 1-50 (by identity) will:
--   user_id  = artist ids cycling 1..10
--   album_id = same number as track (1..50)
--   genre_id = cycles 1..7
------------------------------------------------------------
INSERT ALL
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 1, 1, 'Track 1', 181, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 2, 2, 'Track 2', 182, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 3, 3, 'Track 3', 183, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 4, 4, 'Track 4', 184, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 5, 5, 'Track 5', 185, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 6, 6, 'Track 6', 186, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 7, 7, 'Track 7', 187, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 8, 8, 'Track 8', 188, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 9, 9, 'Track 9', 189, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 10, 10, 'Track 10', 190, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 11, 4, 'Track 11', 191, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 12, 5, 'Track 12', 192, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 13, 6, 'Track 13', 193, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 14, 7, 'Track 14', 194, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 15, 1, 'Track 15', 195, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 16, 2, 'Track 16', 196, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 17, 3, 'Track 17', 197, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 18, 4, 'Track 18', 198, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 19, 5, 'Track 19', 199, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 20, 6, 'Track 20', 200, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 21, 7, 'Track 21', 201, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 22, 1, 'Track 22', 202, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 23, 2, 'Track 23', 203, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 24, 3, 'Track 24', 204, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 25, 4, 'Track 25', 205, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 26, 5, 'Track 26', 206, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 27, 6, 'Track 27', 207, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 28, 7, 'Track 28', 208, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 29, 1, 'Track 29', 209, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 30, 2, 'Track 30', 210, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 31, 3, 'Track 31', 211, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 32, 4, 'Track 32', 212, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 33, 5, 'Track 33', 213, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 34, 6, 'Track 34', 214, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 35, 7, 'Track 35', 215, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 36, 1, 'Track 36', 216, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 37, 2, 'Track 37', 217, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 38, 3, 'Track 38', 218, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 39, 4, 'Track 39', 219, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 40, 5, 'Track 40', 220, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 41, 6, 'Track 41', 221, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 42, 7, 'Track 42', 222, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 43, 1, 'Track 43', 223, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 44, 2, 'Track 44', 224, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 45, 3, 'Track 45', 225, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 46, 4, 'Track 46', 226, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 47, 5, 'Track 47', 227, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 48, 6, 'Track 48', 228, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 49, 7, 'Track 49', 229, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 50, 1, 'Track 50', 230, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 1, 1, 'Track 1', 181, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 2, 2, 'Track 2', 182, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 3, 3, 'Track 3', 183, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 4, 4, 'Track 4', 184, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 5, 5, 'Track 5', 185, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 6, 6, 'Track 6', 186, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 7, 7, 'Track 7', 187, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 8, 8, 'Track 8', 188, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 9, 9, 'Track 9', 189, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 10, 10, 'Track 10', 190, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 11, 4, 'Track 11', 191, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 12, 5, 'Track 12', 192, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 13, 6, 'Track 13', 193, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 14, 7, 'Track 14', 194, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 15, 1, 'Track 15', 195, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 16, 2, 'Track 16', 196, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 17, 3, 'Track 17', 197, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 18, 4, 'Track 18', 198, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 19, 5, 'Track 19', 199, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 20, 6, 'Track 20', 200, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 21, 7, 'Track 21', 201, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 22, 1, 'Track 22', 202, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 23, 2, 'Track 23', 203, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 24, 3, 'Track 24', 204, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 25, 4, 'Track 25', 205, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 26, 5, 'Track 26', 206, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 27, 6, 'Track 27', 207, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 28, 7, 'Track 28', 208, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 29, 1, 'Track 29', 209, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 30, 2, 'Track 30', 210, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 31, 3, 'Track 31', 211, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 32, 4, 'Track 32', 212, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 33, 5, 'Track 33', 213, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 34, 6, 'Track 34', 214, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 35, 7, 'Track 35', 215, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 36, 1, 'Track 36', 216, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 37, 2, 'Track 37', 217, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 38, 3, 'Track 38', 218, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 39, 4, 'Track 39', 219, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 40, 5, 'Track 40', 220, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 41, 6, 'Track 41', 221, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 42, 7, 'Track 42', 222, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 43, 1, 'Track 43', 223, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 44, 2, 'Track 44', 224, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 45, 3, 'Track 45', 225, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 46, 4, 'Track 46', 226, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 47, 5, 'Track 47', 227, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 48, 6, 'Track 48', 228, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 49, 7, 'Track 49', 229, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 50, 1, 'Track 50', 230, 0)
SELECT 1 FROM dual;
INSERT ALL
  INTO playlists (user_id, name, is_private)
    VALUES (11, 'Playlist 1', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (12, 'Playlist 2', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (13, 'Playlist 3', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (14, 'Playlist 4', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (15, 'Playlist 5', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (16, 'Playlist 6', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (17, 'Playlist 7', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (18, 'Playlist 8', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (19, 'Playlist 9', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (20, 'Playlist 10', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (21, 'Playlist 11', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (22, 'Playlist 12', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (23, 'Playlist 13', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (24, 'Playlist 14', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (25, 'Playlist 15', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (26, 'Playlist 16', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (27, 'Playlist 17', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (28, 'Playlist 18', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (29, 'Playlist 19', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (30, 'Playlist 20', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (31, 0)
  INTO playlists (user_id, name, is_private)
    VALUES (32, 'Playlist 32', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (33, 'Playlist 33', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (34, 'Playlist 34', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (35, 'Playlist 35', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (36, 'Playlist 36', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (37, 'Playlist 37', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (38, 'Playlist 38', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (39, 'Playlist 39', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (40, 'Playlist 40', 1)
SELECT 1 FROM dual;
INSERT ALL
  -- Playlists 1–30, 4 tracks each
  INTO playlist_tracks (playlist_id, track_id) VALUES (1, 1)
  INTO playlist_tracks (playlist_id, track_id) VALUES (1, 2)
  INTO playlist_tracks (playlist_id, track_id) VALUES (1, 3)
  INTO playlist_tracks (playlist_id, track_id) VALUES (1, 4)

  INTO playlist_tracks (playlist_id, track_id) VALUES (2, 5)
  INTO playlist_tracks (playlist_id, track_id) VALUES (2, 6)
  INTO playlist_tracks (playlist_id, track_id) VALUES (2, 7)
  INTO playlist_tracks (playlist_id, track_id) VALUES (2, 8)

  INTO playlist_tracks (playlist_id, track_id) VALUES (3, 9)
  INTO playlist_tracks (playlist_id, track_id) VALUES (3, 10)
  INTO playlist_tracks (playlist_id, track_id) VALUES (3, 11)
  INTO playlist_tracks (playlist_id, track_id) VALUES (3, 12)

  INTO playlist_tracks (playlist_id, track_id) VALUES (4, 13)
  INTO playlist_tracks (playlist_id, track_id) VALUES (4, 14)
  INTO playlist_tracks (playlist_id, track_id) VALUES (4, 15)
  INTO playlist_tracks (playlist_id, track_id) VALUES (4, 16)

  INTO playlist_tracks (playlist_id, track_id) VALUES (5, 17)
  INTO playlist_tracks (playlist_id, track_id) VALUES (5, 18)
  INTO playlist_tracks (playlist_id, track_id) VALUES (5, 19)
  INTO playlist_tracks (playlist_id, track_id) VALUES (5, 20)

  INTO playlist_tracks (playlist_id, track_id) VALUES (6, 21)
  INTO playlist_tracks (playlist_id, track_id) VALUES (6, 22)
  INTO playlist_tracks (playlist_id, track_id) VALUES (6, 23)
  INTO playlist_tracks (playlist_id, track_id) VALUES (6, 24)

  INTO playlist_tracks (playlist_id, track_id) VALUES (7, 25)
  INTO playlist_tracks (playlist_id, track_id) VALUES (7, 26)
  INTO playlist_tracks (playlist_id, track_id) VALUES (7, 27)
  INTO playlist_tracks (playlist_id, track_id) VALUES (7, 28)

  INTO playlist_tracks (playlist_id, track_id) VALUES (8, 29)
  INTO playlist_tracks (playlist_id, track_id) VALUES (8, 30)
  INTO playlist_tracks (playlist_id, track_id) VALUES (8, 31)
  INTO playlist_tracks (playlist_id, track_id) VALUES (8, 32)

  INTO playlist_tracks (playlist_id, track_id) VALUES (9, 33)
  INTO playlist_tracks (playlist_id, track_id) VALUES (9, 34)
  INTO playlist_tracks (playlist_id, track_id) VALUES (9, 35)
  INTO playlist_tracks (playlist_id, track_id) VALUES (9, 36)

  INTO playlist_tracks (playlist_id, track_id) VALUES (10, 37)
  INTO playlist_tracks (playlist_id, track_id) VALUES (10, 38)
  INTO playlist_tracks (playlist_id, track_id) VALUES (10, 39)
  INTO playlist_tracks (playlist_id, track_id) VALUES (10, 40)

  INTO playlist_tracks (playlist_id, track_id) VALUES (11, 41)
  INTO playlist_tracks (playlist_id, track_id) VALUES (11, 42)
  INTO playlist_tracks (playlist_id, track_id) VALUES (11, 43)
  INTO playlist_tracks (playlist_id, track_id) VALUES (11, 44)

  INTO playlist_tracks (playlist_id, track_id) VALUES (12, 45)
  INTO playlist_tracks (playlist_id, track_id) VALUES (12, 46)
  INTO playlist_tracks (playlist_id, track_id) VALUES (12, 47)
  INTO playlist_tracks (playlist_id, track_id) VALUES (12, 48)

  INTO playlist_tracks (playlist_id, track_id) VALUES (13, 49)
  INTO playlist_tracks (playlist_id, track_id) VALUES (13, 50)
  INTO playlist_tracks (playlist_id, track_id) VALUES (13, 1)
  INTO playlist_tracks (playlist_id, track_id) VALUES (13, 2)

  INTO playlist_tracks (playlist_id, track_id) VALUES (14, 3)
  INTO playlist_tracks (playlist_id, track_id) VALUES (14, 4)
  INTO playlist_tracks (playlist_id, track_id) VALUES (14, 5)
  INTO playlist_tracks (playlist_id, track_id) VALUES (14, 6)

  INTO playlist_tracks (playlist_id, track_id) VALUES (15, 7)
  INTO playlist_tracks (playlist_id, track_id) VALUES (15, 8)
  INTO playlist_tracks (playlist_id, track_id) VALUES (15, 9)
  INTO playlist_tracks (playlist_id, track_id) VALUES (15, 10)

  INTO playlist_tracks (playlist_id, track_id) VALUES (16, 11)
  INTO playlist_tracks (playlist_id, track_id) VALUES (16, 12)
  INTO playlist_tracks (playlist_id, track_id) VALUES (16, 13)
  INTO playlist_tracks (playlist_id, track_id) VALUES (16, 14)

  INTO playlist_tracks (playlist_id, track_id) VALUES (17, 15)
  INTO playlist_tracks (playlist_id, track_id) VALUES (17, 16)
  INTO playlist_tracks (playlist_id, track_id) VALUES (17, 17)
  INTO playlist_tracks (playlist_id, track_id) VALUES (17, 18)

  INTO playlist_tracks (playlist_id, track_id) VALUES (18, 19)
  INTO playlist_tracks (playlist_id, track_id) VALUES (18, 20)
  INTO playlist_tracks (playlist_id, track_id) VALUES (18, 21)
  INTO playlist_tracks (playlist_id, track_id) VALUES (18, 22)

  INTO playlist_tracks (playlist_id, track_id) VALUES (19, 23)
  INTO playlist_tracks (playlist_id, track_id) VALUES (19, 24)
  INTO playlist_tracks (playlist_id, track_id) VALUES (19, 25)
  INTO playlist_tracks (playlist_id, track_id) VALUES (19, 26)

  INTO playlist_tracks (playlist_id, track_id) VALUES (20, 27)
  INTO playlist_tracks (playlist_id, track_id) VALUES (20, 28)
  INTO playlist_tracks (playlist_id, track_id) VALUES (20, 29)
  INTO playlist_tracks (playlist_id, track_id) VALUES (20, 30)

  INTO playlist_tracks (playlist_id, track_id) VALUES (21, 31)
  INTO playlist_tracks (playlist_id, track_id) VALUES (21, 32)
  INTO playlist_tracks (playlist_id, track_id) VALUES (21, 33)
  INTO playlist_tracks (playlist_id, track_id) VALUES (21, 34)

  INTO playlist_tracks (playlist_id, track_id) VALUES (22, 35)
  INTO playlist_tracks (playlist_id, track_id) VALUES (22, 36)
  INTO playlist_tracks (playlist_id, track_id) VALUES (22, 37)
  INTO playlist_tracks (playlist_id, track_id) VALUES (22, 38)

  INTO playlist_tracks (playlist_id, track_id) VALUES (23, 39)
  INTO playlist_tracks (playlist_id, track_id) VALUES (23, 40)
  INTO playlist_tracks (playlist_id, track_id) VALUES (23, 41)
  INTO playlist_tracks (playlist_id, track_id) VALUES (23, 42)

  INTO playlist_tracks (playlist_id, track_id) VALUES (24, 43)
  INTO playlist_tracks (playlist_id, track_id) VALUES (24, 44)
  INTO playlist_tracks (playlist_id, track_id) VALUES (24, 45)
  INTO playlist_tracks (playlist_id, track_id) VALUES (24, 46)

  INTO playlist_tracks (playlist_id, track_id) VALUES (25, 47)
  INTO playlist_tracks (playlist_id, track_id) VALUES (25, 48)
  INTO playlist_tracks (playlist_id, track_id) VALUES (25, 49)
  INTO playlist_tracks (playlist_id, track_id) VALUES (25, 50)

  INTO playlist_tracks (playlist_id, track_id) VALUES (26, 1)
  INTO playlist_tracks (playlist_id, track_id) VALUES (26, 2)
  INTO playlist_tracks (playlist_id, track_id) VALUES (26, 3)
  INTO playlist_tracks (playlist_id, track_id) VALUES (26, 4)

  INTO playlist_tracks (playlist_id, track_id) VALUES (27, 5)
  INTO playlist_tracks (playlist_id, track_id) VALUES (27, 6)
  INTO playlist_tracks (playlist_id, track_id) VALUES (27, 7)
  INTO playlist_tracks (playlist_id, track_id) VALUES (27, 8)

  INTO playlist_tracks (playlist_id, track_id) VALUES (28, 9)
  INTO playlist_tracks (playlist_id, track_id) VALUES (28, 10)
  INTO playlist_tracks (playlist_id, track_id) VALUES (28, 11)
  INTO playlist_tracks (playlist_id, track_id) VALUES (28, 12)

  INTO playlist_tracks (playlist_id, track_id) VALUES (29, 13)
  INTO playlist_tracks (playlist_id, track_id) VALUES (29, 14)
  INTO playlist_tracks (playlist_id, track_id) VALUES (29, 15)
  INTO playlist_tracks (playlist_id, track_id) VALUES (29, 16)

  INTO playlist_tracks (playlist_id, track_id) VALUES (30, 17)
  INTO playlist_tracks (playlist_id, track_id) VALUES (30, 18)
  INTO playlist_tracks (playlist_id, track_id) VALUES (30, 19)
  INTO playlist_tracks (playlist_id, track_id) VALUES (30, 20)

  -- Playlists 31–40, 3 tracks each
  INTO playlist_tracks (playlist_id, track_id) VALUES (31, 21)
  INTO playlist_tracks (playlist_id, track_id) VALUES (31, 22)
  INTO playlist_tracks (playlist_id, track_id) VALUES (31, 23)

  INTO playlist_tracks (playlist_id, track_id) VALUES (32, 24)
  INTO playlist_tracks (playlist_id, track_id) VALUES (32, 25)
  INTO playlist_tracks (playlist_id, track_id) VALUES (32, 26)

  INTO playlist_tracks (playlist_id, track_id) VALUES (33, 27)
  INTO playlist_tracks (playlist_id, track_id) VALUES (33, 28)
  INTO playlist_tracks (playlist_id, track_id) VALUES (33, 29)

  INTO playlist_tracks (playlist_id, track_id) VALUES (34, 30)
  INTO playlist_tracks (playlist_id, track_id) VALUES (34, 31)
  INTO playlist_tracks (playlist_id, track_id) VALUES (34, 32)

  INTO playlist_tracks (playlist_id, track_id) VALUES (35, 33)
  INTO playlist_tracks (playlist_id, track_id) VALUES (35, 34)
  INTO playlist_tracks (playlist_id, track_id) VALUES (35, 35)

  INTO playlist_tracks (playlist_id, track_id) VALUES (36, 36)
  INTO playlist_tracks (playlist_id, track_id) VALUES (36, 37)
  INTO playlist_tracks (playlist_id, track_id) VALUES (36, 38)

  INTO playlist_tracks (playlist_id, track_id) VALUES (37, 39)
  INTO playlist_tracks (playlist_id, track_id) VALUES (37, 40)
  INTO playlist_tracks (playlist_id, track_id) VALUES (37, 41)

  INTO playlist_tracks (playlist_id, track_id) VALUES (38, 42)
  INTO playlist_tracks (playlist_id, track_id) VALUES (38, 43)
  INTO playlist_tracks (playlist_id, track_id) VALUES (38, 44)

  INTO playlist_tracks (playlist_id, track_id) VALUES (39, 45)
  INTO playlist_tracks (playlist_id, track_id) VALUES (39, 46)
  INTO playlist_tracks (playlist_id, track_id) VALUES (39, 47)

  INTO playlist_tracks (playlist_id, track_id) VALUES (40, 48)
  INTO playlist_tracks (playlist_id, track_id) VALUES (40, 49)
  INTO playlist_tracks (playlist_id, track_id) VALUES (40, 50)
SELECT 1 FROM dual;
INSERT ALL
  -- Artists (10) & Listeners (40)
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_01', 'Artist 1', 'artist1@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_02', 'Artist 2', 'artist2@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_03', 'Artist 3', 'artist3@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_04', 'Artist 4', 'artist4@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_05', 'Artist 5', 'artist5@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_06', 'Artist 6', 'artist6@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_07', 'Artist 7', 'artist7@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_08', 'Artist 8', 'artist8@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_09', 'Artist 9', 'artist9@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (2, 'hash_artist_10', 'Artist 10', 'artist10@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_11', 'Listener 11', 'listener11@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_12', 'Listener 12', 'listener12@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_13', 'Listener 13', 'listener13@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_14', 'Listener 14', 'listener14@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_15', 'Listener 15', 'listener15@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_16', 'Listener 16', 'listener16@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_17', 'Listener 17', 'listener17@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_18', 'Listener 18', 'listener18@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_19', 'Listener 19', 'listener19@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_20', 'Listener 20', 'listener20@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_21', 'Listener 21', 'listener21@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_22', 'Listener 22', 'listener22@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_23', 'Listener 23', 'listener23@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)\n    VALUES (1, 'hash_listener_24', 'Listener 24', 'listener24@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_25', 'Listener 25', 'listener25@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_26', 'Listener 26', 'listener26@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_27', 'Listener 27', 'listener27@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_28', 'Listener 28', 'listener28@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_29', 'Listener 29', 'listener29@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_30', 'Listener 30', 'listener30@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_31', 'Listener 31', 'listener31@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_32', 'Listener 32', 'listener32@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_33', 'Listener 33', 'listener33@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_34', 'Listener 34', 'listener34@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_35', 'Listener 35', 'listener35@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_36', 'Listener 36', 'listener36@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_37', 'Listener 37', 'listener37@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_38', 'Listener 38', 'listener38@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_39', 'Listener 39', 'listener39@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_40', 'Listener 40', 'listener40@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_41', 'Listener 41', 'listener41@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_42', 'Listener 42', 'listener42@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_43', 'Listener 43', 'listener43@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_44', 'Listener 44', 'listener44@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (1, 'hash_listener_45', 'Listener 45', 'listener45@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_46', 'Admin 46', 'admin46@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_47', 'Admin 47', 'admin47@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_48', 'Admin 48', 'admin48@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_49', 'Admin 49', 'admin49@musicapp.com')
  INTO users (role_id, password_hash, display_name, email)
    VALUES (3, 'hash_admin_50', 'Admin 50', 'admin50@musicapp.com')
SELECT 1 FROM dual;


------------------------------------------------------------
-- ALBUMS (50 rows)
-- Albums 1-50 (by identity) will be associated to artists 1–10 (cycling)
-- role id bhi add kri h
------------------------------------------------------------
INSERT ALL
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 1', TO_DATE('2023-01-01','YYYY-MM-DD'), 'ALBUM_01_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 2', TO_DATE('2023-01-02','YYYY-MM-DD'), 'ALBUM_02_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 3', TO_DATE('2023-01-03','YYYY-MM-DD'), 'ALBUM_03_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 4', TO_DATE('2023-01-04','YYYY-MM-DD'), 'ALBUM_04_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 5', TO_DATE('2023-01-05','YYYY-MM-DD'), 'ALBUM_05_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 6', TO_DATE('2023-01-06','YYYY-MM-DD'), 'ALBUM_06_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 7', TO_DATE('2023-01-07','YYYY-MM-DD'), 'ALBUM_07_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 8', TO_DATE('2023-01-08','YYYY-MM-DD'), 'ALBUM_08_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 9', TO_DATE('2023-01-09','YYYY-MM-DD'), 'ALBUM_09_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 10', TO_DATE('2023-01-10','YYYY-MM-DD'), 'ALBUM_10_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 11', TO_DATE('2023-01-11','YYYY-MM-DD'), 'ALBUM_11_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 12', TO_DATE('2023-01-12','YYYY-MM-DD'), 'ALBUM_12_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 13', TO_DATE('2023-01-13','YYYY-MM-DD'), 'ALBUM_13_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 14', TO_DATE('2023-01-14','YYYY-MM-DD'), 'ALBUM_14_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 15', TO_DATE('2023-01-15','YYYY-MM-DD'), 'ALBUM_15_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 16', TO_DATE('2023-01-16','YYYY-MM-DD'), 'ALBUM_16_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 17', TO_DATE('2023-01-17','YYYY-MM-DD'), 'ALBUM_17_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 18', TO_DATE('2023-01-18','YYYY-MM-DD'), 'ALBUM_18_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 19', TO_DATE('2023-01-19','YYYY-MM-DD'), 'ALBUM_19_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 20', TO_DATE('2023-01-20','YYYY-MM-DD'), 'ALBUM_20_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 21', TO_DATE('2023-01-21','YYYY-MM-DD'), 'ALBUM_21_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 22', TO_DATE('2023-01-22','YYYY-MM-DD'), 'ALBUM_22_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 23', TO_DATE('2023-01-23','YYYY-MM-DD'), 'ALBUM_23_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 24', TO_DATE('2023-01-24','YYYY-MM-DD'), 'ALBUM_24_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 25', TO_DATE('2023-01-25','YYYY-MM-DD'), 'ALBUM_25_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 26', TO_DATE('2023-01-26','YYYY-MM-DD'), 'ALBUM_26_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 27', TO_DATE('2023-01-27','YYYY-MM-DD'), 'ALBUM_27_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 28', TO_DATE('2023-01-28','YYYY-MM-DD'), 'ALBUM_28_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 29', TO_DATE('2023-01-29','YYYY-MM-DD'), 'ALBUM_29_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 30', TO_DATE('2023-01-30','YYYY-MM-DD'), 'ALBUM_30_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 31', TO_DATE('2023-01-31','YYYY-MM-DD'), 'ALBUM_31_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 32', TO_DATE('2023-02-01','YYYY-MM-DD'), 'ALBUM_32_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 33', TO_DATE('2023-02-02','YYYY-MM-DD'), 'ALBUM_33_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 34', TO_DATE('2023-02-03','YYYY-MM-DD'), 'ALBUM_34_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 35', TO_DATE('2023-02-04','YYYY-MM-DD'), 'ALBUM_35_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 36', TO_DATE('2023-02-05','YYYY-MM-DD'), 'ALBUM_36_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 37', TO_DATE('2023-02-06','YYYY-MM-DD'), 'ALBUM_37_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 38', TO_DATE('2023-02-07','YYYY-MM-DD'), 'ALBUM_38_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 39', TO_DATE('2023-02-08','YYYY-MM-DD'), 'ALBUM_39_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 40', TO_DATE('2023-02-09','YYYY-MM-DD'), 'ALBUM_40_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (1, 'Album 41', TO_DATE('2023-02-10','YYYY-MM-DD'), 'ALBUM_41_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (2, 'Album 42', TO_DATE('2023-02-11','YYYY-MM-DD'), 'ALBUM_42_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (3, 'Album 43', TO_DATE('2023-02-12','YYYY-MM-DD'), 'ALBUM_43_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (4, 'Album 44', TO_DATE('2023-02-13','YYYY-MM-DD'), 'ALBUM_44_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (5, 'Album 45', TO_DATE('2023-02-14','YYYY-MM-DD'), 'ALBUM_45_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (6, 'Album 46', TO_DATE('2023-02-15','YYYY-MM-DD'), 'ALBUM_46_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (7, 'Album 47', TO_DATE('2023-02-16','YYYY-MM-DD'), 'ALBUM_47_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (8, 'Album 48', TO_DATE('2023-02-17','YYYY-MM-DD'), 'ALBUM_48_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (9, 'Album 49', TO_DATE('2023-02-18','YYYY-MM-DD'), 'ALBUM_49_COVER')
  INTO albums (user_id, title, release_date, cover_art_url)
    VALUES (10, 'Album 50', TO_DATE('2023-02-19','YYYY-MM-DD'), 'ALBUM_50_COVER')
SELECT 1 FROM dual;



------------------------------------------------------------
-- TRACKS (50 rows)
-- Tracks 1-50 (by identity) will:
--   user_id  = artist ids cycling 1..10
--   album_id = same number as track (1..50)
--   genre_id = cycles 1..7
------------------------------------------------------------
INSERT ALL
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 1, 1, 'Track 1', 181, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 2, 2, 'Track 2', 182, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 3, 3, 'Track 3', 183, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 4, 4, 'Track 4', 184, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 5, 5, 'Track 5', 185, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 6, 6, 'Track 6', 186, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 7, 7, 'Track 7', 187, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 8, 1, 'Track 8', 188, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 9, 2, 'Track 9', 189, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 10, 3, 'Track 10', 190, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 11, 4, 'Track 11', 191, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 12, 5, 'Track 12', 192, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 13, 6, 'Track 13', 193, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 14, 7, 'Track 14', 194, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 15, 1, 'Track 15', 195, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 16, 2, 'Track 16', 196, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 17, 3, 'Track 17', 197, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 18, 4, 'Track 18', 198, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 19, 5, 'Track 19', 199, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 20, 6, 'Track 20', 200, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 21, 7, 'Track 21', 201, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 22, 1, 'Track 22', 202, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 23, 2, 'Track 23', 203, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 24, 3, 'Track 24', 204, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 25, 4, 'Track 25', 205, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 26, 5, 'Track 26', 206, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 27, 6, 'Track 27', 207, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 28, 7, 'Track 28', 208, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 29, 1, 'Track 29', 209, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 30, 2, 'Track 30', 210, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 31, 3, 'Track 31', 211, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 32, 4, 'Track 32', 212, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 33, 5, 'Track 33', 213, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 34, 6, 'Track 34', 214, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 35, 7, 'Track 35', 215, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 36, 1, 'Track 36', 216, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 37, 2, 'Track 37', 217, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 38, 3, 'Track 38', 218, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 39, 4, 'Track 39', 219, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 40, 5, 'Track 40', 220, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (1, 41, 6, 'Track 41', 221, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (2, 42, 7, 'Track 42', 222, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (3, 43, 1, 'Track 43', 223, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (4, 44, 2, 'Track 44', 224, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (5, 45, 3, 'Track 45', 225, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (6, 46, 4, 'Track 46', 226, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (7, 47, 5, 'Track 47', 227, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (8, 48, 6, 'Track 48', 228, 1)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (9, 49, 7, 'Track 49', 229, 0)
  INTO tracks (user_id, album_id, genre_id, title, duration_seconds, explicit_flag)
    VALUES (10, 50, 1, 'Track 50', 230, 0)
SELECT 1 FROM dual;
INSERT ALL
  INTO playlists (user_id, name, is_private)
    VALUES (11, 'Playlist 1', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (12, 'Playlist 2', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (13, 'Playlist 3', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (14, 'Playlist 4', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (15, 'Playlist 5', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (16, 'Playlist 6', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (17, 'Playlist 7', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (18, 'Playlist 8', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (19, 'Playlist 9', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (20, 'Playlist 10', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (21, 'Playlist 11', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (22, 'Playlist 12', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (23, 'Playlist 13', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (24, 'Playlist 14', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (25, 'Playlist 15', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (26, 'Playlist 16', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (27, 'Playlist 17', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (28, 'Playlist 18', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (29, 'Playlist 19', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (30, 'Playlist 20', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (31, 'Playlist 21', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (32, 'Playlist 22', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (33, 'Playlist 23', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (34, 'Playlist 24', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (35, 'Playlist 25', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (36, 'Playlist 26', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (37, 'Playlist 27', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (38, 'Playlist 28', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (39, 'Playlist 29', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (40, 'Playlist 30', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (41, 'Playlist 31', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (42, 'Playlist 32', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (43, 'Playlist 33', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (44, 'Playlist 34', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (45, 'Playlist 35', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (46, 'Playlist 36', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (47, 'Playlist 37', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (48, 'Playlist 38', 1)
  INTO playlists (user_id, name, is_private)
    VALUES (49, 'Playlist 39', 0)
  INTO playlists (user_id, name, is_private)
    VALUES (50, 'Playlist 40', 1)
SELECT 1 FROM dual;
INSERT ALL
  -- Playlists 1–30, 4 tracks each
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (1, 1, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (1, 2, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (1, 3, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (1, 4, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (2, 5, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (2, 6, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (2, 7, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (2, 8, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (3, 9, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (3, 10, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (3, 11, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (3, 12, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (4, 13, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (4, 14, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (4, 15, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (4, 16, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (5, 17, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (5, 18, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (5, 19, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (5, 20, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (6, 21, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (6, 22, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (6, 23, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (6, 24, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (7, 25, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (7, 26, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (7, 27, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (7, 28, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (8, 29, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (8, 30, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (8, 31, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (8, 32, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (9, 33, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (9, 34, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (9, 35, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (9, 36, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (10, 37, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (10, 38, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (10, 39, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (10, 40, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (11, 41, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (11, 42, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (11, 43, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (11, 44, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (12, 45, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (12, 46, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (12, 47, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (12, 48, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (13, 49, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (13, 50, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (13, 1, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (13, 2, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (14, 3, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (14, 4, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (14, 5, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (14, 6, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (15, 7, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (15, 8, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (15, 9, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (15, 10, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (16, 11, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (16, 12, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (16, 13, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (16, 14, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (17, 15, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (17, 16, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (17, 17, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (17, 18, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (18, 19, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (18, 20, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (18, 21, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (18, 22, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (19, 23, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (19, 24, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (19, 25, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (19, 26, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (20, 27, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (20, 28, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (20, 29, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (20, 30, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (21, 31, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (21, 32, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (21, 33, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (21, 34, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (22, 35, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (22, 36, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (22, 37, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (22, 38, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (23, 39, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (23, 40, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (23, 41, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (23, 42, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (24, 43, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (24, 44, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (24, 45, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (24, 46, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (25, 47, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (25, 48, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (25, 49, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (25, 50, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (26, 1, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (26, 2, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (26, 3, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (26, 4, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (27, 5, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (27, 6, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (27, 7, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (27, 8, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (28, 9, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (28, 10, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (28, 11, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (28, 12, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (29, 13, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (29, 14, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (29, 15, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (29, 16, 4)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (30, 17, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (30, 18, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (30, 19, 3)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (30, 20, 4)

  -- Playlists 31–40, 3 tracks each
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (31, 21, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (31, 22, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (31, 23, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (32, 24, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (32, 25, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (32, 26, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (33, 27, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (33, 28, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (33, 29, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (34, 30, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (34, 31, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (34, 32, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (35, 33, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (35, 34, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (35, 35, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (36, 36, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (36, 37, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (36, 38, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (37, 39, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (37, 40, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (37, 41, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (38, 42, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (38, 43, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (38, 44, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (39, 45, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (39, 46, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (39, 47, 3)

  INTO playlist_tracks (playlist_id, track_id, position) VALUES (40, 48, 1)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (40, 49, 2)
  INTO playlist_tracks (playlist_id, track_id, position) VALUES (40, 50, 3)
SELECT 1 FROM dual;

------------------------------------------------------------
-- PLAY_EVENTS (100 rows)
--   user_id  - listeners 11..50
--   track_id - tracks 1..50
--   played_at spread over 2024-11-20
------------------------------------------------------------
INSERT ALL
  INTO play_events (user_id, track_id, played_at)
    VALUES (11, 1, TO_TIMESTAMP('2024-11-20 09:01:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (12, 2, TO_TIMESTAMP('2024-11-20 09:02:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (13, 3, TO_TIMESTAMP('2024-11-20 09:03:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (14, 4, TO_TIMESTAMP('2024-11-20 09:04:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (15, 5, TO_TIMESTAMP('2024-11-20 09:05:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (16, 6, TO_TIMESTAMP('2024-11-20 09:06:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (17, 7, TO_TIMESTAMP('2024-11-20 09:07:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (18, 8, TO_TIMESTAMP('2024-11-20 09:08:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (19, 9, TO_TIMESTAMP('2024-11-20 09:09:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (20, 10, TO_TIMESTAMP('2024-11-20 09:10:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (21, 11, TO_TIMESTAMP('2024-11-20 09:11:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (22, 12, TO_TIMESTAMP('2024-11-20 09:12:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (23, 13, TO_TIMESTAMP('2024-11-20 09:13:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (24, 14, TO_TIMESTAMP('2024-11-20 09:14:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (25, 15, TO_TIMESTAMP('2024-11-20 09:15:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (26, 16, TO_TIMESTAMP('2024-11-20 09:16:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (27, 17, TO_TIMESTAMP('2024-11-20 09:17:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (28, 18, TO_TIMESTAMP('2024-11-20 09:18:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (29, 19, TO_TIMESTAMP('2024-11-20 09:19:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (30, 20, TO_TIMESTAMP('2024-11-20 09:20:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (31, 21, TO_TIMESTAMP('2024-11-20 09:21:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (32, 22, TO_TIMESTAMP('2024-11-20 09:22:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (33, 23, TO_TIMESTAMP('2024-11-20 09:23:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (34, 24, TO_TIMESTAMP('2024-11-20 09:24:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (35, 25, TO_TIMESTAMP('2024-11-20 09:25:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (36, 26, TO_TIMESTAMP('2024-11-20 09:26:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (37, 27, TO_TIMESTAMP('2024-11-20 09:27:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (38, 28, TO_TIMESTAMP('2024-11-20 09:28:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (39, 29, TO_TIMESTAMP('2024-11-20 09:29:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (40, 30, TO_TIMESTAMP('2024-11-20 09:30:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (41, 31, TO_TIMESTAMP('2024-11-20 09:31:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (42, 32, TO_TIMESTAMP('2024-11-20 09:32:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (43, 33, TO_TIMESTAMP('2024-11-20 09:33:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (44, 34, TO_TIMESTAMP('2024-11-20 09:34:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (45, 35, TO_TIMESTAMP('2024-11-20 09:35:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (46, 36, TO_TIMESTAMP('2024-11-20 09:36:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (47, 37, TO_TIMESTAMP('2024-11-20 09:37:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (48, 38, TO_TIMESTAMP('2024-11-20 09:38:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (49, 39, TO_TIMESTAMP('2024-11-20 09:39:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (50, 40, TO_TIMESTAMP('2024-11-20 09:40:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (11, 41, TO_TIMESTAMP('2024-11-20 09:41:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (12, 42, TO_TIMESTAMP('2024-11-20 09:42:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (13, 43, TO_TIMESTAMP('2024-11-20 09:43:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (14, 44, TO_TIMESTAMP('2024-11-20 09:44:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (15, 45, TO_TIMESTAMP('2024-11-20 09:45:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (16, 46, TO_TIMESTAMP('2024-11-20 09:46:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (17, 47, TO_TIMESTAMP('2024-11-20 09:47:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (18, 48, TO_TIMESTAMP('2024-11-20 09:48:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (19, 49, TO_TIMESTAMP('2024-11-20 09:49:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (20, 50, TO_TIMESTAMP('2024-11-20 09:50:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (21, 1, TO_TIMESTAMP('2024-11-20 09:51:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (22, 2, TO_TIMESTAMP('2024-11-20 09:52:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (23, 3, TO_TIMESTAMP('2024-11-20 09:53:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (24, 4, TO_TIMESTAMP('2024-11-20 09:54:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (25, 5, TO_TIMESTAMP('2024-11-20 09:55:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (26, 6, TO_TIMESTAMP('2024-11-20 09:56:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (27, 7, TO_TIMESTAMP('2024-11-20 09:57:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (28, 8, TO_TIMESTAMP('2024-11-20 09:58:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (29, 9, TO_TIMESTAMP('2024-11-20 09:59:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (30, 10, TO_TIMESTAMP('2024-11-20 10:00:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (31, 11, TO_TIMESTAMP('2024-11-20 10:01:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (32, 12, TO_TIMESTAMP('2024-11-20 10:02:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (33, 13, TO_TIMESTAMP('2024-11-20 10:03:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (34, 14, TO_TIMESTAMP('2024-11-20 10:04:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (35, 15, TO_TIMESTAMP('2024-11-20 10:05:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (36, 16, TO_TIMESTAMP('2024-11-20 10:06:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (37, 17, TO_TIMESTAMP('2024-11-20 10:07:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (38, 18, TO_TIMESTAMP('2024-11-20 10:08:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (39, 19, TO_TIMESTAMP('2024-11-20 10:09:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (40, 20, TO_TIMESTAMP('2024-11-20 10:10:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (41, 21, TO_TIMESTAMP('2024-11-20 10:11:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (42, 22, TO_TIMESTAMP('2024-11-20 10:12:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (43, 23, TO_TIMESTAMP('2024-11-20 10:13:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (44, 24, TO_TIMESTAMP('2024-11-20 10:14:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (45, 25, TO_TIMESTAMP('2024-11-20 10:15:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (46, 26, TO_TIMESTAMP('2024-11-20 10:16:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (47, 27, TO_TIMESTAMP('2024-11-20 10:17:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (48, 28, TO_TIMESTAMP('2024-11-20 10:18:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (49, 29, TO_TIMESTAMP('2024-11-20 10:19:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (50, 30, TO_TIMESTAMP('2024-11-20 10:20:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (11, 31, TO_TIMESTAMP('2024-11-20 10:21:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (12, 32, TO_TIMESTAMP('2024-11-20 10:22:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (13, 33, TO_TIMESTAMP('2024-11-20 10:23:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (14, 34, TO_TIMESTAMP('2024-11-20 10:24:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (15, 35, TO_TIMESTAMP('2024-11-20 10:25:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (16, 36, TO_TIMESTAMP('2024-11-20 10:26:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (17, 37, TO_TIMESTAMP('2024-11-20 10:27:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (18, 38, TO_TIMESTAMP('2024-11-20 10:28:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (19, 39, TO_TIMESTAMP('2024-11-20 10:29:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (20, 40, TO_TIMESTAMP('2024-11-20 10:30:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (21, 41, TO_TIMESTAMP('2024-11-20 10:31:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (22, 42, TO_TIMESTAMP('2024-11-20 10:32:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (23, 43, TO_TIMESTAMP('2024-11-20 10:33:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (24, 44, TO_TIMESTAMP('2024-11-20 10:34:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (25, 45, TO_TIMESTAMP('2024-11-20 10:35:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (26, 46, TO_TIMESTAMP('2024-11-20 10:36:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (27, 47, TO_TIMESTAMP('2024-11-20 10:37:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (28, 48, TO_TIMESTAMP('2024-11-20 10:38:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (29, 49, TO_TIMESTAMP('2024-11-20 10:39:00','YYYY-MM-DD HH24:MI:SS'))
  INTO play_events (user_id, track_id, played_at)
    VALUES (30, 50, TO_TIMESTAMP('2024-11-20 10:40:00','YYYY-MM-DD HH24:MI:SS'))
SELECT 1 FROM dual;

------------------------------------------------------------
-- STORED LOGIC: TIMESTAMP TRIGGERS FOR ALL TABLES
------------------------------------------------------------

-- Trigger for ROLES
CREATE OR REPLACE TRIGGER trg_roles_timestamps
BEFORE INSERT OR UPDATE ON roles
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.id IS NULL THEN
            :NEW.id := roles_seq.NEXTVAL;
        END IF;
        :NEW.created_at := SYSDATE;
        :NEW.updated_at := SYSDATE;

    ELSIF UPDATING THEN
        :NEW.created_at := :OLD.created_at;
        :NEW.updated_at := SYSDATE;
    END IF;
END;
/

------------------------------------------------------------

-- Trigger for GENRES
CREATE OR REPLACE TRIGGER trg_genres_timestamps
BEFORE INSERT OR UPDATE ON genres
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.id IS NULL THEN
            :NEW.id := genres_seq.NEXTVAL;
        END IF;
        :NEW.created_at := SYSDATE;
        :NEW.updated_at := SYSDATE;

    ELSIF UPDATING THEN
        :NEW.created_at := :OLD.created_at;
        :NEW.updated_at := SYSDATE;
    END IF;
END;
/

------------------------------------------------------------

-- Trigger for USERS
CREATE OR REPLACE TRIGGER trg_users_timestamps
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.id IS NULL THEN
            :NEW.id := users_seq.NEXTVAL;
        END IF;
        :NEW.created_at := SYSDATE;
        :NEW.updated_at := SYSDATE;

    ELSIF UPDATING THEN
        :NEW.created_at := :OLD.created_at;
        :NEW.updated_at := SYSDATE;
    END IF;
END;
/

------------------------------------------------------------

-- Trigger for ALBUMS
CREATE OR REPLACE TRIGGER trg_albums_timestamps
BEFORE INSERT OR UPDATE ON albums
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.id IS NULL THEN
            :NEW.id := albums_seq.NEXTVAL;
        END IF;
        :NEW.created_at := SYSDATE;
        :NEW.updated_at := SYSDATE;

    ELSIF UPDATING THEN
        :NEW.created_at := :OLD.created_at;
        :NEW.updated_at := SYSDATE;
    END IF;
END;
/

------------------------------------------------------------

-- Trigger for TRACKS
CREATE OR REPLACE TRIGGER trg_tracks_timestamps
BEFORE INSERT OR UPDATE ON tracks
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.id IS NULL THEN
            :NEW.id := tracks_seq.NEXTVAL;
        END IF;
        :NEW.created_at := SYSDATE;
        :NEW.updated_at := SYSDATE;

    ELSIF UPDATING THEN
        :NEW.created_at := :OLD.created_at;
        :NEW.updated_at := SYSDATE;
    END IF;
END;
/

------------------------------------------------------------

-- Trigger for PLAYLISTS
CREATE OR REPLACE TRIGGER trg_playlists_timestamps
BEFORE INSERT OR UPDATE ON playlists
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.id IS NULL THEN
            :NEW.id := playlists_seq.NEXTVAL;
        END IF;
        :NEW.created_at := SYSDATE;
        :NEW.updated_at := SYSDATE;

    ELSIF UPDATING THEN
        :NEW.created_at := :OLD.created_at;
        :NEW.updated_at := SYSDATE;
    END IF;
END;
/

------------------------------------------------------------

-- Trigger for PLAYLIST_TRACKS
CREATE OR REPLACE TRIGGER trg_playlist_tracks_timestamps
BEFORE INSERT OR UPDATE ON playlist_tracks
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := SYSDATE;
        :NEW.updated_at := SYSDATE;

    ELSIF UPDATING THEN
        :NEW.created_at := :OLD.created_at;
        :NEW.updated_at := SYSDATE;
    END IF;
END;
/

------------------------------------------------------------

-- Trigger for PLAY_EVENTS
CREATE OR REPLACE TRIGGER trg_play_events_business_rules
BEFORE INSERT OR UPDATE ON play_events
FOR EACH ROW
BEGIN
    -- 1) played_at future mein nahi hona chahiye
    IF :NEW.played_at > SYSTIMESTAMP THEN
        RAISE_APPLICATION_ERROR(
            -20010,
            'PLAY_EVENTS: played_at cannot be in the future.'
        );
    END IF;

    -- 2) System-owned timestamps
    IF INSERTING THEN
        IF :NEW.id IS NULL THEN
            :NEW.id := play_events_seq.NEXTVAL;
        END IF;
        :NEW.created_at := SYSDATE;   -- insert time
        :NEW.updated_at := SYSDATE;   -- same as insert time
    ELSIF UPDATING THEN
        :NEW.created_at := :OLD.created_at; -- freeze created_at
        :NEW.updated_at := SYSDATE;         -- update time
    END IF;
END;
/
------------------------------------------------------------

------------------------------------------------------------
-- STORED PROCEDURE: get_user_listening_stats
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE get_user_listening_stats(
    p_user_id    IN users.id%TYPE,
    p_start_date IN DATE,
    p_end_date   IN DATE
) AS
    v_total_plays      NUMBER;
    v_unique_tracks    NUMBER;
    v_total_seconds    NUMBER;
    v_user_count       NUMBER;
    v_role_name        roles.name%TYPE;   -- NEW: to store the user's role
BEGIN
    -- 0) Basic null checks for dates (optional but safe)
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20009,
            'Start date and end date must not be NULL.'
        );
    END IF;

    -- 1) Validate user id: must be positive, non-zero
    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'User id must be a positive, non-zero number.'
        );
    END IF;

    -- 2) Check that user id does not exceed total users
    SELECT COUNT(*)
    INTO   v_user_count
    FROM   users;

    IF p_user_id > v_user_count THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'User id cannot be greater than total users (current count = '
            || v_user_count || ').'
        );
    END IF;

    -- 2b) ROLE-BASED CHECK: only Listener or Artist allowed
    SELECT r.name
    INTO   v_role_name
    FROM   users u
    JOIN   roles r ON r.id = u.role_id
    WHERE  u.id = p_user_id;

    IF v_role_name NOT IN ('Listener', 'Artist') THEN
        RAISE_APPLICATION_ERROR(
            -20013,
            'Listening stats are only allowed for Listener or Artist roles. '
            || 'Current role = ' || v_role_name || '.'
        );
    END IF;

    -- 3) Date validations

    -- 3a) Start date cannot be in the future (REQUIRMENT REMOVED)
    /*
    IF p_start_date > SYSDATE THEN
        RAISE_APPLICATION_ERROR(
            -20010,
            'Start date cannot be in the future.'
        );
    END IF;
    */

    -- 3b) End date cannot be in the future (REQUIRMENT REMOVED)
    /*
    IF p_end_date > SYSDATE THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            'End date cannot be in the future.'
        );
    END IF;
    */

    -- 3c) Start date must be less than or equal to end date
    IF p_start_date > p_end_date THEN
        RAISE_APPLICATION_ERROR(
            -20012,
            'Start date cannot be greater than end date.'
        );
    END IF;

    -- 4) Aggregate listening data
    SELECT COUNT(*),                           -- total play events
           COUNT(DISTINCT pe.track_id),        -- unique tracks
           NVL(SUM(t.duration_seconds), 0)     -- total listening seconds
    INTO   v_total_plays,
           v_unique_tracks,
           v_total_seconds
    FROM   play_events pe
           JOIN tracks t ON t.id = pe.track_id
    WHERE  pe.user_id = p_user_id
    AND    pe.played_at BETWEEN p_start_date AND p_end_date;

    -- 5) Output a small report
    DBMS_OUTPUT.PUT_LINE('===== Listening stats =====');
    DBMS_OUTPUT.PUT_LINE('User ID        : ' || p_user_id);
    DBMS_OUTPUT.PUT_LINE('From           : ' ||
                         TO_CHAR(p_start_date, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('To             : ' ||
                         TO_CHAR(p_end_date,   'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('Total plays    : ' || v_total_plays);
    DBMS_OUTPUT.PUT_LINE('Unique tracks  : ' || v_unique_tracks);
    DBMS_OUTPUT.PUT_LINE('Total seconds  : ' || v_total_seconds);
    DBMS_OUTPUT.PUT_LINE('Total minutes  : ' ||
                         ROUND(v_total_seconds / 60, 2));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(
            'No listening data found for user ' || p_user_id ||
            ' in this period.'
        );
END;
/


/* =========================================================
 MUSIC STREAMING PROJECT - INDEXES AND VIEWS ONLY
 Run this AFTER your main schema (tables, data, procedures, triggers)
 ========================================================= */

-- =========================================================
-- SECTION 1: NON-KEY INDEXES (JUSTIFIED)
-- =========================================================

-- Index 1: Speed up user listening history by user + time.
-- Non-key because PK of PLAY_EVENTS is ID, not (USER_ID, PLAYED_AT).
-- Used by queries/procedures that filter by:
-- WHERE user_id = ? AND played_at BETWEEN ? AND ?
CREATE INDEX idx_play_events_user_played_at
 ON play_events (user_id, played_at);

-- Index 2: Speed up filters on genre + explicit_flag.
-- Non-key because PK of TRACKS is ID, not (GENRE_ID, EXPLICIT_FLAG).
-- Supports queries like:
-- WHERE genre_id = ? AND explicit_flag = 0/1
CREATE INDEX idx_tracks_genre_explicit
 ON tracks (genre_id, explicit_flag);

-- =========================================================
-- SECTION 2: INFORMATIVE / ANALYTICAL VIEWS
-- =========================================================

-- ---------------------------------------------------------
-- View 1: Track-level play statistics
-- ---------------------------------------------------------
-- For each track, shows:
-- - track title
-- - artist name
-- - genre name
-- - total plays
-- - first and last time it was played
CREATE OR REPLACE VIEW v_track_play_stats AS
SELECT
 t.id AS track_id,
 t.title AS track_title,
 u.display_name AS artist_name,
 g.name AS genre_name,
 COUNT(pe.id) AS total_plays,
 MIN(pe.played_at) AS first_played_at,
 MAX(pe.played_at) AS last_played_at
FROM tracks t
JOIN users u ON u.id = t.user_id
JOIN genres g ON g.id = t.genre_id
LEFT JOIN play_events pe ON pe.track_id = t.id
GROUP BY
 t.id,
 t.title,
 u.display_name,
 g.name;

-- MATERIALIZED VIEW 3

CREATE MATERIALIZED VIEW v_listener_summary
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    u.id           AS listener_id,
    u.display_name AS listener_name,

    -- total different artists the listener has listened to
    COUNT(DISTINCT t.user_id)      AS artists_played,

    -- total seconds listened
    SUM(t.duration_seconds)        AS total_seconds,

    -- favourite artist (most played)
    fav.fav_artist

FROM users u
JOIN roles r
      ON r.id = u.role_id
     AND r.name = 'Listener'          -- sirf listeners

LEFT JOIN play_events pe
       ON pe.user_id = u.id

LEFT JOIN tracks t
       ON t.id = pe.track_id

-- yeh subquery har listener_id ka favourite artist nikaal rahi hai
LEFT JOIN (
    SELECT
        fa.listener_id,
        MAX(fa.artist_name) KEEP (DENSE_RANK LAST ORDER BY fa.play_count)
            AS fav_artist
    FROM (
        SELECT
            pe.user_id        AS listener_id,
            ua.display_name   AS artist_name,
            COUNT(*)          AS play_count
        FROM play_events pe
        JOIN tracks t
              ON t.id = pe.track_id
        JOIN users ua
              ON ua.id = t.user_id   -- artist user
        GROUP BY
            pe.user_id,
            ua.display_name
    ) fa
    GROUP BY
        fa.listener_id
) fav
   ON fav.listener_id = u.id

GROUP BY
    u.id,
    u.display_name,
    fav.fav_artist;
-- ---------------------------------------------------------
-- Materialized View 2: Artist performance overview
-- ---------------------------------------------------------
-- For each ARTIST user, shows:
-- - total tracks they created
-- - total albums they own
-- - total plays of their tracks
-- - how many distinct listeners played their tracks
-- - last time any of their tracks was played
CREATE MATERIALIZED VIEW v_artist_performance_overview
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
 a.id AS artist_id,
 a.display_name AS artist_name,
 COUNT(DISTINCT tr.id) AS total_tracks,
 COUNT(DISTINCT al.id) AS total_albums,
 COUNT(DISTINCT pe.id) AS total_plays,
 COUNT(DISTINCT pe.user_id) AS distinct_listeners,
 MAX(pe.played_at) AS last_played_at
FROM users a
JOIN roles r ON r.id = a.role_id
 AND r.name = 'Artist' -- only artist users
LEFT JOIN tracks tr ON tr.user_id = a.id -- their tracks
LEFT JOIN albums al ON al.user_id = a.id -- their albums
LEFT JOIN play_events pe
 ON pe.track_id = tr.id -- plays of their tracks
GROUP BY
 a.id, a.display_name;

