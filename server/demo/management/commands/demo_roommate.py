from django.core.management.base import BaseCommand, CommandError

from demo import services


class Command(BaseCommand):
    help = "Acts as Sami from his phone during the demo video."

    def add_arguments(self, parser):
        parser.add_argument("action", choices=["pay"], help="pay: Sami pays Dhafer what he owes in the flat.")

    def handle(self, *args, action, **options):
        try:
            paid = services.roommate_pays()
        except services.DemoError as e:
            raise CommandError(str(e)) from e
        if paid:
            self.stdout.write(f"Sami paid Dhafer {paid / 1000:.3f} DT. Sync Dhafer's phone to see it.")
        else:
            self.stdout.write("Sami owes Dhafer nothing right now.")
