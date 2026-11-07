#!/bin/bash
# Утилита разработки: дождаться CI для коммита, скачать лог job «godot», вывести итог и декодировать превью.
# usage: tools/ci_wait.sh <sha> <outdir>
# Вывод (коротко, для чтения агентом): run: <status> <conclusion> <id>, число тестов, упавшие проверки,
# ошибки скриптов/шейдеров, сохранённые превью <outdir>/<ракурс>.jpg. Полный лог — <outdir>/job.log.
set -u
SHA=$1
OUT=$2
REPO=${CI_REPO:-CoolS2/virtualgodisland}
API="https://api.github.com/repos/$REPO"
mkdir -p "$OUT"
status="none"
for _ in $(seq 1 360); do
  status=$(curl -sS "$API/actions/runs?head_sha=$SHA" | python3 -c "
import json, sys
runs = json.load(sys.stdin).get('workflow_runs', [])
print(f\"{runs[0]['status']} {runs[0]['conclusion']} {runs[0]['id']}\" if runs else 'none')" 2>/dev/null || echo none)
  case "$status" in completed*) break ;; esac
  sleep 10
done
echo "run: $status"
case "$status" in completed*) ;; *) echo "CI не завершился за отведённое время"; exit 1 ;; esac
run_id=$(echo "$status" | awk '{print $3}')
job_id=$(curl -sS "$API/actions/runs/$run_id/jobs" | python3 -c "
import json, sys
print([j['id'] for j in json.load(sys.stdin)['jobs'] if j['name'] == 'godot'][0])")
curl -sSL -o "$OUT/job.log" "$API/actions/jobs/$job_id/logs"
grep -E "Passing Tests|Failing Tests|\[Failed\]|SCRIPT ERROR|SHADER ERROR|Parse Error|at: test_|##\[error\]" "$OUT/job.log" \
  | sed -E 's/^[0-9TZ:.-]+ //' | cut -c1-400 | sort -u | head -40
grep -oE 'PREVIEW_JPEG_BASE64\[[a-z_]+\]:.*' "$OUT/job.log" | while IFS= read -r line; do
  name=$(echo "$line" | sed -E 's/PREVIEW_JPEG_BASE64\[([a-z_]+)\].*/\1/')
  echo "$line" | cut -d: -f2 | tr -d '\r\n ' | base64 -d > "$OUT/$name.jpg" && echo "превью: $OUT/$name.jpg"
done
