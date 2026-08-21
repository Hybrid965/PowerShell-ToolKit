```powershell
#Requires -Version 5.1

<#
.SYNOPSIS
    Media Converter v3.0 using FFmpeg.

.DESCRIPTION
    General-purpose media converter using FFmpeg.

    Features:
      - Select source folder
      - Select input media type
      - Select output format
      - Select video quality
      - Converts multiple files
      - Creates individual output folders
      - Conversion summary
      - Optional deletion of successfully converted originals
      - Automatically selects a suitable codec

.NOTES
    Requires FFmpeg to be installed and available in PATH.
#>

# ===========================================================================
# CONFIGURATION
# ===========================================================================

$OutputFolderName = "Converted Media"

# Supported input extensions
$SupportedExtensions = @(
    ".mp4",
    ".mkv",
    ".avi",
    ".mov",
    ".flv",
    ".webm",
    ".wmv",
    ".mpeg",
    ".mpg",
    ".m4v",
    ".ts",
    ".mts",
    ".m2ts",
    ".3gp",
    ".ogv",
    ".mp3",
    ".wav",
    ".aac",
    ".flac",
    ".ogg",
    ".m4a",
    ".wma"
)

# ===========================================================================
# BANNER
# ===========================================================================

function Write-Banner {

    Clear-Host

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║             Media Converter              ║" -ForegroundColor Cyan
    Write-Host "║                  v3.0                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# ===========================================================================
# CHECK FFMPEG
# ===========================================================================

function Test-FFmpeg {

    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {

        Write-Host ""
        Write-Host "✖ FFmpeg was not found." -ForegroundColor Red
        Write-Host ""
        Write-Host "FFmpeg must be installed and available in PATH."
        Write-Host ""

        return $false
    }

    return $true
}

# ===========================================================================
# SELECT SOURCE FOLDER
# ===========================================================================

function Select-SourceFolder {

    do {

        Write-Host ""
        $path = Read-Host "Enter the source folder path"

        if ([string]::IsNullOrWhiteSpace($path)) {

            Write-Host ""
            Write-Host "✖ Folder path cannot be empty." -ForegroundColor Red
            continue
        }

        if (-not (Test-Path $path -PathType Container)) {

            Write-Host ""
            Write-Host "✖ Folder does not exist." -ForegroundColor Red
            continue
        }

        return (Resolve-Path $path).Path

    } while ($true)
}

# ===========================================================================
# SELECT INPUT TYPE
# ===========================================================================

function Select-InputType {

    Write-Host ""
    Write-Host "Select input media type:" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  1. MP4"
    Write-Host "  2. MKV"
    Write-Host "  3. AVI"
    Write-Host "  4. MOV"
    Write-Host "  5. FLV"
    Write-Host "  6. WebM"
    Write-Host "  7. WMV"
    Write-Host "  8. MPEG / MPG"
    Write-Host "  9. M4V"
    Write-Host " 10. TS / MTS / M2TS"
    Write-Host " 11. Audio files"
    Write-Host " 12. All supported media"
    Write-Host ""

    do {

        $choice = Read-Host "Enter your choice (1-12)"

        switch ($choice) {

            "1" {
                return @(".mp4")
            }

            "2" {
                return @(".mkv")
            }

            "3" {
                return @(".avi")
            }

            "4" {
                return @(".mov")
            }

            "5" {
                return @(".flv")
            }

            "6" {
                return @(".webm")
            }

            "7" {
                return @(".wmv")
            }

            "8" {
                return @(".mpeg", ".mpg")
            }

            "9" {
                return @(".m4v")
            }

            "10" {
                return @(".ts", ".mts", ".m2ts")
            }

            "11" {
                return @(
                    ".mp3",
                    ".wav",
                    ".aac",
                    ".flac",
                    ".ogg",
                    ".m4a",
                    ".wma"
                )
            }

            "12" {
                return $SupportedExtensions
            }

            default {
                Write-Host ""
                Write-Host "✖ Invalid choice." -ForegroundColor Red
            }
        }

    } while ($true)
}

# ===========================================================================
# SELECT OUTPUT FORMAT
# ===========================================================================

function Select-OutputFormat {

    Write-Host ""
    Write-Host "Select output format:" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  1. MP4"
    Write-Host "  2. MKV"
    Write-Host "  3. AVI"
    Write-Host "  4. MOV"
    Write-Host "  5. FLV"
    Write-Host "  6. WebM"
    Write-Host "  7. MP3"
    Write-Host "  8. WAV"
    Write-Host "  9. FLAC"
    Write-Host " 10. M4A"
    Write-Host ""

    do {

        $choice = Read-Host "Enter your choice (1-10)"

        switch ($choice) {

            "1" {
                return @{
                    Extension = "mp4"
                    Name      = "MP4"
                    Codec     = "libx264"
                }
            }

            "2" {
                return @{
                    Extension = "mkv"
                    Name      = "MKV"
                    Codec     = "libx264"
                }
            }

            "3" {
                return @{
                    Extension = "avi"
                    Name      = "AVI"
                    Codec     = "libx264"
                }
            }

            "4" {
                return @{
                    Extension = "mov"
                    Name      = "MOV"
                    Codec     = "libx264"
                }
            }

            "5" {
                return @{
                    Extension = "flv"
                    Name      = "FLV"
                    Codec     = "libx264"
                }
            }

            "6" {
                return @{
                    Extension = "webm"
                    Name      = "WebM"
                    Codec     = "libvpx-vp9"
                }
            }

            "7" {
                return @{
                    Extension = "mp3"
                    Name      = "MP3"
                    Codec     = "libmp3lame"
                }
            }

            "8" {
                return @{
                    Extension = "wav"
                    Name      = "WAV"
                    Codec     = "pcm_s16le"
                }
            }

            "9" {
                return @{
                    Extension = "flac"
                    Name      = "FLAC"
                    Codec     = "flac"
                }
            }

            "10" {
                return @{
                    Extension = "m4a"
                    Name      = "M4A"
                    Codec     = "aac"
                }
            }

            default {
                Write-Host ""
                Write-Host "✖ Invalid choice." -ForegroundColor Red
            }
        }

    } while ($true)
}

# ===========================================================================
# DETERMINE IF OUTPUT IS AUDIO ONLY
# ===========================================================================

function Test-AudioOutput {

    param (
        [string]$Extension
    )

    return $Extension -in @(
        "mp3",
        "wav",
        "flac",
        "m4a"
    )
}

# ===========================================================================
# SELECT QUALITY
# ===========================================================================

function Select-Quality {

    Write-Host ""
    Write-Host "Select video quality:" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  1. High"
    Write-Host "  2. Medium"
    Write-Host "  3. Low"
    Write-Host "  4. Custom CRF"
    Write-Host ""

    do {

        $choice = Read-Host "Enter your choice (1-4)"

        switch ($choice) {

            "1" {
                return @{
                    CRF  = "18"
                    Name = "High"
                }
            }

            "2" {
                return @{
                    CRF  = "23"
                    Name = "Medium"
                }
            }

            "3" {
                return @{
                    CRF  = "28"
                    Name = "Low"
                }
            }

            "4" {

                do {

                    $crf = Read-Host "Enter CRF value (0-51)"

                    $number = 0

                    if (
                        [int]::TryParse($crf, [ref]$number) -and
                        $number -ge 0 -and
                        $number -le 51
                    ) {

                        return @{
                            CRF  = $number
                            Name = "Custom CRF $number"
                        }
                    }

                    Write-Host ""
                    Write-Host "✖ CRF must be between 0 and 51." `
                        -ForegroundColor Red

                } while ($true)
            }

            default {
                Write-Host ""
                Write-Host "✖ Invalid choice." -ForegroundColor Red
            }
        }

    } while ($true)
}

# ===========================================================================
# BUILD FFMPEG ARGUMENTS
# ===========================================================================

function Get-FFmpegArguments {

    param (
        [string]$InputFile,
        [string]$OutputFile,
        [hashtable]$OutputFormat,
        [hashtable]$Quality
    )

    $arguments = @(
        "-hide_banner"
        "-i"
        $InputFile
    )

    # -----------------------------------------------------------------------
    # AUDIO OUTPUT
    # -----------------------------------------------------------------------

    if (Test-AudioOutput $OutputFormat.Extension) {

        $arguments += "-vn"

        switch ($OutputFormat.Extension) {

            "mp3" {

                $arguments += @(
                    "-c:a"
                    "libmp3lame"
                    "-q:a"
                    "2"
                )
            }

            "wav" {

                $arguments += @(
                    "-c:a"
                    "pcm_s16le"
                )
            }

            "flac" {

                $arguments += @(
                    "-c:a"
                    "flac"
                )
            }

            "m4a" {

                $arguments += @(
                    "-c:a"
                    "aac"
                    "-b:a"
                    "192k"
                )
            }
        }

        $arguments += @(
            "-y"
            $OutputFile
        )

        return $arguments
    }

    # -----------------------------------------------------------------------
    # VIDEO OUTPUT
    # -----------------------------------------------------------------------

    $arguments += @(
        "-c:v"
        $OutputFormat.Codec
        "-crf"
        $Quality.CRF
    )

    # -----------------------------------------------------------------------
    # AUDIO
    # -----------------------------------------------------------------------

    if ($OutputFormat.Extension -eq "webm") {

        $arguments += @(
            "-c:a"
            "libopus"
            "-b:a"
            "128k"
        )
    }
    else {

        $arguments += @(
            "-c:a"
            "aac"
            "-b:a"
            "192k"
        )
    }

    # -----------------------------------------------------------------------
    # MP4 FAST START
    # -----------------------------------------------------------------------

    if ($OutputFormat.Extension -eq "mp4") {

        $arguments += @(
            "-movflags"
            "+faststart"
        )
    }

    # -----------------------------------------------------------------------
    # OUTPUT
    # -----------------------------------------------------------------------

    $arguments += @(
        "-y"
        $OutputFile
    )

    return $arguments
}

# ===========================================================================
# MAIN
# ===========================================================================

Write-Banner

# ---------------------------------------------------------------------------
# Check FFmpeg
# ---------------------------------------------------------------------------

if (-not (Test-FFmpeg)) {

    Read-Host "Press Enter to exit"
    exit
}

Write-Host "FFmpeg detected successfully." -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------------------
# Select source folder
# ---------------------------------------------------------------------------

$SourcePath = Select-SourceFolder

# ---------------------------------------------------------------------------
# Select input type
# ---------------------------------------------------------------------------

$InputExtensions = Select-InputType

# ---------------------------------------------------------------------------
# Select output format
# ---------------------------------------------------------------------------

$OutputFormat = Select-OutputFormat

# ---------------------------------------------------------------------------
# Select quality if video output
# ---------------------------------------------------------------------------

if (Test-AudioOutput $OutputFormat.Extension) {

    $Quality = @{
        CRF  = "0"
        Name = "Audio"
    }

}
else {

    $Quality = Select-Quality
}

# ===========================================================================
# SETTINGS SUMMARY
# ===========================================================================

Write-Host ""
Write-Host "═════════════════════════════════════════" `
    -ForegroundColor Cyan

Write-Host "             CONVERSION SETTINGS"

Write-Host "═════════════════════════════════════════" `
    -ForegroundColor Cyan

Write-Host ""

Write-Host "Source folder : $SourcePath"
Write-Host "Input type    : $($InputExtensions -join ', ')"
Write-Host "Output format : $($OutputFormat.Name)"
Write-Host "Quality       : $($Quality.Name)"

Write-Host ""

# ===========================================================================
# FIND FILES
# ===========================================================================

Write-Host "Scanning for media files..." `
    -ForegroundColor Yellow

Write-Host ""

$files = @(
    Get-ChildItem `
        -Path $SourcePath `
        -File |
    Where-Object {
        $InputExtensions -contains $_.Extension.ToLower()
    }
)

if ($files.Count -eq 0) {

    Write-Host "✖ No matching media files were found." `
        -ForegroundColor Yellow

    Write-Host ""

    Read-Host "Press Enter to exit"
    exit
}

Write-Host "Found $($files.Count) media file(s)." `
    -ForegroundColor Green

Write-Host ""

# ===========================================================================
# DISPLAY FILES
# ===========================================================================

Write-Host "Files to convert:" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $files) {

    Write-Host "  - $($file.Name)"
}

Write-Host ""

# ===========================================================================
# CONFIRM
# ===========================================================================

$confirm = Read-Host "Start conversion? (Y/N)"

if ($confirm -notmatch "^(Y|y)$") {

    Write-Host ""
    Write-Host "Conversion cancelled." -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Press Enter to exit"
    exit
}

# ===========================================================================
# CREATE OUTPUT ROOT
# ===========================================================================

$OutputRoot = Join-Path `
    $SourcePath `
    $OutputFolderName

New-Item `
    -ItemType Directory `
    -Path $OutputRoot `
    -Force |
    Out-Null

# ===========================================================================
# COUNTERS
# ===========================================================================

$Converted = 0
$Failed = 0
$FailedFiles = @()

# ===========================================================================
# CONVERT FILES
# ===========================================================================

foreach ($file in $files) {

    $BaseName = $file.BaseName

    # Individual folder for each source file
    $OutputFolder = Join-Path `
        $OutputRoot `
        $BaseName

    New-Item `
        -ItemType Directory `
        -Path $OutputFolder `
        -Force |
        Out-Null

    $OutputFile = Join-Path `
        $OutputFolder `
        "$BaseName.$($OutputFormat.Extension)"

    Write-Host ""
    Write-Host "─────────────────────────────────────────" `
        -ForegroundColor DarkGray

    Write-Host "Converting:" -ForegroundColor Cyan
    Write-Host $file.Name

    Write-Host ""

    Write-Host "Output : $($OutputFormat.Name)"
    Write-Host "Quality: $($Quality.Name)"

    Write-Host ""

    $FFmpegArguments = Get-FFmpegArguments `
        -InputFile $file.FullName `
        -OutputFile $OutputFile `
        -OutputFormat $OutputFormat `
        -Quality $Quality

    & ffmpeg @FFmpegArguments

    if (
        $LASTEXITCODE -eq 0 -and
        (Test-Path $OutputFile)
    ) {

        Write-Host ""
        Write-Host "✔ Conversion successful" `
            -ForegroundColor Green

        Write-Host "  Output: $OutputFile"

        $Converted++

    }
    else {

        Write-Host ""
        Write-Host "✖ Conversion failed" `
            -ForegroundColor Red

        $Failed++

        $FailedFiles += $file.Name
    }
}

# ===========================================================================
# SUMMARY
# ===========================================================================

Write-Host ""
Write-Host ""
Write-Host "═════════════════════════════════════════" `
    -ForegroundColor Cyan

Write-Host "           CONVERSION COMPLETE"

Write-Host "═════════════════════════════════════════" `
    -ForegroundColor Cyan

Write-Host ""

Write-Host "Total files : $($files.Count)"

Write-Host "Converted   : $Converted" `
    -ForegroundColor Green

if ($Failed -gt 0) {

    Write-Host "Failed      : $Failed" `
        -ForegroundColor Red
}
else {

    Write-Host "Failed      : $Failed" `
        -ForegroundColor Green
}

# ===========================================================================
# FAILED FILES
# ===========================================================================

if ($FailedFiles.Count -gt 0) {

    Write-Host ""
    Write-Host "Failed files:" -ForegroundColor Red

    Write-Host ""

    foreach ($FailedFile in $FailedFiles) {

        Write-Host "  - $FailedFile" `
            -ForegroundColor Red
    }
}

# ===========================================================================
# DELETE ORIGINALS
# ===========================================================================

if ($Converted -gt 0) {

    Write-Host ""

    Write-Host "The original files are still present." `
        -ForegroundColor Yellow

    Write-Host ""

    $Delete = Read-Host `
        "Delete successfully converted original files? (Y/N)"

    if ($Delete -match "^(Y|y)$") {

        Write-Host ""

        Write-Host "Removing successfully converted files..." `
            -ForegroundColor Yellow

        foreach ($file in $files) {

            $BaseName = $file.BaseName

            $ConvertedFile = Join-Path `
                $OutputRoot `
                "$BaseName\$BaseName.$($OutputFormat.Extension)"

            # Only delete if the converted file exists
            if (Test-Path $ConvertedFile) {

                Remove-Item `
                    -Path $file.FullName `
                    -Force

                Write-Host "✔ Deleted: $($file.Name)" `
                    -ForegroundColor Green
            }
        }
    }
    else {

        Write-Host ""

        Write-Host "Original files have been kept." `
            -ForegroundColor Yellow
    }
}

# ===========================================================================
# FINISHED
# ===========================================================================

Write-Host ""
Write-Host "═════════════════════════════════════════" `
    -ForegroundColor Cyan

Write-Host "                  DONE"

Write-Host "═════════════════════════════════════════" `
    -ForegroundColor Cyan

Write-Host ""

Write-Host "Converted files:"
Write-Host $OutputRoot

Write-Host ""

Read-Host "Press Enter to exit"
```
