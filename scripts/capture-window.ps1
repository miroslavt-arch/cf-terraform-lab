# Capture ONE window to a PNG, for building the screenshot guide.
#
# Scoped to a single window on purpose: capturing the whole desktop would pull
# in whatever else is open. Pass a window-title substring and an output path.
#
#   powershell -File scripts/capture-window.ps1 -TitleMatch "Chrome" -Out docs/img/03-x.png
param(
  [Parameter(Mandatory = $true)][string]$TitleMatch,
  [Parameter(Mandatory = $true)][string]$Out,
  # Pixels to trim off the top. Defaults to 150, which removes Chrome's tab
  # strip, address bar and any debug banner. The tab strip leaks whatever else
  # you have open (mail subjects, account names) into a client-facing guide,
  # so it is cropped by default rather than as an afterthought.
  [int]$CropTop = 150,
  # Capture the primary screen without touching focus. Needed when a native
  # dropdown is open: focusing the parent window would dismiss it, and the
  # popup owns the window title so a title match fails.
  [switch]$NoFocus,
  # Pixels to trim off the bottom, to drop the Windows taskbar.
  [int]$CropBottom = 60
)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@

if ($NoFocus) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $capH = $b.Height - $CropTop - $CropBottom
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $capH
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.X, ($b.Y + $CropTop), 0, 0, $bmp.Size)
  $dir = Split-Path -Parent $Out
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "OK (nofocus): $Out ($($b.Width)x$capH, cropped ${CropTop}px)"
  exit 0
}

$proc = Get-Process |
  Where-Object { $_.MainWindowTitle -and $_.MainWindowTitle -like "*$TitleMatch*" } |
  Select-Object -First 1

if (-not $proc) {
  Write-Output "NOTFOUND: no window whose title contains '$TitleMatch'"
  exit 1
}

$h = $proc.MainWindowHandle
if ([Win]::IsIconic($h)) { [Win]::ShowWindow($h, 9) | Out-Null }   # 9 = SW_RESTORE
[Win]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 900

$r = New-Object Win+RECT
[Win]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.R - $r.L
$hgt = $r.B - $r.T
if ($w -le 0 -or $hgt -le 0) { Write-Output "BADRECT: ${w}x${hgt}"; exit 1 }

if (($CropTop + $CropBottom) -ge $hgt) { Write-Output "CROPTOOBIG"; exit 1 }
$capH = $hgt - $CropTop - $CropBottom
$bmp = New-Object System.Drawing.Bitmap $w, $capH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, ($r.T + $CropTop), 0, 0, $bmp.Size)

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

Write-Output "OK: $Out ($($w)x$($capH), cropped ${CropTop}px) from '$($proc.MainWindowTitle)'"
