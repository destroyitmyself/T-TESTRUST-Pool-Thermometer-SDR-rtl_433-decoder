<#
.SYNOPSIS
  Listener for the TESTRUST pool thermometer. Screen only.

.DESCRIPTION
  With no args: discovery mode, prints every valid sensor.
  With -SensorId: targeted mode, only prints the given ID(s).

.EXAMPLE
  .\pool-listen.ps1
  .\pool-listen.ps1 -SensorId 95c0
  .\pool-listen.ps1 -SensorId '95c0,abcd'
#>

[CmdletBinding()]
param(
    [string]$SensorId  = '',
    [long]  $Frequency = 434108000,
    [string]$RtlPath   = 'C:\rtl_433'
)

$ScriptVersion = 'v1.0 (2026-04-20, from confirmed-working one-liner)'

# Don't turn rtl_433's stderr banner into a fatal PS error.
$ErrorActionPreference = 'Continue'
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$exe = Join-Path $RtlPath 'rtl_433.exe'
if (-not (Test-Path $exe)) {
    Write-Host "ERROR: rtl_433.exe not found at $exe" -ForegroundColor Red
    exit 1
}

# Build ID filter: empty = accept any non-zero; otherwise only listed IDs.
$idList = @($SensorId -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
$mode = if ($idList.Count -eq 0) { 'discovery (any sensor ID)' } else { "id=$($idList -join ',')" }

$freqMHz = [math]::Round($Frequency / 1e6, 3)
Write-Host "pool-listen.ps1 $ScriptVersion"
Write-Host "Listening on $freqMHz MHz - $mode. Ctrl+C to stop."
Write-Host ''

& $exe -f $Frequency -s 1024000 -R 0 `
    -X 'n=pool,m=OOK_PPM,s=1956,l=3908,g=3928,r=8796,bits>=40' `
    -F json -M time 2>&1 | ForEach-Object {

    $line = [string]$_

    # Non-"codes" lines are rtl_433's own status/banner output.
    # Show them in gray so you can see what's going on if things misbehave.
    if ($line -notmatch '"codes"') {
        if ($line.Trim()) { Write-Host $line -ForegroundColor DarkGray }
        return
    }

    try {
        $r = $line | ConvertFrom-Json

        # Pick the first 45-bit row from the repeats.
        $row = $r.rows | Where-Object { $_.len -eq 45 } | Select-Object -First 1
        if (-not $row) { return }

        $hex = $row.data
        if ($hex.Length -lt 12) { return }

        # Bits 0-15 = sensor ID.
        $id = $hex.Substring(0, 4).ToLower()

        # ID filter.
        if ($idList.Count -eq 0) {
            if ($id -eq '0000') { return }
        } else {
            if ($idList -notcontains $id) { return }
        }

        # Bits 19-27 = 9-bit temperature x 10 (manual spec goes to 122 F / 50 C).
        $b2 = [Convert]::ToInt32($hex.Substring(4, 2), 16)
        $b3 = [Convert]::ToInt32($hex.Substring(6, 2), 16)
        $raw = (($b2 -band 0x1F) -shl 4) -bor (($b3 -shr 4) -band 0x0F)

        # Sanity-check temperature range.
        if ($raw -lt 10 -or $raw -gt 500) { return }

        $c = $raw / 10.0
        $f = [math]::Round($c * 9 / 5 + 32, 1)

        $out = '{0}  id={1}  raw={2,3}  {3,5:N1} C / {4,5:N1} F' -f `
            $r.time, $id, $raw, $c, $f

        Write-Host $out -ForegroundColor Green
    }
    catch {
        Write-Host "parse error: $line" -ForegroundColor Red
    }
}
