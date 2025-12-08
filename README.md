# Music-Streaming-Platform-DataBase-project
# Music Streaming Database Project

A comprehensive Oracle 11g backend for a music streaming service (like Spotify), featuring advanced database automation, security, and analytics.

## 🚀 Key Features

### 1. Role-Based Access Control (RBAC)
*   **Secure by Design**: Authorization is enforced at the database level using Triggers.
*   **Roles**:
    *   **Listeners**: Can manage playlists but cannot modify albums/tracks.
    *   **Artists**: Can only manage *their own* music content.
    *   **Admins**: Have full system access.
*   **Implementation**: Uses `SYS_CONTEXT` to identify the logged-in user.

### 2. Intelligent Automation
*   **Auto-Ordering**: Tracks added to playlists are automatically assigned the next available position number via triggers.
*   **Cascading Logic**: Deleting a user or album cleanly removes all related data (likes, play history, tracks) to maintain integrity.

### 3. Advanced Analytics
*   **Materialized Views**: Pre-calculated reports for "Artist Performance" and "Listener Summaries" for high-performance querying.
*   **Stored Procedures**: Custom logic to generate detailed listening history reports.

## 🛠️ Technology Stack
*   **Database**: Oracle Database 11g (Compatible with 12c/19c)
*   **Languages**: SQL, PL/SQL (Triggers, Procedures, Functions)

## 📦 Database Objects
*   **Tables**: `USERS`, `ROLES`, `ALBUMS`, `TRACKS`, `PLAYLISTS`, `GENRES`, `PLAY_EVENTS`, etc.
*   **Triggers**: `trg_protect_albums`, `trg_protect_tracks`, `trg_protect_users`, `trg_playlist_tracks_position`.
*   **Functions**: `get_current_role`.
*   **Procedures**: `get_user_listening_stats`.

  
I have implemented comprehensive database triggers to enforce authorization rules for Listeners, Artists, and Admins.

## Protection Summary

| Action | Listener (Role 1) | Artist (Role 2) | Admin (Role 3) |
| :--- | :--- | :--- | :--- |
| **Manage Albums** | ❌ Blocked | ✅ Own Data Only | ✅ Allowed |
| **Manage Tracks** | ❌ Blocked | ✅ Own Data Only | ✅ Allowed |
| **Manage Playlists**| ✅ Allowed | ❌ Blocked | ✅ Allowed |
| **Modify Users** | ❌ Blocked | ❌ Blocked | ✅ Allowed |
| **Manage Genres** | ❌ Blocked | ❌ Blocked | ✅ Allowed |

## Verification Steps

Run the following SQL blocks to test the permissions.

### 1. Set User Context (Mock Login)
Since we are using `SYS_CONTEXT`, you simulate a login by setting the context variable `CURRENT_USER_ID` to the ID of the user you want to test.

```sql
-- Simulate login as LISTENER (User ID 11)
BEGIN
    DBMS_SESSION.SET_CONTEXT('MYAPP', 'CURRENT_USER_ID', '11');
END;
/
```

### 2. Test Restrictions

#### Listener trying to delete an album (Should Fail)
```sql
DELETE FROM albums WHERE id = 1;
-- ORA-20020: Listeners are not allowed to add or modify albums.
```

#### Artist (User ID 1) trying to modify another Artist's album (Should Fail)
```sql
-- Simulate login as Artist 1
BEGIN
    DBMS_SESSION.SET_CONTEXT('MYAPP', 'CURRENT_USER_ID', '1');
END;
/

-- Try to update Artist 2's album
UPDATE albums SET title = 'Hacked' WHERE user_id = 2;
-- ORA-20025: Artists cannot modify albums they do not own.
```

#### Artist trying to create a playlist (Should Fail)
```sql
INSERT INTO playlists (user_id, name) VALUES (1, 'My Banned Playlist');
-- ORA-20027: Artists are not allowed to manage playlists.
```


## ⚡ Quick Start

1.  **Open** your Oracle SQL Client (SQL Developer, SQLPlus, etc.).
2.  **Run** the main script: [music_schema_with_triggers_proc_indexes_views.sql](file:///f:/University/DATABASE/database%20project/music_schema_with_triggers_proc_indexes_views.sql).
    *   *Note: The script handles clean-up (dropping old tables) automatically.*
3.  **Verify** installation by checking the `USERS` table for seed data.

## 🧪 Testing the System

To test the security features, you must simulate a user login:

```sql
-- 1. Simulate an Admin (Everything allowed)
BEGIN DBMS_SESSION.SET_CONTEXT('MYAPP', 'CURRENT_USER_ID', '3'); END;
/

-- 2. Simulate a Listener (Restricted access)
BEGIN DBMS_SESSION.SET_CONTEXT('MYAPP', 'CURRENT_USER_ID', '11'); END;
/
```

See [walkthrough.md](file:///C:/Users/Mudassir/.gemini/antigravity/brain/0f44b9fe-796e-4c20-bbfb-0fc12e6be26a/walkthrough.md) for a complete step-by-step testing guide.
