@echo off
chcp 65001 >nul
title reasonix 更新工具
echo ========================================
echo    reasonix 自动更新脚本
echo ========================================
echo.

:: 确保 npm 配置优化
call npm config set fetch-retries 4
call npm config set fetch-retry-mintimeout 20000
call npm config set fetch-retry-maxtimeout 120000

echo [信息] npm 重试配置已优化（重试4次、20s~120s退避）
echo.

:: 尝试更新，最多重试 3 次
set MAX_RETRIES=3
set RETRY_COUNT=0
set SUCCESS=0

:RETRY_LOOP
set /a RETRY_COUNT+=1
echo [尝试 %RETRY_COUNT%/%MAX_RETRIES%] 正在检查 reasonix 更新...

:: 先尝试 prefer-offline（优先使用已有缓存）
call npm install -g reasonix@latest --prefer-offline --no-audit --no-fund 2>nul

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [成功] reasonix 已更新到最新版本！
    call reasonix version
    set SUCCESS=1
    goto END
)

echo [警告] 缓存安装失败，尝试在线安装...
call npm install -g reasonix@latest --no-audit --no-fund 2>&1

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [成功] reasonix 已更新到最新版本！
    call reasonix version
    set SUCCESS=1
    goto END
)

if %RETRY_COUNT% LSS %MAX_RETRIES% (
    echo [重试] 等待 5 秒后重试...
    timeout /t 5 /nobreak >nul
    goto RETRY_LOOP
)

echo.
echo [失败] 连续 %MAX_RETRIES% 次更新失败。
echo.
echo 可能的原因：
echo   1. 网络连接不稳定（当前镜像: registry.npmmirror.com）
echo   2. 代理/CDN 服务暂时不可用
echo.
echo 备选方案：
echo   方案 A：切换到官方 registry 再试
echo      npm config set registry https://registry.npmjs.org
echo      npm install -g reasonix@latest
echo      npm config set registry https://registry.npmmirror.com
echo.
echo   方案 B：使用代理域名克隆源码后本地安装
echo      git clone https://githubproxy.cc/https://github.com/esengine/DeepSeek-Reasonix.git
echo      cd DeepSeek-Reasonix
echo      npm install && npm run build
echo.
echo   方案 C：清空 npm 缓存后重试
echo      npm cache clean --force
echo      然后重新运行本脚本
echo.

:END
if %SUCCESS% EQU 1 (
    echo.
    echo ========================================
    echo    更新完成
    echo ========================================
)
pause
