#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
GO="$HOME/development/go/bin/go"

echo "[1/6] Exercise catalog and local media"
"$ROOT/scripts/import_exercise_library.py" --check

echo "[2/6] Go API tests"
(cd "$ROOT/services/api" && "$GO" test ./...)

echo "[3/6] Go API build"
(cd "$ROOT/services/api" && "$GO" build -o bin/api ./cmd/api)

echo "[4/6] Flutter static analysis"
(cd "$ROOT/mobile" && ./tool/flutterw analyze)

echo "[5/6] Flutter unit, widget and golden tests"
(cd "$ROOT/mobile" && ./tool/flutterw test)

echo "[6/6] API contract smoke test"
PORT=18080
DB="$ROOT/services/api/data/self-test.db"
rm -f "$DB"
HTTP_ADDR="127.0.0.1:$PORT" DATABASE_PATH="$DB" "$ROOT/services/api/bin/api" >/tmp/suilian-api-self-test.log 2>&1 &
PID=$!
trap 'kill "$PID" >/dev/null 2>&1 || true' EXIT
for _ in {1..30}; do
  curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break
  sleep 0.1
done
INSTALL=$(curl -sf -X POST "http://127.0.0.1:$PORT/v1/installations" -H 'Content-Type: application/json' --data @"$ROOT/contracts/examples/create-installation-request.json")
TOKEN=$(printf '%s' "$INSTALL" | sed -E 's/.*"access_token":"([^"]+)".*/\1/')
curl -sf -X POST "http://127.0.0.1:$PORT/v1/coach/plans" -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" --data @"$ROOT/contracts/examples/checkin-plan-request.json" | grep -q 'workout_plan'
curl -sf -X POST "http://127.0.0.1:$PORT/v1/coach/adjustments" -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" --data @"$ROOT/contracts/examples/adjustment-request.json" | grep -q 'estimated_minutes'
curl -sf -X POST "http://127.0.0.1:$PORT/v1/coach/summaries" -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" --data @"$ROOT/contracts/examples/summary-request.json" | grep -q 'factual_message'

echo "All Suilian AI demo checks passed."
