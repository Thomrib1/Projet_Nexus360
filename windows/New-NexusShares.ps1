<#
.SYNOPSIS
    Cree les dossiers, partages SMB, droits NTFS et quotas FSRM decrits dans config/shares.json.
.DESCRIPTION
    Idempotent : un second passage ne modifie rien ([OK] partout).
    Supporte -WhatIf pour simuler sans rien changer.
    A executer sur SRV-FS01 (ou a distance depuis SRV-MGT01 avec Invoke-Command).
.EXAMPLE
    .\New-NexusShares.ps1 -WhatIf
    .\New-NexusShares.ps1
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\shares.json')
)

$ErrorActionPreference = 'Stop'
$config  = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$changes = 0

function Get-Account {
    param([string]$Sid)
    (New-Object System.Security.Principal.SecurityIdentifier $Sid).Translate([System.Security.Principal.NTAccount])
}

function Resolve-DomainGroup {
    param([string]$Domain, [string]$Name)
    try {
        $account = New-Object System.Security.Principal.NTAccount($Domain, $Name)
        [void]$account.Translate([System.Security.Principal.SecurityIdentifier])
        return $account
    } catch {
        return $null
    }
}

# Comptes identifies par SID : fonctionne quelle que soit la langue du serveur
$authUsers = (Get-Account 'S-1-5-11').Value   # Utilisateurs authentifies
$system    = Get-Account 'S-1-5-18'           # SYSTEM
$admins    = Get-Account 'S-1-5-32-544'       # Administrateurs

foreach ($s in $config.Shares) {
    $path = Join-Path $config.Root $s.Name
    Write-Host "== $($s.Name) ($path)"

    # 1. Dossier
    if (-not (Test-Path $path)) {
        if ($PSCmdlet.ShouldProcess($path, 'Creer le dossier')) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            $changes++
            Write-Host '  [CHANGED] dossier cree'
        }
    } else {
        Write-Host '  [OK] dossier'
    }
    if (-not (Test-Path $path)) { continue }   # cas -WhatIf : rien a configurer plus loin

    # 2. Partage SMB avec enumeration basee sur l'acces (ABE)
    $share = Get-SmbShare -Name $s.Name -ErrorAction SilentlyContinue
    if (-not $share) {
        if ($PSCmdlet.ShouldProcess($s.Name, 'Creer le partage SMB')) {
            New-SmbShare -Name $s.Name -Path $path -FolderEnumerationMode AccessBased -FullAccess $authUsers | Out-Null
            $changes++
            Write-Host '  [CHANGED] partage cree (ABE)'
        }
    } elseif ($share.FolderEnumerationMode -ne 'AccessBased') {
        if ($PSCmdlet.ShouldProcess($s.Name, 'Activer ABE')) {
            Set-SmbShare -Name $s.Name -FolderEnumerationMode AccessBased -Force
            $changes++
            Write-Host '  [CHANGED] ABE active'
        }
    } else {
        Write-Host '  [OK] partage (ABE)'
    }

    # 3. Droits NTFS (AGDLP : groupes locaux de domaine DL_*)
    $mod = Resolve-DomainGroup $config.NetBIOSDomain $s.Modify
    $rd  = Resolve-DomainGroup $config.NetBIOSDomain $s.Read
    if (-not $mod -or -not $rd) {
        Write-Warning "  Groupes $($s.Modify) / $($s.Read) introuvables : droits NTFS ignores (domaine pas pret ?)"
    } else {
        $flags   = 'ContainerInherit,ObjectInherit'
        $desired = New-Object System.Security.AccessControl.DirectorySecurity
        $desired.SetAccessRuleProtection($true, $false)   # coupe l'heritage, retire les droits herites
        $rules = @(
            @($system, 'FullControl'),
            @($admins, 'FullControl'),
            @($mod,    'Modify'),
            @($rd,     'ReadAndExecute')
        )
        foreach ($r in $rules) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($r[0], $r[1], $flags, 'None', 'Allow')
            $desired.AddAccessRule($rule)
        }
        $current = (Get-Acl -Path $path).GetSecurityDescriptorSddlForm('Access')
        if ($current -ne $desired.GetSecurityDescriptorSddlForm('Access')) {
            if ($PSCmdlet.ShouldProcess($path, 'Appliquer les droits NTFS')) {
                Set-Acl -Path $path -AclObject $desired
                $changes++
                Write-Host '  [CHANGED] droits NTFS appliques'
            }
        } else {
            Write-Host '  [OK] droits NTFS'
        }
    }

    # 4. Quota FSRM
    $size  = [int64]$s.QuotaGB * 1GB
    $quota = Get-FsrmQuota -Path $path -ErrorAction SilentlyContinue
    if (-not $quota) {
        if ($PSCmdlet.ShouldProcess($path, "Creer le quota de $($s.QuotaGB) Go")) {
            New-FsrmQuota -Path $path -Size $size | Out-Null
            $changes++
            Write-Host '  [CHANGED] quota cree'
        }
    } elseif ($quota.Size -ne $size) {
        if ($PSCmdlet.ShouldProcess($path, "Modifier le quota ($($s.QuotaGB) Go)")) {
            Set-FsrmQuota -Path $path -Size $size | Out-Null
            $changes++
            Write-Host '  [CHANGED] quota modifie'
        }
    } else {
        Write-Host '  [OK] quota'
    }
}

Write-Host "Termine : $changes changement(s)."