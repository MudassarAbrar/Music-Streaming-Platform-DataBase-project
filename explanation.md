# Comprehensive Database System Documentation

## 1. Introduction
This database is designed for a **Music Streaming Application**. It is not just a storage bin for data; it is an intelligent system that enforces rules, manages permissions, and calculates statistics automatically.

The system uses **Oracle SQL** syntax and features, such as `SEQUENCES` for ID generation, `TRIGGERS` for automation and security, and `PL/SQL` (Procedural Language) for complex logic.

---

## 2. The Core Structure: Tables & Constraints
Tables are where data lives. Each table has "Constraints" which are rules that the data must follow (e.g., "Email cannot be empty").

### 2.1. ROLES Table
*   **Purpose**: Defines the 3 types of users in the system.
*   **Columns**:
    *   `id`: The unique ID (1, 2, 3..).
    *   `name`: The role name ('Listener', 'Artist', 'Admin').
*   **Constraints**:
    *   `NOT NULL UNIQUE`: You cannot have a role without a name, and you cannot have two roles with the same name.
*   **Automation**:
    *   `roles_seq`: A counter that generates the ID.
    *   `trg_roles_timestamps`: Auto-sets `created_at` when a role is made.

### 2.2. GENRES Table
*   **Purpose**: Categories for music (Pop, Rock, etc.).
*   **Constraints**:
    *   `pk_genres`: Primary Key.
    *   `trg_protect_genres`: **Security Rule**. Only Admins can add or change genres. Pass regular users will get an error.

### 2.3. USERS Table
*   **Purpose**: Stores login and profile info for all humans using the app.
*   **Key Columns**:
    *   `role_id`: Links to the `ROLES` table. This determines what they can do.
    *   `email`: Must be unique (`uq_users_email`).
    *   `password_hash`: We store a hash, not the real password, for security.
*   **Relationships**:
    *   `fk_users_role`: A user *must* have a valid role ID.
*   **Security Trigger (`trg_protect_users`)**:
    *   **Logic**: Blocks anyone who is not an Admin from changing this table directly. This prevents hackers or bugs from changing permissions or deleting users easily.

### 2.4. ALBUMS Table
*   **Purpose**: Grouping of tracks.
*   **Relationships**:
    *   `user_id`: The Artist who "owns" the album.
    *   `ON DELETE CASCADE`: If an Artist is deleted, all their albums are deleted automatically.
*   **Security Trigger (`trg_protect_albums`)**:
    *   **RBAC (Role Based Access Control)**:
        *   **Listeners**: Are strictly blocked. They cannot create albums.
        *   **Artists**: Can only create/edit albums where `user_id` matches their own ID. They cannot touch other artists' work.

### 2.5. TRACKS Table
*   **Purpose**: The actual songs.
*   **Columns**:
    *   `duration_seconds`: Length of song.
    *   `explicit_flag`: 0 for Clean, 1 for Explicit.
*   **Relationships**:
    *   `genre_id`: Every track must have a genre.
    *   `album_id`: Can be NULL (for singles that aren't on an album).
*   **Constraints**:
    *   `chk_tracks_duration`: Ensures time is always > 0.
*   **Security Trigger (`trg_protect_tracks`)**:
    *   **Logic**: Identical to Albums. Listeners are blocked. Artists are restricted to their own songs.

---

## 3. Organization & Playback

### 3.1. PLAYLISTS Table
*   **Purpose**: Custom lists created by users.
*   **Columns**:
    *   `is_private`: 1 (True) or 0 (False).
    *   `last_position`: A helper column that remembers the number of tracks, so we know what number to give the next track added.
*   **Security Trigger (`trg_protect_playlists`)**:
    *   **Rule**: In this specific system design, **Artists** are blocked from making playlists. Only **Listeners** and **Admins** can make them.

### 3.2. PLAYLIST_TRACKS Table
*   **Purpose**: A "Junction Table" that links Playlists to Tracks.
*   **Columns**:
    *   `position`: The order (1st song, 2nd song).
*   **Constraints**:
    *   `pk_playlist_tracks`: You cannot add the exact same song to the exact same playlist twice (Composite Primary Key).
*   **Smart Trigger (`trg_playlist_tracks_position`)**:
    *   **Problem**: When you add a song, you might not know it should be song #53.
    *   **Solution**: This trigger activates "BEFORE INSERT". It checks the parent `playlists.last_position`, adds +1 to it, and assigns that number to the new track. It keeps the order perfect without the app needing to calculate it.

### 3.3. PLAY_EVENTS Table
*   **Purpose**: The "History" log.
*   **Columns**:
    *   `played_at`: Exact timestamp of the listen.
*   **Business Rules (`trg_play_events_business_rules`)**:
    *   **Rule 1**: Preventing Time Travel. IF `played_at` is in the future, the database raises an error.
    *   **Rule 2**: Immutable History. If someone tries to UPDATE a play event (change history), the trigger forces `created_at` to remain the same, preserving the original audit trail.

---

## 4. Advanced Logic: Functions & Procedures

These are blocks of code stored inside the database.

### 4.1. FUNCTION `get_current_role`
*   **The Context**: In a real app, the database connection is generic. It doesn't know "User John is logged in".
*   **How it Works**:
    1.  It looks for a session variable `CURRENT_USER_ID`.
    2.  It queries the `USERS` table to find that ID's role (e.g., 'Listener').
    3.  It returns the Role ID (1, 2, or 3).
*   **Why**: All the security triggers (Section 2) call this function first to decide whether to block the action.

### 4.2. PROCEDURE `get_user_listening_stats`
*   **The Context**: We need a report for the "Year Wrapped" or admin dashboard.
*   **How it Works**:
    *   **Inputs**: User ID, Start Date, End Date.
    *   **Logic**:
        1.  Validates inputs (Dates not null? User exists?).
        2.  Enforces Roles (Only specific roles get stats).
        3.  Runs a complex math query (`SUM(duration)`, `COUNT(DISTINCT tracks)`).
        4.  Prints the results to the standard output (`DBMS_OUTPUT`).

---

## 5. Analytics: Views & Materialized Views

We have two ways to look at complex data.

### 5.1. Regular View (`v_track_play_stats`)
*   **What is it**: A saved query. It is not real data, it's a window.
*   **Usage**: When you select from it, it calculates "Total Plays per Track" *right at that moment*.
*   **Good For**: Real-time reference.

### 5.2. Materialized Views (`v_listener_summary`)
*   **What is it**: A snapshot. The database calculates the answer and *saves the result physically* to a table.
*   **Usage**: Contains complex data like "Who is this user's favorite artist?".
*   **Why Materialized?**: Calculating "Favorite Artist" involves sorting thousands of rows. Doing this every time is slow. By "Materializing" it, the data is pre-calculated and instant to read. It only refreshes when we ask it to.

---

## 6. Social Features
*   **LIKES Table**: Links User to Track.
*   **FOLLOWS Table**: Links User to User (Follower -> Followed).
    *   **Constraint**: `chk_no_self_follow` ensures a user cannot follow themselves.

---

## Summary of the "Flow"
1.  **User Action**: A user tries to upload a song on the website.
2.  **Authentication**: The app sets the `CURRENT_USER_ID` in the database.
3.  **Trigger Check**: `trg_protect_tracks` runs. It calls `get_current_role`.
    *   If Role is 'Listener' -> **Access Denied**.
    *   If Role is 'Artist' -> It checks if the `user_id` on the song matches the `CURRENT_USER_ID`.
4.  **Data Entry**: If passed, the data is sent to the `TRACKS` table.
5.  **Timestamping**: `trg_tracks_timestamps` runs and stamps the exact `created_at` time.
6.  **Success**: The song is saved.
