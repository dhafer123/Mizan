from django.db import migrations

from sync.db import install_functions


class Migration(migrations.Migration):
    """The global server_seq sequence and the trigger functions (sync/db.py)."""

    initial = True

    dependencies = []

    operations = [install_functions()]
