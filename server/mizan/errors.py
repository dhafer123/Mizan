"""One JSON shape for every API error, so the app can map them by `code`:

    {"code": "invalid", "detail": "...", "fields": {"email": [{"code": "email_taken", "message": "..."}]}}

`fields` is only present for validation errors; nested fields use dotted names ("device.id").
"""

from rest_framework.exceptions import ValidationError
from rest_framework.views import exception_handler


def api_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is not None:
        response.data = error_body(exc)
    return response


def error_body(exc):
    if isinstance(exc, ValidationError):
        return {"code": "invalid", "detail": "Some fields are invalid.", "fields": _fields(exc.detail)}
    detail = exc.detail
    # simplejwt errors carry {"detail": ..., "code": ...} as their detail.
    if isinstance(detail, dict) and "code" in detail:
        return {"code": str(detail["code"]), "detail": str(detail.get("detail", ""))}
    codes = exc.get_codes()
    return {"code": codes if isinstance(codes, str) else exc.default_code, "detail": str(detail)}


def _fields(detail, prefix=""):
    if isinstance(detail, list):
        detail = {"non_field_errors": detail}
    fields = {}
    for name, errors in detail.items():
        key = f"{prefix}{name}"
        if isinstance(errors, dict):
            fields.update(_fields(errors, prefix=f"{key}."))
        else:
            fields[key] = [{"code": error.code, "message": str(error)} for error in errors]
    return fields
