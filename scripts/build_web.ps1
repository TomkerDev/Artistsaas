#Requires -Version 5.1
<#
.SYNOPSIS
    Compile le panneau d'administration (Flutter Web) et prépare `build/web`
    pour un déploiement Firebase Hosting.

.DESCRIPTION
    Comme `scripts/build_apk.ps1`, les secrets ne sont jamais écrits dans le
    dépôt : le script lit `.env` (local, ignoré par git) ou les variables déjà
    présentes dans l'environnement, puis les transmet à `flutter build web`
    sous forme de `--dart-define=CLÉ=valeur`.

    Le panneau est bâti depuis `lib/main_admin.dart` : l'application artiste
    n'embarque ni les écrans d'upload ni les services d'administration.

    Les quatre valeurs non secrètes du projet (`FIREBASE_PROJECT_ID`,
    `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`) sont identiques à celles
    du workflow `.github/workflows/deploy.yml` ; elles restent surchargeables
    par `.env` pour cibler un autre projet Firebase.

    Exemple :

        powershell -ExecutionPolicy Bypass -File scripts/build_web.ps1
        firebase deploy --only hosting --project novaa-music-tchaddd

.PARAMETER Target
    Point d'entrée compilé. `lib/main_admin.dart` par défaut.

.PARAMETER OutputDirectory
    Répertoire de build alternatif (`--build-dir`). Laisser vide pour `build/`,
    l'emplacement lu par `firebase.json`.

.PARAMETER NoSourceMaps
    Désactive `--source-maps` (cartes de sources plus lourdes mais seules
    capables de restituer une pile d'appel lisible en production).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/build_web.ps1 -NoSourceMaps
#>
[CmdletBinding()]
param(
    [string]$Target = 'lib/main_admin.dart',
    [string]$OutputDirectory = '',
    [switch]$NoSourceMaps
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

# --- Secrets ---------------------------------------------------------------
# Seules les paires réellement renseignées sont transmises : une clé vide
# produirait un `--dart-define` qui masque la valeur par défaut sans l'informer.
$secrets = @(
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY'
)


# --- Constantes de projet (surchargeables) ---------------------------------
# Alignées sur `.github/workflows/deploy.yml` : un build local et un build CI
# visent donc le même site Hosting.
$constants = @(
    @{ Name = 'FIREBASE_PROJECT_ID';   Default = 'novaa-music-tchaddd' },
    @{ Name = 'FIREBASE_AUTH_DOMAIN';  Default = 'novaa-music-tchaddd.firebaseapp.com' },
    @{ Name = 'FIREBASE_STORAGE_BUCKET'; Default = 'novaa-music-tchaddd.firebasestorage.app' }
)

$defines = @()
foreach ($constant in $constants) {
    $defines += "--dart-define=$($constant.Name)=$(Get-Config $constant.Name $constant.Default)"
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
Write-Host 'Configuration du build web' -ForegroundColor Cyan
Write-Host "  cible         : $Target"
Write-Host "  site          : $(Get-Config 'FIREBASE_PROJECT_ID' 'novaa-music-tchaddd').web.app"
Write-Host "  secrets       : $($secrets.Count - $missing.Count)/$($secrets.Count) renseignes"
Write-Host "  source maps   : $(if ($NoSourceMaps) { 'non' } else { 'oui' })"

if ($missing.Count -gt 0) {
    Write-Warning "Variables absentes : $($missing -join ', ')"
    Write-Warning 'Sans FIREBASE_*, l''ecran de connexion affichera une erreur ; sans'
    Write-Warning 'SUPABASE_*, les uploads echoueront au premier appel. Copiez'
    Write-Warning '.env.example vers .env pour un build complet.'
}

# --- Commande de build ----------------------------------------------------
$arguments = @('build', 'web', '--release', "--target=$Target")
# `--no-tree-shake-icons` : sans l'artefact `const_finder` de l'engine, le
# tree-shaker d'icones echoue (cf. README, « Pieges connus »).
$arguments += '--no-tree-shake-icons'
if (-not $NoSourceMaps) {
    $arguments += '--source-maps'
}
$arguments += $defines

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
        throw "Le build a echoue (code $LASTEXITCODE)."
    }
}
finally {
    Pop-Location
}

# --- Controle du livrable -------------------------------------------------
# `firebase.json` publie le dossier `build/web` : un dossier vide deployerait
# une page 404 silencieuse, donc on verifie le binaire avant de rendre la main.
$webRoot = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $repoRoot 'build\web'
}
else {
    Join-Path (Join-Path $repoRoot $OutputDirectory) 'web'
}

$bundle = Join-Path $webRoot 'main.dart.js'
if (-not (Test-Path $bundle)) {
    throw "Build web incomplet : main.dart.js introuvable dans $webRoot"
}

$sizeMb = [math]::Round((Get-Item $bundle).Length / 1MB, 2)
$files = (Get-ChildItem -Recurse -File $webRoot).Count

Write-Host ''
Write-Host "main.dart.js  : $sizeMb Mo" -ForegroundColor Green
Write-Host "fichiers      : $files" -ForegroundColor Green
Write-Host "racine web    : $webRoot" -ForegroundColor Green
Write-Host ''
Write-Host 'Deploiement :' -ForegroundColor Cyan
Write-Host '  firebase deploy --only hosting --project novaa-music-tchaddd'
