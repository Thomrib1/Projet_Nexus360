#Requires -Version 5.1
<#
.SYNOPSIS
    Point d'entrée unique du déploiement Windows, appelé par le pipeline via SSH sur SRV-MGT01.

.DESCRIPTION
    1. Aligne la copie locale du dépôt (C:\Nexus360) sur le commit demandé par le pipeline.
    2. Exécute dans l'ordre les scripts listés dans windows/config/deploiement.json
       (scripts idempotents des rôles 1, 2 et 4 : OU, groupes, utilisateurs, partages, quotas, supervision…).
    3. Avec -WhatIf (pull request), chaque script n'affiche que ce qu'il FERAIT.
    Un journal horodaté est écrit dans C:\Nexus360-logs (trace de chaque changement, exigence 3).

.NOTES
    Écrit par   : rôle 4 (pipeline) — Machine : SRV-MGT01 (VM du PC du rôle 2)
    Dépend de   : rôle 2 (OpenSSH Server sur MGT01, clone C:\Nexus360 avec une clé de déploiement GitHub en
                  lecture seule, scripts Set-NexusShares.ps1…), rôle 1 (compte svc-deploy et ses délégations,
                  scripts Set-NexusOU.ps1 / Import-NexusUsers.ps1), rôle 4 (clé SSH du runner autorisée)

.EXAMPLE
    powershell -NoProfile -File C:\Nexus360\windows\scripts\Invoke-Deploy.ps1 -Commit 3f2a9c1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{7,40}$')][string]$Commit,
    [string]$RepoPath = 'C:\Nexus360'
)

$ErrorActionPreference = 'Stop'
$logDir = 'C:\Nexus360-logs'
New-Item -ItemType Directory -Path $logDir -Force -WhatIf:$false | Out-Null
$mode = if ($WhatIfPreference) { 'whatif' } else { 'reel' }
Start-Transcript -Path (Join-Path $logDir ("deploy-{0:yyyyMMdd-HHmmss}-{1}-{2}.log" -f (Get-Date), $Commit.Substring(0, 7), $mode)) | Out-Null

try {
    # --- 1. Copie locale du dépôt au bon commit (lecture seule : on ne pousse jamais depuis MGT01)
    git -C $RepoPath fetch --quiet origin
    if ($LASTEXITCODE -ne 0) { throw 'git fetch a échoué' }
    git -C $RepoPath checkout --quiet --force $Commit
    if ($LASTEXITCODE -ne 0) { throw "commit $Commit introuvable" }
    Write-Output "Dépôt aligné sur $(git -C $RepoPath log -1 --format='%h %s')"

    # --- 2. Scripts à exécuter, dans l'ordre
    $plan = Get-Content -Raw (Join-Path $RepoPath 'windows\config\deploiement.json') | ConvertFrom-Json
    foreach ($etape in $plan.etapes) {
        $script = Join-Path $RepoPath $etape.script
        Write-Output "--- $($etape.nom) ($($etape.script))"
        & $script -WhatIf:$WhatIfPreference -Verbose:($VerbosePreference -eq 'Continue')
    }
    Write-Output "Déploiement Windows terminé ($mode)."
}
finally {
    Stop-Transcript | Out-Null
}
