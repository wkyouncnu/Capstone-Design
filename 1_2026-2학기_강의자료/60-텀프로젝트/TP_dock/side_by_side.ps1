# side_by_side.ps1 — 창 둘을 좌·우로 붙여 놓고 화면 전체를 한 장으로 담는다
#
#   용도 : 가제보(왼쪽) · RViz2 또는 MATLAB GCS(오른쪽) 를 한 화면에 보이게 한다
#
#   powershell -ExecutionPolicy Bypass -File side_by_side.ps1 `
#       -Left "Gazebo" -Right "tp_dock.rviz" -Out shots\dock_rviz.png
#
#   유의 사항
#     - 제목 일부만 주면 된다. 여러 개가 맞으면 **처음 찾은 것**을 쓴다
#     - 좌표는 물리 픽셀이다. 화면 배율이 125 % 여도 이 값이 기준이 된다
#     - 창을 못 찾으면 그 창은 건너뛰고 캡처는 그대로 한다 (어디까지 됐는지 보려고)

param(
  [string]$Left  = "Gazebo",
  [string]$Right = "RViz",
  [string]$Out   = "shots\side_by_side.png",
  [int]$Gap      = 0,
  [int]$Wait     = 1200
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class SBS {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int t, bool r);
}
"@

function Find-WindowHandle([string]$needle) {
  $found = [IntPtr]::Zero
  $cb = [SBS+EnumWindowsProc]{
    param($h, $l)
    if (-not [SBS]::IsWindowVisible($h)) { return $true }
    $n = [SBS]::GetWindowTextLength($h)
    if ($n -le 0) { return $true }
    $sb = New-Object System.Text.StringBuilder ($n + 1)
    [void][SBS]::GetWindowText($h, $sb, $sb.Capacity)
    if ($sb.ToString() -like "*$needle*") { $script:found = $h; return $false }
    return $true
  }
  [void][SBS]::EnumWindows($cb, [IntPtr]::Zero)
  return $script:found
}

$scr = [System.Windows.Forms.Screen]::PrimaryScreen
$SW = $scr.Bounds.Width
$SH = $scr.Bounds.Height
$halfW = [int](($SW - $Gap) / 2)

$pairs = @(
  @{ Name = $Left;  X = 0 },
  @{ Name = $Right; X = $halfW + $Gap }
)
foreach ($p in $pairs) {
  $h = Find-WindowHandle $p.Name
  if ($h -eq [IntPtr]::Zero) {
    Write-Output ("창을 못 찾음 : {0}" -f $p.Name)
    continue
  }
  [void][SBS]::ShowWindow($h, 9)          # 9 = SW_RESTORE (최소화 풀기)
  [void][SBS]::MoveWindow($h, $p.X, 0, $halfW, $SH, $true)
  [void][SBS]::SetForegroundWindow($h)
  Write-Output ("배치 : {0}  ->  x {1} 폭 {2}" -f $p.Name, $p.X, $halfW)
  Start-Sleep -Milliseconds 400
}

Start-Sleep -Milliseconds $Wait

#  절대 경로를 Join-Path 로 또 이으면 깨진다 — 뿌리인지 먼저 본다
if ([System.IO.Path]::IsPathRooted($Out)) { $dst = $Out }
else { $dst = Join-Path (Get-Location).Path $Out }
$dir = Split-Path -Parent $dst
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
$bmp = New-Object System.Drawing.Bitmap $SW, $SH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output ("저장 : {0}  ({1} x {2})" -f $dst, $SW, $SH)
