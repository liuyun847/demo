param([string]$ProjectPath)

Write-Host "=== Godot Project Check Tool ==="

# 基础验证
if (-not (Test-Path (Join-Path $ProjectPath "project.godot"))) {
    Write-Host "Error: Invalid Godot project path" -ForegroundColor Red
    exit 1
}
$ProjectPath = $ProjectPath.TrimEnd('\', '/')
# 优先使用 $GODOT 环境变量（与 pre-commit hook 保持一致），其次 $GODOT_PATH，否则回退硬编码路径
$godotPath = if ($env:GODOT) { $env:GODOT } elseif ($env:GODOT_PATH) { $env:GODOT_PATH } else { 'C:\Users\MLTZ\Desktop\Godot_v4.6.1-stable_win64.exe' }
if (-not (Test-Path $godotPath)) {
    Write-Host "Error: Godot executable not found at $godotPath" -ForegroundColor Red
    exit 1
}

# 提取 autoload 列表
$autoloadNames = @()
$godotFile = Join-Path $ProjectPath "project.godot"
$inAutoload = $false
foreach ($line in Get-Content $godotFile -Encoding UTF8) {
    if ($line -match '^\[autoload\]') {
        $inAutoload = $true
        continue
    }
    if ($inAutoload -and $line -match '^\[') { break }
    if ($inAutoload -and $line -match '^(\w+)\s*=') {
        $autoloadNames += $Matches[1]
    }
}

# Godot 执行与输出捕获函数
function Invoke-GodotCheck {
    param(
        [string[]]$Arguments,
        [int]$TimeoutMs = 5000
    )
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath $godotPath -ArgumentList $Arguments -NoNewWindow -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $timedOut = $false
        if (-not $proc.WaitForExit($TimeoutMs)) {
            $proc.Kill()
            $timedOut = $true
        }
        $outLines = @()
        if (Test-Path $stdoutFile) { $outLines = Get-Content $stdoutFile -Encoding UTF8 }
        $errLines = @()
        if (Test-Path $stderrFile) { $errLines = Get-Content $stderrFile -Encoding UTF8 }
        $allLines = $outLines + $errLines
        $hasErrors = ($allLines | Where-Object {
                $_ -match "ERROR:" -or $_ -match "Parse Error" -or $_ -match "Compile Error" -or $_ -match "Script error"
            }).Count -gt 0
        $exitCode = if ($timedOut) { -1 } else { $proc.ExitCode }
        return @{ Lines = $allLines; ExitCode = $exitCode; TimedOut = $timedOut; HasErrors = $hasErrors }
    }
    finally {
        Remove-Item $stdoutFile -ErrorAction SilentlyContinue
        Remove-Item $stderrFile -ErrorAction SilentlyContinue
    }
}

# 错误过滤函数 (核心逻辑)
function Filter-Errors {
    param([string[]]$Lines)
    if (-not $Lines) { return @() }
    return $Lines | Where-Object {
        # 跳过引擎无害噪声
        if ($_ -match "Debugger Break") { return $false }
        if ($_ -match "ObjectDB instances leaked at exit") { return $false }
        if ($_ -match "Orphan StringName detected") { return $false }
        $_ -match "ERROR:" -or
        $_ -match "WARNING:" -or
        $_ -match "USER ERROR:" -or
        $_ -match "USER WARNING:" -or
        $_ -match "Parse Error" -or
        $_ -match "Compile Error" -or
        $_ -match "Script error" -or
        $_ -match "Failed to load resource" -or
        $_ -match "Invalid get index" -or
        $_ -match "Invalid call" -or
        $_ -match "Attempt to call function" -or
        $_ -match "Assertion failed" -or
        $_ -match "Cannot get path" -or
        # Godot 4 命令行输出紧凑格式: W 0:00:00:651 ...
        $_ -match "^\s*[WE]\s+\d+:\d+:\d+(:\d+)?" -or
        # GDScript 错误/源文件 信息行
        $_ -match "GDScript 错误" -or
        $_ -match "GDScript 源文件" -or
        $_ -match "^\s+at:" -or
        $_ -match "^\s*res://"
    }
}

# 场景文件错误过滤 (递归依赖相关)
function Filter-FileErrors {
    param([string[]]$Lines, [string]$ScriptResPath = "")
    $filtered = Filter-Errors $Lines
    if (-not $filtered) { return @() }

    $result = @()
    $autoloadFailedScripts = @()
    $skipNext = $false
    for ($i = 0; $i -lt $filtered.Count; $i++) {
        $line = $filtered[$i]

        if ($skipNext -and ($line -match "^\s+at:" -or $line -match "^\s*res://")) {
            $skipNext = $false
            continue
        }
        $skipNext = $false

        if ($line -match "Failed to compile depended scripts") {
            $skipNext = $true
            if ($i + 1 -lt $filtered.Count) {
                $nextLine = $filtered[$i + 1]
                if ($nextLine -match "(res://[^\s]+\.gd)") {
                    $autoloadFailedScripts += $Matches[1]
                }
            }
            continue
        }

        $isAutoloadFP = $false
        foreach ($name in $script:autoloadNames) {
            $prefix = "Compile Error: Identifier not found: " + $name
            if ($line -match $prefix) {
                $isAutoloadFP = $true
                break
            }
        }
        if ($isAutoloadFP) {
            $skipNext = $true
            if ($i + 1 -lt $filtered.Count) {
                $nextLine = $filtered[$i + 1]
                if ($nextLine -match "(res://[^\s]+\.gd)") {
                    $autoloadFailedScripts += $Matches[1]
                }
            }
            continue
        }

        $isAutoloadLoadErr = $false
        foreach ($fs in $autoloadFailedScripts) {
            $escaped = [regex]::Escape($fs)
            if ($line -match $escaped) {
                $isAutoloadLoadErr = $true
                break
            }
        }
        if ((-not $isAutoloadLoadErr) -and $ScriptResPath -and ($line -match "Failed to load script")) {
            $escapedPath = [regex]::Escape($ScriptResPath)
            if ($line -match $escapedPath) {
                foreach ($fs in $autoloadFailedScripts) {
                    if ($fs -eq $ScriptResPath) {
                        $isAutoloadLoadErr = $true
                        break
                    }
                }
            }
        }
        if ($isAutoloadLoadErr) {
            $skipNext = $true
            continue
        }

        $result += $line
    }
    return $result
}

function Format-Output {
    param([string[]]$Lines, [string]$Label)
    if ($Lines) {
        Write-Host "`n$Label results:" -ForegroundColor Cyan
        $inError = $false
        foreach ($line in $Lines) {
            if ($line -match "ERROR:" -or $line -match "Parse Error" -or $line -match "Compile Error" -or $line -match "Script error" -or $line -match "^\s*E\s+\d+:\d+:\d+(:\d+)?") {
                Write-Host $line -ForegroundColor Red
                $inError = $true
            }
            elseif ($line -match "WARNING:" -or $line -match "^\s*W\s+\d+:\d+:\d+(:\d+)?") {
                Write-Host $line -ForegroundColor Yellow
                $inError = $false
            }
            elseif ($line -match "GDScript 错误") {
                Write-Host $line -ForegroundColor Red
                $inError = $true
            }
            elseif ($line -match "GDScript 源文件") {
                if ($inError) { Write-Host $line -ForegroundColor DarkRed }
                else { Write-Host $line -ForegroundColor DarkYellow }
            }
            elseif ($line -match "^\s+at:" -or $line -match "^\s*res://") {
                if ($inError) { Write-Host $line -ForegroundColor DarkRed }
                else { Write-Host $line -ForegroundColor DarkYellow }
            }
            else {
                Write-Host $line
                $inError = $false
            }
        }
    }
    else {
        Write-Host "`n$Label completed, no errors" -ForegroundColor Green
    }
    return $Lines
}

# 1/3 项目级静态检查（编辑器模式 + --verbose 可选）
Write-Host "`n1/3 Project static checking (editor mode)..."
$projectArgs = @(
    "--path", $ProjectPath,
    "--editor",
    "--headless",
    "--quit"
)
$projectResult = Invoke-GodotCheck -Arguments $projectArgs -TimeoutMs 10000
if ($projectResult.TimedOut) { Write-Host "  Timed out after 10 seconds" -ForegroundColor Yellow }
$staticProjectErrors = @(Filter-Errors $projectResult.Lines | Sort-Object -Unique)
Format-Output $staticProjectErrors "Project static"

# 2/3 逐文件静态语法检查（补充捕获编辑器模式可能遗漏的文件，过滤 autoload 误报，加上 --debug 以获取警告）
Write-Host "`n2/3 Per-file static syntax checking..."
$gdFiles = Get-ChildItem -Path $ProjectPath -Filter "*.gd" -Recurse -File | Where-Object {
    $_.FullName -notmatch "\\.[\\/]git[\\/]" -and $_.FullName -notmatch "addons[\\/]"
}
$staticFileErrors = @()
if ($gdFiles) {
    Write-Host "  Found $($gdFiles.Count) script(s) to check"
    foreach ($file in $gdFiles) {
        $relPath = $file.FullName.Substring($ProjectPath.Length).TrimStart('/', '\')
        $resPath = "res://$relPath" -replace "\\", "/"

        # 先不带 --debug 检查错误（避免 Godot#117123：--debug + 有错误脚本 = 无限循环）
        $checkResult = Invoke-GodotCheck -Arguments @(
            "--path", $ProjectPath,
            "--headless",
            "--check-only",
            "--script", $resPath
        ) -TimeoutMs 5000

        $scriptOut = $checkResult.Lines

        if ($checkResult.TimedOut) {
            Write-Host "  [$resPath] Timed out after 5 seconds" -ForegroundColor Yellow
        }
        elseif (-not $checkResult.HasErrors) {
            # 无错误时才用 --debug 获取静态警告（Godot#117123 只在有错误时触发无限循环）
            $debugResult = Invoke-GodotCheck -Arguments @(
                "--path", $ProjectPath,
                "--headless",
                "--check-only",
                "--debug",
                "--script", $resPath
            ) -TimeoutMs 5000
            if (-not $debugResult.TimedOut) {
                $scriptOut = $debugResult.Lines
            }
        }

        $filtered = @(Filter-FileErrors $scriptOut -ScriptResPath $resPath)
        if ($filtered) {
            Write-Host "  [$resPath]" -ForegroundColor Red
            foreach ($line in $filtered) {
                Write-Host "    $line" -ForegroundColor Red
            }
            $staticFileErrors += $filtered
        }
    }
    if (-not $staticFileErrors) {
        Write-Host "  All scripts passed static check" -ForegroundColor Green
    }
}
else {
    Write-Host "  No .gd files found" -ForegroundColor Yellow
}

# 3/3 运行时错误检查
Write-Host "`n3/3 Runtime error checking..."
$runtimeArgs = @(
    "--path", $ProjectPath,
    "--headless",
    "--no-debug-break",
    "--ignore-error-breaks",
    "--quit-after", "60"
)
$runtimeResult = Invoke-GodotCheck -Arguments $runtimeArgs -TimeoutMs 5000
if ($runtimeResult.TimedOut) { Write-Host "  Timed out after 5 seconds" -ForegroundColor Yellow }
$runtimeErrors = @(Filter-Errors $runtimeResult.Lines)
Format-Output $runtimeErrors "Runtime"

$allLines = $staticProjectErrors + $staticFileErrors + $runtimeErrors

$errorCount = ($allLines | Where-Object {
        $_ -match "ERROR:" -or $_ -match "Parse Error" -or $_ -match "Compile Error" -or $_ -match "Script error"
    }).Count

$warningCount = ($allLines | Where-Object {
        $_ -match "WARNING:"
    }).Count

Write-Host "`n=== Summary ==="
Write-Host "Errors: $errorCount"
Write-Host "Warnings: $warningCount"

if ($errorCount -eq 0) {
    Write-Host "`nCheck completed, no errors found!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`nFound $errorCount errors, $warningCount warnings" -ForegroundColor Yellow
    exit 1
}
