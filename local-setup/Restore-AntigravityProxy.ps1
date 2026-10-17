<#
.SYNOPSIS
    Antigravity Proxy Guardian & Disaster Recovery Tool
.DESCRIPTION
    Checks and restores the DLL injection patch (version.dll + config.json) for Antigravity,
    and inspects process memory loading and proxy port connectivity.
#>
param(
    [switch]$ForceRestore,
    [string]$Version = "current" # options: "current", "v1.9", "v2.4"
)

$TargetDir = "C:\Users\a1634\AppData\Local\Programs\antigravity"
$BackupRoot = "C:\Users\a1634\.antigravity_tools\backup_inject"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      Antigravity Proxy Guardian & Disaster Recovery      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. 检查目标目录
if (-not (Test-Path $TargetDir)) {
    Write-Host "[-] Antigravity 安装目录不存在: $TargetDir" -ForegroundColor Red
    return
}

# 2. 检查注入文件状态
$DllPath = Join-Path $TargetDir "version.dll"
$ConfigPath = Join-Path $TargetDir "config.json"

$DllExists = Test-Path $DllPath
$ConfigExists = Test-Path $ConfigPath

Write-Host "[1] 检查注入文件就绪状态:" -ForegroundColor Yellow
if ($DllExists) {
    $dllItem = Get-Item $DllPath
    Write-Host "  [√] version.dll 存在 ($($dllItem.Length) bytes, 修改时间: $($dllItem.LastWriteTime))" -ForegroundColor Green
} else {
    Write-Host "  [!] version.dll 缺失 (被更新冲掉)" -ForegroundColor Red
}

if ($ConfigExists) {
    $cfgItem = Get-Item $ConfigPath
    Write-Host "  [√] config.json 存在 ($($cfgItem.Length) bytes)" -ForegroundColor Green
} else {
    Write-Host "  [!] config.json 缺失 (被更新冲掉)" -ForegroundColor Red
}

# 3. 触发恢复逻辑 (如果缺失或强制恢复)
if ($ForceRestore -or (-not $DllExists) -or (-not $ConfigExists)) {
    Write-Host "`n[2] 执行注入文件恢复..." -ForegroundColor Yellow
    
    $SourceDir = if ($Version -eq "v2.4") {
        Join-Path $BackupRoot "v2.4\ide"
    } else {
        Join-Path $BackupRoot $Version
    }

    if (-not (Test-Path $SourceDir)) {
        Write-Host "  [-] 恢复源路径不存在: $SourceDir" -ForegroundColor Red
        return
    }

    Copy-Item "$SourceDir\version.dll" $DllPath -Force
    # 如果 config.json 已存在且非强制，可保留原配置；否则用备份恢复
    if ($ForceRestore -or (-not $ConfigExists)) {
        Copy-Item "$SourceDir\config.json" $ConfigPath -Force
    }

    Write-Host "  [√] 已成功从 [$Version] 恢复注入文件至 $TargetDir" -ForegroundColor Green
} else {
    Write-Host "`n[2] 注入文件状态完好，无需恢复。" -ForegroundColor Cyan
}

# 4. 检查网络与端口状态
Write-Host "`n[3] 检查代理与协同服务端口:" -ForegroundColor Yellow
$Ports = @(
    @{ Name = "Clash Verge (SOCKS5)"; Port = 7897 },
    @{ Name = "Antigravity Tools";   Port = 8046 }
)

foreach ($p in $Ports) {
    $conn = Get-NetTCPConnection -LocalPort $p.Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn) {
        $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
        Write-Host "  [√] $($p.Name) 端口 $($p.Port) 正常监听中 (PID: $($conn.OwningProcess), 进程名: $($proc.ProcessName))" -ForegroundColor Green
    } else {
        Write-Host "  [!] $($p.Name) 端口 $($p.Port) 未处于监听状态！" -ForegroundColor Red
    }
}

# 5. 检查 Antigravity 进程与模块加载
Write-Host "`n[4] 检查 Antigravity 进程模块挂载:" -ForegroundColor Yellow
$agProcs = Get-Process -Name "Antigravity" -ErrorAction SilentlyContinue
if ($agProcs) {
    $mainProc = $agProcs | Select-Object -First 1
    $injectedMod = $mainProc.Modules | Where-Object { $_.FileName -like "*programs\antigravity\version.dll*" }
    if ($injectedMod) {
        Write-Host "  [√] Antigravity 正在运行中 (总计 $($agProcs.Count) 个进程)，已检测到内存劫持模块:" -ForegroundColor Green
        Write-Host "      模块路径: $($injectedMod.FileName)" -ForegroundColor Gray
        Write-Host "      模块大小: $($injectedMod.ModuleMemorySize) 字节" -ForegroundColor Gray
    } else {
        Write-Host "  [!] Antigravity 进程在运行，但未检测到本地 version.dll 模块注入！可能需要重启 IDE。" -ForegroundColor Red
    }
} else {
    Write-Host "  [-] Antigravity 目前未运行。启动 IDE 后将自动加载注入补丁。" -ForegroundColor Gray
}

Write-Host "==========================================================" -ForegroundColor Cyan
