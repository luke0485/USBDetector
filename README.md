<p align="center"><img src="logo.jpg" width="110" alt="USB 检测器图标"></p>
<h1 align="center">USB 检测器</h1>
<p align="center">查看 USB 设备 · 巡检名称与属性 · 监听文件变化</p>

<p align="center"><img src="docs/overview.svg" width="800" alt="USB 检测器功能示意"></p>

一款 Windows 桌面 USB 监测工具，使用 PowerShell 和 WinForms 构建，可最小化到托盘。

| 功能 | 用途 |
| --- | --- |
| 硬件检测 | 显示 USB 设备、存储卷与设备标识 |
| 名称/属性 | 遍历文件名称和属性，提示双扩展名、隐藏执行文件等线索 |
| 文件变化 | 记录创建、修改、重命名与删除 |
| 进程监听 | 记录与 USB 路径关联的进程及后续进程 |

### 使用

1. 下载项目并解压，保留文件夹内的配套文件。
2. 双击 `LaunchUSBMonitor.vbs` 启动；需要桌面快捷方式时运行 `安装USB检测器.bat`。
3. 插入 U 盘，等待硬件信息刷新，或点击巡检查看结果。

运行环境：Windows 10 / 11、Windows PowerShell 5.1。正常监测使用普通权限；禁用或启用设备需要管理员确认。

巡检只读取名称和属性，不读取文件内容，不是病毒扫描。提示表示需要核对的线索，不能据此确认恶意；单次巡检最多 10,000 条。实时进程事件不可用时采用轮询，无法保证记录所有短暂进程。设备插入后不会自动阻断。

### 开发验证

使用 Windows PowerShell 运行 `Test-GuardLogic.ps1`、`Test-FileWatcher.ps1`、`Test-AsyncMonitor.ps1` 和 `Test-MetadataInventory.ps1`。硬件检测可运行 `Test-HardwareSnapshot.ps1`；真实 U 盘测试结果取决于当前连接设备。
