# PEPK RuStore: one-line encryption key in rustore_pepk.enckey (from RuStore console).
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$jar = Join-Path $root "pepk.jar"
$encFile = Join-Path $root "rustore_pepk.enckey"
$ks = Join-Path $root "..\solitaire-release.jks"
$out = Join-Path $root "pepk_out.zip"

if (-not (Test-Path -LiteralPath $jar)) {
  Write-Host "[ERR] Missing pepk.jar in $root"
  exit 1
}
if (-not (Test-Path -LiteralPath $encFile)) {
  Write-Host "[ERR] Create rustore_pepk.enckey (one line = encryptionkey from RuStore upload-signing dialog)."
  exit 1
}
if (-not (Test-Path -LiteralPath $ks)) {
  Write-Host "[ERR] Keystore not found: $ks"
  exit 1
}

$key = (Get-Content -LiteralPath $encFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($key)) {
  Write-Host "[ERR] rustore_pepk.enckey is empty."
  exit 1
}

Write-Host "PEPK: keystore=$ks alias=solitaire out=$out"
if (-not $env:PEPK_STORE_PASS) {
  Write-Host "Пароли: введите вручную, либо задайте env PEPK_STORE_PASS / PEPK_KEY_PASS (в git не класть)."
  Write-Host ""
}

# Опционально: пароли только из окружения — не хранить в файлах репозитория.
$args = @(
  "-jar", $jar,
  "--keystore=$ks",
  "--alias=solitaire",
  "--output=$out",
  "--encryptionkey=$key",
  "--include-cert"
)
if ($env:PEPK_STORE_PASS) { $args += "--keystore-pass=$($env:PEPK_STORE_PASS)" }
if ($env:PEPK_KEY_PASS) { $args += "--key-pass=$($env:PEPK_KEY_PASS)" }

& java @args
exit $LASTEXITCODE
