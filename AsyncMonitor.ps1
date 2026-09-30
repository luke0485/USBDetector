function New-UsbAsyncTask([string[]] $Functions, [string] $Body, $Shared) {
    $definitions = foreach ($name in $Functions) {
        'function ' + $name + ' {' + (Get-Command $name -CommandType Function -ErrorAction Stop).Definition + "}`n"
    }
    $initialization = @'
param($shared)
$ErrorActionPreference = 'Stop'
foreach ($module in @('Microsoft.PowerShell.Utility','Microsoft.PowerShell.Management','CimCmdlets')) {
    Import-Module (Join-Path $PSHOME ('Modules\' + $module + '\' + $module + '.psd1')) -ErrorAction Stop
}
'@
    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = 'MTA'
    $runspace.ThreadOptions = 'ReuseThread'
    $runspace.Open()
    $pipeline = [PowerShell]::Create()
    $pipeline.Runspace = $runspace
    [void]$pipeline.AddScript($initialization + "`n" + ($definitions -join "`n") + "`n" + $Body).AddArgument($Shared)
    try {
        $handle = $pipeline.BeginInvoke()
        return [pscustomobject]@{PowerShell=$pipeline; Runspace=$runspace; Handle=$handle}
    } catch { $pipeline.Dispose(); $runspace.Dispose(); throw }
}
function Close-UsbAsyncTask($Task) {
    if ($null -eq $Task) { return }
    if ($Task.Handle.IsCompleted) {
        try { [void]$Task.PowerShell.EndInvoke($Task.Handle) } catch {}
        $Task.PowerShell.Dispose(); $Task.Runspace.Dispose()
    } else {
        # Stopping a slow provider must not hold the GUI thread.
        [void]$Task.PowerShell.BeginStop($null,$null)
    }
}
function Start-UsbBackgroundMonitors {
    $script:monitorCancel = [Threading.ManualResetEvent]::new($false)
    $script:scanRequest = [Threading.AutoResetEvent]::new($false)
    $script:scanResults = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    $script:backgroundStatus = New-Object 'System.Collections.Concurrent.ConcurrentDictionary[string,string]'
    $hardware = @{Cancel=$script:monitorCancel; Request=$script:scanRequest; Results=$script:scanResults}
    $scanBody = @'
$script:containerIdCache = @{}
while (-not $shared.Cancel.WaitOne(0)) {
    try {
        $disks = @(Get-UsbPhysicalDisks)
        $devices = @(Get-UsbDevices $disks)
        $volumes = @(Get-UsbVolumes $disks)
        $currentIds = @{}
        foreach ($device in $devices) { $currentIds[[string]$device.InstanceId] = $true }
        foreach ($cachedId in @($script:containerIdCache.Keys)) { if (-not $currentIds.ContainsKey($cachedId)) { $script:containerIdCache.Remove($cachedId) } }
        $snapshot = [pscustomobject]@{Devices=$devices; Volumes=$volumes; Error=''}
    } catch { $snapshot = [pscustomobject]@{Devices=@(); Volumes=@(); Error=$_.Exception.Message} }
    if ($shared.Cancel.WaitOne(0)) { break }
    $previous = $null
    while ($shared.Results.Count -gt 0) { [void]$shared.Results.TryDequeue([ref]$previous) }
    $shared.Results.Enqueue($snapshot)
    $wait = [Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]@($shared.Cancel,$shared.Request),8000)
    if ($wait -eq 0) { break }
}
'@
    $script:hardwareTask = New-UsbAsyncTask @('Get-UsbPhysicalDisks','Get-UsbDevices','Get-UsbVolumes','Get-DeviceType','Get-DeviceContainerId') $scanBody $hardware
    $process = @{
        Cancel=$script:monitorCancel; Status=$script:backgroundStatus
        Events=$script:processEvents; Drives=$script:activeUsbDrives; Instances=$script:usbDriveInstances
        Chains=$script:trackedUsbProcesses; Overflow=$script:usbProcessEventOverflow; Errors=$script:processMonitorErrors
    }
    $processBody = @'
$script:processEvents = $shared.Events
$script:activeUsbDrives = $shared.Drives
$script:usbDriveInstances = $shared.Instances
$script:trackedUsbProcesses = $shared.Chains
$script:usbProcessEventOverflow = $shared.Overflow
$script:processMonitorErrors = $shared.Errors
$script:processEventSource = 'USBMON-PROCESSSTART-BACKGROUND'
$script:processMonitorDiagnostics = $null
function Add-LogLine([string]$Message) {}
try {
    Start-ProcessMonitor
    $shared.Status['Process'] = $script:processMonitorStatus
    while (-not $shared.Cancel.WaitOne(1000)) {
        Invoke-UsbProcessPoll
        Prune-UsbProcessChains
        $shared.Status['Process'] = $script:processMonitorStatus
    }
} catch { $shared.Status['Process'] = '失败：' + $_.Exception.Message }
finally {
    Unregister-Event -SourceIdentifier $script:processEventSource -ErrorAction SilentlyContinue
    Get-Job -Name $script:processEventSource -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
}
'@
    $script:processTask = New-UsbAsyncTask @('Start-ProcessMonitor','Invoke-UsbProcessPoll','Prune-UsbProcessChains') $processBody $process
    $files = @{Cancel=$script:monitorCancel; Input=$script:fileEventsRaw; Output=$script:fileEvents; Overflow=$script:fileWatcherOverflow; Drives=$script:activeUsbDrives; Instances=$script:usbDriveInstances}
    $fileBody = @'
$script:fileEventsRaw=$shared.Input
$script:fileEvents=$shared.Output
$script:fileWatcherOverflow=$shared.Overflow
$script:fileWatchers=@{}; $script:fileWatcherSources=@{}; $script:fileWatcherRecoveryAt=@{}
$watcherInstances=@{}
function Add-LogLine([string]$Message) {}
try { while (-not $shared.Cancel.WaitOne(50)) {
    foreach ($drive in @($script:fileWatchers.Keys)) {
        if (-not $shared.Drives.ContainsKey($drive) -or -not $shared.Drives[$drive] -or $watcherInstances[$drive] -ne [string]$shared.Instances[$drive]) { Remove-VolumeWatcher $drive; $watcherInstances.Remove($drive) }
    }
    foreach ($drive in @($shared.Drives.Keys)) {
        if ($shared.Drives[$drive]) {
            Add-VolumeWatcher $drive
            if ($script:fileWatchers.ContainsKey($drive)) { $watcherInstances[$drive]=[string]$shared.Instances[$drive] }
        }
    }
    $entry = ''
    while (-not $shared.Cancel.WaitOne(0) -and $shared.Input.TryDequeue([ref]$entry)) {
        $parts = [regex]::Split($entry,'\|',4)
        if ($parts.Count -lt 4) { continue }
        $path = $parts[3]
        $arrow = $path.LastIndexOf(' -> ')
        if ($arrow -ge 0) { $path = $path.Substring($arrow+4) }
        $attributes = [IO.FileAttributes]::Normal
        if ($parts[2] -ne 'DELETED') { try { $attributes = [IO.File]::GetAttributes($path) } catch {} }
        if ($shared.Output.Count -lt 1000) {
            $shared.Output.Enqueue(('FILE|{0}|{1}|{2}|{3}' -f $parts[1],$parts[2],[int]$attributes,$parts[3]))
        } else { [void]$shared.Overflow.TryAdd([string]$parts[1],$true) }
    }
} } finally { foreach ($drive in @($script:fileWatchers.Keys)) { Remove-VolumeWatcher $drive } }
'@
    $script:fileTask = New-UsbAsyncTask @('Add-VolumeWatcher','Remove-VolumeWatcher') $fileBody $files
}
function Receive-UsbBackgroundResults {
    if ($script:backgroundStatus.ContainsKey('Process')) { $script:processMonitorStatus = $script:backgroundStatus['Process'] }
    $snapshot = $null
    if ($script:scanResults.TryDequeue([ref]$snapshot)) {
        if ($snapshot.Error) { Add-LogLine ('设备查询失败，保留上次结果：' + $snapshot.Error) }
        else { Refresh-Views $snapshot }
    }
    foreach ($task in @($script:hardwareTask,$script:processTask,$script:fileTask)) {
        if ($null -ne $task -and $task.Handle.IsCompleted -and $task.PowerShell.HadErrors) {
            if (-not $task.PSObject.Properties['ErrorReported']) {
                Add-LogLine ('后台查询失败：' + ($task.PowerShell.Streams.Error | Select-Object -First 1))
                $task | Add-Member NoteProperty ErrorReported $true
            }
        }
    }
}
