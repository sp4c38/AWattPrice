async def check_and_sent(data, data_region, db_manager):
    # Get all tokens and their settings
    db_manager.lock.acquire()
    cursor = db_manager.db.cursor()
    items = cursor.execute("SELECT * FROM token_storage;").fetchall()


    # await db_manager.lock.release()
