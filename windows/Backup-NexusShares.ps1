[CmdletBinding(SupportsShouldProcess)]
param([string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\backup.json'))
$ErrorActionPreference = 'Stop'
$c = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$target = Join-Path $c.Destination (Get-Date -Format 'yyyyMMdd-HHmmss')

if ($PSCmdlet.ShouldProcess($target, "Copier $($c.Source)")) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    robocopy $c.Source $target /E /COPY:DATSO /R:2 /W:5 /NFL /NDL /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy a echoue (code $LASTEXITCODE)" }
    Write-Host "[CHANGED] sauvegarde creee : $target"
}
if (Test-Path $c.Destination) {
    Get-ChildItem $c.Destination -Directory |
      Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$c.RetentionDays) } |
      ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.FullName, 'Supprimer (retention)')) {
            Remove-Item $_.FullName -Recurse -Force
            Write-Host "[CHANGED] supprime : $($_.Name)"
        }
      }
}