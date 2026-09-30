$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
$launcher = Join-Path $root 'LaunchUSBMonitor.vbs'
$icon = Join-Path $root 'usb-monitor-v2.ico'
if (!(Test-Path -LiteralPath $wscript)) { throw 'Windows Script Host 未找到。' }
if (!(Test-Path -LiteralPath $launcher)) { throw '隐藏启动器未找到。' }
if (!(Test-Path -LiteralPath $icon -PathType Leaf)) { throw '快捷方式图标未找到。' }
Add-Type -AssemblyName System.Drawing
$validatedIcon = [System.Drawing.Icon]::new($icon)
$validatedIcon.Dispose()
$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$startup = [Environment]::GetFolderPath('Startup')
foreach ($folder in @($desktop, $startup)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
$desktopLink = $shell.CreateShortcut((Join-Path $desktop 'USB检测器.lnk'))
$desktopLink.TargetPath = $wscript
$desktopLink.Arguments = '"' + $launcher + '"'
$desktopLink.WorkingDirectory = $root
$desktopLink.Description = 'USB MONITOR'
$desktopLink.IconLocation = $icon + ',0'
$desktopLink.Save()
$startupLink = $shell.CreateShortcut((Join-Path $startup 'USB检测器.lnk'))
$startupLink.TargetPath = $wscript
$startupLink.Arguments = '"' + $launcher + '" -Tray'
$startupLink.WorkingDirectory = $root
$startupLink.Description = 'USB MONITOR - tray'
$startupLink.IconLocation = $icon + ',0'
$startupLink.Save()
Write-Output 'Shortcuts installed.'
if (-not ('USBDetectorShellNotify' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class USBDetectorShellNotify {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern void SHChangeNotify(uint eventId, uint flags, string item, IntPtr item2);
}
"@
}
foreach ($linkPath in @((Join-Path $desktop 'USB检测器.lnk'), (Join-Path $startup 'USB检测器.lnk'))) {
    $check = $shell.CreateShortcut($linkPath)
    if ($check.TargetPath -ne $wscript -or $check.IconLocation -ne ($icon + ',0')) { throw "快捷方式校验失败：$linkPath" }
    [USBDetectorShellNotify]::SHChangeNotify(0x00002000, 0x0005, $linkPath, [IntPtr]::Zero)
}
