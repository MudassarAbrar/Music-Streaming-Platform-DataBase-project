# End-to-End Project Walkthrough

This guide covers how to set up the database, verified that it works, and testing the complex features.

## 1. Installation / Setup

1.  **Open Oracle SQL Developer** (or your preferred client).
2.  **Connect** to your database instance.
3.  **Open the Script**: Load [music_schema_with_triggers_proc_indexes_views.sql](file:///f:/University/DATABASE/database%20project/music_schema_with_triggers_proc_indexes_views.sql).
4.  **Run as Script**: Execute the entire file (usually F5).
    *   *Note: You may see "Table does not exist" errors at the very top (DROP statements). This is normal for the first run.*

**Success Indicator**: The script ends with "Commit complete" and you can see tables like `USERS`, `ALBUMS`, `TRACKS` in the sidebar.

---

## 2. Feature Verification

Run these SQL blocks one by one to verify the "Special Features" we built.

### Feature A: Role-Based Access Control (RBAC)
*Goal: Prove that Listeners cannot hack the system.*

**Test 1: Admin Power (Should Succeed)**
```sql
-- Simulate Admin Login (ID 3)
BEGIN DBMS_SESSION.SET_CONTEXT('MYAPP', 'CURRENT_USER_ID', '3'); END;
/
-- Admin deletes a genre
DELETE FROM genres WHERE name = 'Indie'; 
-- 1 row deleted.
ROLLBACK; -- Undo it to keep data safe
```

**Test 2: Listener Restriction (Should Fail)**
```sql
-- Simulate Listener Login (ID 11)
BEGIN DBMS_SESSION.SET_CONTEXT('MYAPP', 'CURRENT_USER_ID', '11'); END;
/
-- Listener tries to delete an album
DELETE FROM albums WHERE id = 1;
-- ERROR: ORA-20020: Listeners are not allowed to add or modify albums.
```

---

### Feature B: Automated Playlist Positioning
*Goal: Prove the trigger automatically numbers new songs.*

**Test:**
```sql
-- 1. Create a new empty playlist for User 11
INSERT INTO playlists (id, user_id, name) VALUES (999, 11, 'My Test Playlist');

-- 2. Add two tracks (Notice we DO NOT specify 'position')
INSERT INTO playlist_tracks (playlist_id, track_id) VALUES (999, 1);
INSERT INTO playlist_tracks (playlist_id, track_id) VALUES (999, 2);

-- 3. Verify the positions were auto-generated
SELECT track_id, position FROM playlist_tracks WHERE playlist_id = 999 ORDER BY position;
```
**Expected Output:**
| TRACK_ID | POSITION |
| :--- | :--- |
| 1 | 1 |
| 2 | 2 |

---

### Feature C: Stored Procedure (Reporting)
*Goal: Get listening stats for a user.*

**Test:**
```sql
SET SERVEROUTPUT ON;
BEGIN
    -- Get stats for User 11 (Listener) from last year to today
    get_user_listening_stats(11, SYSDATE - 365, SYSDATE);
END;
/
```
**Expected Output:**
> ===== Listening stats =====
> Total plays: [Number]
> Total minutes: [Number]

---

### Feature D: Analytical Views
*Goal: View complex data without writing joins.*

**Test:**
```sql
SELECT * FROM v_artist_performance_overview WHERE ROWNUM <= 5;
```
**Expected Output:**
A neat table showing Artist Name, Total Tracks, Total Plays, etc.

---

## 3. Troubleshooting
*   **"ORA-200xx Error"**: This means the **Security Triggers** are working! You are likely logged in as a Listener or Artist trying to do something forbidden.
    *   *Fix*: Run `BEGIN DBMS_SESSION.SET_CONTEXT('MYAPP', 'CURRENT_USER_ID', '3'); END;` to switch back to Admin.
