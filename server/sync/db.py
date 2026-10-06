"""Database-level sync rules (Postgres), installed by migrations.

Every write to a synced table, by any path (ORM save, bulk insert, raw SQL),
goes through a trigger that:

- sets `version`: 1 on insert, +1 on every update;
- sets `server_seq` from one global sequence (ARCHITECTURE.md §6).

`server_seq` is taken under a transaction-level advisory lock, held until
commit. Writes therefore commit in `server_seq` order: once a reader sees
seq N, every row with a smaller seq is already committed (or rolled back).
Without that, `/sync/pull?since=N` could skip a row whose transaction took a
smaller seq but committed later. See ADR 0005.

Insert-only tables (settlements, history, the applied-op log) get a trigger
that rejects UPDATE.
"""

from django.db import migrations

SEQUENCE = "mizan_server_seq"

# Any constant works; it only has to be the same everywhere.
ADVISORY_LOCK_KEY = 7_211_001

_CREATE_FUNCTIONS = f"""
CREATE SEQUENCE {SEQUENCE};

CREATE FUNCTION mizan_next_server_seq() RETURNS bigint AS $$
BEGIN
    PERFORM pg_advisory_xact_lock({ADVISORY_LOCK_KEY});
    RETURN nextval('{SEQUENCE}');
END
$$ LANGUAGE plpgsql;

CREATE FUNCTION mizan_stamp_synced_row() RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.version := 1;
    ELSE
        NEW.version := OLD.version + 1;
    END IF;
    NEW.server_seq := mizan_next_server_seq();
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE FUNCTION mizan_stamp_server_seq() RETURNS trigger AS $$
BEGIN
    NEW.server_seq := mizan_next_server_seq();
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE FUNCTION mizan_forbid_update() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION '% is insert-only', TG_TABLE_NAME USING ERRCODE = 'integrity_constraint_violation';
END
$$ LANGUAGE plpgsql;
"""

_DROP_FUNCTIONS = f"""
DROP FUNCTION mizan_forbid_update();
DROP FUNCTION mizan_stamp_server_seq();
DROP FUNCTION mizan_stamp_synced_row();
DROP FUNCTION mizan_next_server_seq();
DROP SEQUENCE {SEQUENCE};
"""


def install_functions():
    """The sequence and trigger functions. Every trigger below depends on it."""
    return migrations.RunSQL(_CREATE_FUNCTIONS, _DROP_FUNCTIONS)


def _trigger(table, name, timing, events, function):
    return migrations.RunSQL(
        f"CREATE TRIGGER {name} {timing} {events} ON {table} "
        f"FOR EACH ROW EXECUTE FUNCTION {function}();",
        f"DROP TRIGGER {name} ON {table};",
    )


def synced_table(table):
    """`version` and `server_seq` stamped on every insert and update."""
    return _trigger(table, f"{table}_stamp", "BEFORE", "INSERT OR UPDATE", "mizan_stamp_synced_row")


def sequenced_table(table):
    """`server_seq` stamped on insert (for insert-only tables that are pulled)."""
    return _trigger(table, f"{table}_seq", "BEFORE", "INSERT", "mizan_stamp_server_seq")


def insert_only(table):
    return _trigger(table, f"{table}_insert_only", "BEFORE", "UPDATE", "mizan_forbid_update")


def lock_ledger():
    """Takes the server_seq lock now, for the rest of the transaction.

    Push calls this before reading the row an op touches, so the read, the
    merge and the write can't interleave with another op on the same row.
    (Every synced write takes the same lock anyway; this just takes it early.)
    """
    from django.db import connection

    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_advisory_xact_lock(%s)", [ADVISORY_LOCK_KEY])
