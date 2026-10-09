from django.core.management.base import BaseCommand

from beta import services
from beta.models import Feedback


class Command(BaseCommand):
    help = "Prints the beta's anonymous usage counts and the latest feedback."

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, default=14)
        parser.add_argument("--feedback", type=int, default=20, help="How many messages to show.")

    def handle(self, *args, days, feedback, **options):
        ever, this_week = services.install_counts()
        self.stdout.write(f"Installs sharing usage: {ever} (reported in the last 7 days: {this_week})")
        self.stdout.write("")
        self.stdout.write(f"{'day':<12}{'installs':>9}{'manual':>8}{'voice':>7}{'receipt':>9}")
        for day, row in services.usage_summary(days).items():
            self.stdout.write(
                f"{day.isoformat():<12}{row.get('installs', 0):>9}"
                f"{row.get('manual', 0):>8}{row.get('voice', 0):>7}{row.get('receipt', 0):>9}"
            )
        self.stdout.write("")
        self.stdout.write(f"Feedback ({Feedback.objects.count()} in all):")
        for item in Feedback.objects.all()[:feedback]:
            contact = f" <{item.contact}>" if item.contact else ""
            self.stdout.write(f"- {item.created_at:%Y-%m-%d %H:%M} v{item.app_version}{contact}: {item.message}")
