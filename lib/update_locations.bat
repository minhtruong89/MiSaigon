@echo off
chcp 65001 >nul
echo ======================================================
echo    CAP NHAT DANH SACH QUAN (LOCATIONS) VAO QUAN_INFO.JSON
echo ======================================================
if exist "%~dp0sync_locations.py" (
    python "%~dp0sync_locations.py"
) else if exist "%~dp0sync_location.py" (
    python "%~dp0sync_location.py"
) else (
    echo Khong tim thay script python trong %~dp0
)
echo.
pause
