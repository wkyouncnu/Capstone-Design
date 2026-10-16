# wincap.ps1 — 창을 앞으로 가져오지 않고 그 창만 캡처한다 (PrintWindow)
#   -Match  창 제목 일부 (부분 일치, 첫 번째 창)
#   -Out    저장 경로 (.png)
#   -W -H   창 크기를 이 값으로 바꾼 뒤 찍는다 (0 이면 그대로)
#
#   winshot.ps1 은 창을 앞으로 놓고 클릭·입력을 보낸다 — 사용자가 PC 를 쓰는 중이면
#   포커스를 빼앗고, 앞으로 못 오면 "FOREGROUND MISMATCH" 로 저장을 거부한다.
#   이 스크립트는 입력을 보내지 않으므로 사용자가 다른 창을 쓰는 중에도 찍힌다 (2026-10-16).
#   Windows Terminal · VS Code · MATLAB 에서 확인. 최소화된 창은 포커스 없이 복원한 뒤 찍는다.
param(
  [string]$Match = "Visual Studio Code",
  [string]$Out   = "",
  [int]$W = 0,
  [int]$H = 0
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class P {
  public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int t, bool r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[void][P]::SetProcessDPIAware()

$found = New-Object System.Collections.ArrayList
$cb = [P+EnumWindowsProc]{ param($h, $l)
  if ([P]::IsWindowVisible($h)) {
    $sb = New-Object System.Text.StringBuilder 512
    [void][P]::GetWindowText($h, $sb, 512)
    $t = $sb.ToString()
    # -like 는 [ ] 를 와일드카드로 읽는다 — "[WSL: ...]" 제목이 깨지므로 부분 문자열로 찾는다
    if ($t.Contains($Match)) { [void]$found.Add(@{H=$h; T=$t}) }
  }
  return $true }
[void][P]::EnumWindows($cb, [IntPtr]::Zero)
if ($found.Count -eq 0) { Write-Output "NOTFOUND: $Match"; exit 2 }
$win = $found[0]
Write-Output ("WINDOW: " + $win.T)

# 최소화돼 있으면 포커스를 주지 않고 복원한다 (4 = SW_SHOWNOACTIVATE)
if ([P]::IsIconic($win.H)) { [void][P]::ShowWindow($win.H, 4); Start-Sleep -Milliseconds 1500 }

if ($W -gt 0 -and $H -gt 0) {
  $r0 = New-Object P+RECT; [void][P]::GetWindowRect($win.H, [ref]$r0)
  [void][P]::MoveWindow($win.H, $r0.Left, $r0.Top, $W, $H, $true)
  Start-Sleep -Milliseconds 1200
}
$r = New-Object P+RECT; [void][P]::GetWindowRect($win.H, [ref]$r)
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$dc = $g.GetHdc()
[void][P]::PrintWindow($win.H, $dc, 2)      # 2 = PW_RENDERFULLCONTENT (GPU 로 그리는 창도 찍힘)
$g.ReleaseHdc($dc); $g.Dispose()
if ($Out -ne "") { $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); Write-Output "SAVED $Out ${w}x${h}" }
$bmp.Dispose()
