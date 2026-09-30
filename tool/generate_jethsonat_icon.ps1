#Requires -Version 5.1
<#
.SYNOPSIS
    Génère l'icône de lancement et la pochette de header de Jethsonat à partir
    de la photo officielle de l'artiste.

.DESCRIPTION
    Le script ne fabrique aucun visuel : il recadre et redimensionne le cliché
    officiel de l'artiste (`assets/covers/jethsonat_cover2.jpg` — portrait
    cadré sur la tête, fond noir) et écrit deux fichiers versionnés :

      - `assets/icons/jethsonat_icon.png`  : source de `flutter_launcher_icons`
        (mipmaps Android `mipmap-*` / `drawable-*` et AppIcon iOS) ;
      - `assets/covers/jethsonat_cover.png` : pochette déclarée par
        `ArtistProfile.coverAsset` (lib/core/constants/artist_config.dart).

    Ces deux fichiers ne doivent donc plus être écrasés par
    `tool/generate_brand_assets.dart` (générateur de la marque générique).

    Exécution : Windows (System.Drawing / .NET Framework). Le poste de
    développement du dépôt est Windows, où `scripts/build_apk.ps1` est déjà
    écrit en PowerShell ; la CI web n'a pas besoin de ce script puisque les
    fichiers produits sont versionnés.

.PARAMETER Source
    Photo officielle à recadrer, chemin relatif à la racine du dépôt.

.PARAMETER CropX
    Abscisse du coin haut-gauche du carré de recadrage, en fraction de la
    largeur de la photo (0 = bord gauche).

.PARAMETER CropY
    Ordonnée du coin haut-gauche du carré de recadrage, en fraction de la
    hauteur de la photo (0 = bord supérieur).

.PARAMETER CropSide
    Côté du carré de recadrage, en fraction de la largeur de la photo.

.PARAMETER Size
    Côté, en pixels, des deux PNG produits.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tool/generate_jethsonat_icon.ps1

.EXAMPLE
    # Reproduire l'icône après avoir reçu un nouveau portrait :
    powershell -ExecutionPolicy Bypass -File tool/generate_jethsonat_icon.ps1 `
        -Source assets/covers/jethsonat_nouveau.jpg -CropSide 0.8
#>
[CmdletBinding()]
param(
    [string]$Source = 'assets/covers/jethsonat_cover2.jpg',
    # Cadrage réglé sur le portrait officiel (853x1280) : la tête occupe
    # ~63 % de la largeur du carré, dans la zone sûre de l'icône adaptative.
    [double]$CropX = 0.158,
    [double]$CropY = 0.0,
    [double]$CropSide = 0.727,
    [int]$Size = 1024
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot $Source
if (-not (Test-Path $sourcePath)) {
    throw "Photo introuvable : $sourcePath"
}

$image = [System.Drawing.Image]::FromFile($sourcePath)
try {
    # Carré de recadrage, borné aux dimensions du cliché.
    $side = [int][Math]::Round($image.Width * $CropSide)
    $side = [Math]::Min($side, [Math]::Min($image.Width, $image.Height))
    $x = [Math]::Min([int][Math]::Round($image.Width * $CropX), $image.Width - $side)
    $y = [Math]::Min([int][Math]::Round($image.Height * $CropY), $image.Height - $side)
    $x = [Math]::Max($x, 0)
    $y = [Math]::Max($y, 0)
    $sourceRect = New-Object System.Drawing.Rectangle($x, $y, $side, $side)

    Write-Host "Source      : $Source ($($image.Width)x$($image.Height))" -ForegroundColor Cyan
    Write-Host "Recadrage   : ${side}x${side} en ($x,$y)" -ForegroundColor Cyan

    foreach ($output in @(
            'assets/icons/jethsonat_icon.png',
            'assets/covers/jethsonat_cover.png'
        )) {
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CompositingQuality =
                [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode =
                [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode =
                [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.SmoothingMode =
                [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $destination = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
            $graphics.DrawImage(
                $image,
                $destination,
                $sourceRect,
                [System.Drawing.GraphicsUnit]::Pixel
            )
        }
        finally {
            $graphics.Dispose()
        }

        $target = Join-Path $repoRoot $output
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) |
            Out-Null
        # PNG sans canal alpha (source JPEG) : iOS refuse une icône transparente.
        $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        Write-Host "Ecrit       : $output ($($Size)x$($Size))" -ForegroundColor Green
    }
}
finally {
    $image.Dispose()
}
