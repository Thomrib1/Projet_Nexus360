#Requires -Version 5.1
<#
.SYNOPSIS
    Installe et configure windows_exporter sur les serveurs Windows de Nexus360 (exigence C2).

.DESCRIPTION
    Script idempotent piloté par windows/config/supervision.json, lancé depuis SRV-MGT01
    (ou par le pipeline). Pour chaque serveur :
      1. installe la bonne version du MSI si elle est absente ou différente ;
      2. limite le collecteur "service" aux services critiques listés (alerte WindowsServiceCritiqueArrete) ;
      3. ouvre le port 9182 UNIQUEMENT pour LNX-MON01 ;
      4. configure les actions de récupération du service (exigence C1).
    Un second passage ne modifie rien. -WhatIf affiche ce qui serait fait sans rien changer.

.NOTES
    Écrit par   : rôle 4 (Exploitation) — Exécuté depuis : SRV-MGT01 (VM du PC du rôle 2), avec le rôle 2,
                  ou par le pipeline via Invoke-Deploy.ps1
    Cibles      : SRV-DC01 (PC rôle 1), SRV-DC02, SRV-FS01, SRV-MGT01 (PC rôle 2)
    Dépend de   : rôle 1 (compte nominatif T1 admin des serveurs membres ; MSI copié dans NETLOGON pour les DC),
                  rôle 2 (WinRM, partage Deploiement$ avec le MSI), rôle 5 (tailnet : MON01 site 4 -> 9182 des sites 1 et 2)
    Tiering (B3): les serveurs marqués "niveau": "T0" (les DC) sont IGNORÉS par défaut : un compte T1 ou le
                  compte svc-deploy du pipeline ne doit jamais administrer un DC. Le rôle 1 lance le script
                  LUI-MÊME, ouvert en session sur chaque DC avec son compte T0 :
                      .\Install-WindowsExporter.ps1 -Serveur SRV-DC01

.EXAMPLE
    .\Install-WindowsExporter.ps1 -WhatIf
    .\Install-WindowsExporter.ps1 -Verbose
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\supervision.json'),
    # Limiter à certains serveurs (obligatoire pour viser un serveur T0)
    [string[]]$Serveur
)

$ErrorActionPreference = 'Stop'
$cfg = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

if ($Serveur) {
    $cibles = $cfg.serveurs | Where-Object { $_.nom -in $Serveur }
} else {
    $cibles = $cfg.serveurs | Where-Object { $_.niveau -ne 'T0' }
    $cfg.serveurs | Where-Object { $_.niveau -eq 'T0' } | ForEach-Object {
        Write-Warning "$($_.nom) (T0) ignoré : à lancer par le rôle 1 sur le DC avec -Serveur $($_.nom)"
    }
}

foreach ($srv in $cibles) {
    $nom = $srv.nom
    $sourceMsi = if ($srv.niveau -eq 'T0') { $cfg.source_msi_t0 } else { $cfg.source_msi }
    Write-Verbose "=== $nom ==="
    $session = New-PSSession -ComputerName $nom
    try {
        # --- État actuel
        $etat = Invoke-Command -Session $session -ScriptBlock {
            $svc  = Get-CimInstance Win32_Service -Filter "Name='windows_exporter'" -ErrorAction SilentlyContinue
            $prod = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
                    Where-Object DisplayName -like 'windows_exporter*' | Select-Object -First 1
            $fw   = Get-NetFirewallRule -Name 'Nexus360-windows_exporter' -ErrorAction SilentlyContinue
            [pscustomobject]@{
                Installe    = [bool]$svc
                Version     = if ($prod) { $prod.DisplayVersion } else { $null }
                CommandLine = if ($svc) { $svc.PathName } else { '' }
                PareFeu     = [bool]$fw
            }
        }

        # (?i) : insensible à la casse (windows_exporter publie les noms en minuscules, ex. name="dhcpserver")
        $includeRegex = '(?i)^(' + (($srv.services | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')$'
        $extraFlags   = "--collector.service.include=`"$includeRegex`""
        $versionOk    = $etat.Version -and $etat.Version.StartsWith($cfg.version)
        $flagsOk      = $etat.CommandLine -like "*$includeRegex*"

        # --- 1 & 2. Installation / reconfiguration
        if (-not ($etat.Installe -and $versionOk -and $flagsOk)) {
            if ($PSCmdlet.ShouldProcess($nom, "Installer windows_exporter $($cfg.version) (services : $($srv.services -join ', '))")) {
                $msiLocal = 'C:\Windows\Temp\windows_exporter.msi'
                Copy-Item -Path $sourceMsi -Destination $msiLocal -ToSession $session -Force
                Invoke-Command -Session $session -ArgumentList $msiLocal, $cfg.collecteurs, $cfg.port, $extraFlags -ScriptBlock {
                    param($msi, $collecteurs, $port, $flags)
                    $arguments = @('/i', $msi, '/qn', '/norestart',
                                   "ENABLED_COLLECTORS=$collecteurs", "LISTEN_PORT=$port", "EXTRA_FLAGS=$flags")
                    $p = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
                    if ($p.ExitCode -notin 0, 3010) { throw "msiexec a échoué (code $($p.ExitCode))" }
                    Remove-Item $msi -Force
                }
                Write-Output "[$nom] windows_exporter installé/reconfiguré"
            }
        } else {
            Write-Verbose "[$nom] windows_exporter $($etat.Version) déjà conforme"
        }

        # --- 3. Pare-feu : 9182 ouvert à LNX-MON01 seulement
        if (-not $etat.PareFeu) {
            if ($PSCmdlet.ShouldProcess($nom, "Autoriser TCP $($cfg.port) depuis $($cfg.serveur_supervision)")) {
                Invoke-Command -Session $session -ArgumentList $cfg.port, $cfg.serveur_supervision -ScriptBlock {
                    param($port, $source)
                    New-NetFirewallRule -Name 'Nexus360-windows_exporter' -DisplayName 'Nexus360 - windows_exporter (LNX-MON01)' `
                        -Direction Inbound -Protocol TCP -LocalPort $port -RemoteAddress $source -Action Allow -Profile Domain | Out-Null
                }
                Write-Output "[$nom] règle de pare-feu créée"
            }
        }

        # --- 4. Actions de récupération (C1) : redémarrer après 1 min, 3 fois, compteur remis à zéro chaque jour
        $recup = Invoke-Command -Session $session -ScriptBlock { (sc.exe qfailure windows_exporter) -join "`n" }
        if ($recup -notmatch 'RESTART') {
            if ($PSCmdlet.ShouldProcess($nom, 'Configurer les actions de récupération de windows_exporter')) {
                Invoke-Command -Session $session -ScriptBlock {
                    sc.exe failure windows_exporter reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
                }
                Write-Output "[$nom] actions de récupération configurées"
            }
        }
    }
    finally {
        Remove-PSSession $session
    }
}
