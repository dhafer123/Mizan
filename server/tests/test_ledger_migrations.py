"""The sync migrations install their triggers and can be undone and redone."""

import pytest
from django.core.management import call_command
from django.db import connection

TRIGGERS = {
    "groups_group_stamp",
    "groups_member_stamp",
    "ledger_expense_stamp",
    "ledger_category_stamp",
    "ledger_incomesource_stamp",
    "ledger_budget_stamp",
    "ledger_sharedexpense_stamp",
    "ledger_settlement_stamp",
    "ledger_settlement_insert_only",
    "sync_entityhistory_seq",
    "sync_entityhistory_insert_only",
    "sync_appliedop_insert_only",
}


def installed_triggers():
    with connection.cursor() as cursor:
        cursor.execute("SELECT tgname FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE ANY (ARRAY['groups_%', 'ledger_%', 'sync_%'])")
        return {row[0] for row in cursor.fetchall()}


def sequence_exists():
    with connection.cursor() as cursor:
        cursor.execute("SELECT to_regclass('mizan_server_seq') IS NOT NULL")
        return cursor.fetchone()[0]


@pytest.mark.django_db
def test_every_synced_table_has_its_triggers():
    assert installed_triggers() == TRIGGERS
    assert sequence_exists()


@pytest.mark.django_db(transaction=True)
def test_migrations_unapply_and_reapply_cleanly():
    call_command("migrate", "sync", "zero", verbosity=0)  # Also unapplies groups and ledger.

    assert installed_triggers() == set()
    assert not sequence_exists()

    call_command("migrate", verbosity=0)

    assert installed_triggers() == TRIGGERS
    assert sequence_exists()
