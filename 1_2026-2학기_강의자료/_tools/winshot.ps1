# ui.ps1 — 창을 앞으로 놓고, 좌표 클릭·문자 입력·단축키를 보낸 뒤 캡처한다.
#   -Match  대상 창 제목 일부
#   -Do     "click:44,439|type:WSL|key:ctrl+shift+x|sleep:1500" 형태의 동작 목록
#   -Out    저장 경로 (없으면 캡처하지 않음)
# 좌표는 화면(=캡처 이미지) 물리 픽셀 기준이다.
param(
  [string]$Match = "Visual Studio Code",
  [string]$Do    = "",
  [string]$Out   = "",
  [int]$W = 0,
  [int]$H = 0,
  [int]$Wait = 1500
)

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class U {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int t, bool r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] i, int cb);
  [DllImport("user32.dll")] public static extern short VkKeyScanW(char c);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KEYBDINPUT ki; }
  public const uint KEYEVENTF_KEYUP = 0x0002;
  public const uint KEYEVENTF_UNICODE = 0x0004;
  public static void Key(ushort vk, bool up) {
    INPUT[] i = new INPUT[1];
    i[0].type = 1;
    i[0].ki.wVk = vk;
    i[0].ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
  public static void Uni(char c, bool up) {
    INPUT[] i = new INPUT[1];
    i[0].type = 1;
    i[0].ki.wVk = 0;
    i[0].ki.wScan = (ushort)c;
    i[0].ki.dwFlags = KEYEVENTF_UNICODE | (up ? KEYEVENTF_KEYUP : 0);
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
}
"@

[void][U]::SetProcessDPIAware()

$VK = @{
  'ctrl'=0x11; 'shift'=0x10; 'alt'=0x12; 'enter'=0x0D; 'tab'=0x09; 'esc'=0x1B;
  'back'=0x08; 'del'=0x2E; 'up'=0x26; 'down'=0x28; 'left'=0x25; 'right'=0x27;
  'home'=0x24; 'end'=0x23; 'space'=0x20; 'f1'=0x70; 'f5'=0x74;
  'a'=0x41;'b'=0x42;'c'=0x43;'d'=0x44;'e'=0x45;'f'=0x46;'g'=0x47;'h'=0x48;'i'=0x49;
  'j'=0x4A;'k'=0x4B;'l'=0x4C;'m'=0x4D;'n'=0x4E;'o'=0x4F;'p'=0x50;'q'=0x51;'r'=0x52;
  's'=0x53;'t'=0x54;'u'=0x55;'v'=0x56;'w'=0x57;'x'=0x58;'y'=0x59;'z'=0x5A;
  'grave'=0xC0; 'backtick'=0xC0
}

$acc = New-Object System.Collections.ArrayList
$cb = [U+EnumWindowsProc]{
  param($h, $l)
  if ([U]::IsWindowVisible($h)) {
    $len = [U]::GetWindowTextLength($h)
    if ($len -gt 0) {
      $sb = New-Object System.Text.StringBuilder ($len + 2)
      [void][U]::GetWindowText($h, $sb, $sb.Capacity)
      $null = $acc.Add([pscustomobject]@{ H = $h; T = $sb.ToString() })
    }
  }
  return $true
}
[void][U]::EnumWindows($cb, [IntPtr]::Zero)
$win = $acc | Where-Object { $_.T -like "*$Match*" } | Select-Object -First 1
if (-not $win) { Write-Output "NOTFOUND: $Match"; $acc | ForEach-Object { "  candidate: " + $_.T }; exit 2 }

[void][U]::ShowWindow($win.H, 9)
[void][U]::SetForegroundWindow($win.H)
Start-Sleep -Milliseconds 600
if ($W -gt 0 -and $H -gt 0) {
  [void][U]::MoveWindow($win.H, 0, 0, $W, $H, $true)
  Start-Sleep -Milliseconds 700
}
[void][U]::SetForegroundWindow($win.H)
Start-Sleep -Milliseconds 500

foreach ($step in ($Do -split '\|')) {
  if (-not $step) { continue }
  $kind, $arg = $step -split ':', 2
  switch ($kind) {
    'click' {
      $xy = $arg -split ','
      [void][U]::SetCursorPos([int]$xy[0], [int]$xy[1])
      Start-Sleep -Milliseconds 250
      [U]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)   # LEFTDOWN
      Start-Sleep -Milliseconds 60
      [U]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)   # LEFTUP
    }
    'type' {
      foreach ($ch in $arg.ToCharArray()) {
        [U]::Uni($ch, $false); Start-Sleep -Milliseconds 25
        [U]::Uni($ch, $true);  Start-Sleep -Milliseconds 25
      }
    }
    'key' {
      $parts = $arg -split '\+'
      $mods = @(); $main = $null
      foreach ($p in $parts) {
        if ($p -in @('ctrl','shift','alt')) { $mods += $VK[$p] } else { $main = $VK[$p] }
      }
      foreach ($m in $mods) { [U]::Key([uint16]$m, $false); Start-Sleep -Milliseconds 40 }
      if ($main) { [U]::Key([uint16]$main, $false); Start-Sleep -Milliseconds 60; [U]::Key([uint16]$main, $true) }
      [array]::Reverse($mods)
      foreach ($m in $mods) { Start-Sleep -Milliseconds 40; [U]::Key([uint16]$m, $true) }
    }
    'move' { $xy = $arg -split ','; [void][U]::SetCursorPos([int]$xy[0], [int]$xy[1]) }
    'sleep' { Start-Sleep -Milliseconds ([int]$arg) }
  }
  Start-Sleep -Milliseconds 400
}

if (-not $Out) { Write-Output "DONE (no capture)"; exit 0 }
Start-Sleep -Milliseconds $Wait

$fg = [U]::GetForegroundWindow()
if ($fg -ne $win.H) {
  [void][U]::SetForegroundWindow($win.H); Start-Sleep -Milliseconds 800
  $fg = [U]::GetForegroundWindow()
  if ($fg -ne $win.H) { Write-Output "FOREGROUND MISMATCH - not saving"; exit 3 }
}

$r = New-Object U+RECT
$hr = [U]::DwmGetWindowAttribute($win.H, 9, [ref]$r, 16)
if ($hr -ne 0) { [void][U]::GetWindowRect($win.H, [ref]$r) }
$cw = $r.Right - $r.Left; $ch = $r.Bottom - $r.Top
if ($cw -le 0 -or $ch -le 0) { Write-Output "BADRECT $cw x $ch"; exit 4 }

$bmp = New-Object System.Drawing.Bitmap $cw, $ch
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($cw, $ch)))
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("SAVED {0}  {1}x{2}  rect={3},{4}  <- {5}" -f $Out, $cw, $ch, $r.Left, $r.Top, $win.T)
