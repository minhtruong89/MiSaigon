@echo off
chcp 65001 >nul
echo ======================================================
echo    CAP NHAT DANH SACH MEMBERS VAO QUAN_INFO.JSON
echo ======================================================
if exist "%~dp0sync_members.py" (
    python "%~dp0sync_members.py"
) else if exist "%~dp0sync_member.py" (
    python "%~dp0sync_member.py"
) else (
    echo Khong tim thay script python trong %~dp0
)
echo.
pause
