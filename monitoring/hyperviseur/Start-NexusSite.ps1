#Requires -Version 5.1
<#
.SYNOPSIS
    Démarre (ou arrête) dans l'ordre les VM VMware Workstation d'un site Nexus360 (exigence C4).

.DESCRIPTION
    Un PC = une personne = un rôle = un site. Chaque membre lance ce script sur SON PC avec son numéro
    de site ; les VM et délais viennent de hyperviseur/sites.json (le DAT fait foi).
    Ordre global, garanti par les délais : passerelle (0 s) -> DC (60 s) -> serveurs membres / Linux
    (240-270 s) -> postes (300 s). MON01 démarre tôt sur le site 4 pour recevoir les journaux de démarrage.
    -Arret arrête proprement les VM dans l'ordre inverse (vmrun stop soft = arrêt du système invité,
    nécessite les VMware Tools / open-vm-tools dans la VM).

.NOTES
    Propriétaire : rôle 4 (ordre de redémarrage C4) — Exécuté par : chaque membre sur son PC (hôte Windows)
    Dépend de    : chaque membre (chemins .vmx de son PC dans sites.json), rôle 5 (passerelles), rôle 3
                   (open-vm-tools dans les VM Linux via le rôle base), rôles 1/2 (VMware Tools sur les Windows)
    Démarrage SANS intervention : -InstallerTache crée une tâche planifiée à l'ouverture de session
    (les VM Workstation appartiennent à l'utilisateur : vmrun doit tourner dans SA session). Avec VMware
    Workstation Pro 17+, la fonction « Auto Start » (clic droit sur « My Computer » dans la bibliothèque)
    démarre aussi les VM à l'allumage du PC ; reporter alors le même ordre.

.EXAMPLE
    .\Start-NexusSite.ps1 -Site 4                 # PC du rôle 4 : LNX-GW04 puis LNX-MON01
    .\Start-NexusSite.ps1 -Site 2 -WhatIf          # voir l'ordre sans rien démarrer
    .\Start-NexusSite.ps1 -Site 3 -Arret           # arrêt propre en ordre inverse
    .\Start-NexusSite.ps1 -Site 4 -InstallerTache  # démarrage automatique à l'allumage du PC
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][ValidateRange(1, 5)][int]$Site,
    [switch]$Arret,
    [switch]$InstallerTache,
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'sites.json')
)

$ErrorActionPreference = 'Stop'
$cfg   = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
$site  = $cfg.sites."$Site"
$vmrun = $cfg.vmrun
if (-not (Test-Path $vmrun)) { throw "vmrun introuvable : $vmrun (VMware Workstation Pro installé ?)" }

if ($InstallerTache) {
    if ($PSCmdlet.ShouldProcess("Tâche planifiée Nexus360-Site$Site", 'Créer (au démarrage du PC)')) {
        $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
                     -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Site $Site"
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        Register-ScheduledTask -TaskName "Nexus360-Site$Site" -Action $action -Trigger $trigger `
            -Description "Démarre les VM du site $Site dans l'ordre (C4)" -Force | Out-Null
        Write-Output "Tâche 'Nexus360-Site$Site' créée (s'exécute à l'ouverture de session de $env:USERNAME)."
    }
    return
}

$enCours = & $vmrun -T ws list

if ($Arret) {
    $liste = @($site.vms); [array]::Reverse($liste)
    foreach ($vm in $liste) {
        if ($enCours -notcontains $vm.vmx) { Write-Verbose "$($vm.nom) déjà arrêtée"; continue }
        if ($PSCmdlet.ShouldProcess($vm.nom, 'Arrêt propre')) {
            & $vmrun -T ws stop $vm.vmx soft
            Write-Output "$(Get-Date -Format T) $($vm.nom) arrêtée"
        }
    }
    return
}

Write-Output "=== Site $Site — $($site.pc) — $($site.reseau) ==="
$debut = Get-Date
foreach ($vm in $site.vms) {
    if ($enCours -contains $vm.vmx) { Write-Output "$($vm.nom) déjà démarrée"; continue }
    $attente = $vm.delai - ((Get-Date) - $debut).TotalSeconds
    if ($attente -gt 0 -and -not $WhatIfPreference) {
        Write-Output "Attente $([int]$attente) s avant $($vm.nom)…"
        Start-Sleep -Seconds ([int]$attente)
    }
    if ($PSCmdlet.ShouldProcess($vm.nom, "Démarrer (délai prévu $($vm.delai) s)")) {
        & $vmrun -T ws start $vm.vmx nogui
        if ($LASTEXITCODE -ne 0) { Write-Warning "Échec du démarrage de $($vm.nom)" }
        else { Write-Output "$(Get-Date -Format T) $($vm.nom) démarrée" }
    }
}
Write-Output "Site $Site démarré. Contrôle global depuis LNX-OPS01 : bash scripts/check-infra.sh"
