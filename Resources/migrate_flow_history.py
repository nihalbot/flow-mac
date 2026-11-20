import sqlite3
import json
import uuid
import os
from datetime import datetime, timezone, timedelta

def migrate():
    db_path = os.path.expanduser("~/Library/Application Support/Flow/CoreData.sqlite")
    if not os.path.exists(db_path):
        print(f"Error: Original Flow database not found at {db_path}")
        return False
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 1. Fetch tags
    cursor.execute("SELECT Z_PK, ZTITLE, ZCOLOR FROM ZTAG")
    tags_map = {}
    categories_list = []
    seen_titles = set()
    
    tag_icons = {
        "Work": "briefcase.fill",
        "Personal": "person.fill",
        "Study": "book.fill",
        "Coding": "chevron.left.forwardslash.chevron.right",
        "Design": "paintbrush.fill",
        "Writing": "pencil.and.outline"
    }
    
    for pk, title, color in cursor.fetchall():
        tags_map[pk] = (title, color)
        if title and title not in seen_titles:
            seen_titles.add(title)
            categories_list.append({
                "id": str(uuid.uuid4()).upper(),
                "name": title,
                "colorHex": color if color else "#FF5F56",
                "icon": tag_icons.get(title, "tag.fill")
            })
    
    # Ensure standard tags exist if missing
    for default_tag, default_color in [("Coding", "#FF5F56"), ("Writing", "#FFBD2E"), ("Design", "#A259FF")]:
        if default_tag not in seen_titles:
            categories_list.append({
                "id": str(uuid.uuid4()).upper(),
                "name": default_tag,
                "colorHex": default_color,
                "icon": tag_icons.get(default_tag, "tag.fill")
            })
    
    # 2. Fetch Sessions
    cursor.execute("SELECT Z_PK, ZDURATION, ZCOMPLETEDAT, ZSTARTEDAT, ZPHASE, ZTITLE, ZTAG, ZID FROM ZSESSION ORDER BY ZSTARTEDAT ASC")
    sessions = []
    
    flow_count = 0
    short_break_count = 0
    long_break_count = 0
    
    for pk, duration, completed_at, started_at, phase, title, tag_id, zid in cursor.fetchall():
        if not started_at or not completed_at:
            continue
        
        # Map phase to FlowApp SessionType
        if phase == "flow":
            session_type = "Focus"
            flow_count += 1
        elif phase == "shortBreak":
            session_type = "Short Break"
            short_break_count += 1
        elif phase == "longBreak":
            session_type = "Long Break"
            long_break_count += 1
        else:
            session_type = "Focus"
            flow_count += 1
        
        tag_info = tags_map.get(tag_id, ("Study", "#FFD96D5A"))
        tag_name = tag_info[0] if tag_info[0] else "Study"
        
        # Duration in seconds
        if duration and duration > 0:
            dur_secs = float(duration * 60)
        else:
            dur_secs = float(completed_at - started_at)
        
        if dur_secs <= 0:
            dur_secs = float(completed_at - started_at)
        
        sess_id = zid if (zid and len(zid) > 10) else str(uuid.uuid4()).upper()
        
        display_title = title if (title and title != "Flow") else f"{tag_name} Focus"
        if session_type != "Focus":
            display_title = session_type
        
        sessions.append({
            "id": sess_id,
            "title": display_title,
            "categoryName": tag_name,
            "startTime": float(started_at),
            "endTime": float(completed_at),
            "durationSeconds": float(dur_secs),
            "completed": True,
            "type": session_type
        })
    
    # 3. Write to destination directories
    app_support = os.path.expanduser("~/Library/Application Support/FlowApp")
    os.makedirs(app_support, exist_ok=True)
    dest_file = os.path.join(app_support, "sessions_history.json")
    
    with open(dest_file, "w") as f:
        json.dump(sessions, f, indent=2)
    
    print(f"Successfully migrated {len(sessions)} sessions to {dest_file}")
    print(f"  • Focus Sessions: {flow_count}")
    print(f"  • Short Breaks: {short_break_count}")
    print(f"  • Long Breaks: {long_break_count}")
    
    # 4. Also sync to iCloud if available
    icloud_dir = os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs/FlowApp")
    if os.path.exists(os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs")):
        os.makedirs(icloud_dir, exist_ok=True)
        icloud_file = os.path.join(icloud_dir, "sessions_history.json")
        with open(icloud_file, "w") as f:
            json.dump(sessions, f, indent=2)
        print(f"  • Also synced to Free Apple iCloud Drive: {icloud_file}")
    
    # 5. Save categories and all-time best streak into UserDefaults
    categories_json = json.dumps(categories_list)
    
    import subprocess
    # Write categories to defaults
    subprocess.run(["defaults", "write", "com.yugen.flow", "savedCategories", "-data", categories_json.encode('utf-8').hex()], check=False)
    subprocess.run(["defaults", "write", "com.yugen.flow", "allTimeBestStreak", "-int", "6"], check=False)
    
    print("Migration complete!")
    return True

if __name__ == "__main__":
    migrate()
