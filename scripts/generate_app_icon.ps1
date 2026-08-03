# Gera o icone provisorio do App Store (1024x1024, sem canal alfa) a partir do
# LogoAcordado, num fundo cream + circulo branco imitando o botao redondo do app -
# mesma tecnica ja usada no projeto pra imagem (PowerShell + System.Drawing, sem
# instalar nada). Rodar uma vez localmente e commitar o resultado:
#   powershell -File scripts/generate_app_icon.ps1

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$size = 1024
$creamColor = [System.Drawing.Color]::FromArgb(255, 244, 243, 240)   # #F4F3F0
$circleColor = [System.Drawing.Color]::White
$circleDiameter = 800
$circlePadding = ($size - $circleDiameter) / 2

$sourcePath = Join-Path $PSScriptRoot "..\Luminaria\Assets.xcassets\LogoAcordado.imageset\logo_acordado.png"
$outputPath = Join-Path $PSScriptRoot "..\Luminaria\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png"

# Format24bppRgb: sem canal alfa nenhum (nem opaco) - o encoder PNG do GDI+ ainda escreve
# RGBA mesmo a partir de Format32bppRgb (alfa sempre 255, mas o canal continua existindo
# no arquivo), e a validacao da Apple rejeita qualquer PNG com canal alfa presente,
# transparente ou nao.
$bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$graphics.Clear($creamColor)

$circleBrush = New-Object System.Drawing.SolidBrush($circleColor)
$graphics.FillEllipse($circleBrush, $circlePadding, $circlePadding, $circleDiameter, $circleDiameter)

$logo = [System.Drawing.Image]::FromFile($sourcePath)
$logoSize = $circleDiameter * 0.72
$logoOffset = ($size - $logoSize) / 2
$graphics.DrawImage($logo, $logoOffset, $logoOffset, $logoSize, $logoSize)

$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()
$logo.Dispose()

Write-Host "Icone gerado em $outputPath"
