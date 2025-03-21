@echo off
setlocal enabledelayedexpansion
echo Building Flutter App...

:: 保存根目录路径
set ROOT_DIR=%CD%

:: 检查必要的工具
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Flutter not found. Please install Flutter and add it to your PATH.
    exit /b 1
)

where dart >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Dart not found. Please install Dart and add it to your PATH.
    exit /b 1
)

:: 检查必要的目录是否存在
if not exist client (
    echo Client directory not found
    exit /b 1
)

if not exist server-dart (
    echo Server directory not found
    exit /b 1
)

if not exist launcher (
    echo Launcher directory not found
    exit /b 1
)

:: 清理旧的构建目录
if exist dist rmdir /s /q dist
mkdir dist

:: 构建 Flutter Windows 客户端
echo Building Windows client...
cd client
echo Ensuring build directory exists...
if not exist build\windows mkdir build\windows
echo Running flutter clean...
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo Failed to clean Flutter project
    cd %ROOT_DIR%
    exit /b 1
)
echo Running flutter pub get...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo Failed to get Flutter dependencies
    cd %ROOT_DIR%
    exit /b 1
)
echo Building Windows application...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo Failed to build Windows client
    cd %ROOT_DIR%
    exit /b 1
)
cd %ROOT_DIR%

:: 检查 Windows 构建输出
if not exist client\build\windows\x64\runner\Release (
    echo Windows build output directory not found
    exit /b 1
)

:: 构建 Flutter Web 版本
echo Building Web version...
cd client
call flutter build web --web-renderer html --release
if %ERRORLEVEL% neq 0 (
    echo Failed to build Web version
    cd %ROOT_DIR%
    exit /b 1
)
cd %ROOT_DIR%

:: 构建 Dart 服务器
echo Building Server...
cd server-dart
if not exist build mkdir build
call dart compile exe bin/server.dart -o build/server.exe
if %ERRORLEVEL% neq 0 (
    echo Failed to build server
    cd %ROOT_DIR%
    exit /b 1
)
cd %ROOT_DIR%

:: 构建启动器
echo Building Launcher...
cd launcher
if not exist build mkdir build
call dart pub get
call dart compile exe bin/main.dart -o build/launcher.exe
if %ERRORLEVEL% neq 0 (
    echo Failed to build launcher
    cd %ROOT_DIR%
    exit /b 1
)
cd %ROOT_DIR%

:: 创建发布目录结构
echo Creating distribution directories...
mkdir dist\client
mkdir dist\server
mkdir dist\web

:: 复制文件
echo Copying files...
echo Copying Windows client files...
if exist client\build\windows\x64\runner\Release (
    xcopy /E /I /Y "client\build\windows\x64\runner\Release\*" "dist\client\"
) else (
    echo Windows client build directory not found
    exit /b 1
)

echo Copying Web files...
if exist client\build\web (
    xcopy /E /I /Y "client\build\web\*" "dist\web\"
) else (
    echo Web build directory not found
    exit /b 1
)

echo Copying server file...
if exist server-dart\build\server.exe (
    copy "server-dart\build\server.exe" "dist\server\"
) else (
    echo Server executable not found
    exit /b 1
)

echo Copying launcher...
if exist launcher\build\launcher.exe (
    copy "launcher\build\launcher.exe" "dist\"
) else (
    echo Launcher executable not found
    exit /b 1
)

echo Build complete! You can find the output in the 'dist' folder.
echo To run the application, execute launcher.exe in the dist folder.
pause 