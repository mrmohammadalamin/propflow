import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv('.env')

DATABASE_URL = os.getenv('DATABASE_URL')

engine = create_engine(DATABASE_URL)

with engine.begin() as conn:
    print('Adding is_read...')
    conn.execute(text('ALTER TABLE communication_messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE'))
    print('Adding contact_type...')
    conn.execute(text('ALTER TABLE communication_messages ADD COLUMN IF NOT EXISTS contact_type VARCHAR(50)'))

print('Done!')
