# =====================================================================
#  Chrome + Python 一键安装/检查脚本
#  - Chrome : 未装则从 dl.google.com 下载安装包并静默安装
#  - Python : 检查 python、PATH、pip 三项，缺任意一项则安装 3.15.2
#  - 已装   : 只提示"本机已装 Chrome / Python"，不重复安装
#  - 双击 install.bat 即可运行；窗口结束前显示结果
# =====================================================================

$ErrorActionPreference = 'Stop'
$web  = New-Object System.Net.WebClient
$web.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
$web.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$dlDir = Join-Path $env:TEMP 'zcode-installer'
New-Item -ItemType Directory -Force -Path $dlDir | Out-Null

# ---------- 小工具 ----------
function Read-ExeVersion([string]$path) {
    if (Test-Path $path) {
        return (Get-Item $path).VersionInfo.FileVersion
    }
    return $null
}

function Wait-InstallerExit([string]$name) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Wait-Process -Timeout 600 -ErrorAction SilentlyContinue
}

function Find-Chrome {
    $paths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

# ================= Chrome =================
Write-Host '[Chrome] 开始检查...' -ForegroundColor Cyan
$chromePath = Find-Chrome

if ($chromePath) {
    $v = Read-ExeVersion $chromePath
    Write-Host "[Chrome] 本机已装 Chrome（版本 $v），跳过安装" -ForegroundColor Green
}
else {
    Write-Host '[Chrome] 未检测到 Chrome，开始下载安装包...' -ForegroundColor Yellow
    $chromeExe = Join-Path $dlDir 'ChromeSetup.exe'
    $chromeUrl = 'https://dl.google.com/chrome/install/latest/chrome_installer.exe'
    try {
        $web.DownloadFile($chromeUrl, $chromeExe)
        Write-Host "[Chrome] 下载完成：$chromeExe"
        Write-Host '[Chrome] 正在静默安装（安装器在后台完成，请耐心等待）...'
        $null = Start-Process -FilePath $chromeExe -ArgumentList '/silent /install' -Wait -PassThru
        Wait-InstallerExit 'GoogleUpdate'
        $chromePath = Find-Chrome
        if ($chromePath) {
            $v = Read-ExeVersion $chromePath
            Write-Host "[Chrome] 安装完成：$chromePath（版本 $v）" -ForegroundColor Green
        }
        else {
            Write-Host '[Chrome] 安装器已运行，但未找到 chrome.exe，请手动运行安装包' -ForegroundColor Red
            Write-Host "[Chrome] 安装包位置：$chromeExe" -ForegroundColor Yellow
        }
    }
    catch {
        $msg = $_.Exception.Message
        Write-Host "[Chrome] 下载失败：$msg" -ForegroundColor Red
        Write-Host "[Chrome] 可手动下载：$chromeUrl" -ForegroundColor Yellow
    }
}

Write-Host ''
# ================= Python =================
Write-Host '[Python] 开始检查...' -ForegroundColor Cyan
# 三项全满足才算"已装好"：
#   1. python 命令可用且不是商店占位符
#   2. python 在 PATH 上（Get-Command 能解析出真实路径）
#   3. pip 可用（python -m pip --version 成功，或 pip.exe 在 PATH 上）
$pythonOk  = $false
$pythonLoc = $null
$missReasons = @()

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $missReasons += 'python 命令不可用'
}
else {
    $src = $pythonCmd.Source
    if ($src -like "$env:LOCALAPPDATA\Microsoft\WindowsApps\*") {
        $missReasons += 'python 命令是商店占位符(WindowsApps stub)，非真实安装'
    }
    else {
        $pythonLoc = $src
        $pipOk = $false
        try {
            $null = & $src -m pip --version 2>$null
            if ($LASTEXITCODE -eq 0) { $pipOk = $true }
        } catch { $pipOk = $false }
        if (-not $pipOk) {
            $pipExe = Get-Command pip -ErrorAction SilentlyContinue
            if ($pipExe -and $pipExe.Source -notlike "$env:LOCALAPPDATA\Microsoft\WindowsApps\*") {
                $pipOk = $true
            }
        }
        if ($pipOk) { $pythonOk = $true }
        else        { $missReasons += 'pip 不可用（python -m pip 失败）' }
    }
}

if ($pythonOk) {
    $pyVer = (& $pythonLoc --version) 2>$null
    Write-Host "[Python] 本机已装 Python（$pyVer，位于 $pythonLoc，PATH 与 pip 均正常），跳过安装" -ForegroundColor Green
}
else {
    Write-Host '[Python] 检查未通过：' -ForegroundColor Yellow
    foreach ($r in $missReasons) { Write-Host "         - $r" -ForegroundColor Yellow }
    Write-Host '[Python] 开始下载并安装 Python 3.15.2 ...' -ForegroundColor Yellow
    $pyExe = Join-Path $dlDir 'python-3.15.2-amd64.exe'
    $pyUrl = 'https://www.python.org/ftp/python/3.15.2/python-3.15.2-amd64.exe'
    try {
        $web.DownloadFile($pyUrl, $pyExe)
        Write-Host "[Python] 下载完成：$pyExe"
        Write-Host '[Python] 正在静默安装（自动加 PATH、含 pip）...'
        $null = Start-Process -FilePath $pyExe -ArgumentList '/quiet InstallAllUsers=0 PrependPath=1 Include_pip=1' -Wait -PassThru
        Refresh-Path
        $fresh = Get-Command python -ErrorAction SilentlyContinue
        if ($fresh -and $fresh.Source -notlike "$env:LOCALAPPDATA\Microsoft\WindowsApps\*") {
            $v = (& $fresh.Source --version) 2>$null
            Write-Host "[Python] 安装完成：$($fresh.Source)（$v）" -ForegroundColor Green
            $pipCheck = & $fresh.Source -m pip --version 2>$null
            if ($pipCheck) { Write-Host "[Python] pip 验证：$pipCheck" -ForegroundColor Green }
        }
        else {
            Write-Host '[Python] 安装器已运行，但未找到 python 命令，请重新打开终端检查' -ForegroundColor Red
            Write-Host "[Python] 安装包位置：$pyExe" -ForegroundColor Yellow
        }
    }
    catch {
        $msg = $_.Exception.Message
        Write-Host "[Python] 下载失败：$msg" -ForegroundColor Red
        Write-Host "[Python] 可手动下载：$pyUrl" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '===== 检查/安装结束 =====' -ForegroundColor Cyan
