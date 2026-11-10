#requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Continue'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$AckFile   = Join-Path $ScriptDir '.acknowledged'
$ProfileDir = Join-Path $env:USERPROFILE 'ykt-chrome-profile'

# ---------- GitHub 深色配色 ----------
$Bg      = [System.Drawing.Color]::FromArgb(13, 17, 23)
$Surface = [System.Drawing.Color]::FromArgb(22, 27, 34)
$Border  = [System.Drawing.Color]::FromArgb(48, 54, 61)
$Text    = [System.Drawing.Color]::FromArgb(230, 237, 243)
$Muted   = [System.Drawing.Color]::FromArgb(139, 148, 158)
$Blue    = [System.Drawing.Color]::FromArgb(88, 166, 255)
$Red     = [System.Drawing.Color]::FromArgb(248, 81, 73)
$Green   = [System.Drawing.Color]::FromArgb(63, 185, 80)

$FntTitle = New-Object System.Drawing.Font('Microsoft YaHei', 19, [System.Drawing.FontStyle]::Bold)
$FntSmall = New-Object System.Drawing.Font('Microsoft YaHei', 10.5)
$FntNote  = New-Object System.Drawing.Font('Microsoft YaHei', 9.5)
$FntBig   = New-Object System.Drawing.Font('Microsoft YaHei', 17, [System.Drawing.FontStyle]::Bold)
$FntMono  = New-Object System.Drawing.Font('Consolas', 9.5)

$cHover   = { param($s, $e) $s.ForeColor = [System.Drawing.Color]::FromArgb(121, 192, 255) }
$cRestore = { param($s, $e) if ($s.Tag -ne $null) { $s.ForeColor = [System.Drawing.Color]$s.Tag } }

# ---------- 主窗体 ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = '雨课堂自动观看'
$form.ClientSize = New-Object System.Drawing.Size(780, 660)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = $Bg
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# ---------- 标题栏 ----------
$bar = New-Object System.Windows.Forms.Panel
$bar.Location = New-Object System.Drawing.Point(0, 0)
$bar.Size = New-Object System.Drawing.Size(780, 58)
$bar.BackColor = $Surface
$form.Controls.Add($bar)
$bar.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(48, 54, 61), 1)
    $e.Graphics.DrawLine($p, 0, $s.Height - 1, $s.Width, $s.Height - 1)
    $p.Dispose()
})

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = '雨课堂自动观看    版本 Ver 1.0.4'
$lblTitle.Font = $FntTitle
$lblTitle.ForeColor = $Text
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(24, 14)
$lblTitle.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$bar.Controls.Add($lblTitle)

function Add-Drag($ctrl) {
    $ctrl.Add_MouseDown({
        param($s, $e)
        $script:drag = $true
        $script:dragX = $e.X
        $script:dragY = $e.Y
    })
    $ctrl.Add_MouseMove({
        param($s, $e)
        if ($script:drag) {
            $f = $s.FindForm()
            if ($f -ne $null) {
                $f.Left = $f.Left + ($e.X - $script:dragX)
                $f.Top  = $f.Top  + ($e.Y - $script:dragY)
            }
        }
    })
    $ctrl.Add_MouseUp({ param($s, $e) $script:drag = $false })
}
Add-Drag $bar
Add-Drag $lblTitle

function New-BarButton($text, $x, $normalColor) {
    $b = New-Object System.Windows.Forms.Label
    $b.Text = $text
    $b.Font = New-Object System.Drawing.Font('Consolas', 14, [System.Drawing.FontStyle]::Bold)
    $b.ForeColor = $normalColor
    $b.Tag = $normalColor
    $b.AutoSize = $false
    $b.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $b.Size = New-Object System.Drawing.Size(34, 34)
    $b.Location = New-Object System.Drawing.Point($x, 12)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Add_MouseEnter($cHover)
    $b.Add_MouseLeave($cRestore)
    return $b
}

$btnMin   = New-BarButton '—' 672 $Muted
$btnClose = New-BarButton '×' 716 $Muted
$bar.Controls.AddRange(@($btnMin, $btnClose))
$btnMin.Add_Click({ param($s, $e) $s.FindForm().WindowState = [System.Windows.Forms.FormWindowState]::Minimized })
$btnClose.Add_Click({ param($s, $e) $s.FindForm().Close() })

# ---------- 内容容器 ----------
$body = New-Object System.Windows.Forms.Panel
$body.Location = New-Object System.Drawing.Point(0, 58)
$body.Size = New-Object System.Drawing.Size(780, 602)
$body.BackColor = $Bg
$form.Controls.Add($body)

# ================= 用前须知 =================
$panelIntro = New-Object System.Windows.Forms.Panel
$panelIntro.Location = New-Object System.Drawing.Point(0, 0)
$panelIntro.Size = New-Object System.Drawing.Size(780, 602)
$panelIntro.BackColor = $Bg
$body.Controls.Add($panelIntro)

$introTip = New-Object System.Windows.Forms.Label
$introTip.Text = '第一次打开弹出这个，以后不弹开，重启电脑后也不弹开'
$introTip.Font = $FntNote
$introTip.ForeColor = $Red
$introTip.AutoSize = $true
$introTip.Location = New-Object System.Drawing.Point(32, 14)
$panelIntro.Controls.Add($introTip)

$introBox = New-Object System.Windows.Forms.Panel
$introBox.Location = New-Object System.Drawing.Point(32, 42)
$introBox.Size = New-Object System.Drawing.Size(716, 440)
$introBox.BackColor = $Surface
$introBox.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(48, 54, 61), 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.ClientSize.Width - 1, $s.ClientSize.Height - 1)
    $p.Dispose()
})
$panelIntro.Controls.Add($introBox)

$h1 = New-Object System.Windows.Forms.Label
$h1.Text = '用前须知'
$h1.Font = New-Object System.Drawing.Font('Microsoft YaHei', 17, [System.Drawing.FontStyle]::Bold)
$h1.ForeColor = $Text
$h1.AutoSize = $true
$h1.Location = New-Object System.Drawing.Point(24, 16)
$introBox.Controls.Add($h1)

$introLines = @(
    '1. 本工具强制使用 Chrome 浏览器，不会调用 Edge 或其他浏览器。',
    '',
    '2. 运行期间会打开一个独立的 Chrome 调试窗口。',
    '   这个窗口不能关闭，也不能最小化——最小化会导致视频卡住不走。',
    '   可以切到别的窗口，也可以用电脑做别的事情。',
    '',
    '3. 只会自动完成视频、PPT 课件、PPT 内嵌视频。',
    '   作业、图文、讨论、各类题目会跳过，需要你自己做。',
    '',
    '4. 所有操作都在你本机完成，脚本不会上传你的账号或进度数据。',
    '',
    '免责声明：本工具仅供个人学习与技术研究使用。',
    '使用产生的一切后果由使用者自行承担，请遵守所在学校及平台的相关规定。'
)
$iy = 58
foreach ($line in $introLines) {
    $lb = New-Object System.Windows.Forms.Label
    $lb.Text = $line
    $lb.Font = $FntSmall
    $lb.ForeColor = $Text
    $lb.AutoSize = $true
    $lb.Location = New-Object System.Drawing.Point(26, $iy)
    $introBox.Controls.Add($lb)
    $iy += 26
}

$btnOk = New-Object System.Windows.Forms.Label
$btnOk.Text = '确认'
$btnOk.Font = New-Object System.Drawing.Font('Microsoft YaHei', 16, [System.Drawing.FontStyle]::Bold)
$btnOk.ForeColor = $Text
$btnOk.Tag = $Text
$btnOk.AutoSize = $false
$btnOk.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$btnOk.Size = New-Object System.Drawing.Size(160, 46)
$btnOk.Location = New-Object System.Drawing.Point(310, 502)
$btnOk.BackColor = [System.Drawing.Color]::FromArgb(33, 38, 45)
$btnOk.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnOk.Add_MouseEnter($cHover)
$btnOk.Add_MouseLeave($cRestore)
$panelIntro.Controls.Add($btnOk)

# ================= 主界面 =================
$panelMain = New-Object System.Windows.Forms.Panel
$panelMain.Location = New-Object System.Drawing.Point(0, 0)
$panelMain.Size = New-Object System.Drawing.Size(780, 602)
$panelMain.BackColor = $Bg
$panelMain.Visible = $false
$body.Controls.Add($panelMain)

$status = New-Object System.Windows.Forms.Label
$status.Text = '就绪。点上面的文字即可执行对应操作。'
$status.Font = $FntNote
$status.ForeColor = $Muted
$status.AutoSize = $false
$status.Size = New-Object System.Drawing.Size(700, 20)
$status.Location = New-Object System.Drawing.Point(40, 566)
$panelMain.Controls.Add($status)

function New-TaskBlock($top, $stepText, $linkText, $linkColor, $descText, $num) {
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Location = New-Object System.Drawing.Point(40, $top)
    $wrap.Size = New-Object System.Drawing.Size(700, 76)
    $wrap.BackColor = $Bg

    $idx = New-Object System.Windows.Forms.Label
    $idx.Text = $num
    $idx.Font = New-Object System.Drawing.Font('Microsoft YaHei', 26, [System.Drawing.FontStyle]::Bold)
    $idx.ForeColor = [System.Drawing.Color]::FromArgb(48, 54, 61)
    $idx.AutoSize = $true
    $idx.Location = New-Object System.Drawing.Point(620, 6)
    $wrap.Controls.Add($idx)

    $s = New-Object System.Windows.Forms.Label
    $s.Text = $stepText
    $s.Font = $FntNote
    $s.ForeColor = $Muted
    $s.AutoSize = $true
    $s.Location = New-Object System.Drawing.Point(0, 0)
    $wrap.Controls.Add($s)

    $lk = New-Object System.Windows.Forms.Label
    $lk.Text = $linkText
    $lk.Font = $FntBig
    $lk.ForeColor = $linkColor
    $lk.Tag = $linkColor
    $lk.AutoSize = $true
    $lk.Location = New-Object System.Drawing.Point(0, 20)
    $lk.Cursor = [System.Windows.Forms.Cursors]::Hand
    $lk.Add_MouseEnter($cHover)
    $lk.Add_MouseLeave($cRestore)
    $wrap.Controls.Add($lk)

    $d = New-Object System.Windows.Forms.Label
    $d.Text = $descText
    $d.Font = $FntSmall
    $d.ForeColor = $Muted
    $d.AutoSize = $true
    $d.Location = New-Object System.Drawing.Point(2, 52)
    $wrap.Controls.Add($d)

    return @{ Panel = $wrap; Link = $lk }
}

$t1 = New-TaskBlock 10  '第一步 点击这个'    '检查环境，安装依赖' $Blue  '安装 Python 依赖并检查 Chrome'           '01'
$t2 = New-TaskBlock 92  '第二步 点击这个'    '开始刷课'           $Text  '启动 Chrome 调试窗口，登录后自动开始'     '02'
$t3 = New-TaskBlock 174 '如需停止，点击这个' '停止并保存记录'     $Red   '停掉后台脚本，进度保存在 progress.json'   '03'

$panelMain.Controls.AddRange(@($t1.Panel, $t2.Panel, $t3.Panel))

foreach ($yy in @(84, 166, 248)) {
    $line = New-Object System.Windows.Forms.Panel
    $line.Location = New-Object System.Drawing.Point(40, $yy)
    $line.Size = New-Object System.Drawing.Size(700, 1)
    $line.BackColor = $Border
    $panelMain.Controls.Add($line)
}

# ---------- 日志面板 ----------
$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(44, 266)
$logBox.Size = New-Object System.Drawing.Size(696, 292)
$logBox.ReadOnly = $true
$logBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$logBox.BackColor = $Surface
$logBox.ForeColor = $Muted
$logBox.Font = $FntMono
$logBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$logBox.WordWrap = $true
$logBox.HideSelection = $false
$logBox.DetectUrls = $false
$panelMain.Controls.Add($logBox)

$logFrame = New-Object System.Windows.Forms.Panel
$logFrame.Location = New-Object System.Drawing.Point(40, 266)
$logFrame.Size = New-Object System.Drawing.Size(700, 292)
$logFrame.BackColor = $Surface
$logFrame.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(48, 54, 61), 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.ClientSize.Width - 1, $s.ClientSize.Height - 1)
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(88, 166, 255))
    $e.Graphics.FillRectangle($b, 1, 1, 3, $s.ClientSize.Height - 2)
    $b.Dispose()
    $p.Dispose()
})
$panelMain.Controls.Add($logFrame)
$logFrame.BringToFront()
$logBox.BringToFront()

$logBox.Text = "运行日志会显示在这里。`r`n`r`n· 三个操作都在窗口内执行，不会弹出黑色命令行窗口。`r`n· 调试用的 Chrome 窗口不能关闭，也不能最小化。`r`n· 想停止随时点第三步，进度不会丢。`r`n· 作业、图文、讨论、各种题目不会被自动完成。"

# ---------- 工具函数 ----------
function Set-Status($msg, $color) {
    $script:status.Text = $msg
    $script:status.ForeColor = $color
}

function Append-Log($s) {
    if ([string]::IsNullOrEmpty($s)) { return }
    $script:logBox.AppendText($s)
    $script:logBox.SelectionStart = $script:logBox.Text.Length
    $script:logBox.ScrollToCaret()
}

function Write-LogLine($s, $color) {
    $script:logBox.SelectionStart = $script:logBox.Text.Length
    $script:logBox.SelectionLength = 0
    if ($color -ne $null) { $script:logBox.SelectionColor = $color }
    Append-Log ($s + "`r`n")
    $script:logBox.SelectionColor = [System.Drawing.Color]::FromArgb(139, 148, 158)
}

function Test-Port($p) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $ar = $c.BeginConnect('127.0.0.1', $p, $null, $null)
        $ok = $ar.AsyncWaitHandle.WaitOne(300)
        if ($ok -and $c.Connected) { $c.Close(); return $true }
        $c.Close()
        return $false
    } catch { return $false }
}

function Test-PythonExe($exe) {
    if (-not $exe) { return $false }
    # Windows 应用商店占位符，不是真正的 Python
    if ($exe -like '*\WindowsApps\*') { return $false }
    if (-not (Test-Path $exe)) { return $false }
    try {
        $o = & $exe --version 2>&1
        if ($LASTEXITCODE -eq 0 -and ("$o" -match 'Python\s+3')) { return $true }
    } catch {}
    return $false
}

function Find-Python {
    $cands = New-Object System.Collections.ArrayList

    foreach ($cmd in @('python', 'py')) {
        try {
            $c = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($c -and $c.Source) { [void]$cands.Add($c.Source) }
        } catch {}
    }

    foreach ($root in @(
        'HKLM:\SOFTWARE\Python\PythonCore',
        'HKCU:\SOFTWARE\Python\PythonCore',
        'HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore'
    )) {
        try {
            Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
                $ip = Join-Path $_.PSPath 'InstallPath'
                try {
                    $v = (Get-ItemProperty -Path $ip -ErrorAction Stop).'(default)'
                    if ($v) { [void]$cands.Add((Join-Path $v.Trim('"') 'python.exe')) }
                } catch {}
            }
        } catch {}
    }

    foreach ($ver in @('314', '313', '312', '311', '310', '39', '38')) {
        [void]$cands.Add("$env:LOCALAPPDATA\Programs\Python\Python$ver\python.exe")
        [void]$cands.Add("C:\Python$ver\python.exe")
        [void]$cands.Add("D:\Python$ver\python.exe")
        [void]$cands.Add("E:\Python$ver\python.exe")
        [void]$cands.Add("C:\Program Files\Python$ver\python.exe")
    }
    [void]$cands.Add("$env:LOCALAPPDATA\Programs\Python\Launcher\py.exe")
    [void]$cands.Add('C:\Windows\py.exe')

    foreach ($c in $cands) {
        if (Test-PythonExe $c) { return $c }
    }
    return $null
}

function Find-Chrome {
    foreach ($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
    )) {
        try {
            $v = (Get-ItemProperty -Path $key -ErrorAction Stop).'(default)'
            if ($v) {
                $v = $v.Trim('"')
                if (Test-Path $v) { return $v }
            }
        } catch {}
    }
    foreach ($p in @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome Beta\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome Dev\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome SxS\Application\chrome.exe",
        'D:\Program Files\Google\Chrome\Application\chrome.exe',
        'D:\Google\Chrome\Application\chrome.exe',
        'E:\Program Files\Google\Chrome\Application\chrome.exe'
    )) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

# ---------- 运行状态 ----------
$script:proc     = $null
$script:logFile  = Join-Path $ScriptDir '.ui-run.log'
$script:errFile  = Join-Path $ScriptDir '.ui-run.err.log'
$script:readPos  = 0
$script:lastErr  = ''
$script:stage    = 'idle'      # idle | waitport | running
$script:portWait = 0
$script:py       = $null
$script:chrome   = $null

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 400
$script:timer.Add_Tick({
    # 阶段：等待调试端口
    if ($script:stage -eq 'waitport') {
        $script:portWait += 0.4
        if (Test-Port 9222) {
            Write-LogLine '[OK] 调试端口 9222 已就绪' ([System.Drawing.Color]::FromArgb(63, 185, 80))
            Set-Status '正在启动刷课脚本…' ([System.Drawing.Color]::FromArgb(63, 185, 80))
            $script:stage = 'running'
            [System.IO.File]::WriteAllText($script:logFile, '')
            [System.IO.File]::WriteAllText($script:errFile, '')
            $script:readPos = 0
            $script:lastErr = ''
            $script:proc = Start-Process -FilePath $script:py `
                -ArgumentList '-u', 'run_all.py' `
                -WorkingDirectory $ScriptDir `
                -RedirectStandardOutput $script:logFile `
                -RedirectStandardError $script:errFile `
                -NoNewWindow -PassThru
        } elseif ($script:portWait -gt 40) {
            Write-LogLine '[X] 等了 40 秒端口还没起来，请检查 Chrome 是否被拦截' ([System.Drawing.Color]::FromArgb(248, 81, 73))
            Set-Status '启动失败：调试端口未就绪' ([System.Drawing.Color]::FromArgb(248, 81, 73))
            $script:stage = 'idle'
        }
        return
    }

    # 读输出
    if (Test-Path $script:logFile) {
        try {
            $fs = [System.IO.File]::Open($script:logFile, 'Open', 'Read', 'ReadWrite')
            $fs.Seek($script:readPos, 'Begin') | Out-Null
            $sr = New-Object System.IO.StreamReader($fs, (New-Object System.Text.UTF8Encoding($false)))
            $new = $sr.ReadToEnd()
            $script:readPos = $fs.Position
            $sr.Close(); $fs.Close()
            if ($new) { Append-Log $new }
        } catch {}
    }
    if (Test-Path $script:errFile) {
        try {
            $et = [System.IO.File]::ReadAllText($script:errFile, (New-Object System.Text.UTF8Encoding($false)))
            if ($et -and $et.Length -gt $script:lastErr.Length) {
                $add = $et.Substring($script:lastErr.Length)
                $script:lastErr = $et
                if ($add.Trim()) {
                    $script:logBox.SelectionColor = [System.Drawing.Color]::FromArgb(248, 81, 73)
                    Append-Log $add
                    $script:logBox.SelectionColor = [System.Drawing.Color]::FromArgb(139, 148, 158)
                }
            }
        } catch {}
    }

    # 进程结束
    if ($script:proc -ne $null -and $script:proc.HasExited) {
        Write-LogLine "[进程已结束，退出码 $($script:proc.ExitCode)]" ([System.Drawing.Color]::FromArgb(63, 185, 80))
        Set-Status '任务已结束' ([System.Drawing.Color]::FromArgb(139, 148, 158))
        $script:proc = $null
        $script:stage = 'idle'
        $script:timer.Stop()
    }
})

# ---------- 三个任务 ----------
function Do-Check {
    $script:logBox.Clear()
    $script:stage = 'idle'
    Write-LogLine '=== 检查环境 ===' ([System.Drawing.Color]::FromArgb(88, 166, 255))

    $script:py = Find-Python
    if (-not $script:py) {
        Write-LogLine '[X] 这台电脑没有检测到 Python' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        Write-LogLine ''
        Write-LogLine '请先安装 Python 3.8 或更新版本：' ([System.Drawing.Color]::FromArgb(230, 237, 243))
        Write-LogLine '  https://www.python.org/downloads/' ([System.Drawing.Color]::FromArgb(88, 166, 255))
        Write-LogLine ''
        Write-LogLine '安装时务必勾选第一屏底部的 "Add python.exe to PATH"' ([System.Drawing.Color]::FromArgb(230, 237, 243))
        Write-LogLine '装好后再点一次「检查环境，安装依赖」' ([System.Drawing.Color]::FromArgb(139, 148, 158))
        Set-Status '找不到 Python，请先安装' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        try { Start-Process 'https://www.python.org/downloads/' } catch {}
        return
    }
    Write-LogLine "[OK] Python: $($script:py)" ([System.Drawing.Color]::FromArgb(63, 185, 80))

    $script:chrome = Find-Chrome
    if (-not $script:chrome) {
        Write-LogLine '[X] 没找到 Chrome，请先安装：https://www.google.com/chrome/' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        Set-Status 'Chrome 未安装' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        try { Start-Process 'https://www.google.com/chrome/' } catch {}
        return
    }
    Write-LogLine "[OK] Chrome: $($script:chrome)" ([System.Drawing.Color]::FromArgb(63, 185, 80))

    try {
        $ver = & $script:py --version 2>&1
        Write-LogLine "[OK] $ver" ([System.Drawing.Color]::FromArgb(63, 185, 80))
    } catch {
        Write-LogLine "[X] Python 无法运行：$($_.Exception.Message)" ([System.Drawing.Color]::FromArgb(248, 81, 73))
        Set-Status 'Python 无法运行' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        return
    }

    $wsOk = $false
    try {
        & $script:py -c "import websockets" 2>&1 | Out-Null
        $wsOk = ($LASTEXITCODE -eq 0)
    } catch { $wsOk = $false }
    if (-not $wsOk) {
        Write-LogLine '缺少 websockets，正在安装依赖…' ([System.Drawing.Color]::FromArgb(230, 237, 243))
        [System.IO.File]::WriteAllText($script:logFile, '')
        [System.IO.File]::WriteAllText($script:errFile, '')
        $script:readPos = 0
        $script:lastErr = ''
        $script:proc = Start-Process -FilePath $script:py `
            -ArgumentList '-m', 'pip', 'install', '-r', 'requirements.txt' `
            -WorkingDirectory $ScriptDir `
            -RedirectStandardOutput $script:logFile `
            -RedirectStandardError $script:errFile `
            -NoNewWindow -PassThru
        $script:timer.Start()
        Set-Status '正在安装依赖…' ([System.Drawing.Color]::FromArgb(230, 237, 243))
        return
    }
    Write-LogLine '[OK] 依赖已就绪（websockets）' ([System.Drawing.Color]::FromArgb(63, 185, 80))
    Write-LogLine ''
    Write-LogLine '环境检查完成，可以点第二步开始刷课。' ([System.Drawing.Color]::FromArgb(63, 185, 80))
    Set-Status '环境检查通过' ([System.Drawing.Color]::FromArgb(63, 185, 80))
}

function Do-Start {
    if ($script:stage -eq 'running' -and $script:proc -ne $null -and -not $script:proc.HasExited) {
        Set-Status '已经在刷了，先点第三步停止' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        return
    }
    $script:logBox.Clear()
    Write-LogLine '=== 开始刷课 ===' ([System.Drawing.Color]::FromArgb(88, 166, 255))

    if (-not $script:py) { $script:py = Find-Python }
    if (-not $script:py) {
        Write-LogLine '[X] 没找到 Python，先点第一步检查环境' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        Set-Status 'Python 未就绪' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        return
    }
    if (-not $script:chrome) { $script:chrome = Find-Chrome }
    if (-not $script:chrome) {
        Write-LogLine '[X] 没找到 Chrome，先点第一步检查环境' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        Set-Status 'Chrome 未就绪' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        return
    }

    if (Test-Port 9222) {
        Write-LogLine '[OK] 调试端口已在，直接启动脚本' ([System.Drawing.Color]::FromArgb(63, 185, 80))
        $script:stage = 'running'
        [System.IO.File]::WriteAllText($script:logFile, '')
        [System.IO.File]::WriteAllText($script:errFile, '')
        $script:readPos = 0
        $script:lastErr = ''
        $script:proc = Start-Process -FilePath $script:py `
            -ArgumentList '-u', 'run_all.py' `
            -WorkingDirectory $ScriptDir `
            -RedirectStandardOutput $script:logFile `
            -RedirectStandardError $script:errFile `
            -NoNewWindow -PassThru
        $script:timer.Start()
        Set-Status '刷课进行中（Chrome 不能关也不能最小化）' ([System.Drawing.Color]::FromArgb(63, 185, 80))
        return
    }

    Write-LogLine '正在关闭现有 Chrome…' ([System.Drawing.Color]::FromArgb(230, 237, 243))
    Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 1200

    Write-LogLine '正在启动 Chrome 调试窗口…' ([System.Drawing.Color]::FromArgb(230, 237, 243))
    try {
        Start-Process -FilePath $script:chrome -ArgumentList '--remote-debugging-port=9222', "--user-data-dir=$ProfileDir"
    } catch {
        Write-LogLine "[X] 启动 Chrome 失败：$($_.Exception.Message)" ([System.Drawing.Color]::FromArgb(248, 81, 73))
        Set-Status '启动 Chrome 失败' ([System.Drawing.Color]::FromArgb(248, 81, 73))
        return
    }

    Write-LogLine '等待调试端口就绪…' ([System.Drawing.Color]::FromArgb(230, 237, 243))
    Write-LogLine '（Chrome 弹出后请先登录雨课堂，脚本会自动接管）' ([System.Drawing.Color]::FromArgb(139, 148, 158))
    $script:stage = 'waitport'
    $script:portWait = 0
    $script:timer.Start()
    Set-Status '正在启动 Chrome…' ([System.Drawing.Color]::FromArgb(230, 237, 243))
}

function Do-Stop {
    Write-LogLine '=== 停止 ===' ([System.Drawing.Color]::FromArgb(248, 81, 73))
    $killed = 0
    try {
        Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -match 'run_all' } |
            ForEach-Object {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                Write-LogLine "[OK] 已停止 python PID $($_.ProcessId)" ([System.Drawing.Color]::FromArgb(63, 185, 80))
                $killed++
            }
    } catch {}
    if ($killed -eq 0) {
        Write-LogLine '没有正在运行的刷课进程。' ([System.Drawing.Color]::FromArgb(139, 148, 158))
    }
    if ($script:proc -ne $null -and -not $script:proc.HasExited) {
        try { Stop-Process -Id $script:proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
    $script:proc = $null
    $script:stage = 'idle'
    $script:timer.Stop()
    $pj = Join-Path $ScriptDir 'progress.json'
    if (Test-Path $pj) {
        Write-LogLine '[OK] 进度已保存到 progress.json' ([System.Drawing.Color]::FromArgb(63, 185, 80))
    }
    Set-Status '已停止，进度已保存' ([System.Drawing.Color]::FromArgb(63, 185, 80))
}

$t1.Link.Add_Click({ Do-Check })
$t2.Link.Add_Click({ Do-Start })
$t3.Link.Add_Click({ Do-Stop })

$btnOk.Add_Click({
    try { Set-Content -Path $script:AckFile -Value 'acknowledged' -Encoding ASCII } catch {}
    $script:panelIntro.Visible = $false
    $script:panelMain.Visible = $true
})

if (Test-Path $AckFile) {
    $panelIntro.Visible = $false
    $panelMain.Visible = $true
}

try {
    [System.Windows.Forms.Application]::Run($form)
} catch {
    $log = Join-Path $ScriptDir 'launcher-error.log'
    try { Set-Content -Path $log -Value $_.Exception.ToString() -Encoding UTF8 } catch {}
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '启动器错误')
}
