"""Field codecs for sync ops: check a JSON value from the app and turn it into
a Python value (`clean`), and back to the app's JSON form (`dump`).

The JSON forms are what the app's drift rows produce with `toJson`
(`app/lib/features/sync/data/db/sync_payload.dart`): camelCase keys, money as
integer minor units, calendar days as UTC-midnight ISO-8601 strings.
`clean` raises ValueError for a bad value.
"""

import datetime
import re
from dataclasses import dataclass
from typing import Any, Callable

# The app's `Currency` enum (app/lib/core/money/currency.dart).
CURRENCIES = {"TND", "EUR", "USD"}

ENTITY_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
MONTH = re.compile(r"^[0-9]{4}-(0[1-9]|1[0-2])$")


@dataclass(frozen=True)
class Codec:
    clean: Callable[[Any], Any]
    dump: Callable[[Any], Any] = lambda value: value
    nullable: bool = False


def _int(value):
    # bool is an int in Python; JSON true is not a number.
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError("not an integer")
    return value


def _positive_int(value):
    if _int(value) <= 0:
        raise ValueError("must be positive")
    return value


def text(max_length):
    def clean(value):
        if not isinstance(value, str) or not value.strip() or len(value) > max_length:
            raise ValueError("bad text")
        return value

    return clean


def _bool(value):
    if not isinstance(value, bool):
        raise ValueError("not a boolean")
    return value


def _currency(value):
    if value not in CURRENCIES:
        raise ValueError("unknown currency")
    return value


def choice(*values):
    def clean(value):
        if value not in values:
            raise ValueError("not a choice")
        return value

    return clean


def _day(value):
    """A calendar day: "2026-10-06T00:00:00.000Z" (the app) or "2026-10-06"."""
    if not isinstance(value, str):
        raise ValueError("not a date")
    try:
        parsed = datetime.datetime.fromisoformat(value)
    except ValueError:
        raise ValueError("not a date") from None
    if parsed.tzinfo is not None:
        if parsed.utcoffset() != datetime.timedelta(0):
            raise ValueError("not UTC")
    if parsed.time() != datetime.time(0):
        raise ValueError("not a calendar day")
    return parsed.date()


def _dump_day(value):
    return f"{value.isoformat()}T00:00:00.000Z"


def _month(value):
    if not isinstance(value, str) or not MONTH.match(value):
        raise ValueError("not YYYY-MM")
    return value


def _day_of_month(value):
    if not 1 <= _int(value) <= 31:
        raise ValueError("not a day of the month")
    return value


def _entity_ref(value):
    if not isinstance(value, str) or not ENTITY_ID.match(value):
        raise ValueError("not an id")
    return value


def _json_object(value):
    if not isinstance(value, dict):
        raise ValueError("not an object")
    return value


def _shares(value):
    """{memberId: minor units ≥ 0}, at least one member."""
    if not isinstance(value, dict) or not value:
        raise ValueError("not a share map")
    for member_id, amount in value.items():
        _entity_ref(member_id)
        if _int(amount) < 0:
            raise ValueError("negative share")
    return value


POSITIVE_INT = Codec(_positive_int)
OPTIONAL_POSITIVE_INT = Codec(_positive_int, nullable=True)
CURRENCY = Codec(_currency)
BOOL = Codec(_bool)
DAY = Codec(_day, _dump_day)
OPTIONAL_DAY = Codec(_day, _dump_day, nullable=True)
MONTH_CODEC = Codec(_month)
DAY_OF_MONTH = Codec(_day_of_month, nullable=True)
REF = Codec(_entity_ref)
OPTIONAL_REF = Codec(_entity_ref, nullable=True)
JSON_OBJECT = Codec(_json_object)
SHARES = Codec(_shares)


def TEXT(max_length):  # noqa: N802 - reads like the constants above
    return Codec(text(max_length))


def OPTIONAL_TEXT(max_length):  # noqa: N802
    return Codec(text(max_length), nullable=True)


def CHOICE(*values):  # noqa: N802
    return Codec(choice(*values))


@dataclass(frozen=True)
class Field:
    """One synced field: its JSON name (the dict key in a spec), model
    attribute, codec, and whether a create must include it."""

    attr: str
    codec: Codec
    required: bool = True
    # Can't change after create (e.g. which group an expense belongs to).
    immutable: bool = False
    # A reference resolved within the group: "member" or "settlement".
    ref: str | None = None

    def clean(self, value):
        if value is None:
            if self.codec.nullable:
                return None
            raise ValueError("required")
        return self.codec.clean(value)

    def dump(self, value):
        return None if value is None else self.codec.dump(value)
