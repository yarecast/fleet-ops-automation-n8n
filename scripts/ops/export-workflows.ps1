$ErrorActionPreference = 'Stop'
docker compose exec -T n8n sh -c 'rm -rf /tmp/wf-export && mkdir -p /tmp/wf-export'
docker compose exec -T n8n n8n export:workflow --all --separate --pretty --output=/tmp/wf-export/
if (-not (Test-Path workflows)) { New-Item -ItemType Directory workflows | Out-Null }
docker compose cp n8n:/tmp/wf-export/. workflows
docker compose exec -T n8n sh -c 'rm -rf /tmp/wf-export'

$files = Get-ChildItem workflows -Filter *.json
$hits = 0
foreach ($line in Get-Content .env) {
  if ($line -match '^([A-Z0-9_]*(PASSWORD|SECRET|TOKEN|KEY)[A-Z0-9_]*|TELEGRAM_CHAT_ID)=(.+)$') {
    $k = $Matches[1]; $v = $Matches[3].Trim()
    if ($v.Length -lt 6) { continue }
    foreach ($f in $files) {
      if ([System.IO.File]::ReadAllText($f.FullName).Contains($v)) { Write-Host ("SECRETO de .env en " + $f.Name + ": " + $k); $hits++ }
    }
  }
}
foreach ($f in $files) {
  if ([System.IO.File]::ReadAllText($f.FullName) -match '\d{8,10}:[A-Za-z0-9_-]{35}') { Write-Host ("Posible token de bot en " + $f.Name); $hits++ }
}
if ($hits -eq 0) { Write-Host ("OK: " + $files.Count + " workflows exportados, sin secretos de .env") } else { Write-Host ("REVISAR: " + $hits + " coincidencias, no commitear") }
git status --short workflows