#!/usr/bin/env python3
"""Fetch and track App Store reviews for Soak.

Polls Apple's public customer reviews RSS feed across several territories,
diffs against the last-saved snapshot in ../reviews.json, prints any new
reviews, then re-saves the snapshot.
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib import error, request

APP_ID = "6775030424"
COUNTRIES = ["us", "gb", "no", "de", "fr", "ca", "au"]

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_FILE = SCRIPT_DIR.parent / "reviews.json"
FEED_URL = (
    "https://itunes.apple.com/{country}/rss/customerreviews/"
    "id={app_id}/sortBy=mostRecent/json"
)


def fetch_country(country: str) -> list[dict]:
    url = FEED_URL.format(country=country, app_id=APP_ID)
    try:
        with request.urlopen(url, timeout=10) as resp:
            data = json.load(resp)
    except error.HTTPError as e:
        if e.code in (403, 404):
            return []
        raise

    entries = data.get("feed", {}).get("entry", [])
    if isinstance(entries, dict):
        entries = [entries]

    reviews = []
    for entry in entries:
        # The app-metadata entry has no rating; skip it.
        if "im:rating" not in entry:
            continue
        reviews.append({
            "id": entry["id"]["label"],
            "country": country.upper(),
            "rating": int(entry["im:rating"]["label"]),
            "title": entry["title"]["label"],
            "body": entry["content"]["label"],
            "author": entry["author"]["name"]["label"],
            "version": entry["im:version"]["label"],
            "updated": entry["updated"]["label"],
        })
    return reviews


def load_snapshot() -> dict:
    if not DATA_FILE.exists():
        return {"reviews": []}
    return json.loads(DATA_FILE.read_text())


def save_snapshot(reviews: list[dict]) -> None:
    sorted_reviews = sorted(reviews, key=lambda r: r["updated"], reverse=True)
    payload = {
        "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "reviews": sorted_reviews,
    }
    DATA_FILE.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")


def format_review(r: dict) -> str:
    stars = "★" * r["rating"] + "☆" * (5 - r["rating"])
    return (
        f"{stars}  [{r['country']}, v{r['version']}, {r['updated'][:10]}]\n"
        f"  {r['title']}  — {r['author']}\n"
        f"  {r['body']}\n"
    )


def main() -> int:
    all_reviews: list[dict] = []
    for country in COUNTRIES:
        try:
            all_reviews.extend(fetch_country(country))
        except Exception as exc:
            print(f"warn: {country}: {exc}", file=sys.stderr)

    snapshot = load_snapshot()
    seen_ids = {r["id"] for r in snapshot["reviews"]}
    new_reviews = [r for r in all_reviews if r["id"] not in seen_ids]

    if new_reviews:
        print(f"\n{len(new_reviews)} new review(s):\n")
        for r in sorted(new_reviews, key=lambda r: r["updated"], reverse=True):
            print(format_review(r))
    else:
        print(f"No new reviews. ({len(all_reviews)} known total across {len(COUNTRIES)} territories.)")

    merged = list({r["id"]: r for r in snapshot["reviews"] + all_reviews}.values())
    save_snapshot(merged)
    return 0


if __name__ == "__main__":
    sys.exit(main())
