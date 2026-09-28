#Requires -Version 5.1
<#
.SYNOPSIS
    Compile l'APK release d'un artiste en transmettant les clés d'environnement
    via --dart-define.

.DESCRIPTION
    Les secrets ne sont jamais écrits dans le dépôt : le script lit le fichier
    `.env` (local, ignoré par git) ou les variables déjà présentes dans
    l'environnement, puis les transmet à `flutter build` sous forme de
    `--dart-define=CLÉ=valeur`.

    Exemple (Jethsonat, label Tete Roh Studio) :

        powershell -ExecutionPolicy Bypass -File scripts/build_apk.ps1 `
            -Flavor jethsonat -ArtistId jethsonat -ArtistFolder artist_2

    Sans `.env`, les valeurs présente dans l'environnement du processus sont
    utilisées : c'est le mode attendu en CI (secrets du dépôt).

.PARAMETER Flavor
    Flavor Android (doit exister dans `android/app/build.gradle.kts`).

.PARAMETER ArtistId
    Identifiant Firestore de l'artiste : doit correspondre au champ `artistId`
    des documents de la collection `tracks`.

.PARAMETER ArtistFolder
    Uniquement utilisé si `-ArtistId` est omis : `artist_1` dérive `artist1`.

.PARAMETER StreamOnly
    Mode « 100 % streaming » : le catalogue embarqué est ignoré et tout
    provient de Firestore. Par défaut `false` (catalogue hybride : titres
    embarqués jouables hors-ligne + nouveautés Firestore).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/build_apk.ps1 -Flavor jethsonat
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Flavor,
    [string]$ArtistId,
    [string]$ArtistFolder,
    [bool]$StreamOnly = $false,
    [string]$Target = 'lib/main.dart',
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env'

# --- Lecture du .env -------------------------------------------------------
# Format accepté : `CLE=valeur`, `#` pour les commentaires. Les guillemets
# entourant la valeur sont retirés.
$fromFile = @{}
if (Test-Path $envFile) {
    Write-Host "Lecture de la configuration : $envFile" -ForegroundColor DarkGray
    foreach ($line in Get-Content $envFile) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $parts = $trimmed -split '=', 2
        if ($parts.Count -ne 2) { continue }
        $fromFile[$parts[0].Trim()] = $parts[1].Trim().Trim('"').Trim("'")
    }
}

function Get-Config {
    param([string]$Name, [string]$Default = '')
    # Priorité : variable du processus, puis .env, puis valeur par défaut.
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value) -and $fromFile.ContainsKey($Name)) {
        $value = $fromFile[$Name]
    }
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value
}

# --- Identité de l'artiste -------------------------------------------------
if ([string]::IsNullOrWhiteSpace($ArtistId))     { $ArtistId     = Get-Config 'ARTIST_ID'     $Flavor }
if ([string]::IsNullOrWhiteSpace($ArtistFolder)) { $ArtistFolder = Get-Config 'ARTIST_FOLDER' 'artist_1' }
$streamOnlyValue = Get-Config 'STREAM_ONLY' ($StreamOnly.ToString().ToLower())

# --- Secrets ---------------------------------------------------------------
# Seules les paires réellement renseignées sont transmises : une clé vide
# produirait un `--dart-define` qui masque la valeur par défaut sans l'informer.
$secrets = @(
    'FIREBASE_API_KEY',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_STORAGE_BUCKET',
    'FIREBASE_APP_ID',
    'FIREBASE_ANDROID_APP_ID',
    'FIREBASE_AUTH_DOMAIN',
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY'
)

$defines = @(
    "--dart-define=ARTIST_ID=$ArtistId",
    "--dart-define=ARTIST_FOLDER=$ArtistFolder",
    "--dart-define=STREAM_ONLY=$streamOnlyValue"
)

# --- Publicité (AdMob) ------------------------------------------------------
# Les identifiants ne sont pas secrets : ce sont des valeurs publiques, mais
# propres à chaque artiste. Elles voyagent donc par variable d'environnement,
# ce qui permet aussi à Gradle de lire ADMOB_APP_ID pour le manifest.
$admobAppId        = Get-Config 'ADMOB_APP_ID'
$admobBannerId     = Get-Config 'ADMOB_BANNER_ID'
$admobInterstitial = Get-Config 'ADMOB_INTERSTITIAL_ID'

if ($admobAppId) {
    $env:ADMOB_APP_ID = $admobAppId
}
if ($admobBannerId) {
    $defines += "--dart-define=ADMOB_BANNER_ID=$admobBannerId"
}
if ($admobInterstitial) {
    $defines += "--dart-define=ADMOB_INTERSTITIAL_ID=$admobInterstitial"
}

$missing = @()
foreach ($name in $secrets) {
    $value = Get-Config $name
    if ([string]::IsNullOrWhiteSpace($value)) {
        $missing += $name
        continue
    }
    $defines += "--dart-define=$name=$value"
}

Write-Host ''
Write-Host 'Configuration du build' -ForegroundColor Cyan
Write-Host "  flavor        : $Flavor"
Write-Host "  artistId      : $ArtistId"
Write-Host "  artistFolder  : $ArtistFolder"
Write-Host "  streamOnly    : $streamOnlyValue"
Write-Host "  secrets       : $($secrets.Count - $missing.Count)/$($secrets.Count) renseignés"
$admobBannerState = if ($admobBannerId) { 'oui' } else { 'non' }
$admobInterState = if ($admobInterstitial) { 'oui' } else { 'non' }
Write-Host "  admob appId   : $(if ($admobAppId) { 'oui' } else { 'non' })"
Write-Host "  admob banner  : $admobBannerState"
Write-Host "  admob interst.: $admobInterState"

if (-not $admobAppId) {
    Write-Warning 'Pas de ADMOB_APP_ID : le build fonctionnera, sans publicité.'
    Write-Warning 'Chaque artiste doit disposer de son propre compte AdMob (cf.'
    Write-Warning 'docs/ONBOARDING_ARTISTE.md) ; partager des IDs est interdit.'
}

if ($missing.Count -gt 0) {
    Write-Warning "Variables absentes : $($missing -join ', ')"
    Write-Warning 'Sans FIREBASE_*, le catalogue distant restera vide et l''application'
    Write-Warning 'affichera « Catalogue indisponible ». Copiez .env.example vers .env.'
}

# --- Commande de build ----------------------------------------------------
$arguments = @('build', 'apk', '--release', '--flavor', $Flavor, '-t', $Target) + $defines
# `--no-tree-shake-icons` : sans l'artefact `const_finder` de l'engine, le
# tree-shaker d'icônes échoue (cf. README, « Pièges connus »).
$arguments += '--no-tree-shake-icons'

if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $arguments += @('--build-dir', $OutputDirectory)
}

Write-Host ''
Write-Host "flutter $($arguments -join ' ')" -ForegroundColor Green
Write-Host ''

Push-Location $repoRoot
try {
    & flutter @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Le build a échoué (code $LASTEXITCODE)."
    }
}
finally {
    Pop-Location
}

# Les APK vivent sous `build/`, effacé par `flutter clean` : on les copie hors
# de `build/` dès la production.
$apk = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-$Flavor-release.apk"
if (Test-Path $apk) {
    $destination = Join-Path $repoRoot "releases\$Flavor"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $target = Join-Path $destination "app-$Flavor-release.apk"
    Copy-Item $apk $target -Force
    Write-Host ''
    Write-Host "APK copié dans : $target" -ForegroundColor Green
}
else {
    Write-Warning "APK introuvable à l'emplacement attendu : $apk"
}
