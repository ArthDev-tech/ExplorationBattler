param(
  [Parameter(Mandatory = $true)]
  [string]$InputFile,

  [Parameter(Mandatory = $true)]
  [string]$OutputFile,

  # Common equirect sizes
  [ValidateSet("2000x1000", "1920x960", "3840x1920", "4096x2048")]
  [string]$Size = "4096x2048",

  # Theora quality (0-10). 10 is max quality but larger files.
  [ValidateRange(0, 10)]
  [int]$Quality = 10,

  # Keyframe interval (GOP). Smaller can reduce artifacts but increase size.
  [ValidateRange(10, 240)]
  [int]$Gop = 60,

  # Optional subtle grain (helps starfields survive macroblocking)
  [switch]$AddGrain
)

$ErrorActionPreference = "Stop"

function Require-Ffmpeg {
  $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host ""
    Write-Host "ffmpeg was not found on PATH."
    Write-Host "Install one of these, then re-run:"
    Write-Host "  - winget install Gyan.FFmpeg"
    Write-Host "  - choco install ffmpeg"
    Write-Host "Or download from: https://ffmpeg.org/download.html"
    Write-Host ""
    throw "Missing ffmpeg"
  }
}

Require-Ffmpeg

if (-not (Test-Path -LiteralPath $InputFile)) {
  throw "InputFile not found: $InputFile"
}

$scale = $Size.Replace("x", ":")

# Lanczos gives the sharpest resample (good for stars).
$vf = "scale=$scale:flags=lanczos"
if ($AddGrain) {
  # Very light temporal noise helps reduce banding/macroblocking on starfields.
  $vf = "$vf,noise=alls=2:allf=t"
}

Write-Host "Encoding HDRI sky video..."
Write-Host "  Input : $InputFile"
Write-Host "  Output: $OutputFile"
Write-Host "  Size  : $Size"
Write-Host "  Q     : $Quality"
Write-Host "  GOP   : $Gop"
Write-Host "  Grain : $AddGrain"
Write-Host ""

ffmpeg `
  -y `
  -i "$InputFile" `
  -vf "$vf" `
  -c:v libtheora `
  -q:v $Quality `
  -g $Gop `
  -an `
  "$OutputFile"

Write-Host ""
Write-Host "Done."
Write-Host ""
Write-Host "Next steps:"
Write-Host "  - Replace: exploration-battler/assets/Vidieo/TwilightHDRI.ogv"
Write-Host "  - Or set AnimatedHDRISky.video_path to your new file."

