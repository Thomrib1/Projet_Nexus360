<#
.SYNOPSIS
  Configure la recuperation automatique des services critiques (C1, A7).
  Idempotent : un second passage affiche 0 changement. Supporte -WhatIf.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config\services.json'),
    [string]$ComputerName = $env:COMPUTERNAME
)
$ErrorActionPreference = 'Stop'

function Get-FailureConfig {
    param([string]$Name)
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    $raw = (Get-ItemProperty -Path $key -Name FailureActions -ErrorAction SilentlyContinue).FailureActions
    if (-not $raw) { return $null }
    $count = [BitConverter]::ToUInt32($raw, 12)
    $actions = for ($i = 0; $i -lt $count; $i++) {
        $o = 20 + 8 * $i
        '{0}/{1}' -f [BitConverter]::ToUInt32($raw, $o), [BitConverter]::ToUInt32($raw, $o + 4)
    }
    [pscustomobject]@{ Reset = [BitConverter]::ToUInt32($raw, 0); Actions = @($actions) }
}

$cfg  = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$list = $cfg.servers.$ComputerName
if (-not $list) { Write-Warning "Aucun service defini pour $ComputerName dans $ConfigPath"; return }

$reset      = [string]$cfg.resetSeconds
$wanted     = ($cfg.delaysMs | ForEach-Object { "1/$_" }) -join ','
$actionsArg = ($cfg.delaysMs | ForEach-Object { "restart/$_" }) -join '/'
$todo = 0

foreach ($name in $list) {
    if (-not (Get-Service -Name $name -ErrorAction SilentlyContinue)) {
        Write-Warning "$name absent : ignore"; continue
    }
    $startType = (Get-Service -Name $name).StartType
    if ($startType -notin 'Automatic','AutomaticDelayedStart') {
        $todo++
        if ($PSCmdlet.ShouldProcess($name, 'Demarrage automatique')) {
            Set-Service -Name $name -StartupType Automatic
        }
    }
    $cur = Get-FailureConfig -Name $name
    $ok  = $cur -and ([string]$cur.Reset -eq $reset) -and (($cur.Actions -join ',') -eq $wanted)
    if (-not $ok) {
        $todo++
        if ($PSCmdlet.ShouldProcess($name, "Recuperation $actionsArg")) {
            sc.exe failure $name reset= $reset actions= $actionsArg | Out-Null
        }
    }
}
$mode = if ($WhatIfPreference) { 'prevu(s)' } else { 'applique(s)' }
Write-Host "$ComputerName : $todo changement(s) $mode"
