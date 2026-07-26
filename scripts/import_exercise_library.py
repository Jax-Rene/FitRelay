#!/usr/bin/env python3
"""Import the complete free-exercise-db catalog and media for FitRelay.

The upstream dataset is public domain / Unlicense. The app keeps the original
English names and instructions for bulk-imported exercises so safety guidance
is not silently changed by machine translation. The original twelve curated
chest entries continue to use the project's reviewed Chinese copy and defaults.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import re
import shutil
import subprocess
import time
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "mobile" / "assets" / "exercise_library"
GENERATED_DART = (
    ROOT / "mobile" / "lib" / "models" / "exercise_catalog_data.g.dart"
)

UPSTREAM_REPOSITORY = "https://github.com/yuhonas/free-exercise-db"
UPSTREAM_REF = "b0eed061e1c832b3ed815fbaa4b45b3cdc14df49"
RAW_ROOT = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db/"
    f"{UPSTREAM_REF}"
)
DATA_URL = f"{RAW_ROOT}/dist/exercises.json"
MEDIA_ROOT = f"{RAW_ROOT}/exercises"
MEDIA_EXTENSION = ".webp"
MEDIA_MAX_EDGE = 480
MEDIA_QUALITY = 60

# These entries already have reviewed Chinese names, steps, cues and defaults
# in exercise_catalog.dart. Keep their existing asset names for stable builds.
CURATED_ASSETS = {
    "Leverage_Chest_Press": "leverage-chest-press",
    "Butterfly": "butterfly",
    "Leverage_Incline_Chest_Press": "leverage-incline-chest-press",
    "Dumbbell_Bench_Press": "dumbbell-bench-press",
    "Incline_Dumbbell_Press": "incline-dumbbell-press",
    "Dumbbell_Flyes": "dumbbell-flyes",
    "Barbell_Bench_Press_-_Medium_Grip": (
        "barbell-bench-press---medium-grip"
    ),
    "Barbell_Incline_Bench_Press_-_Medium_Grip": (
        "barbell-incline-bench-press---medium-grip"
    ),
    "Decline_Barbell_Bench_Press": "decline-barbell-bench-press",
    "Pushups": "pushups",
    "Incline_Push-Up": "incline-push-up",
    "Push-Ups_With_Feet_Elevated": "push-ups-with-feet-elevated",
}

MUSCLE_LABELS = {
    "abdominals": "核心",
    "abductors": "腿部",
    "adductors": "腿部",
    "biceps": "二头",
    "calves": "腿部",
    "chest": "胸部",
    "forearms": "前臂",
    "glutes": "腿部",
    "hamstrings": "腿部",
    "lats": "背部",
    "lower back": "背部",
    "middle back": "背部",
    "neck": "颈部",
    "quadriceps": "腿部",
    "shoulders": "肩部",
    "traps": "背部",
    "triceps": "三头",
}

EQUIPMENT_ENUMS = {
    None: "other",
    "bands": "bands",
    "barbell": "barbell",
    "body only": "bodyweight",
    "cable": "cable",
    "dumbbell": "dumbbell",
    "e-z curl bar": "ezBar",
    "exercise ball": "exerciseBall",
    "foam roll": "foamRoller",
    "kettlebells": "kettlebell",
    "machine": "machine",
    "medicine ball": "medicineBall",
    "other": "other",
}

CATEGORY_ENUMS = {
    "cardio": "cardio",
    "olympic weightlifting": "olympicWeightlifting",
    "plyometrics": "plyometrics",
    "powerlifting": "powerlifting",
    "strength": "strength",
    "stretching": "stretching",
    "strongman": "strongman",
}

LEVEL_LABELS = {
    "beginner": "入门",
    "intermediate": "中级",
    "expert": "进阶",
}

CATEGORY_DEFAULTS = {
    "cardio": (10, 20, 0),
    "olympic weightlifting": (3, 6, 180),
    "plyometrics": (6, 12, 90),
    "powerlifting": (3, 6, 180),
    "strength": (8, 12, 90),
    "stretching": (1, 3, 30),
    "strongman": (6, 10, 120),
}


def fetch(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "fitrelay-exercise-importer"},
    )
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read()
        except Exception as error:  # noqa: BLE001 - preserve the last network error
            last_error = error
            time.sleep(0.5 * (attempt + 1))
    assert last_error is not None
    raise last_error


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


def dart_string(value: str) -> str:
    # JSON string literals are valid Dart string literals after escaping "$",
    # which would otherwise start Dart interpolation.
    return json.dumps(value, ensure_ascii=False).replace("$", r"\$")


def load_catalog() -> list[dict[str, Any]]:
    catalog = json.loads(fetch(DATA_URL))
    if not isinstance(catalog, list):
        raise SystemExit("upstream catalog is not a JSON array")
    return catalog


def validate_catalog(catalog: list[dict[str, Any]]) -> None:
    source_ids = [entry.get("id") for entry in catalog]
    if len(source_ids) != len(set(source_ids)):
        raise SystemExit("upstream catalog contains duplicate source IDs")

    missing_curated = sorted(set(CURATED_ASSETS) - set(source_ids))
    if missing_curated:
        raise SystemExit(
            f"missing curated upstream entries: {', '.join(missing_curated)}"
        )

    generated_slugs: dict[str, str] = {}
    errors: list[str] = []
    for entry in catalog:
        source_id = entry.get("id")
        name = entry.get("name")
        images = entry.get("images")
        primary_muscles = entry.get("primaryMuscles")
        instructions = entry.get("instructions")
        category = entry.get("category")
        equipment = entry.get("equipment")

        if not isinstance(source_id, str) or not source_id:
            errors.append("entry without a source ID")
            continue
        if not isinstance(name, str) or not name:
            errors.append(f"{source_id}: missing name")
        if not isinstance(images, list) or len(images) != 2:
            errors.append(f"{source_id}: expected exactly two images")
        if not isinstance(primary_muscles, list) or not primary_muscles:
            errors.append(f"{source_id}: missing primary muscle")
        if not isinstance(instructions, list):
            errors.append(f"{source_id}: instructions are not an array")
        if category not in CATEGORY_ENUMS:
            errors.append(f"{source_id}: unsupported category {category!r}")
        if equipment not in EQUIPMENT_ENUMS:
            errors.append(f"{source_id}: unsupported equipment {equipment!r}")

        generated_slug = f"free_{slugify(source_id)}"
        previous = generated_slugs.get(generated_slug)
        if previous is not None:
            errors.append(
                f"slug collision: {source_id} and {previous} -> {generated_slug}"
            )
        generated_slugs[generated_slug] = source_id

    if errors:
        raise SystemExit("\n".join(errors))


def local_asset_stem(source_id: str) -> str:
    return CURATED_ASSETS.get(source_id, slugify(source_id).replace("_", "-"))


def local_asset_paths(entry: dict[str, Any]) -> list[Path]:
    stem = local_asset_stem(entry["id"])
    return [OUTPUT / f"{stem}_{index}{MEDIA_EXTENSION}" for index in range(2)]


def jpeg_dimensions(data: bytes) -> tuple[int, int]:
    if not data.startswith(b"\xff\xd8"):
        raise ValueError("source image is not a JPEG")

    offset = 2
    start_of_frame_markers = {
        0xC0,
        0xC1,
        0xC2,
        0xC3,
        0xC5,
        0xC6,
        0xC7,
        0xC9,
        0xCA,
        0xCB,
        0xCD,
        0xCE,
        0xCF,
    }
    while offset + 4 <= len(data):
        if data[offset] != 0xFF:
            offset += 1
            continue
        while offset < len(data) and data[offset] == 0xFF:
            offset += 1
        if offset >= len(data):
            break

        marker = data[offset]
        offset += 1
        if marker in {0x01, 0xD8, 0xD9}:
            continue
        if offset + 2 > len(data):
            break
        segment_length = int.from_bytes(data[offset : offset + 2], "big")
        if segment_length < 2 or offset + segment_length > len(data):
            break
        if marker in start_of_frame_markers:
            if segment_length < 7:
                break
            height = int.from_bytes(data[offset + 3 : offset + 5], "big")
            width = int.from_bytes(data[offset + 5 : offset + 7], "big")
            if width > 0 and height > 0:
                return width, height
            break
        offset += segment_length

    raise ValueError("could not read JPEG dimensions")


def encode_webp(data: bytes, destination: Path) -> None:
    cwebp = shutil.which("cwebp")
    if cwebp is None:
        raise RuntimeError(
            "cwebp is required to import optimized exercise images"
        )

    width, height = jpeg_dimensions(data)
    scale = min(1.0, MEDIA_MAX_EDGE / max(width, height))
    resized_width = max(1, round(width * scale))
    resized_height = max(1, round(height * scale))
    source = destination.with_suffix(".source.jpg")
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    source.write_bytes(data)
    try:
        subprocess.run(
            [
                cwebp,
                "-quiet",
                "-mt",
                "-m",
                "6",
                "-q",
                str(MEDIA_QUALITY),
                "-resize",
                str(resized_width),
                str(resized_height),
                str(source),
                "-o",
                str(temporary),
            ],
            check=True,
        )
        temporary.replace(destination)
    finally:
        source.unlink(missing_ok=True)
        temporary.unlink(missing_ok=True)


def muscle_label(entry: dict[str, Any]) -> str:
    if entry["category"] == "cardio":
        return "有氧"
    return MUSCLE_LABELS.get(entry["primaryMuscles"][0], "全身")


def generated_dart(catalog: list[dict[str, Any]]) -> str:
    entries = [
        entry for entry in catalog if entry["id"] not in CURATED_ASSETS
    ]
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "//",
        f"// Source: {UPSTREAM_REPOSITORY}",
        f"// Revision: {UPSTREAM_REF}",
        f"// Imported entries in this file: {len(entries)}",
        "",
        "part of 'exercise_catalog.dart';",
        "",
        "const generatedExerciseCatalog = <ExerciseCatalogEntry>[",
    ]

    for entry in entries:
        category = entry["category"]
        reps_min, reps_max, rest_seconds = CATEGORY_DEFAULTS[category]
        paths = local_asset_paths(entry)
        instructions = entry["instructions"] or [
            "The source dataset does not provide instructions for this "
            "exercise. Practice only with qualified professional guidance."
        ]
        level = LEVEL_LABELS.get(entry.get("level"), "未分级")
        equipment = EQUIPMENT_ENUMS[entry.get("equipment")]

        lines.extend(
            [
                "  ExerciseCatalogEntry(",
                f"    slug: {dart_string(f'free_{slugify(entry['id'])}')},",
                f"    sourceId: {dart_string(entry['id'])},",
                f"    name: {dart_string(entry['name'])},",
                f"    muscle: {dart_string(muscle_label(entry))},",
                f"    equipment: ExerciseEquipment.{equipment},",
                f"    category: ExerciseCategory.{CATEGORY_ENUMS[category]},",
                f"    level: {dart_string(level)},",
                "    images: [",
                *[
                    "      "
                    + dart_string(
                        "assets/exercise_library/" + path.name
                    )
                    + ","
                    for path in paths
                ],
                "    ],",
                "    instructions: [",
                *[
                    f"      {dart_string(str(instruction))},"
                    for instruction in instructions
                ],
                "    ],",
                "    cue: '保持动作可控；若出现疼痛或明显不适，请立即停止。',",
                "    defaultLoadKg: 0,",
                f"    repsMin: {reps_min},",
                f"    repsMax: {reps_max},",
                f"    restSeconds: {rest_seconds},",
                "  ),",
            ]
        )

    lines.extend(["];", ""])
    return "\n".join(lines)


def media_jobs(
    catalog: list[dict[str, Any]],
) -> list[tuple[str, Path]]:
    jobs: list[tuple[str, Path]] = []
    for entry in catalog:
        destinations = local_asset_paths(entry)
        for source_path, destination in zip(
            entry["images"],
            destinations,
            strict=True,
        ):
            jobs.append((f"{MEDIA_ROOT}/{source_path}", destination))
    return jobs


def download_media(
    job: tuple[str, Path],
    *,
    refresh: bool,
) -> tuple[Path, bool]:
    url, destination = job
    if (
        not refresh
        and destination.is_file()
        and destination.stat().st_size > 0
    ):
        return destination, False

    legacy_jpeg = destination.with_suffix(".jpg")
    migrated_legacy_jpeg = not refresh and legacy_jpeg.is_file()
    data = legacy_jpeg.read_bytes() if migrated_legacy_jpeg else fetch(url)
    if not data:
        raise RuntimeError(f"empty media response for {url}")
    encode_webp(data, destination)
    if migrated_legacy_jpeg:
        legacy_jpeg.unlink()
    return destination, True


def verify_assets(
    jobs: list[tuple[str, Path]],
) -> list[tuple[Path, str]]:
    problems: list[tuple[Path, str]] = []
    for _, destination in jobs:
        if not destination.is_file():
            problems.append((destination, "missing"))
            continue
        if destination.stat().st_size < 1024:
            problems.append((destination, "file is unexpectedly small"))
            continue
        with destination.open("rb") as image:
            header = image.read(12)
        if not (header.startswith(b"RIFF") and header[8:12] == b"WEBP"):
            problems.append((destination, "invalid WebP header"))
    return problems


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify generated catalog and all local assets without rewriting",
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="redownload media that already exists",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=12,
        help="parallel media download workers (default: 12)",
    )
    args = parser.parse_args()

    catalog = load_catalog()
    validate_catalog(catalog)
    expected_dart = generated_dart(catalog)
    jobs = media_jobs(catalog)

    if args.check:
        problems: list[str] = []
        if not GENERATED_DART.is_file():
            problems.append(
                f"missing generated catalog: {GENERATED_DART.relative_to(ROOT)}"
            )
        elif GENERATED_DART.read_text() != expected_dart:
            problems.append(
                f"stale generated catalog: {GENERATED_DART.relative_to(ROOT)}"
            )
        asset_problems = verify_assets(jobs)
        if asset_problems:
            paths = "\n".join(
                f"{path.relative_to(ROOT)}: {reason}"
                for path, reason in asset_problems
            )
            problems.append(f"invalid local assets:\n{paths}")
        if problems:
            raise SystemExit("\n".join(problems))
    else:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        GENERATED_DART.parent.mkdir(parents=True, exist_ok=True)
        GENERATED_DART.write_text(expected_dart)

        downloaded = 0
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=max(1, args.jobs)
        ) as executor:
            futures = [
                executor.submit(download_media, job, refresh=args.refresh)
                for job in jobs
            ]
            for future in concurrent.futures.as_completed(futures):
                _, changed = future.result()
                downloaded += int(changed)

        asset_problems = verify_assets(jobs)
        if asset_problems:
            paths = "\n".join(
                f"{path.relative_to(ROOT)}: {reason}"
                for path, reason in asset_problems
            )
            raise SystemExit(f"invalid local assets after import:\n{paths}")

        print(
            f"downloaded {downloaded} media files; "
            f"verified {len(catalog)} exercises and {len(jobs)} images"
        )

    digest = hashlib.sha256(expected_dart.encode()).hexdigest()[:12]
    print(
        f"catalog OK: {len(catalog)} exercises, {len(jobs)} images, "
        f"generated sha256 {digest}"
    )


if __name__ == "__main__":
    main()
