<#
.SYNOPSIS
    Boite a outils d'investigation PowerShell (D2) : une fonction par type d'evenement.
.DESCRIPTION
    Lit les journaux Security et System, en local ou a distance (-ComputerName).
    Necessite une session administrateur.
#>

function Get-NxEvents {
    param(
        [Parameter(Mandatory)][string]$LogName,
        [Parameter(Mandatory)][int[]]$Id,
        [datetime]$Since = (Get-Date).AddDays(-1),
        [string]$ComputerName
    )
    $p = @{
        FilterHashtable = @{ LogName = $LogName; Id = $Id; StartTime = $Since }
        ErrorAction     = 'SilentlyContinue'
    }
    if ($ComputerName) { $p.ComputerName = $ComputerName }
    Get-WinEvent @p
}

function ConvertTo-NxData {
    param([Parameter(Mandatory)]$Event)
    $xml = [xml]$Event.ToXml()
    $h = @{}
    foreach ($d in $xml.Event.EventData.Data) { $h[$d.Name] = $d.'#text' }
    $h
}

function Resolve-NxSid {
    param([string]$Sid)
    if (-not $Sid -or $Sid -eq '-') { return $null }
    try {
        (New-Object System.Security.Principal.SecurityIdentifier $Sid).Translate([System.Security.Principal.NTAccount]).Value
    } catch { $Sid }
}

$script:NxSubStatus = @{
    '0xc0000064' = 'compte inexistant'
    '0xc000006a' = 'mot de passe incorrect'
    '0xc000006d' = 'echec d''authentification (generique)'
    '0xc000006e' = 'restriction de compte'
    '0xc000006f' = 'connexion hors horaires autorises'
    '0xc0000070' = 'poste non autorise pour ce compte'
    '0xc0000071' = 'mot de passe expire'
    '0xc0000072' = 'compte desactive'
    '0xc0000193' = 'compte expire'
    '0xc0000234' = 'compte verrouille'
}

function Get-NxFailedLogons {
    <# 4625 : echecs d'authentification, avec la raison traduite #>
    param([datetime]$Since = (Get-Date).AddDays(-1), [string]$ComputerName)
    Get-NxEvents -LogName Security -Id 4625 -Since $Since -ComputerName $ComputerName | ForEach-Object {
        $d = ConvertTo-NxData $_
        $key = "$($d.SubStatus)".ToLower()
        $raison = if ($script:NxSubStatus.ContainsKey($key)) { $script:NxSubStatus[$key] } else { 'autre' }
        [pscustomobject]@{
            Heure = $_.TimeCreated; Machine = $_.MachineName
            Compte = $d.TargetUserName; Domaine = $d.TargetDomainName
            Source = $d.IpAddress; TypeOuverture = $d.LogonType
            SousStatut = $d.SubStatus; Raison = $raison
        }
    }
}

function Get-NxLockouts {
    <# 4740 : verrouillages de comptes (visibles sur les controleurs de domaine) #>
    param([datetime]$Since = (Get-Date).AddDays(-1), [string]$ComputerName)
    Get-NxEvents -LogName Security -Id 4740 -Since $Since -ComputerName $ComputerName | ForEach-Object {
        $d = ConvertTo-NxData $_
        [pscustomobject]@{
            Heure = $_.TimeCreated; Machine = $_.MachineName
            Compte = $d.TargetUserName; DepuisMachine = $d.TargetDomainName
        }
    }
}

function Get-NxAccountCreations {
    <# 4720 : creations de comptes #>
    param([datetime]$Since = (Get-Date).AddDays(-7), [string]$ComputerName)
    Get-NxEvents -LogName Security -Id 4720 -Since $Since -ComputerName $ComputerName | ForEach-Object {
        $d = ConvertTo-NxData $_
        [pscustomobject]@{
            Heure = $_.TimeCreated; Machine = $_.MachineName
            NouveauCompte = $d.TargetUserName; CreePar = $d.SubjectUserName
        }
    }
}

function Get-NxGroupAdditions {
    <# 4728 / 4732 / 4756 : ajouts a des groupes #>
    param([datetime]$Since = (Get-Date).AddDays(-7), [string]$ComputerName)
    Get-NxEvents -LogName Security -Id 4728,4732,4756 -Since $Since -ComputerName $ComputerName | ForEach-Object {
        $d = ConvertTo-NxData $_
        $membre = if ($d.MemberName -and $d.MemberName -ne '-') { $d.MemberName } else { Resolve-NxSid $d.MemberSid }
        [pscustomobject]@{
            Heure = $_.TimeCreated; Machine = $_.MachineName; Id = $_.Id
            Membre = $membre; Groupe = $d.TargetUserName; AjoutePar = $d.SubjectUserName
        }
    }
}

function Get-NxInstalledServices {
    <# 7045 : services installes #>
    param([datetime]$Since = (Get-Date).AddDays(-7), [string]$ComputerName)
    Get-NxEvents -LogName System -Id 7045 -Since $Since -ComputerName $ComputerName | ForEach-Object {
        $d = ConvertTo-NxData $_
        [pscustomobject]@{
            Heure = $_.TimeCreated; Machine = $_.MachineName
            Service = $d.ServiceName; Chemin = $d.ImagePath; Compte = $d.AccountName
        }
    }
}

function Get-NxUnexpectedShutdowns {
    <# 6008 / 41 : arrets inattendus #>
    param([datetime]$Since = (Get-Date).AddDays(-30), [string]$ComputerName)
    Get-NxEvents -LogName System -Id 6008,41 -Since $Since -ComputerName $ComputerName |
        Select-Object @{n='Heure';e={$_.TimeCreated}}, @{n='Machine';e={$_.MachineName}}, Id,
            @{n='Message';e={($_.Message -split "`r?`n")[0]}}
}

function Export-NxReport {
    <# Lance toutes les recherches et ecrit un CSV par type dans le dossier choisi #>
    param(
        [string]$OutDir = 'C:\Temp\investigation',
        [datetime]$Since = (Get-Date).AddDays(-7),
        [string]$ComputerName
    )
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    $jobs = [ordered]@{
        'echecs-authentification' = { Get-NxFailedLogons        -Since $Since -ComputerName $ComputerName }
        'verrouillages'           = { Get-NxLockouts            -Since $Since -ComputerName $ComputerName }
        'creations-comptes'       = { Get-NxAccountCreations    -Since $Since -ComputerName $ComputerName }
        'ajouts-groupes'          = { Get-NxGroupAdditions      -Since $Since -ComputerName $ComputerName }
        'services-installes'      = { Get-NxInstalledServices   -Since $Since -ComputerName $ComputerName }
        'arrets-inattendus'       = { Get-NxUnexpectedShutdowns -Since $Since -ComputerName $ComputerName }
    }
    foreach ($name in $jobs.Keys) {
        $rows = @(& $jobs[$name])
        $file = Join-Path $OutDir "$name.csv"
        $rows | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
        '{0,-26} {1,4} evenement(s) -> {2}' -f $name, $rows.Count, $file
    }
}

Export-ModuleMember -Function Get-Nx*, Export-NxReport