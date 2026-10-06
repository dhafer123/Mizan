"""A pretend phone for push tests: a signed-in client with a device id."""

import uuid

from accounts.services import issue_tokens

from .conftest import auth_client

DAY = "2026-10-06T00:00:00.000Z"


class Device:
    def __init__(self, user):
        self.user = user
        self.id = uuid.uuid4()
        self.client = auth_client(issue_tokens(user)["access"])

    def push(self, *ops):
        response = self.client.post("/sync/push", {"deviceId": str(self.id), "ops": list(ops)}, format="json")
        assert response.status_code == 200, response.json()
        return response.json()["results"]

    def one(self, op):
        (result,) = self.push(op)
        return result


def op(entity, entity_id, op_type="update", base=0, op_id=None, **fields):
    return {
        "opId": str(op_id or uuid.uuid4()),
        "entity": entity,
        "entityId": entity_id,
        "opType": op_type,
        "baseVersion": base,
        "changedFields": fields,
    }


def expense_fields(entity_id, **overrides):
    """A create payload exactly as the app's ExpenseRow.toJson makes it."""
    return {
        "id": entity_id,
        "amountMinor": 4500,
        "currency": "TND",
        "categoryId": "food",
        "date": DAY,
        "note": None,
        "source": "manual",
        **overrides,
    }


def create_expense(device, entity_id=None, **overrides):
    entity_id = entity_id or str(uuid.uuid4())
    return device.one(op("expenses", entity_id, "create", 0, **expense_fields(entity_id, **overrides)))
