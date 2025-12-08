# Database Project: Music Streaming System (Viva/Presentation Guide)

## 1. Project Overview (The "Elevator Pitch")
"We built a robust backend for a music streaming service similar to Spotify. The system manages **Users** (Listeners, Artists, Admins), **Music Content** (Albums, Tracks, Genres), and **Interaction Data** (Playlists, Likes, Play History).

**Key Technical Highlight:** 
We went beyond simple table storage by implementing **Automation** and **Security** directly inside the database using **Triggers** and **Stored Procedures**. The database protects itself, rather than relying entirely on the frontend."

---

## 2. Key Features (The "Wow" Factors)

### A. Role-Based Security (The "Bouncer")
*   **The Problem:** Normal databases let anyone with a connection delete anything.
*   **Our Solution:** We built a custom security layer.
    *   **Listeners** can make playlists but cannot delete albums.
    *   **Artists** can manage *their own* music but cannot touch other artists' work.
    *   **Admins** have full control.
*   **How it works:** A function `get_current_role` checks who is logged in. Before any `INSERT` or `UPDATE`, a **Trigger** runs this check and blocks unauthorized actions (throws an error).

### B. Automated Playlist Positioning (The "Smart Counter")
*   **The Problem:** When you add a song to a playlist, you shouldn't have to manually type "This is song #15."
*   **Our Solution:** We created a **Trigger** (`trg_playlist_tracks_position`) that automatically finds the last position number in a playlist and assigns the next number (e.g., 16) to the new song.

### C. Data Integrity (The "Guardrails")
*   **Cascading Deletes:** If an Artist deletes an Album, all its Tracks are automatically removed to prevent "orphan" data.
*   **Constraints:**
    *   `chk_tracks_duration`: A song cannot be 0 seconds long.
    *   `chk_playlists_is_private`: Flags must be 0 or 1.
    *   `uq_users_email`: No two users can have the same email.

---

## 3. Technical Walkthrough (For the Examiner)

**"If asked to explain your code, point to these 3 areas:"**

1.  **The Schema (Tables):**
    *   Show the **Relationships**: `Playlist_Tracks` is a "Junction Table" connecting `Playlists` and `Tracks`.
    *   Show `Users` table linking to `Roles`.

2.  **The Logic (Triggers):**
    *   Show `trg_protect_albums`. Explain: "This block of code runs *before* any change. It asks 'Is this user an Admin?' If not, it stops the transaction."

3.  **The Analytics (Views & Materialized Views):**
    *   We created **Views** to simplify complex reporting.
    *   `v_listener_summary`: Instead of writing a complex 5-table join every time we want to see user stats, we just `SELECT * FROM v_listener_summary`. It pre-calculates total seconds listened and favorite artists.

---

## 4. Why Oracle 11g?
*   We used standard SQL features compatible with Oracle 11g (Sequences, Triggers, PL/SQL).
*   We avoided modern shortcuts (like `IDENTITY` columns) to ensure this runs on older, robust banking-grade database systems often found in enterprise environments.

## 5. Potential Viva Questions & Answers

**Q: Why use Triggers instead of checking permissions in Python/Java?**
**A:** "Security in Depth. If the application code has a bug or if someone connects directly to the database (like a DBA), the data remains protected. The database is the final line of defense."

**Q: What is the difference between a View and a Materialized View?**
**A:** "A **View** is just a saved query; it runs every time you look at it (real-time). A **Materialized View** saves the *result* physically (like a cache). We use Materialized Views for heavy reports (like Artist Performance) to improve performance, so we don't recalculate millions of rows every time."

**Q: How do you handle passwords?**
**A:** "We store `password_hash` (a scrambled string), not the plain text password. This is a standard security practice."
