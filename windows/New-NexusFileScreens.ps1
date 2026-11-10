<#
.SYNOPSIS
    Bloque les executables sur les partages (FSRM file screening), pilote par config/filescreen.json.
.DESCRIPTION
    Idempotent. Supporte -WhatIf. Les dossiers viennent de config/shares.json.
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath      = (Join-Path $PSScriptRoot 'config\filescreen.json'),
    [string]$ShareConfigPath = (Join-Path $PSScriptRoot 'config\shares.json')
)

$ErrorActionPreference = 'Stop'
$cfg     = Get-Content -Path $ConfigPath      -Raw | ConvertFrom-Json
$shares  = Get-Content -Path $ShareConfigPath -Raw | ConvertFrom-Json
$changes = 0

# 1. Groupe de fichiers (liste des extensions bloquees)
$fg = Get-FsrmFileGroup -Name $cfg.FileGroupName -ErrorAction SilentlyContinue
if (-not $fg) {
    if ($PSCmdlet.ShouldProcess($cfg.FileGroupName, 'Creer le groupe de fichiers')) {
        New-FsrmFileGroup -Name $cfg.FileGroupName -IncludePattern $cfg.Patterns | Out-Null
        $changes++
        Write-Host '[CHANGED] groupe de fichiers cree'
    }
} elseif (Compare-Object $fg.IncludePattern $cfg.Patterns) {
    if ($PSCmdlet.ShouldProcess($cfg.FileGroupName, 'Mettre a jour les extensions')) {
        Set-FsrmFileGroup -Name $cfg.FileGroupName -IncludePattern $cfg.Patterns | Out-Null
        $changes++
        Write-Host '[CHANGED] groupe de fichiers mis a jour'
    }
} else {
    Write-Host '[OK] groupe de fichiers'
}

# 2. Modele de filtrage actif (blocage reel)
$tpl = Get-FsrmFileScreenTemplate -Name $cfg.TemplateName -ErrorAction SilentlyContinue
if (-not $tpl) {
    if ($PSCmdlet.ShouldProcess($cfg.TemplateName, 'Creer le modele de filtrage')) {
        New-FsrmFileScreenTemplate -Name $cfg.TemplateName -Active -IncludeGroup @($cfg.FileGroupName) | Out-Null
        $changes++
        Write-Host '[CHANGED] modele cree'
    }
} elseif (-not ($tpl.Active -and ($tpl.IncludeGroup -contains $cfg.FileGroupName))) {
    if ($PSCmdlet.ShouldProcess($cfg.TemplateName, 'Corriger le modele')) {
        Set-FsrmFileScreenTemplate -Name $cfg.TemplateName -Active -IncludeGroup @($cfg.FileGroupName) | Out-Null
        $changes++
        Write-Host '[CHANGED] modele corrige'
    }
} else {
    Write-Host '[OK] modele'
}

# 3. Application sur chaque partage
foreach ($s in $shares.Shares) {
    $path = Join-Path $shares.Root $s.Name
    if (-not (Test-Path $path)) { Write-Warning "$path absent : lancer New-NexusShares.ps1 d'abord"; continue }
    $fs = Get-FsrmFileScreen -Path $path -ErrorAction SilentlyContinue
    if (-not $fs) {
        if ($PSCmdlet.ShouldProcess($path, 'Appliquer le filtrage')) {
            New-FsrmFileScreen -Path $path -Template $cfg.TemplateName | Out-Null
            $changes++
            Write-Host "[CHANGED] $($s.Name) : filtrage applique"
        }
    } elseif ($fs.Template -ne $cfg.TemplateName) {
        if ($PSCmdlet.ShouldProcess($path, 'Corriger le modele du filtrage')) {
            Set-FsrmFileScreen -Path $path -Template $cfg.TemplateName | Out-Null
            $changes++
            Write-Host "[CHANGED] $($s.Name) : modele corrige"
        }
    } else {
        Write-Host "[OK] $($s.Name) : filtrage"
    }
}
Write-Host "Termine : $changes changement(s)."
