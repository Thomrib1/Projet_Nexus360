<#
.SYNOPSIS
    Exporte l'etat reel de l'annuaire en fichiers texte : preuves du role Identite (A1, A2, B1, B3, B5, C1).
.DESCRIPTION
    Lecture seule : ce script ne modifie rien sur le controleur de domaine.
    Il n'exporte aucun mot de passe (pas de Get-LapsADPassword, pas de fichier de secrets).
    A lancer sur SRV-DC01, dans une console PowerShell ouverte en administrateur, avec un compte T0.
    Chaque fichier commence par le nom de la machine et la date : c'est ce qui en fait une preuve.
.EXAMPLE
    .\Export-N360Preuves.ps1
    .\Export-N360Preuves.ps1 -Dossier C:\N360\exports-preuves
.NOTES
    Copier ensuite le contenu du dossier dans docs/identite/exports/ du depot.
    RELIRE les fichiers avant tout commit : aucun mot de passe ne doit y figurer.
#>
[CmdletBinding()]
param(
    [string]$Dossier = (Join-Path 'C:\N360\exports-preuves' (Get-Date -Format 'yyyy-MM-dd')),
    [string]$RacineOU = 'OU=NEXUS360'
)

$ErrorActionPreference = 'Continue'
Import-Module ActiveDirectory -ErrorAction Stop

New-Item -ItemType Directory -Path $Dossier -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Dossier 'gpo') -Force | Out-Null

$dom    = Get-ADDomain
$domDN  = $dom.DistinguishedName
$domFqdn = $dom.DNSRoot
$sid    = $dom.DomainSID.Value
$racine = "$RacineOU,$domDN"

function Save-Preuve {
    param([string]$Nom, [scriptblock]$Commande)
    $fichier = Join-Path $Dossier "$Nom.txt"
    $entete  = "# Preuve  : $Nom`r`n# Machine : $env:COMPUTERNAME`r`n# Domaine : $domFqdn`r`n# Date    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n# Compte  : $env:USERDOMAIN\$env:USERNAME`r`n`r`n"
    try {
        $sortie = & $Commande 2>&1 | Out-String -Width 250
    } catch {
        $sortie = "ERREUR : $($_.Exception.Message)"
    }
    Set-Content -Path $fichier -Value ($entete + $sortie) -Encoding UTF8
    Write-Host "[OK] $Nom.txt"
}

function Write-Titre { param([string]$Texte) "`r`n===== $Texte =====" }

# ---------------------------------------------------------------- A1 : domaine, DC, sites
Save-Preuve 'A1-domaine' {
    Write-Titre 'Get-ADDomain'
    Get-ADDomain | Format-List DNSRoot, NetBIOSName, DistinguishedName, DomainMode, PDCEmulator, RIDMaster, InfrastructureMaster, ComputersContainer, UsersContainer
    Write-Titre 'Get-ADForest'
    Get-ADForest | Format-List Name, ForestMode, SchemaMaster, DomainNamingMaster, Sites
}

Save-Preuve 'A1-dc' {
    Write-Titre 'Get-ADDomainController -Filter *'
    Get-ADDomainController -Filter * | Format-Table Name, Site, IPv4Address, IsGlobalCatalog, OperatingSystem -AutoSize
}

Save-Preuve 'A1-sites' {
    Write-Titre 'Sites'
    Get-ADReplicationSite -Filter * | Format-Table Name, Description -AutoSize
    Write-Titre 'Sous-reseaux'
    Get-ADReplicationSubnet -Filter * | Format-Table Name, Site -AutoSize
    Write-Titre 'Liens de sites'
    Get-ADReplicationSiteLink -Filter * | Format-Table Name, Cost, ReplicationFrequencyInMinutes, SitesIncluded -AutoSize
}

Save-Preuve 'A1-replication' {
    Write-Titre 'repadmin /replsummary'
    repadmin /replsummary
    Write-Titre 'repadmin /showrepl'
    repadmin /showrepl
}

Save-Preuve 'A1-dcdiag' {
    Write-Titre 'dcdiag /skip:systemlog /skip:dfsrevent'
    dcdiag /skip:systemlog /skip:dfsrevent
}

# ---------------------------------------------------------------- A1 : DNS
Save-Preuve 'A1-dns-zones' {
    Write-Titre 'Zones'
    Get-DnsServerZone | Format-Table ZoneName, ZoneType, IsDsIntegrated, IsReverseLookupZone, DynamicUpdate -AutoSize
    Write-Titre 'Redirecteurs'
    Get-DnsServerForwarder | Format-List IPAddress, UseRootHint
    Write-Titre 'Interfaces d ecoute'
    (Get-DnsServerSetting -All).ListeningIPAddress
    Write-Titre 'Vieillissement'
    Get-DnsServerScavenging | Format-List
}

Save-Preuve 'A1-dns-enregistrements' {
    foreach ($zone in (Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated -and $_.ZoneName -ne 'TrustAnchors' })) {
        Write-Titre "Zone $($zone.ZoneName)"
        Get-DnsServerResourceRecord -ZoneName $zone.ZoneName |
            Where-Object { $_.RecordType -in 'A', 'CNAME', 'PTR' } |
            Select-Object HostName, RecordType,
                @{ n = 'Donnee'; e = { if ($_.RecordData.IPv4Address) { $_.RecordData.IPv4Address.ToString() } elseif ($_.RecordData.HostNameAlias) { $_.RecordData.HostNameAlias } else { $_.RecordData.PtrDomainName } } },
                @{ n = 'Statique'; e = { -not $_.TimeStamp } } |
            Sort-Object RecordType, HostName | Format-Table -AutoSize
    }
}

Save-Preuve 'A1-dns-dc01' {
    Write-Titre "Resolve-DnsName $env:COMPUTERNAME.$domFqdn (attendu : la seule adresse 10.36.x du DC)"
    Resolve-DnsName "$env:COMPUTERNAME.$domFqdn" -Type A | Format-Table Name, Type, IPAddress -AutoSize
    Write-Titre "Resolve-DnsName intranet.$domFqdn"
    Resolve-DnsName "intranet.$domFqdn" | Format-Table Name, Type, NameHost, IPAddress -AutoSize
    Write-Titre 'Enregistrement DNS par carte reseau'
    Get-DnsClient | Format-Table InterfaceAlias, RegisterThisConnectionsAddress -AutoSize
    Write-Titre 'Adresses IPv4 des cartes'
    Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias, IPAddress, PrefixLength -AutoSize
    Write-Titre 'Serveurs DNS des cartes'
    Get-DnsClientServerAddress -AddressFamily IPv4 | Format-Table InterfaceAlias, ServerAddresses -AutoSize
}

# ---------------------------------------------------------------- A1 : heure
Save-Preuve 'A1-heure' {
    Write-Titre 'w32tm /query /source'
    w32tm /query /source
    Write-Titre 'w32tm /query /status'
    w32tm /query /status
    Write-Titre 'w32tm /query /peers'
    w32tm /query /peers
}

# ---------------------------------------------------------------- A1 : DHCP
Save-Preuve 'A1-dhcp' {
    Write-Titre 'Serveurs DHCP autorises dans AD'
    Get-DhcpServerInDC | Format-Table -AutoSize
    Write-Titre 'Etendues'
    $etendues = Get-DhcpServerv4Scope
    $etendues | Format-Table ScopeId, Name, StartRange, EndRange, LeaseDuration, State -AutoSize
    foreach ($e in $etendues) {
        Write-Titre "Options de l etendue $($e.ScopeId)"
        Get-DhcpServerv4OptionValue -ScopeId $e.ScopeId | Format-Table OptionId, Name, Value -AutoSize
        Write-Titre "Reservations de l etendue $($e.ScopeId)"
        Get-DhcpServerv4Reservation -ScopeId $e.ScopeId | Format-Table IPAddress, ClientId, Name, Type -AutoSize
    }
    Write-Titre 'Options de niveau serveur (attendu : aucune option DNS ici)'
    Get-DhcpServerv4OptionValue | Format-Table OptionId, Name, Value -AutoSize
    Write-Titre 'Mises a jour DNS'
    Get-DhcpServerv4DnsSetting | Format-List
    Write-Titre 'Compte utilise pour les mises a jour DNS'
    Get-DhcpServerDnsCredential | Format-List UserName, DomainName
    Write-Titre 'Basculement (vide tant que SRV-DC02 n est pas promu)'
    Get-DhcpServerv4Failover | Format-List Name, PartnerServer, Mode, LoadBalancePercent, MaxClientLeadTime, State, ScopeId
}

# ---------------------------------------------------------------- A2 : comptes ordinateur
Save-Preuve 'A2-ordinateurs' {
    Write-Titre 'Get-ADComputer -Filter *'
    Get-ADComputer -Filter * -Properties OperatingSystem, Created |
        Sort-Object DistinguishedName | Format-Table Name, Enabled, OperatingSystem, Created, DistinguishedName -AutoSize
}

# ---------------------------------------------------------------- B1 : OU, groupes, utilisateurs
Save-Preuve 'B1-ou' {
    $ous = Get-ADOrganizationalUnit -Filter * -SearchBase $racine -Properties Description, ProtectedFromAccidentalDeletion
    Write-Titre "Unites d organisation sous $racine : $(@($ous).Count)"
    $ous | Sort-Object { $p = $_.DistinguishedName -split ','; [array]::Reverse($p); $p -join ',' } |
        Format-Table Name, ProtectedFromAccidentalDeletion, DistinguishedName, Description -AutoSize
}

Save-Preuve 'B1-groupes' {
    $groupes = Get-ADGroup -Filter * -SearchBase $racine -Properties Description | Sort-Object Name
    Write-Titre "Groupes sous $racine : $(@($groupes).Count)"
    $groupes | Format-Table Name, GroupScope, GroupCategory, DistinguishedName -AutoSize
    Write-Titre 'Membres de chaque groupe (AGDLP : des GG_ dans les DL_, des comptes dans les GG_)'
    foreach ($g in $groupes) {
        $membres = Get-ADGroupMember -Identity $g.DistinguishedName | ForEach-Object { "$($_.SamAccountName) [$($_.objectClass)]" }
        '{0,-32} <- {1}' -f $g.Name, ($membres -join ', ')
    }
}

Save-Preuve 'B1-utilisateurs' {
    $base = "OU=Utilisateurs,$racine"
    $utilisateurs = Get-ADUser -Filter * -SearchBase $base -Properties Department, Title, pwdLastSet, Created
    Write-Titre "Utilisateurs sous $base : $(@($utilisateurs).Count)"
    $utilisateurs | Sort-Object DistinguishedName |
        Format-Table SamAccountName, Name, Department, Enabled, Created,
            @{ n = 'ChangementExige'; e = { $_.pwdLastSet -eq 0 } },
            @{ n = 'OU'; e = { ($_.DistinguishedName -split ',', 2)[1] } } -AutoSize
}

# ---------------------------------------------------------------- B3 : comptes a privileges
Save-Preuve 'B3-comptes-admin' {
    Write-Titre 'Comptes nominatifs par niveau'
    $admins = Get-ADUser -Filter "SamAccountName -like 't0-*' -or SamAccountName -like 't1-*' -or SamAccountName -like 't2-*'" -Properties AccountNotDelegated, Created
    $admins | Sort-Object SamAccountName |
        Format-Table SamAccountName, Enabled, AccountNotDelegated, Created, @{ n = 'OU'; e = { ($_.DistinguishedName -split ',', 2)[1] } } -AutoSize
    Write-Titre 'Comptes de service'
    Get-ADUser -Filter "SamAccountName -like 'svc-*'" -Properties Created |
        Format-Table SamAccountName, Enabled, Created, @{ n = 'OU'; e = { ($_.DistinguishedName -split ',', 2)[1] } } -AutoSize
    Write-Titre 'Membres de Admins du domaine (SID -512)'
    Get-ADGroupMember -Identity "$sid-512" | Format-Table SamAccountName, objectClass -AutoSize
    Write-Titre 'Membres de Administrateurs de l entreprise (SID -519)'
    Get-ADGroupMember -Identity "$sid-519" | Format-Table SamAccountName, objectClass -AutoSize
    Write-Titre 'Membres de Administrateurs du schema (SID -518) : attendu vide hors operation'
    Get-ADGroupMember -Identity "$sid-518" | Format-Table SamAccountName, objectClass -AutoSize
    Write-Titre 'Membres de Protected Users (SID -525)'
    Get-ADGroupMember -Identity "$sid-525" | Format-Table SamAccountName, objectClass -AutoSize
    Write-Titre 'Compte Administrateur integre (SID -500) : derniere utilisation'
    Get-ADUser -Identity "$sid-500" -Properties LastLogonDate, PasswordLastSet, Description |
        Format-List SamAccountName, Enabled, LastLogonDate, PasswordLastSet, Description
}

Save-Preuve 'B3-pso' {
    Write-Titre 'Politique du domaine'
    Get-ADDefaultDomainPasswordPolicy | Format-List MinPasswordLength, PasswordHistoryCount, MaxPasswordAge, ComplexityEnabled, LockoutThreshold, LockoutDuration, LockoutObservationWindow
    Write-Titre 'Strategies de mot de passe affinees (PSO)'
    $pso = Get-ADFineGrainedPasswordPolicy -Filter *
    $pso | Format-Table Name, Precedence, MinPasswordLength, PasswordHistoryCount, MaxPasswordAge, LockoutThreshold, LockoutDuration -AutoSize
    foreach ($p in $pso) {
        Write-Titre "Cibles de $($p.Name)"
        Get-ADFineGrainedPasswordPolicySubject -Identity $p.Name | Format-Table Name, ObjectClass -AutoSize
    }
    Write-Titre 'Strategie resultante par compte'
    Get-ADUser -Filter "SamAccountName -like 't0-*' -or SamAccountName -like 't1-*' -or SamAccountName -like 't2-*' -or SamAccountName -like 'svc-*'" |
        ForEach-Object {
            $r = Get-ADUserResultantPasswordPolicy -Identity $_.SamAccountName
            '{0,-16} -> {1}' -f $_.SamAccountName, $(if ($r) { $r.Name } else { '(politique du domaine)' })
        }
}

Save-Preuve 'B3-delegations' {
    foreach ($ou in 'OU=Utilisateurs', 'OU=Groupes', 'OU=Serveurs', 'OU=Postes', 'OU=Admin') {
        Write-Titre "dsacls $ou,$racine (lignes des groupes DL_ et des comptes svc-)"
        dsacls "$ou,$racine" | Select-String -Pattern 'DL_', 'svc-' | ForEach-Object { $_.Line.Trim() }
    }
    Write-Titre 'Attendu : aucune ligne pour OU=Admin'
}

Save-Preuve 'B3-laps' {
    Write-Titre 'Attributs LAPS dans le schema'
    $schema = (Get-ADRootDSE).schemaNamingContext
    Get-ADObject -SearchBase $schema -Filter "Name -like 'ms-LAPS-*'" | Format-Table Name -AutoSize
    foreach ($ou in 'OU=Serveurs', 'OU=Postes') {
        Write-Titre "Find-LapsADExtendedRights $ou,$racine"
        Find-LapsADExtendedRights -Identity "$ou,$racine" | Format-List
    }
}

# ---------------------------------------------------------------- B5 : GPO
Save-Preuve 'B5-gpo' {
    Import-Module GroupPolicy
    Write-Titre 'Get-GPO -All'
    Get-GPO -All | Sort-Object DisplayName | Format-Table DisplayName, GpoStatus, CreationTime, ModificationTime -AutoSize
    $cibles = @($domDN, "OU=Domain Controllers,$domDN", "OU=Serveurs,$racine", "OU=Postes,$racine", "OU=Quarantaine,$racine")
    foreach ($c in $cibles) {
        Write-Titre "Liens de GPO sur $c"
        (Get-GPInheritance -Target $c).GpoLinks | Format-Table DisplayName, Order, Enabled, Enforced -AutoSize
    }
}

try {
    Import-Module GroupPolicy -ErrorAction Stop
    foreach ($gpo in (Get-GPO -All | Where-Object { $_.DisplayName -like 'N360-*' })) {
        $html = Join-Path (Join-Path $Dossier 'gpo') "$($gpo.DisplayName).html"
        Get-GPOReport -Guid $gpo.Id -ReportType Html -Path $html
        Write-Host "[OK] gpo\$($gpo.DisplayName).html"
    }
} catch {
    Write-Warning "Rapports HTML des GPO non exportes : $($_.Exception.Message)"
}

# ---------------------------------------------------------------- C1 : recuperation des services
Save-Preuve 'C1-services' {
    foreach ($s in 'DNS', 'NTDS', 'Kdc', 'Netlogon', 'DHCPServer', 'W32Time') {
        Write-Titre "sc.exe qfailure $s"
        sc.exe qfailure $s
    }
    Write-Titre 'Etat des services'
    Get-Service DNS, NTDS, Kdc, Netlogon, DHCPServer, W32Time -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType -AutoSize
}

# ---------------------------------------------------------------- Controle final
Write-Host ''
Write-Host "Preuves ecrites dans : $Dossier"
$suspects = Select-String -Path (Join-Path $Dossier '*.txt') -Pattern 'Mot de passe initial', 'cpassword', 'Secret' -SimpleMatch
if ($suspects) {
    Write-Warning 'Des lignes ressemblent a des secrets : RELIRE ces fichiers avant tout commit.'
    $suspects | ForEach-Object { "  $($_.Filename):$($_.LineNumber)" }
} else {
    Write-Host 'Aucun motif de secret detecte. Relire quand meme avant de pousser.'
}
