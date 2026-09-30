<p align="center"><img src="logo.jpg" width="110" alt="USB 检测器图标"></p>
<h1 align="center">USB 检测器</h1>
<p align="center">扫描 · 监听 · 查询 · 行为查看 · 手动阻断</p>

<p align="center"><img src="docs/overview.svg" width="800" alt="USB 检测器功能示意"></p>

一款 Windows 桌面 USB 检测工具，支持扫描、监听和设备查询。可以查看文件变化及关联进程等行为，并手动阻断 USB 设备。支持最小化到托盘，在后台持续监听。

| 功能 | 用途 |
| --- | --- |
| 设备查询 | 查看 USB 设备、存储卷和硬件标识 |
| 扫描巡检 | 检查文件名称与属性，展示巡检结果 |
| 文件监听 | 查看文件创建、修改、重命名和删除 |
| 行为查看 | 查看与 USB 关联的进程及后续进程 |
| 手动阻断 | 按需禁用 USB 设备；也可启用恢复 |

### 使用

1. 下载项目并解压，保留文件夹内的配套文件。
2. 双击 `LaunchUSBMonitor.vbs` 启动；需要桌面快捷方式时运行 `安装USB检测器.bat`。
3. 插入 U 盘，等待硬件信息刷新，或点击巡检查看结果。

运行环境：Windows 10 / 11、Windows PowerShell 5.1。正常监测使用普通权限；禁用或启用设备需要管理员确认。

备注：扫描检查名称和属性，不读取文件内容；行为提示供参考，阻断由用户手动操作。

### 开发验证

使用 Windows PowerShell 运行 `Test-GuardLogic.ps1`、`Test-FileWatcher.ps1`、`Test-AsyncMonitor.ps1` 和 `Test-MetadataInventory.ps1`。硬件检测可运行 `Test-HardwareSnapshot.ps1`；真实 U 盘测试结果取决于当前连接设备。

### 作者

luke0485 · GPT6Luna · GPT6.1
