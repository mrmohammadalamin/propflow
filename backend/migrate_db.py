import sqlite3

def migrate():
    conn = sqlite3.connect('rentcollections.db')
    cursor = conn.cursor()
    
    # 1. Add assigned_manager_id to properties
    try:
        cursor.execute("ALTER TABLE properties ADD COLUMN assigned_manager_id INTEGER REFERENCES users(id)")
        print("Added assigned_manager_id to properties table")
    except sqlite3.OperationalError:
        print("assigned_manager_id already exists")

    # 1b. Add role to users
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'support_agent'")
        print("Added role to users table")
    except sqlite3.OperationalError:
        print("role already exists")

    # 1c. Add missing columns to landlords
    for col in ["co", "address_line_1", "address_line_2", "city", "county", "postcode", "email", "phone"]:
        try:
            cursor.execute(f"ALTER TABLE landlords ADD COLUMN {col} TEXT")
            print(f"Added {col} to landlords table")
        except sqlite3.OperationalError:
            print(f"Column {col} already exists in landlords")

    # 2. Create audit_logs table if it doesn't exist
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            agency_id INTEGER NOT NULL REFERENCES agencies(id),
            user_id INTEGER NOT NULL REFERENCES users(id),
            action TEXT NOT NULL,
            resource_type TEXT,
            resource_id INTEGER,
            details TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    # 3. Add logo_url to agencies
    try:
        cursor.execute("ALTER TABLE agencies ADD COLUMN logo_url TEXT")
        print("Added logo_url to agencies table")
    except sqlite3.OperationalError:
        print("logo_url already exists in agencies")

    # 4. Add avatar_url to users
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN avatar_url TEXT")
        print("Added avatar_url to users table")
    except sqlite3.OperationalError:
        print("avatar_url already exists in users")
    
    # 5. Add management_fee_percentage to tenancies
    try:
        cursor.execute("ALTER TABLE tenancies ADD COLUMN management_fee_percentage NUMERIC(5, 2) DEFAULT 10.00")
        print("Added management_fee_percentage to tenancies table")
    except sqlite3.OperationalError:
        print("management_fee_percentage already exists in tenancies")
        
    # 6. Migrate management_fee_percentage data from agencies to tenancies, then drop column
    try:
        # First, ensure tenancies get the agency's management fee if it's not set or still default
        cursor.execute("""
            UPDATE tenancies
            SET management_fee_percentage = (
                SELECT management_fee_percentage FROM agencies WHERE agencies.id = tenancies.agency_id
            )
            WHERE management_fee_percentage IS NULL OR management_fee_percentage = 10.00
        """)
        
        # Now drop the column from agencies
        cursor.execute("ALTER TABLE agencies DROP COLUMN management_fee_percentage")
        print("Dropped management_fee_percentage from agencies table")
    except sqlite3.OperationalError as e:
        print(f"Skipped dropping management_fee_percentage from agencies: {e}")
        
    conn.commit()
    conn.close()

if __name__ == "__main__":
    migrate()
