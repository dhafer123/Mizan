from django.core.management.base import BaseCommand

from notifications.services import settle_up_reminders


class Command(BaseCommand):
    help = "Reminds members who owe money in a group to settle up. Run weekly (cron)."

    def handle(self, *args, **options):
        self.stdout.write(f"Sent {settle_up_reminders()} settle-up reminders.")
