"""Print version-1 review history for a disposable simulator container."""
import json
from datetime import date, datetime, time, timedelta, timezone
from uuid import NAMESPACE_URL, uuid5

today = date.today()
reference = datetime(2001, 1, 1, tzinfo=timezone.utc)


def identifier(key):
    return str(uuid5(NAMESPACE_URL, f"doavoid-field-review/{key}")).upper()


def civil_stamp(day):
    return day.year * 10000 + day.month * 100 + day.day


def item(title, kind, age, offsets=()):
    created = today - timedelta(days=age)
    instant = datetime.combine(created, time(hour=12), tzinfo=timezone.utc)
    entries = [
        {
            "id": identifier(f"{title}/{offset}"),
            "day": civil_stamp(created + timedelta(days=offset)),
            "isMarked": True,
        }
        for offset in offsets
    ]
    return {
        "id": identifier(title),
        "title": title,
        "kind": kind,
        "createdAt": (instant - reference).total_seconds(),
        "createdDay": civil_stamp(created),
        "entries": entries,
        "isRetired": False,
    }


snapshot = {
    "version": 1,
    "items": [
        item("Start a journal", "doItem", age=0),
        item("Read ten pages", "doItem", age=46, offsets=range(39)),
        item("Late caffeine", "avoidItem", age=65, offsets=[61]),
        item("Scroll in bed", "avoidItem", age=65, offsets=range(59, 66)),
        item("Sugary drinks after dinner", "avoidItem", age=65),
    ],
}
print(json.dumps(snapshot, indent=2))
