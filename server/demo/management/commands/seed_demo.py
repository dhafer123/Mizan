from datetime import date

from django.core.management.base import BaseCommand, CommandError

from demo import services


class Command(BaseCommand):
    help = "Creates the demo accounts (Dhafer and Sami) with a month of data, for the video."

    def add_arguments(self, parser):
        parser.add_argument("--reset", action="store_true", help="Remove the demo accounts first.")
        parser.add_argument("--today", type=date.fromisoformat, help="Pretend it's this day (YYYY-MM-DD).")

    def handle(self, *args, reset, today, **options):
        if reset:
            services.reset()
        try:
            dhafer, sami, group = services.seed(today)
        except services.DemoError as e:
            raise CommandError(str(e)) from e
        self.stdout.write(f"Sign in as {dhafer.email} (or {sami.email}), password {services.PASSWORD}")
        self.stdout.write(f"Group: {group.name}. Sami pays later: python manage.py demo_roommate pay")
