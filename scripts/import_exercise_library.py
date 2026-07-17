#!/usr/bin/env python3
"""Import the curated Suilian exercise media from free-exercise-db.

The upstream dataset is public domain / Unlicense. This importer deliberately
vendors only the entries shown in the app so the Android package stays small.
"""

from __future__ import annotations

import argparse
import json
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "mobile" / "assets" / "exercise_library"
DATA_URL = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db/"
    "main/dist/exercises.json"
)
MEDIA_URL = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db/"
    "main/exercises/{source_id}/{frame}.jpg"
)

ENTRIES = {
    "Leverage_Chest_Press": "leverage-chest-press",
    "Butterfly": "butterfly",
    "Leverage_Incline_Chest_Press": "leverage-incline-chest-press",
    "Dumbbell_Bench_Press": "dumbbell-bench-press",
    "Incline_Dumbbell_Press": "incline-dumbbell-press",
    "Dumbbell_Flyes": "dumbbell-flyes",
    "Barbell_Bench_Press_-_Medium_Grip": "barbell-bench-press---medium-grip",
    "Barbell_Incline_Bench_Press_-_Medium_Grip": (
        "barbell-incline-bench-press---medium-grip"
    ),
    "Decline_Barbell_Bench_Press": "decline-barbell-bench-press",
    "Pushups": "pushups",
    "Incline_Push-Up": "incline-push-up",
    "Push-Ups_With_Feet_Elevated": "push-ups-with-feet-elevated",
}


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "suilian-ai-importer"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the curated source IDs and local assets without rewriting them",
    )
    args = parser.parse_args()

    catalog = json.loads(fetch(DATA_URL))
    upstream = {entry["id"]: entry for entry in catalog}
    missing_ids = sorted(set(ENTRIES) - set(upstream))
    if missing_ids:
        raise SystemExit(f"missing upstream entries: {', '.join(missing_ids)}")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    missing_files: list[Path] = []
    for source_id, local_slug in ENTRIES.items():
        images = upstream[source_id].get("images", [])
        if len(images) < 2:
            raise SystemExit(f"{source_id} no longer has two image frames")
        for frame in range(2):
            destination = OUTPUT / f"{local_slug}_{frame}.jpg"
            if args.check:
                if not destination.is_file() or destination.stat().st_size == 0:
                    missing_files.append(destination)
                continue
            destination.write_bytes(
                fetch(MEDIA_URL.format(source_id=source_id, frame=frame))
            )

    if missing_files:
        paths = "\n".join(str(path.relative_to(ROOT)) for path in missing_files)
        raise SystemExit(f"missing local assets:\n{paths}")
    print(f"verified {len(ENTRIES)} exercises and {len(ENTRIES) * 2} images")


if __name__ == "__main__":
    main()
