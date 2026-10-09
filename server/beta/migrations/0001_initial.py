from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Feedback",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("message", models.TextField(max_length=2000)),
                ("contact", models.CharField(blank=True, max_length=254)),
                ("app_version", models.CharField(max_length=32)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="UsageDay",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("install_id", models.UUIDField()),
                ("day", models.DateField()),
                (
                    "method",
                    models.CharField(
                        choices=[("manual", "Manual"), ("voice", "Voice"), ("receipt", "Receipt")], max_length=16
                    ),
                ),
                ("count", models.PositiveIntegerField()),
                ("app_version", models.CharField(max_length=32)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={
                "constraints": [
                    models.UniqueConstraint(fields=("install_id", "day", "method"), name="usage_day_unique")
                ],
            },
        ),
    ]
