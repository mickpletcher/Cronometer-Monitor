import argparse
import datetime as dt
import json
import re
import sqlite3
from pathlib import Path


def ensure_schema(connection: sqlite3.Connection) -> None:
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_key TEXT NOT NULL UNIQUE,
            snapshot_date_text TEXT,
            snapshot_date_iso TEXT,
            captured_at_utc TEXT NOT NULL,
            schema_version TEXT,
            query_status TEXT,
            calories_consumed REAL,
            protein_grams REAL,
            carbs_grams REAL,
            fat_grams REAL,
            payload_json TEXT NOT NULL
        )
        """
    )
    connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_snapshots_snapshot_date_iso ON snapshots (snapshot_date_iso)"
    )
    connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_snapshots_captured_at_utc ON snapshots (captured_at_utc)"
    )
    connection.commit()


def normalize_date_text(value: str) -> str:
    return re.sub(r"\s+", " ", (value or "").strip())


def infer_snapshot_date(diary_date_text: str):
    raw = normalize_date_text(diary_date_text)
    if not raw:
        return None

    today = dt.datetime.now(dt.timezone.utc).date()
    for fmt in ("%Y-%m-%d", "%b %d, %Y", "%B %d, %Y", "%b %d", "%B %d"):
        try:
            parsed = dt.datetime.strptime(raw, fmt)
        except ValueError:
            continue

        if "%Y" not in fmt:
            parsed = parsed.replace(year=today.year)
            if parsed.date() > today + dt.timedelta(days=30):
                parsed = parsed.replace(year=today.year - 1)

        return parsed.date()

    return None


def build_snapshot_record(payload: dict) -> dict:
    diary_date_text = normalize_date_text(str(payload.get("DiaryDate", "")))
    parsed_date = infer_snapshot_date(diary_date_text)
    snapshot_date_iso = parsed_date.isoformat() if parsed_date else None
    if snapshot_date_iso:
        snapshot_key = snapshot_date_iso
    elif diary_date_text:
        snapshot_key = re.sub(r"[^a-z0-9]+", "_", diary_date_text.lower()).strip("_")
    else:
        snapshot_key = "unknown"

    captured_at_utc = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    return {
        "snapshot_key": snapshot_key,
        "snapshot_date_text": diary_date_text or None,
        "snapshot_date_iso": snapshot_date_iso,
        "captured_at_utc": captured_at_utc,
        "schema_version": payload.get("SchemaVersion"),
        "query_status": payload.get("QueryStatus"),
        "calories_consumed": payload.get("CaloriesConsumed"),
        "protein_grams": payload.get("ProteinGrams"),
        "carbs_grams": payload.get("CarbsGrams"),
        "fat_grams": payload.get("FatGrams"),
        "payload_json": json.dumps(payload, ensure_ascii=True),
    }


def command_init(args: argparse.Namespace) -> None:
    db_path = Path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(db_path) as connection:
        ensure_schema(connection)
    print(json.dumps({"DatabasePath": str(db_path), "Initialized": True}))


def command_upsert(args: argparse.Namespace) -> None:
    db_path = Path(args.db)
    payload = json.loads(Path(args.payload).read_text(encoding="utf-8"))
    record = build_snapshot_record(payload)

    with sqlite3.connect(db_path) as connection:
        ensure_schema(connection)
        connection.execute(
            """
            INSERT INTO snapshots (
                snapshot_key,
                snapshot_date_text,
                snapshot_date_iso,
                captured_at_utc,
                schema_version,
                query_status,
                calories_consumed,
                protein_grams,
                carbs_grams,
                fat_grams,
                payload_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(snapshot_key) DO UPDATE SET
                snapshot_date_text = excluded.snapshot_date_text,
                snapshot_date_iso = excluded.snapshot_date_iso,
                captured_at_utc = excluded.captured_at_utc,
                schema_version = excluded.schema_version,
                query_status = excluded.query_status,
                calories_consumed = excluded.calories_consumed,
                protein_grams = excluded.protein_grams,
                carbs_grams = excluded.carbs_grams,
                fat_grams = excluded.fat_grams,
                payload_json = excluded.payload_json
            """,
            (
                record["snapshot_key"],
                record["snapshot_date_text"],
                record["snapshot_date_iso"],
                record["captured_at_utc"],
                record["schema_version"],
                record["query_status"],
                record["calories_consumed"],
                record["protein_grams"],
                record["carbs_grams"],
                record["fat_grams"],
                record["payload_json"],
            ),
        )
        connection.commit()

    print(
        json.dumps(
            {
                "Saved": True,
                "Storage": "SQLite",
                "SnapshotKey": record["snapshot_key"],
                "SnapshotDateText": record["snapshot_date_text"],
                "SnapshotDateIso": record["snapshot_date_iso"],
                "CapturedAtUtc": record["captured_at_utc"],
                "DatabasePath": str(db_path),
            }
        )
    )


def command_query(args: argparse.Namespace) -> None:
    db_path = Path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(db_path) as connection:
        ensure_schema(connection)
        connection.row_factory = sqlite3.Row

        clauses = []
        parameters = []
        if args.from_date:
            clauses.append("snapshot_date_iso >= ?")
            parameters.append(args.from_date)
        if args.to_date:
            clauses.append("snapshot_date_iso <= ?")
            parameters.append(args.to_date)

        where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        order_sql = "DESC" if args.order.lower() == "desc" else "ASC"
        query = f"""
            SELECT
                snapshot_key,
                snapshot_date_text,
                snapshot_date_iso,
                captured_at_utc,
                schema_version,
                query_status,
                calories_consumed,
                protein_grams,
                carbs_grams,
                fat_grams,
                payload_json
            FROM snapshots
            {where_sql}
            ORDER BY COALESCE(snapshot_date_iso, snapshot_key) {order_sql}, captured_at_utc {order_sql}
            LIMIT ?
        """
        parameters.append(args.limit)
        rows = connection.execute(query, parameters).fetchall()

    result = []
    for row in rows:
        item = {
            "SnapshotKey": row["snapshot_key"],
            "SnapshotDateText": row["snapshot_date_text"],
            "SnapshotDateIso": row["snapshot_date_iso"],
            "CapturedAtUtc": row["captured_at_utc"],
            "SchemaVersion": row["schema_version"],
            "QueryStatus": row["query_status"],
            "CaloriesConsumed": row["calories_consumed"],
            "ProteinGrams": row["protein_grams"],
            "CarbsGrams": row["carbs_grams"],
            "FatGrams": row["fat_grams"],
        }
        if args.include_payload:
            item["Payload"] = json.loads(row["payload_json"])
        result.append(item)

    print(json.dumps(result, ensure_ascii=True))


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    parser_init = subparsers.add_parser("init")
    parser_init.add_argument("--db", required=True)
    parser_init.set_defaults(func=command_init)

    parser_upsert = subparsers.add_parser("upsert")
    parser_upsert.add_argument("--db", required=True)
    parser_upsert.add_argument("--payload", required=True)
    parser_upsert.set_defaults(func=command_upsert)

    parser_query = subparsers.add_parser("query")
    parser_query.add_argument("--db", required=True)
    parser_query.add_argument("--from-date")
    parser_query.add_argument("--to-date")
    parser_query.add_argument("--limit", type=int, default=30)
    parser_query.add_argument("--order", choices=("asc", "desc"), default="asc")
    parser_query.add_argument("--include-payload", action="store_true")
    parser_query.set_defaults(func=command_query)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
