from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    """The project's user model.

    Defined before the first migration, as Django recommends, so task 3.2 can
    switch to email login without swapping AUTH_USER_MODEL on a live database.
    """
