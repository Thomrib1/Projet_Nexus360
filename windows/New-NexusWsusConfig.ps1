<#
.SYNOPSIS
    Configure WSUS (langues, produits, classifications, anneaux) depuis config/wsus.json.
.DESCRIPTION
    Idempotent. Supporte -WhatIf. A executer sur SRV-MGT01 apres 'wsusutil postinstall'
    et le chargement du catalogue. -Sync lance une synchronisation complete.
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config\wsus.json'),
    [switch]$Sync
)

$ErrorActionPreference = 'Stop'
$cfg     = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$changes = 0
$wsus    = Get-WsusServer -Name $env:COMPUTERNAME -PortNumber $cfg.Port

function Test-SameSet($A, $B) {
    $a1 = @($A); $b1 = @($B)
    $onlyA = @($a1 | Where-Object { $b1 -notcontains $_ })
    $onlyB = @($b1 | Where-Object { $a1 -notcontains $_ })
    return (($onlyA.Count + $onlyB.Count) -eq 0)
}

# 1. Source et langues
$wcfg = $wsus.GetConfiguration()
$have = @(@($wcfg.GetEnabledUpdateLanguages()) | Sort-Object)
$want = @(@($cfg.Languages) | Sort-Object)
$needSource = -not $wcfg.SyncFromMicrosoftUpdate
$needLang   = $wcfg.AllUpdateLanguagesEnabled -or -not (Test-SameSet $have $want)
if ($needSource -or $needLang) {
    if ($PSCmdlet.ShouldProcess('WSUS', 'Source Microsoft Update et langues')) {
        $langs = New-Object System.Collections.Specialized.StringCollection
        foreach ($l in $cfg.Languages) { [void]$langs.Add($l) }
        $wcfg.SyncFromMicrosoftUpdate = $true
        $wcfg.AllUpdateLanguagesEnabled = $false
        $wcfg.SetEnabledUpdateLanguages($langs)
        $wcfg.Save()
        $changes++
        Write-Host '[CHANGED] source et langues'
    }
} else { Write-Host '[OK] source et langues' }

# 2. Produits
$sub      = $wsus.GetSubscription()
$products = @(Get-WsusProduct)
$wantedProducts = @($products | Where-Object {
    $t = $_.Product.Title
    @($cfg.ProductPatterns | Where-Object { $t -match $_ }).Count -gt 0
} | ForEach-Object { $_.Product.Title })
if ($wantedProducts.Count -eq 0) {
    throw 'Aucun produit ne correspond : catalogue non charge (StartSynchronizationForCategoryOnly) ?'
}
$currentProducts = @($sub.GetUpdateCategories() | ForEach-Object { $_.Title })
if (-not (Test-SameSet $currentProducts $wantedProducts)) {
    if ($PSCmdlet.ShouldProcess('WSUS', 'Limiter les produits')) {
        $products | Set-WsusProduct -Disable
        $products | Where-Object { $wantedProducts -contains $_.Product.Title } | Set-WsusProduct
        $changes++
        Write-Host '[CHANGED] produits'
    }
} else { Write-Host '[OK] produits' }

# 3. Classifications
$classes = @(Get-WsusClassification)
$wantedClasses = @($classes | Where-Object {
    $t = $_.Classification.Title
    @($cfg.ClassificationPatterns | Where-Object { $t -match $_ }).Count -gt 0
} | ForEach-Object { $_.Classification.Title })
if ($wantedClasses.Count -eq 0) { throw 'Aucune classification ne correspond.' }
$currentClasses = @($sub.GetUpdateClassifications() | ForEach-Object { $_.Title })
if (-not (Test-SameSet $currentClasses $wantedClasses)) {
    if ($PSCmdlet.ShouldProcess('WSUS', 'Limiter les classifications')) {
        $classes | Set-WsusClassification -Disable
        $classes | Where-Object { $wantedClasses -contains $_.Classification.Title } | Set-WsusClassification
        $changes++
        Write-Host '[CHANGED] classifications'
    }
} else { Write-Host '[OK] classifications' }

# 4. Anneaux (groupes d'ordinateurs)
$existing = @($wsus.GetComputerTargetGroups() | ForEach-Object { $_.Name })
foreach ($g in $cfg.Groups) {
    if ($existing -notcontains $g) {
        if ($PSCmdlet.ShouldProcess($g, 'Creer le groupe')) {
            [void]$wsus.CreateComputerTargetGroup($g)
            $changes++
            Write-Host "[CHANGED] groupe $g"
        }
    } else { Write-Host "[OK] groupe $g" }
}

# 5. Mode de synchronisation, puis synchronisation si demandee
$sub = $wsus.GetSubscription()
if ($sub.SynchronizeAutomatically -ne [bool]$cfg.SynchronizeAutomatically) {
    if ($PSCmdlet.ShouldProcess('WSUS', 'Mode de synchronisation')) {
        $sub.SynchronizeAutomatically = [bool]$cfg.SynchronizeAutomatically
        $sub.Save()
        $changes++
        Write-Host '[CHANGED] mode de synchronisation'
    }
} else { Write-Host '[OK] mode de synchronisation' }

if ($Sync -and $sub.GetSynchronizationStatus() -eq 'NotProcessing') {
    if ($PSCmdlet.ShouldProcess('WSUS', 'Lancer la synchronisation')) {
        $sub.StartSynchronization()
        Write-Host '[CHANGED] synchronisation lancee'
    }
}

Write-Host "Termine : $changes changement(s)."