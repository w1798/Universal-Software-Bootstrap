@echo off
setlocal EnableDelayedExpansion

rem =======================================================================
rem  Universal Software Bootstrap (USB) 萬用軟體前導程式
rem  ----------------------------------------------------------------------
rem  Component: [核心引擎 - Standalone 混合版 (Sync/ML)]
rem  Copyright (c) 2026 Charles Nextime
rem  Licensed under the GNU General Public License v3.0
rem =======================================================================

rem 指定設定檔（INI）
set "IniFile=start.ini"

rem 切換工作目錄
pushd "%~dp0"

rem 程式開始，新建記錄檔
set "ActiveLog=%~dp0start_log.txt"
set "BakDataFolder=MyData"
set "StartDelay=5"
set "ErrorTimeout=5"
set "MonitorInterval=3"

rem --- 預設語言初始化 (英文) ---
call :InitLanguage "EN"

rem --- 初步解析 INI (只為了抓 Lang 設定) ---
if exist "!IniFile!" (
    for /f "usebackq delims=" %%l in ("!IniFile!") do (
        for /f "tokens=1* delims==" %%a in ("%%l") do (
            if /i "%%a"=="Lang" set "Lang=%%b"
        )
    )
)

rem --- 根據 INI 切換語言 ---
if /i "!Lang!"=="TW" call :InitLanguage "TW"

call :log "============================================" "new"
call :log " !msg_log_header!: %date% %time%"
call :log " !msg_log_path!: %CD%"
call :log "============================================"

if not exist "!IniFile!" (
    set "msgContent=!msg_err_noini!"
    call :log "!msgContent!"    
    call :POPUP_MSG "!msgContent!" "!msg_title_err!" "1"
)

rem --- 第一階段：解析設定檔 ---
call :log "!msg_step1!"
set "section="
set "SaveList=" & set "RegKeyList=" & set "DelList=" & set "KillList="
set "BeforeCMDList=" & set "AfterCMDList="

for /f "usebackq delims=" %%l in ("%IniFile%") do (
    set "line=%%l"
    for /f "tokens=* delims= " %%z in ("!line!") do set "line=%%z"
    set "firstChar=!line:~0,1!"
    
    if "!firstChar!"=="[" (
        set "section=!line:~1,-1!"
    ) else if not "!firstChar!"==";" if not "!firstChar!"=="#" if not "!line!"=="" (
        if /i "!section!"=="Config" (
            for /f "tokens=1* delims==" %%a in ("!line!") do (
                set "k=%%a" & set "v=%%b"
                for /f "tokens=* delims= " %%y in ("!k!") do set "k=%%y"
                call set "v=!v!"
                set "!k!=!v!"
            )
        ) else (
            set "val=%%l"
            call set "val=!line!"
            if /i "!section!"=="SaveList"      set "SaveList=!SaveList! "!val!""
            if /i "!section!"=="RegList"       set "RegKeyList=!RegKeyList! "!val!""
            if /i "!section!"=="DelList"       set "DelList=!DelList! "!val!""
            if /i "!section!"=="KillList"      set "KillList=!KillList! "!val!""
            if /i "!section!"=="BeforeCMDList" set "BeforeCMDList=!BeforeCMDList!^|!line!"
            if /i "!section!"=="AfterCMDList"  set "AfterCMDList=!AfterCMDList!^|!line!"
        )
    )
)

rem --- 環境與安全檢查 ---
set "CheckError=0"
set "errorMsg="

if "%RunExe%"=="" (
    set "CheckError=1"
    set "msg=!msg_err_norunexe!"
    call :log "!msg!"
    set "errorMsg=!errorMsg!!msg! ; "
) else if not exist "%CD%\%RunExe%" (
    set "CheckError=1"
    set "msg=!msg_err_missingexe! %RunExe%"
    call :log "!msg!"
    set "errorMsg=!errorMsg!!msg! ; "
) else (
    if "%ExeTaskName%"=="" (
        set "ExeTaskName=%RunExe%"
        call :log "!msg_warn_notaskname! !RunExe!。"
    )
)

if "%CheckError%"=="1" (
    set "finalMsg=!errorMsg!!msg_err_checkini!"
    call :POPUP_MSG "!finalMsg!" "!msg_title_err!" "1"
)

if /i "%~1"=="s" (
    set "Debug=0"
    set "ErrorTimeout=0"
    call :log "!msg_info_quiet!"
)

if "%MkLinkJ%"=="1" (
    set "UseOld=0"
    call :log "!msg_info_mklink!"
)

title Portable %ExeTaskName% !msg_title_launcher!
set "BakFolderName=%~dp0%BakDataFolder%"

rem --- 啟動前環境檢查 ---
call :process_manager "%ExeTaskName%" "none"

if "!isFound!"=="1" (
    set "msgContent=!msg_err_running! !ExeTaskName!"
    call :log "!msgContent!"
    call :POPUP_MSG "!msgContent!" "!msg_title_err!" "1"
)

rem --- 啟動前環境清理 ---
if defined KillList (
    for %%k in (%KillList%) do (
        set "killed=0"
        for /L %%i in (1,1,5) do (
            if "!killed!"=="0" (
                call :process_manager "%%~k" "kill"
                tasklist /fi "IMAGENAME eq %%~k" | find /i "%%~k" >nul
                if errorlevel 1 (
                    set "killed=1"
                ) else (
                    call :log "  - [!msg_wait!]: !msg_trying_kill! %%~k (%%i)..."
                    timeout /t %MonitorInterval% /nobreak >nul
                )
            )
        )
        if "!killed!"=="0" (
            set "msgContent=!msg_err_kill_failed! %%~k"
            call :log "!msgContent!"
            call :POPUP_MSG "!msgContent!" "!msg_title_warn!" "0"
        )
    )
)

rem --- 第二階段：執行還原/掛載 ---
call :log "!msg_step2!"

if "%MkLinkJ%"=="1" (
    if defined SaveList (
        if not exist "%BakFolderName%" md "%BakFolderName%"
        for %%i in (%SaveList%) do call :link_engine "%%~i" "restore"
    )
) else (
    if defined SaveList (
        for %%i in (%SaveList%) do call :sync_engine "%%~i" "restore"
    )
)

if defined RegKeyList (
    call :log "!msg_reg_restore!"
    for %%r in (%RegKeyList%) do (
        set "rKey=%%~r"
        set "rFileName=%BakFolderName%\!rKey:\=_!.reg"
        if exist "!rFileName!" (
            call :log "  - [!msg_restore_item!]: %%~r"
            call :reg_engine "%%~r" "restore"
            if !errorlevel!==0 (
                call :log "    => [!msg_success!]: !msg_reg_imported!。"
            ) else (
                call :log "    [!] [!msg_title_warn!]: !msg_err_code! !errorlevel!。"
            )
        ) else (
            call :log "  - [!msg_skip_item!]: %%~r (!msg_no_bak!)。"
        )
    )
)

rem --- 第三階段：啟動自定義指令 ---
if defined BeforeCMDList (
    call :log "!msg_step3!"
    call :run_cmds "!BeforeCMDList!" "Before Launcher"
) else (
    call :log "!msg_step3_skip!"
)

rem --- 第四階段：啟動與監控 ---
call :log "!msg_step4! %ExeTaskName%"

if "%StartWait%"=="1" (
    call :log "!msg_mode_wait!"
    start /wait "" "%CD%\%RunExe%"
) else (
    call :log "!msg_mode_loop!"
    start "" "%CD%\%RunExe%"
    call :log "!msg_info_waiting!"
    timeout /t %StartDelay% /nobreak >nul
    :CHECK_RUNNING
    tasklist /fi "IMAGENAME eq %ExeTaskName%" | find /i "%ExeTaskName%" >nul
    if !errorlevel!==0 ( 
        timeout /t %MonitorInterval% /nobreak >nul 
        goto CHECK_RUNNING 
    )
)

call :log "!msg_info_closed!"
timeout /t %MonitorInterval% /nobreak >nul

rem --- 第五階段：結束同步與清理 ---
call :log "!msg_step5!"

if defined KillList (
    call :log "!msg_info_killing!"
    for %%k in (%KillList%) do (
        set "postKilled=0"
        call :log "  - [!msg_check_proc!]: %%~k"
        for /L %%i in (1,1,5) do (
            if "!postKilled!"=="0" (
                call :process_manager "%%~k" "kill"
                tasklist /fi "IMAGENAME eq %%~k" | findstr /i /b /c:"%%~k" >nul
                if errorlevel 1 (
                    if %%i GTR 1 call :log "    => [!msg_success!]: %%~k !msg_info_ended! (%%i)。"
                    set "postKilled=1"
                ) else (
                    call :log "    [!] %%~k !msg_info_still_run! %%i..."
                    timeout /t %MonitorInterval% /nobreak >nul
                )
            )
        )
        if "!postKilled!"=="0" (
            set "msgContent=!msg_err_kill_final! %%~k"
            call :log "!msgContent!"
            call :POPUP_MSG "!msgContent!" "!msg_title_warn!" "0"
        )
    )
)

if "%UseOld%"=="1" (
    call :log "!msg_info_useold! %BakDataFolder%_old..."
    set "BakFolderNameOld=%BakFolderName%_old"
    if exist "!BakFolderNameOld!" rd /s /q "!BakFolderNameOld!"
    if exist "%BakFolderName%" rename "%BakFolderName%" "%BakDataFolder%_old"
)

if "%MkLinkJ%"=="1" (
    if defined SaveList (
        for %%i in (%SaveList%) do call :link_engine "%%~i" "backup"
    )
) else (
    if defined SaveList (
        if not exist "%BakFolderName%" md "%BakFolderName%"
        for %%i in (%SaveList%) do call :sync_engine "%%~i" "backup"
    )
)

if defined RegKeyList (
    if not exist "%BakFolderName%" md "%BakFolderName%"
    call :log "!msg_reg_cleanup!"
    for %%r in (%RegKeyList%) do (
        call :log "  - [!msg_bak_path!]: %%~r"
        call :reg_engine "%%~r" "backup"
        reg delete "%%~r" /f >nul 2>&1
        if !errorlevel!==0 (
            call :log "    => [!msg_success!]: !msg_reg_cleaned!。"
        ) else (
            reg query "%%~r" >nul 2>&1
            if !errorlevel!==0 (
                call :log "    [!] [!msg_fail!]: !msg_err_reg_perm!。"
            ) else (
                call :log "    => [!msg_skip!]: !msg_no_reg_path!。"
            )
        )
    )
)

call :log "!msg_info_cleaning!"
if defined DelList (
    for %%d in (%DelList%) do (
        set "target=%%~d"
        call :is_path_safe "!target!" && call :item_remover "!target!" "Item"
    )
)

if defined AfterCMDList (
    call :log "  - [!msg_ext!]: !msg_step5_aftercmd!..."
    call :run_cmds "!AfterCMDList!" "After Launcher"
)

call :log "!msg_finished!"
if not defined StartLog if exist "!ActiveLog!" del /f /q "!ActiveLog!"

timeout /t %ErrorTimeout% /nobreak
goto :eof

rem ================================================================
rem  功能子程序 (Subroutines)
rem ================================================================

:InitLanguage
    if /i "%~1"=="TW" (
        set "msg_log_header=啟動紀錄"
        set "msg_log_path=執行目錄"
        set "msg_title_err=啟動器錯誤"
        set "msg_title_warn=啟動器警告"
        set "msg_title_launcher=啟動器"
        set "msg_err_noini=錯誤：找不到設定檔 !IniFile!"
        set "msg_err_norunexe=[錯誤] INI 內的 RunExe 參數未設定。"
        set "msg_err_missingexe=[錯誤] 找不到執行檔:"
        set "msg_err_checkini=請檢查 「!IniFile!」 設定內容。"
        set "msg_warn_notaskname=[警告] 未設定 ExeTaskName，預設採用"
        set "msg_info_quiet=[資訊] 已啟動安靜模式，Debug 已強制停用。"
        set "msg_info_mklink=[資訊] 已啟動掛載模式 (MkLinkJ)，UseOld 已強制停用。"
        set "msg_err_running=[錯誤] 主程式已在執行中:"
        set "msg_step1=[1/5] 正在準備環境與個人設定..."
        set "msg_step2=[2/5] 正在還原個人設定與掛載環境..."
        set "msg_step3=[3/5] 執行啟動前自定義指令..."
        set "msg_step3_skip=[3/5] 無自定義指令，跳過。"
        set "msg_step4=[4/5] 正在啟動程序:"
        set "msg_step5=[5/5] 執行同步回寫與痕跡清理..."
        set "msg_wait=等待"
        set "msg_trying_kill=正在嘗試結束"
        set "msg_err_kill_failed=[嚴重錯誤] 無法結束進程:"
        set "msg_err_kill_final=[嚴重警告] 無法完全結束進程:"
        set "msg_reg_restore=[註冊表] 正在還原註冊表設定..."
        set "msg_restore_item=還原項目"
        set "msg_skip_item=跳過項目"
        set "msg_no_bak=無歷史備份檔"
        set "msg_success=成功"
        set "msg_fail=失敗"
        set "msg_skip=跳過"
        set "msg_ext=擴充"
        set "msg_reg_imported=設定已匯入"
        set "msg_err_code=匯入過程回傳錯誤碼"
        set "msg_mode_wait=[監控模式] 使用 start /wait (被動等待)..."
        set "msg_mode_loop=[監控模式] 使用 tasklist 循環 (主動監控)..."
        set "msg_info_waiting=[資訊] 監控中，等待程式結束..."
        set "msg_info_closed=[結束] 偵測到程式已關閉。"
        set "msg_info_killing=[資訊] 正在清理殘留背景進程..."
        set "msg_check_proc=檢查進程"
        set "msg_info_ended=已結束"
        set "msg_info_still_run=仍在運行，準備重殺"
        set "msg_info_useold=[保險] 正在將舊備份移至"
        set "msg_reg_cleanup=[註冊表] 正在處理註冊表設定備份與清理..."
        set "msg_bak_path=備份路徑"
        set "msg_reg_cleaned=主機註冊表項已清理"
        set "msg_err_reg_perm=無法刪除註冊表項，請檢查權限"
        set "msg_no_reg_path=主機無對應路徑，無需清理"
        set "msg_info_cleaning=[資訊] 正在清理電腦上的痕跡..."
        set "msg_step5_aftercmd=執行結束後自定義指令"
        set "msg_finished=[完成] 所有作業已結束。"
        set "msg_debug_wait=[DEBUG WAIT] 檢查上列訊息，按任意鍵繼續..."
        set "msg_mount_ok=掛載成功"
        set "msg_mount_fail=掛載失敗"
        set "msg_dir_restore=目錄還原"
        set "msg_file_restore=檔案還原"
        set "msg_unmount_ok=卸載完成"
        set "msg_dir_clean=清理目錄"
        set "msg_file_bak=檔案備份"
    ) else (
        set "msg_log_header=Launch Log"
        set "msg_log_path=Directory"
        set "msg_title_err=Launcher Error"
        set "msg_title_warn=Launcher Warning"
        set "msg_title_launcher=Launcher"
        set "msg_err_noini=Error: Config file !IniFile! not found."
        set "msg_err_norunexe=[Error] RunExe parameter not set in INI."
        set "msg_err_missingexe=[Error] Executable not found:"
        set "msg_err_checkini=Please check "!IniFile!" content."
        set "msg_warn_notaskname=[Warning] ExeTaskName not set, using"
        set "msg_info_quiet=[Info] Quiet mode enabled, Debug disabled."
        set "msg_info_mklink=[Info] MkLinkJ enabled, UseOld disabled."
        set "msg_err_running=[Error] Program already running:"
        set "msg_step1=[1/5] Preparing environment and settings..."
        set "msg_step2=[2/5] Restoring settings and mounting..."
        set "msg_step3=[3/5] Executing BeforeCMDList..."
        set "msg_step3_skip=[3/5] No custom commands, skipping."
        set "msg_step4=[4/5] Launching:"
        set "msg_step5=[5/5] Syncing back and cleaning up..."
        set "msg_wait=Wait"
        set "msg_trying_kill=Trying to terminate"
        set "msg_err_kill_failed=[Critical Error] Failed to kill process:"
        set "msg_err_kill_final=[Critical Warning] Could not kill process:"
        set "msg_reg_restore=[Registry] Restoring registry settings..."
        set "msg_restore_item=Restore Item"
        set "msg_skip_item=Skip Item"
        set "msg_no_bak=No backup found"
        set "msg_success=Success"
        set "msg_fail=Fail"
        set "msg_skip=Skip"
        set "msg_ext=Ext"
        set "msg_reg_imported=Settings imported"
        set "msg_err_code=Import failed with code"
        set "msg_mode_wait=[Monitor] Using start /wait (Passive)..."
        set "msg_mode_loop=[Monitor] Using tasklist loop (Active)..."
        set "msg_info_waiting=[Info] Monitoring, waiting for exit..."
        set "msg_info_closed=[End] Program terminated."
        set "msg_info_killing=[Info] Cleaning up background processes..."
        set "msg_check_proc=Check Proc"
        set "msg_info_ended=Terminated"
        set "msg_info_still_run=Still running, retrying kill"
        set "msg_info_useold=[Safety] Moving old backup to"
        set "msg_reg_cleanup=[Registry] Backing up and cleaning..."
        set "msg_bak_path=Backup Path"
        set "msg_reg_cleaned=Registry cleaned"
        set "msg_err_reg_perm=Failed to delete reg key, check permissions"
        set "msg_no_reg_path=Path not found, skip cleaning"
        set "msg_info_cleaning=[Info] Cleaning traces on host..."
        set "msg_step5_aftercmd=Executing AfterCMDList"
        set "msg_finished=[Finished] Task completed."
        set "msg_debug_wait=[DEBUG WAIT] Check messages above, press any key..."
        set "msg_mount_ok=Mount Success"
        set "msg_mount_fail=Mount Failed"
        set "msg_dir_restore=Dir Restored"
        set "msg_file_restore=File Restored"
        set "msg_unmount_ok=Unmount Success"
        set "msg_dir_clean=Dir Cleaned"
        set "msg_file_bak=File Backed up"
    )
goto :eof

:link_engine
    set "item=%~1"
    set "action=%~2"
    call :get_full_path "!item!" "srcPath" "dataPath"
    if /i "!action!"=="restore" (
        if exist "!srcPath!\" ( rd /s /q "!srcPath!" >nul 2>&1 )
        if exist "!srcPath!" ( del /f /q "!srcPath!" >nul 2>&1 )
        call :make_parent_dir "!srcPath!"
        if "%MkLinkJ%"=="1" (
            if exist "!dataPath!" if not exist "!dataPath!\" ( goto :restore_file_mode )
            if not exist "!dataPath!\" md "!dataPath!" >nul 2>&1
            mklink /j "!srcPath!" "!dataPath!" >nul 2>&1 && (
                call :log "  - [!msg_mount_ok!]: !item!"
            ) || (
                call :log "  - [!msg_mount_fail!]: !item!"
            )
        ) else (
            :restore_file_mode
            if exist "!dataPath!\" (
                xcopy "!dataPath!" "!srcPath!\" /I /E /Y /C /Q >nul 2>&1
                call :log "  - [!msg_dir_restore!]: !item!"
            ) else if exist "!dataPath!" (
                copy /y "!dataPath!" "!srcPath!" >nul 2>&1
                call :log "  - [!msg_file_restore!]: !item!"
            )
        )
        goto :eof
    )
    if /i "!action!"=="backup" (
        if not exist "!srcPath!" exit /b
        rd "!srcPath!" >nul 2>&1 && (
            call :log "  - [!msg_unmount_ok!]: !item!"
            exit /b
        )
        if exist "!srcPath!\" (
            rd /s /q "!srcPath!" >nul 2>&1
            call :log "  - [!msg_dir_clean!]: !item!"
        ) else (
            copy /y "!srcPath!" "!dataPath!" >nul 2>&1
            del /f /q "!srcPath!" >nul 2>&1
            call :log "  - [!msg_file_bak!]: !item!"
        )
        goto :eof
    )
goto :eof

:make_parent_dir
    set "p_path=%~dp1"
    if not exist "!p_path!" md "!p_path!" >nul 2>&1
goto :eof

:sync_engine
    set "item=%~1"
    set "action=%~2"
    call :get_full_path "!item!" "srcPath" "dataPath"
    if "!action!"=="restore" (
        if exist "!dataPath!" (
            call :log "  - !msg_file_restore!: !item!"
            call :copy_file "!dataPath!" "!srcPath!"
        )
    ) else (
        if exist "!srcPath!" (
            call :log "  - !msg_file_bak!: !item!"
            call :copy_file "!srcPath!" "!dataPath!"
            call :item_remover "!srcPath!" "Item"
        )
    )
goto :eof

:get_full_path
    set "rawPath=%~1"
    for /f "delims=" %%i in ("!rawPath!") do set "absPath=%%~fi"
    set "%~2=!absPath!"
    set "driveLetter=!absPath:~0,1!"
    set "remainPath=!absPath:~3!"
    set "%~3=%BakFolderName%\!driveLetter!\!remainPath!"
goto :eof

:is_path_safe
    set "p=%~1"
    if "!p!"=="" exit /b 1
    set "checkRoot=!p:~1,2!"
    if "!checkRoot!"==":\" if "!p:~3!"=="" exit /b 1
    for %%g in ("%SystemDrive%" "%SystemRoot%" "%WinDir%" "%ProgramFiles%" "%ProgramFiles(x86)%" "%UserProfile%") do (
        if /i "!p!"=="%%~g" exit /b 1
        if /i "!p!"=="%%~g\" exit /b 1
    )
exit /b 0

:reg_engine
    set "rKey=%~1" & set "action=%~2"
    set "rFileName=%BakFolderName%\!rKey:\=_!.reg"
    if "!action!"=="restore" (
        if exist "!rFileName!" reg import "!rFileName!" >nul 2>&1
    ) else (
        reg export "!rKey!" "!rFileName!" /y >nul 2>&1
    )
goto :eof

:item_remover
    set "targetPath=%~1" & set "displayName=%~2"
    if not exist "!targetPath!" goto :eof
    call :log "  - [!msg_check_proc!]: !targetPath!"
    for /L %%I in (1,1,5) do (
        if exist "!targetPath!" (
            rd "!targetPath!" >nul 2>&1
            if exist "!targetPath!" (
                if exist "!targetPath!\" (
                    rd /s /q "!targetPath!" >> "!ActiveLog!" 2>&1
                ) else (
                    del /f /q "!targetPath!" >> "!ActiveLog!" 2>&1
                )
                if exist "!targetPath!" (
                    call :log "    [!] !msg_info_still_run! %%I..."
                    timeout /t 2 /nobreak >nul
                )
            )
        )
    )
    if not exist "!targetPath!" (
        call :log "    => [!msg_success!]: !msg_info_ended!。"
    ) else (
        call :log "    => [!msg_fail!]: !msg_err_kill_final!。"
    )
goto :eof

:process_manager
    set "targetName=%~1" & set "mode=%~2" & set "isFound=0"
    tasklist /fi "IMAGENAME eq !targetName!" | find /i "!targetName!" >nul
    if !errorlevel!==0 (
        set "isFound=1"
        if "!mode!"=="kill" (
            taskkill /f /t /im "!targetName!" >nul 2>&1
            timeout /t %MonitorInterval% /nobreak >nul
        )
    )
goto :eof

:run_cmds
    set "cmdStr=%~1" & set "cmdType=%~2"
    if not defined cmdStr goto :eof
    set "workStr=!cmdStr!"
    :loop_cmds
    for /f "tokens=1* delims=|" %%a in ("!workStr!") do (
        set "thisCmd=%%a"
        call :log "[!cmdType!] !msg_wait!: !thisCmd!"
        !thisCmd! >> "!ActiveLog!" 2>&1
        if errorlevel 1 (
            call :log "  => [!msg_fail!]: !msg_err_code! !errorlevel!"
        ) else (
            call :log "  => [!msg_success!]"
        )
        set "workStr=%%b"
        if defined workStr goto :loop_cmds
    )
goto :eof

:copy_file
    set "cn1=%~1" & set "cn2=%~2"
    for %%f in ("%cn2%") do if not exist "%%~dpf" md "%%~dpf"
    if exist "%cn1%\" ( xcopy "%cn1%" "%cn2%\" /I /E /Y /C /Q >nul ) else ( copy /Y "%cn1%" "%cn2%" >nul )
goto :eof

:POPUP_MSG
set "tmpContent=%~1"
set "tmpTitle=%~2"
set "isExit=%~3"
if "%isExit%"=="1" ( set "msgType=4112" ) else ( set "msgType=4144" )
mshta vbscript:Execute("msgbox ""%tmpContent%"",%msgType%,""%tmpTitle%"":close")
if "%isExit%"=="1" ( timeout /t %ErrorTimeout% & exit )
goto :eof

:log
    set "msg=%~1"
    echo(!msg!
    if /i "%~2"=="new" ( echo(!msg! > "!ActiveLog!" ) else ( echo(!msg! >> "!ActiveLog!" )
    if "%Debug%"=="1" (
        echo    !msg_debug_wait!
        pause >nul
    )
goto :eof