# Media Converter v3.0

A PowerShell-based media conversion tool that uses **FFmpeg** to convert multiple video and audio files between common formats.

## Features

- Convert multiple media files at once
- Select a source folder
- Select the input media type
- Select the output format
- Select video quality
- Supports custom CRF values
- Automatically selects the appropriate codec for the selected format
- Creates an individual output folder for each converted file
- Displays a conversion summary
- Reports failed conversions
- Optionally deletes successfully converted original files
- Supports both video and audio conversion
- Uses FFmpeg for reliable media conversion

---

## Supported Input Formats

### Video

- MP4
- MKV
- AVI
- MOV
- FLV
- WebM
- WMV
- MPEG
- MPG
- M4V
- TS
- MTS
- M2TS
- 3GP
- OGV

### Audio

- MP3
- WAV
- AAC
- FLAC
- OGG
- M4A
- WMA

---

## Supported Output Formats

### Video

| Format | Extension |
|---|---|
| MP4 | `.mp4` |
| MKV | `.mkv` |
| AVI | `.avi` |
| MOV | `.mov` |
| FLV | `.flv` |
| WebM | `.webm` |

### Audio

| Format | Extension |
|---|---|
| MP3 | `.mp3` |
| WAV | `.wav` |
| FLAC | `.flac` |
| M4A | `.m4a` |

---

# Requirements

- Windows
- PowerShell 5.1 or newer
- FFmpeg
- Sufficient disk space for converted files

The script requires the `ffmpeg` command to be available through the Windows `PATH`.

---

# Installing FFmpeg

## Option 1 — Install with Winget

The easiest method on modern versions of Windows is using **Windows Package Manager (winget)**.

Open **PowerShell** or **Command Prompt** and run:

```powershell
winget install Gyan.FFmpeg
```

Allow the installation to complete.

After installation, close PowerShell and open a **new** PowerShell window.

Test FFmpeg:

```powershell
ffmpeg -version
```

If FFmpeg is installed correctly, you should see information about the installed FFmpeg version.

---

## Option 2 — Download FFmpeg Manually

If `winget` is unavailable, FFmpeg can be downloaded manually.

Download a Windows build from:

- https://www.gyan.dev/ffmpeg/builds/
- https://ffmpeg.org/download.html

For a normal Windows installation, the **full build** from Gyan is suitable.

Download the ZIP archive and extract it.

For example:

```text
C:\ffmpeg\
```

The folder structure should contain a `bin` directory:

```text
C:\ffmpeg\bin\
```

Inside the `bin` directory you should have:

```text
ffmpeg.exe
ffprobe.exe
ffplay.exe
```

---

# Adding FFmpeg to PATH

The Media Converter expects `ffmpeg.exe` to be available through the Windows `PATH`.

## 1. Open Environment Variables

Press:

```text
Windows Key + R
```

Enter:

```text
sysdm.cpl
```

Press **Enter**.

Go to:

**Advanced → Environment Variables**

---

## 2. Edit PATH

Under either **User variables** or **System variables**, find:

```text
Path
```

Select it and click:

**Edit**

Click:

**New**

Add:

```text
C:\ffmpeg\bin
```

If you extracted FFmpeg somewhere else, use the path to its `bin` folder.

For example:

```text
C:\Tools\ffmpeg\bin
```

Click **OK** on all open windows.

---

## 3. Verify the Installation

Close any existing PowerShell or Command Prompt windows.

Open a **new** PowerShell window and run:

```powershell
ffmpeg -version
```

You can also run:

```powershell
Get-Command ffmpeg
```

You should see something similar to:

```text
CommandType     Name
-----------     ----
Application     ffmpeg.exe
```

If this works, FFmpeg is ready to use.

---

# Installation of Media Converter

The Media Converter itself does not require a traditional installation.

Save the PowerShell script as:

```text
MediaConverter.ps1
```

For example:

```text
C:\Tools\Media Converter\MediaConverter.ps1
```

You can then run it from PowerShell:

```powershell
.\MediaConverter.ps1
```

---

# PowerShell Execution Policy

If Windows prevents the script from running because of the execution policy, you can allow the script for the current PowerShell session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run:

```powershell
.\MediaConverter.ps1
```

This does **not** permanently change the machine's execution policy.

---

# How to Use

When the script starts, it displays the Media Converter banner:

```text
╔══════════════════════════════════════════╗
║             Media Converter              ║
║                  v3.0                    ║
╚══════════════════════════════════════════╝
```

The script then checks that FFmpeg is installed.

If FFmpeg is detected, you will be asked for the source folder.

---

## 1. Select Source Folder

Enter the folder containing the files you want to convert.

Example:

```text
C:\Users\Will\Videos
```

The script checks that the folder exists before continuing.

---

## 2. Select Input Type

You will be presented with options such as:

```text
1. MP4
2. MKV
3. AVI
4. MOV
5. FLV
6. WebM
7. WMV
8. MPEG / MPG
9. M4V
10. TS / MTS / M2TS
11. Audio files
12. All supported media
```

Select the type of files you want to convert.

For example:

```text
Enter your choice (1-12): 1
```

The script will then search the source folder for `.mp4` files.

---

## 3. Select Output Format

You can choose from:

```text
1. MP4
2. MKV
3. AVI
4. MOV
5. FLV
6. WebM
7. MP3
8. WAV
9. FLAC
10. M4A
```

For example:

```text
Enter your choice (1-10): 1
```

This converts the selected files to MP4.

---

# Video Quality

For video output, the script allows you to select:

```text
1. High
2. Medium
3. Low
4. Custom CRF
```

## High

Uses:

```text
CRF 18
```

Provides high visual quality with relatively large files.

## Medium

Uses:

```text
CRF 23
```

Provides a good balance between quality and file size.

## Low

Uses:

```text
CRF 28
```

Produces smaller files at the expense of additional compression.

## Custom CRF

You can enter any CRF value between:

```text
0 - 51
```

Generally:

```text
Lower CRF = Higher quality / Larger file

Higher CRF = Lower quality / Smaller file
```

A value around **18–23** is generally suitable for normal video conversion.

---

# Audio Conversion

When converting to an audio-only format such as MP3, WAV, FLAC or M4A, the video stream is removed.

For example:

```text
MP4 → MP3
```

will extract the audio from the video file.

The video quality option is skipped because there is no video being produced.

---

# Output Folder Structure

The script creates a folder called:

```text
Converted Media
```

inside the source folder.

Each source file receives its own folder.

For example, if the source folder contains:

```text
C:\Videos\Camera01.mp4
C:\Videos\Camera02.mp4
C:\Videos\Camera03.mp4
```

the output will look like:

```text
C:\Videos\
│
├── Camera01.mp4
├── Camera02.mp4
├── Camera03.mp4
│
└── Converted Media\
    │
    ├── Camera01\
    │   └── Camera01.mp4
    │
    ├── Camera02\
    │   └── Camera02.mp4
    │
    └── Camera03\
        └── Camera03.mp4
```

This keeps each converted file organised separately.

---

# Conversion Confirmation

Before conversion begins, the script displays a summary similar to:

```text
═════════════════════════════════════════
             CONVERSION SETTINGS
═════════════════════════════════════════

Source folder : C:\Videos
Input type    : .mp4
Output format : MP4
Quality       : Medium
```

It then displays all files that will be converted.

You will be asked:

```text
Start conversion? (Y/N)
```

Enter:

```text
Y
```

to start.

Enter:

```text
N
```

to cancel.

---

# Conversion Process

FFmpeg handles each file individually.

For every file, the script displays:

```text
Converting:
Camera01.mp4

Output : MP4
Quality: Medium
```

FFmpeg then performs the conversion.

After a successful conversion:

```text
✔ Conversion successful
```

If FFmpeg reports an error:

```text
✖ Conversion failed
```

The failed filename is added to the final report.

---

# Conversion Summary

Once all files have been processed, the script displays a summary:

```text
═════════════════════════════════════════
           CONVERSION COMPLETE
═════════════════════════════════════════

Total files : 10
Converted   : 9
Failed      : 1
```

If files failed, they are listed individually:

```text
Failed files:

  - Camera07.mp4
```

---

# Deleting Original Files

After conversion, the original files are **not automatically deleted**.

If at least one conversion was successful, you will be asked:

```text
Delete successfully converted original files? (Y/N)
```

Selecting:

```text
Y
```

will delete only originals for which a converted output file exists.

Selecting:

```text
N
```

will keep the originals.

This provides an additional safeguard against losing files when a conversion fails.

---

# Important Notes

## Original Files

Original files are kept by default.

Do not delete them manually until you have confirmed that the converted files work correctly.

---

## Existing Output Files

The script uses FFmpeg's:

```text
-y
```

option.

This means FFmpeg will automatically overwrite an existing output file with the same name.

---

## FFmpeg Errors

If a particular file cannot be converted, the script continues processing the remaining files rather than stopping the entire conversion.

The failed files are listed in the final summary.

---

# Troubleshooting

## FFmpeg was not found

If you see:

```text
✖ FFmpeg was not found.
```

run:

```powershell
ffmpeg -version
```

If Windows says that `ffmpeg` is not recognised, FFmpeg is either not installed or its `bin` directory is not in your `PATH`.

After changing PATH, make sure you open a **new** PowerShell window.

---

## No Matching Media Files

If you see:

```text
✖ No matching media files were found.
```

check:

1. The source folder is correct.
2. The files are actually inside that folder.
3. The selected input type matches the file extensions.
4. The files use one of the supported extensions.

For example, selecting:

```text
1. MP4
```

will only find:

```text
.mp4
```

files.

---

## Permission Errors

If FFmpeg cannot read the source file or write the converted file, check that your Windows account has permission to access the source and destination folders.

Avoid converting files directly from locations where your account does not have appropriate access.

---

# Example

Suppose you have:

```text
C:\Camera Footage\
```

containing:

```text
Camera01.mkv
Camera02.mkv
Camera03.mkv
```

You could select:

```text
Source folder:
C:\Camera Footage

Input type:
2. MKV

Output format:
1. MP4

Quality:
2. Medium
```

The script would create:

```text
C:\Camera Footage\Converted Media\
```

and:

```text
Converted Media\
├── Camera01\
│   └── Camera01.mp4
├── Camera02\
│   └── Camera02.mp4
└── Camera03\
    └── Camera03.mp4
```

---

# FFmpeg Codecs Used

The script automatically selects codecs based on the output format.

| Output | Video Codec | Audio Codec |
|---|---|---|
| MP4 | H.264 | AAC |
| MKV | H.264 | AAC |
| AVI | H.264 | AAC |
| MOV | H.264 | AAC |
| FLV | H.264 | AAC |
| WebM | VP9 | Opus |
| MP3 | — | MP3 |
| WAV | — | PCM |
| FLAC | — | FLAC |
| M4A | — | AAC |

For MP4 files, the script also enables:

```text
+faststart
```

This moves the required MP4 metadata to the beginning of the file, which can improve playback when the file is being streamed or accessed before the entire file has downloaded.

---

# Project Structure

A simple setup can look like:

```text
Media Converter\
│
├── MediaConverter.ps1
└── README.md
```

FFmpeg is installed separately and does not need to be stored inside the Media Converter folder.

---

# License

This script is provided for personal and internal use.

The Media Converter itself is a PowerShell script and relies on FFmpeg for media processing. FFmpeg is a separate open-source project and is distributed under its own licensing terms.

For FFmpeg licensing information, refer to the official FFmpeg documentation and project website.

---

# Version History

## v3.0

- Renamed from CCTV Converter to Media Converter
- Added support for general video conversion
- Added support for audio conversion
- Added multiple input formats
- Added multiple output formats
- Added video quality selection
- Added custom CRF support
- Added automatic codec selection
- Added individual output folders
- Added conversion summary
- Added failed-file reporting
- Added optional deletion of successfully converted originals
- Added MP4 fast-start support
- Added batch conversion