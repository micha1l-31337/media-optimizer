@echo off
setlocal EnableDelayedExpansion
:: Включаем UTF-8 для корректной работы с кириллицей
chcp 65001 >nul
title Media Optimizer v5.4 STABLE - Initializing...
cd /d "%~dp0"

:: =================================================================================================
:: MEDIA OPTIMIZER v5.4 STABLE - ПОЛНАЯ ДОКУМЕНТАЦИЯ
:: =================================================================================================
:: НАЗНАЧЕНИЕ:
::   Пакетная оптимизация медиафайлов с сохранением структуры папок.
::   Поддерживает три режима обработки для каждого типа файлов: СЖАТИЕ (оптимизация), 
::   КОПИРОВАНИЕ (без изменений), ПРОПУСК (игнорирование).
::   Обработанные файлы сохраняются с настраиваемым суффиксом.
::
:: ПОДДЕРЖИВАЕМЫЕ ФОРМАТЫ:
::   Фото (FFmpeg -> JPG): JPG, JPEG, PNG, GIF, TIFF, WebP
::   Фото (ImageMagick -> JPG): HEIC, HEIF, AVIF, SVG, FLIF, BPG
::   Видео: MP4, MKV, WMV, WEBM, M4V, TS, MTS -> конвертация в MP4 (H.264/H.265)
::   Прочие: Любые файлы (копируются без изменений при включённой опции)
::
:: =================================================================================================

:: -------------------------------------------------------------------------------------------------
:: НАСТРОЙКИ ЦВЕТОВ
:: -------------------------------------------------------------------------------------------------
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set "ESC=%%b"
)
set "C_RESET=%ESC%[0m"
set "C_GREEN=%ESC%[92m"
set "C_RED=%ESC%[91m"
set "C_CYAN=%ESC%[96m"
set "C_YELLOW=%ESC%[93m"
set "C_WHITE=%ESC%[97m"
set "C_GRAY=%ESC%[90m"
set "C_PURPLE=%ESC%[95m"

:: -------------------------------------------------------------------------------------------------
:: НАСТРОЙКИ ПО УМОЛЧАНИЮ
:: -------------------------------------------------------------------------------------------------
set "IMG_MAX_SIDE=4320"
set "IMG_Q_FFMPEG=5"        
set "IMG_Q_MAGICK=85"      

set "VID_TARGET_H=1080"
set "VID_PRESET_MODE=2" 
set "VID_FPS=30"            
set "VID_MAXRATE=20M"       
set "VID_BUFSIZE=40M"       
set "VID_CRF_H264=20" 
set "VID_CRF_H265=24" 
set "VID_AUDIO_CODEC=aac" 
set "VID_AUDIO_BITRATE=192k"

set "SUFFIX_RESIZED=_resized"
set "AUTO_BACKUP_ROOT="
set "TEMP_LIST=%TEMP%\media_list_%RANDOM%.txt" 
set "IN_DIR=%CD%"           

set "PROCESS_PHOTOS=1"
set "PROCESS_VIDEOS=1"
set "COPY_OTHERS=1"

:: =================================================================================================
::      ПРОВЕРКА ВХОДЯЩИХ АРГУМЕНТОВ И ПОДГОТОВКА К АВТОЗАПУСКУ
:: =================================================================================================
:PARSE_ARGS
set "AUTO_START=0"
set "IS_DRAG_FILES=0"
if exist "!TEMP_LIST!" del "!TEMP_LIST!" >nul 2>&1

if "%~1"=="" goto MAIN_MENU

:ARG_LOOP
if "%~1"=="" goto CHECK_AUTO_START

if /i "%~1"=="-source"         set "IN_DIR=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-dest"           set "AUTO_BACKUP_ROOT=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-photo_px"       set "IMG_MAX_SIDE=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-video_px"       set "VID_TARGET_H=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-video_mode"     set "VID_PRESET_MODE=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-process_photos" set "PROCESS_PHOTOS=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-process_videos" set "PROCESS_VIDEOS=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-copy_others"    set "COPY_OTHERS=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-video_bitrate"  set "VID_MAXRATE=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-jpg_quality"    set "IMG_Q_FFMPEG=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-suffix"         set "SUFFIX_RESIZED=%~2" & set "AUTO_START=1" & shift & shift & goto ARG_LOOP
if /i "%~1"=="-auto"           set "AUTO_START=1" & shift & goto ARG_LOOP

:: Проверка на перетаскивание файлов или папок
set "ITEM_PATH=%~1"
if exist "!ITEM_PATH!\" (
    :: Это папка
    if "!IS_DRAG_FILES!"=="0" set "IN_DIR=!ITEM_PATH!"
    set "AUTO_START=1"
) else if exist "!ITEM_PATH!" (
    :: Это файл
    set "IS_DRAG_FILES=1"
    set "AUTO_START=1"
    echo !ITEM_PATH!>>"!TEMP_LIST!"
    :: Устанавливаем IN_DIR по первому файлу для корректного сохранения рядом
    if "!IN_DIR!"=="%CD%" (
        for %%I in ("!ITEM_PATH!") do set "IN_DIR=%%~dpI"
    )
)

shift
goto ARG_LOOP

:CHECK_AUTO_START
if "!AUTO_START!"=="1" goto SCAN_PREPARE
goto MAIN_MENU

:: =================================================================================================
::      ГЛАВНОЕ МЕНЮ
:: =================================================================================================
:MAIN_MENU
set "DISPLAY_IN=!IN_DIR!"
if "!DISPLAY_IN:~-1!"=="\" set "DISPLAY_IN=!DISPLAY_IN:~0,-1!"

if "!PROCESS_PHOTOS!"=="1" (set "TXT_P_PHOTO=%C_GREEN%СЖИМАТЬ%C_RESET%") else if "!PROCESS_PHOTOS!"=="0" (set "TXT_P_PHOTO=%C_YELLOW%КОПИРОВАТЬ%C_RESET%") else (set "TXT_P_PHOTO=%C_GRAY%ПРОПУСКАТЬ%C_RESET%")
if "!PROCESS_VIDEOS!"=="1" (set "TXT_P_VIDEO=%C_GREEN%СЖИМАТЬ%C_RESET%") else if "!PROCESS_VIDEOS!"=="0" (set "TXT_P_VIDEO=%C_YELLOW%КОПИРОВАТЬ%C_RESET%") else (set "TXT_P_VIDEO=%C_GRAY%ПРОПУСКАТЬ%C_RESET%")
if "!COPY_OTHERS!"=="1" (set "TXT_COPY=%C_YELLOW%КОПИРОВАТЬ%C_RESET%") else (set "TXT_COPY=%C_GRAY%ПРОПУСКАТЬ%C_RESET%")

if "!VID_PRESET_MODE!"=="1" (set "V_NAME=H.264 [Совместимость]") else (set "V_NAME=H.265 [Макс. сжатие]")

cls
echo %C_WHITE%MEDIA OPTIMIZER v5.4 STABLE%C_RESET%
echo ------------------------------------------------------------------------------
echo %C_WHITE%[1] Источник:%C_RESET%       "!DISPLAY_IN!\"
if "!AUTO_BACKUP_ROOT!"=="" (
    echo %C_WHITE%[2] Куда:%C_RESET%           %C_YELLOW%[В подпапку optimized]%C_RESET%
) else (
    set "DISPLAY_DEST=!AUTO_BACKUP_ROOT!"
    if "!DISPLAY_DEST:~-1!" neq "\" set "DISPLAY_DEST=!DISPLAY_DEST!\"
    echo %C_WHITE%[2] Куда:%C_RESET%           %C_GREEN%"!DISPLAY_DEST!"%C_RESET%
)
echo.
echo %C_WHITE%[3] Фото:  !TXT_P_PHOTO!
echo %C_WHITE%[4] Видео: !TXT_P_VIDEO!
echo %C_WHITE%[5] Кодек: !V_NAME!
echo %C_WHITE%[6] Прочие файлы: !TXT_COPY!
echo %C_WHITE%[7] Изменить размер фото [%C_YELLOW%!IMG_MAX_SIDE!px%C_RESET%]
echo %C_WHITE%[8] Изменить размер видео [%C_YELLOW%!VID_TARGET_H!p%C_RESET%]
echo %C_WHITE%[9] Качество JPG [%C_YELLOW%!IMG_Q_FFMPEG!%C_RESET%]
echo %C_WHITE%[10] Битрейт видео [%C_YELLOW%!VID_MAXRATE!%C_RESET%]
echo %C_WHITE%[11] Суффикс [%C_YELLOW%!SUFFIX_RESIZED!%C_RESET%]
echo.
echo %C_GREEN%ENTER%C_RESET% - Старт    %C_YELLOW%1-11%C_RESET% - Настройки    %C_RED%X%C_RESET% - Выход
echo.
set "choice="
set /p "choice=Ваш выбор > "

if "%choice%"=="" goto SCAN_PREPARE
if "%choice%"=="0" goto SCAN_PREPARE
if "%choice%"=="1" goto SET_PATH_IN
if "%choice%"=="2" goto SET_PATH_OUT
if "%choice%"=="3" goto TOG_PHOTO
if "%choice%"=="4" goto TOG_VIDEO
if "%choice%"=="5" goto SET_VID_CODEC
if "%choice%"=="6" goto TOG_COPY
if "%choice%"=="7" goto SET_IMG_SIZE
if "%choice%"=="8" goto SET_VID_SIZE
if "%choice%"=="9" goto SET_JPG_QUALITY
if "%choice%"=="10" goto SET_VIDEO_BITRATE
if "%choice%"=="11" goto SET_SUFFIX
if /i "%choice%"=="X" exit /b
goto MAIN_MENU

:: --- SETTINGS ---
:SET_PATH_IN
echo.
set /p "new_in=%C_CYAN%Путь к файлам:%C_RESET% "
if not "!new_in!"=="" set "IN_DIR=!new_in:"=!"
goto MAIN_MENU

:SET_PATH_OUT
echo.
set /p "new_root=%C_CYAN%Путь бэкапа:%C_RESET% "
set "new_root=!new_root:"=!"
if not "!new_root!"=="" (
    if "!new_root:~-1!" neq "\" set "new_root=!new_root!\"
)
set "AUTO_BACKUP_ROOT=!new_root!"
goto MAIN_MENU

:TOG_PHOTO
if "!PROCESS_PHOTOS!"=="1" (set "PROCESS_PHOTOS=0") else if "!PROCESS_PHOTOS!"=="0" (set "PROCESS_PHOTOS=-1") else (set "PROCESS_PHOTOS=1")
goto MAIN_MENU

:TOG_VIDEO
if "!PROCESS_VIDEOS!"=="1" (set "PROCESS_VIDEOS=0") else if "!PROCESS_VIDEOS!"=="0" (set "PROCESS_VIDEOS=-1") else (set "PROCESS_VIDEOS=1")
goto MAIN_MENU

:SET_VID_CODEC
if "!VID_PRESET_MODE!"=="1" (set "VID_PRESET_MODE=2") else (set "VID_PRESET_MODE=1")
goto MAIN_MENU

:TOG_COPY
if "!COPY_OTHERS!"=="1" (set "COPY_OTHERS=0") else (set "COPY_OTHERS=1")
goto MAIN_MENU

:SET_IMG_SIZE
echo.
echo %C_CYAN%Рекомендуемые размеры фото (длинная сторона):%C_RESET%
echo   1280 - HD Ready     1920 - FullHD     2560 - QHD/2.5K
echo   3840 - 4K/UHD       4320 - 8K
echo.
set /p "val=%C_CYAN%Введите размер в пикселях:%C_RESET% "
if not "!val!"=="" set "IMG_MAX_SIDE=!val!"
goto MAIN_MENU

:SET_VID_SIZE
echo.
echo %C_CYAN%Рекомендуемые размеры видео (меньшая сторона):%C_RESET%
echo   720  - HD            1080 - FullHD     1440 - 2K/QHD
echo   2160 - 4K/UHD        4320 - 8K
echo.
set /p "val=%C_CYAN%Введите размер в пикселях:%C_RESET% "
if not "!val!"=="" set "VID_TARGET_H=!val!"
goto MAIN_MENU

:SET_JPG_QUALITY
echo.
echo %C_CYAN%Качество JPEG при сжатии (через FFmpeg):%C_RESET%
echo   2  - Архивное качество (макс. размер)
echo   5  - Оптимальный баланс (рекомендуется)
echo   10 - Хорошее сжатие
echo   23 - Стандартное сжатие (мин. качество)
echo.
set /p "val=%C_CYAN%Введите значение (2-31):%C_RESET% "
if not "!val!"=="" set "IMG_Q_FFMPEG=!val!"
goto MAIN_MENU

:SET_VIDEO_BITRATE
echo.
echo %C_CYAN%Максимальный битрейт видео:%C_RESET%
echo   50M - 4K высокое качество
echo   20M - FullHD высокое качество (рекомендуется)
echo   15M - FullHD стандартное качество
echo   10M - FullHD экономия места
echo   5M  - HD (720p)
echo.
set /p "val=%C_CYAN%Введите значение (например: 20M):%C_RESET% "
if not "!val!"=="" (
    set "VID_MAXRATE=!val!"
    set "BUF_VAL=!VID_MAXRATE:M=!"
    set "BUF_VAL=!BUF_VAL:K=!"
    set /a BUF_NUM=!BUF_VAL! * 2
    set "VID_BUFSIZE=!BUF_NUM!M"
)
goto MAIN_MENU

:SET_SUFFIX
echo.
echo %C_CYAN%Суффикс для обработанных файлов:%C_RESET%
echo   По умолчанию: _resized
echo   Примеры: _opt, _small, _archive, _compressed
echo.
set /p "val=%C_CYAN%Введите суффикс (без кавычек):%C_RESET% "
if not "!val!"=="" set "SUFFIX_RESIZED=!val!"
goto MAIN_MENU

:: =================================================================================================
::      ПОДГОТОВКА И СКАНИРОВАНИЕ
:: =================================================================================================
:SCAN_PREPARE
set "IN_DIR=!IN_DIR:"=!"
if "!IN_DIR:~-1!"=="\" set "IN_DIR=!IN_DIR:~0,-1!"

for %%I in ("!IN_DIR!") do set "CURRENT_FOLDER_NAME=%%~nxI"

set "SAME_FOLDER_MODE=0"
if "!AUTO_BACKUP_ROOT!"=="" (
    set "SAME_FOLDER_MODE=1"
    if "!IS_DRAG_FILES!"=="1" (
        :: Для перетащенных файлов сохраняем прямо в их родную папку
        set "TARGET_DIR=!IN_DIR!"
    ) else (
        :: Для папок создаем подпапку optimized
        set "TARGET_DIR=!IN_DIR!\optimized"
    )
) else (
    set "ROOT_TMP=!AUTO_BACKUP_ROOT!"
    if "!ROOT_TMP:~-1!"=="\" set "ROOT_TMP=!ROOT_TMP:~0,-1!"
    set "TARGET_DIR=!ROOT_TMP!\!CURRENT_FOLDER_NAME!"
)

cls
echo %C_CYAN%[1/4] Подготовка списка файлов...%C_RESET%
echo       "!IN_DIR!\"

if "!IS_DRAG_FILES!"=="0" (
    if exist "!TEMP_LIST!" del "!TEMP_LIST!"
    dir /b /s /a-d "!IN_DIR!\*.*" > "!TEMP_LIST!" 2>nul
)

:CHECK_FILES
echo %C_CYAN%[2/4] Анализ и оценка...%C_RESET%
set "CNT_JPG=0"
set "CNT_HEIC=0"
set "CNT_VID=0"
set "CNT_OTHER=0"
set "CNT_DIRS=0"

if not exist "!TEMP_LIST!" goto NO_FILES

if "!IS_DRAG_FILES!"=="0" (
    for /f %%A in ('dir /b /s /ad "!IN_DIR!" 2^>nul ^| find /c /v ""') do set "CNT_DIRS=%%A"
) else (
    set "CNT_DIRS=0"
)

for /f "usebackq delims=" %%A in ("!TEMP_LIST!") do (
    set "TMP_EXT=%%~xA"
    set "IS_MEDIA=0"
    
    if /I "!TMP_EXT!"==".heic" (set /a CNT_HEIC+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".heif" (set /a CNT_HEIC+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".avif" (set /a CNT_HEIC+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".svg"  (set /a CNT_HEIC+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".flif" (set /a CNT_HEIC+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".bpg"  (set /a CNT_HEIC+=1 & set "IS_MEDIA=1")

    if /I "!TMP_EXT!"==".jpg"  (set /a CNT_JPG+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".jpeg" (set /a CNT_JPG+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".png"  (set /a CNT_JPG+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".gif"  (set /a CNT_JPG+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".tiff" (set /a CNT_JPG+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".webp" (set /a CNT_JPG+=1 & set "IS_MEDIA=1")
    
    if /I "!TMP_EXT!"==".mp4"  (set /a CNT_VID+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".mkv"  (set /a CNT_VID+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".wmv"  (set /a CNT_VID+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".webm" (set /a CNT_VID+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".m4v"  (set /a CNT_VID+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".ts"   (set /a CNT_VID+=1 & set "IS_MEDIA=1")
    if /I "!TMP_EXT!"==".mts"  (set /a CNT_VID+=1 & set "IS_MEDIA=1")

    if "!IS_MEDIA!"=="0" set /a CNT_OTHER+=1
)

set /a "TOTAL_FILES=CNT_JPG + CNT_HEIC + CNT_VID + CNT_OTHER"

set /a "TIME_EST_SEC=(CNT_JPG * 1) + (CNT_HEIC * 3) + (CNT_VID * 300)"
set /a "TIME_EST_MIN=TIME_EST_SEC / 60"
if !TIME_EST_MIN! LSS 1 set "TIME_EST_MIN=<1"

if !TOTAL_FILES! equ 0 goto NO_FILES

echo.
echo %C_WHITE%Найдено:%C_RESET% !TOTAL_FILES! файлов в очередь на обработку.
echo   - Фото для FFmpeg:    !CNT_JPG!
echo   - Фото для Magick:   !CNT_HEIC!
echo   - Видео:        !CNT_VID!
echo   - Прочее:       !CNT_OTHER!
echo.
echo %C_YELLOW%Предварительное время работы: ~!TIME_EST_MIN! мин.%C_RESET%
echo.

:: --- ПРОВЕРКА ЗАВИСИМОСТЕЙ ---
set /a "NEED_FFMPEG=0"
if "!PROCESS_PHOTOS!"=="1" if !CNT_JPG! gtr 0 set /a NEED_FFMPEG=1
if "!PROCESS_VIDEOS!"=="1" if !CNT_VID! gtr 0 set /a NEED_FFMPEG=1
if !NEED_FFMPEG! equ 0 goto CHECK_MAGICK
where ffmpeg >nul 2>&1
if !errorlevel! neq 0 goto INSTALL_FFMPEG

:CHECK_MAGICK
set "NEED_MAGICK=0"
if "!PROCESS_PHOTOS!"=="1" if !CNT_HEIC! gtr 0 set "NEED_MAGICK=1"
if "!NEED_MAGICK!"=="0" goto CHECK_GPU
magick -version >nul 2>&1
if !errorlevel! neq 0 goto INSTALL_MAGICK

:CHECK_GPU
if !CNT_VID! equ 0 goto START_PROCESSING
if "!PROCESS_VIDEOS!" neq "1" goto START_PROCESSING

set "USE_NVENC=0"
ffmpeg -hide_banner -encoders 2>nul | findstr /i "hevc_nvenc" >nul
if !errorlevel! equ 0 set "USE_NVENC=1"

if "!USE_NVENC!"=="1" (echo %C_GREEN%[OK] GPU NVENC найден. Использование видеокарты для работы с видео.%C_RESET%) else (echo %C_YELLOW%[INFO] GPU не найден. CPU режим.%C_RESET%)

if "!VID_PRESET_MODE!"=="1" goto MODE_AVC
goto MODE_HEVC

:MODE_AVC
set "V_CODEC_NV=h264_nvenc" & set "V_CODEC_CPU=libx264" & set "V_CQ=!VID_CRF_H264!" & set "V_PROFILE=-profile:v high"
goto START_PROCESSING

:MODE_HEVC
set "V_CODEC_NV=hevc_nvenc" & set "V_CODEC_CPU=libx265" & set "V_CQ=!VID_CRF_H265!" & set "V_PROFILE=-profile:v main"
goto START_PROCESSING

:: =================================================================================================
::      ВОРКЕРЫ ОБРАБОТКИ
:: =================================================================================================
:W_PHOTO_PROCESS
if /i "!F_EXT!"==".heic" goto W_HEIC
if /i "!F_EXT!"==".heif" goto W_HEIC
if /i "!F_EXT!"==".avif" goto W_HEIC
if /i "!F_EXT!"==".svg" goto W_HEIC
if /i "!F_EXT!"==".flif" goto W_HEIC
if /i "!F_EXT!"==".bpg" goto W_HEIC
goto W_JPG

:W_HEIC
set "FULL_DEST=!FINAL_DIR!!F_NAME!!SUFFIX_RESIZED!.jpg"

if exist "!FULL_DEST!" (
    echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[ПРОПУЩЕН]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
    goto :EOF
)

echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_GREEN%[СЖАТИЕ]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
magick "!FULL_SRC!" -resize "%IMG_MAX_SIDE%x%IMG_MAX_SIDE%^>" -quality %IMG_Q_MAGICK% "!FULL_DEST!" 2>nul

dir /b "!FULL_DEST!" >nul 2>&1
if !errorlevel! equ 0 goto :EOF

copy /y "!FULL_SRC!" "!FINAL_DIR!!F_NAME!!F_EXT!" >nul 2>&1
echo %C_YELLOW%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[КОПИЯ]%C_RESET% "!FULL_SRC!" ^> "!FINAL_DIR!!F_NAME!!F_EXT!"
goto :EOF

:W_JPG
set "FULL_DEST=!FINAL_DIR!!F_NAME!!SUFFIX_RESIZED!.jpg"

if exist "!FULL_DEST!" (
    echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[ПРОПУЩЕН]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
    goto :EOF
)

echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_GREEN%[СЖАТИЕ]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
set "RESIZE_FILTER=scale='if(gt(max(iw,ih),%IMG_MAX_SIDE%),if(gt(iw,ih),%IMG_MAX_SIDE%,-2),iw)':'if(gt(max(iw,ih),%IMG_MAX_SIDE%),if(gt(iw,ih),-2,%IMG_MAX_SIDE%),ih)'"
ffmpeg -hide_banner -loglevel error -y -i "!FULL_SRC!" -threads 0 -sws_flags lanczos+accurate_rnd -vf "!RESIZE_FILTER!" -q:v %IMG_Q_FFMPEG% "!FULL_DEST!" 2>nul

dir /b "!FULL_DEST!" >nul 2>&1
if !errorlevel! equ 0 goto :EOF

copy /y "!FULL_SRC!" "!FINAL_DIR!!F_NAME!!F_EXT!" >nul 2>&1
echo %C_YELLOW%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[КОПИЯ]%C_RESET% "!FULL_SRC!" ^> "!FINAL_DIR!!F_NAME!!F_EXT!"
goto :EOF

:W_VIDEO_PROCESS
set "FULL_DEST=!FINAL_DIR!!F_NAME!!SUFFIX_RESIZED!.mp4"

if exist "!FULL_DEST!" (
    echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[ПРОПУЩЕН]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
    goto :EOF
)

echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_GREEN%[СЖАТИЕ]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
set "RESIZE_FILTER=fps=!VID_FPS!,scale=if(gt(iw\,ih)\,-2\,!VID_TARGET_H!):if(gt(iw\,ih)\,!VID_TARGET_H!\,-2)"

if "!USE_NVENC!"=="1" (
    set "V_PARAMS=-c:v !V_CODEC_NV! -preset p6 -tune hq -rc vbr -cq !V_CQ! -b:v 0 -maxrate !VID_MAXRATE! -bufsize !VID_BUFSIZE! !V_PROFILE! -spatial-aq 1"
) else (
    set "V_PARAMS=-c:v !V_CODEC_CPU! -preset medium -crf !V_CQ! -maxrate !VID_MAXRATE! -bufsize !VID_BUFSIZE! -pix_fmt yuv420p"
)

ffmpeg -y -hide_banner -loglevel error -stats -i "!FULL_SRC!" -vf "!RESIZE_FILTER!" !V_PARAMS! -c:a !VID_AUDIO_CODEC! -b:a !VID_AUDIO_BITRATE! -ac 2 "!FULL_DEST!" 2>&1 | findstr /v /r "^$"

if not exist "!FULL_DEST!" (
    echo %C_RED%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_RED%[ОШИБКА]%C_RESET% "!FULL_SRC!" ^> Конвертация не удалась
    copy /y "!FULL_SRC!" "!FINAL_DIR!!F_NAME!!F_EXT!" >nul 2>&1 && (
        echo %C_YELLOW%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[КОПИЯ]%C_RESET% "!FULL_SRC!" ^> "!FINAL_DIR!!F_NAME!!F_EXT!"
    ) || (
        echo %C_RED%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_RED%[ОШИБКА]%C_RESET% "!FULL_SRC!" ^> Не удалось скопировать оригинал
    )
    goto :EOF
)
goto :EOF

:W_COPY_PHOTO
set "FULL_DEST=!FINAL_DIR!!F_NAME!!F_EXT!"
if exist "!FULL_DEST!" (
    echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[ПРОПУЩЕН]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
    goto :EOF
)

echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[КОПИЯ]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
copy /y "!FULL_SRC!" "!FULL_DEST!" >nul 2>&1
goto :EOF

:W_COPY_VIDEO
set "FULL_DEST=!FINAL_DIR!!F_NAME!!F_EXT!"

if exist "!FULL_DEST!" (
    echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[ПРОПУЩЕН]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
    goto :EOF
)

echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[КОПИЯ]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
copy /y "!FULL_SRC!" "!FULL_DEST!" >nul 2>&1
goto :EOF

:W_COPY_OTHER
set "FULL_DEST=!FINAL_DIR!!F_NAME!!F_EXT!"

if exist "!FULL_DEST!" (
    echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_YELLOW%[ПРОПУЩЕН]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
    goto :EOF
)

echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_GRAY%[КОПИЯ]%C_RESET% "!FULL_SRC!" ^> "!FULL_DEST!"
copy /y "!FULL_SRC!" "!FULL_DEST!" >nul 2>&1
goto :EOF

:: =================================================================================================
::      ОБРАБОТКА
:: =================================================================================================
:START_PROCESSING
echo.
echo %C_CYAN%[3/4] Обработка файлов в: !TARGET_DIR!\%C_RESET%
echo ------------------------------------------------------------------------------

if not exist "!TARGET_DIR!" mkdir "!TARGET_DIR!" 2>nul

set "CURRENT_IDX=0"
set "CURRENT_EST_PASSED=0"

set "TOTAL_TASKS=0"
if "!PROCESS_PHOTOS!"=="1" (set /a TOTAL_TASKS+=CNT_JPG + CNT_HEIC) else if "!PROCESS_PHOTOS!"=="0" (set /a TOTAL_TASKS+=CNT_JPG + CNT_HEIC)
if "!PROCESS_VIDEOS!"=="1" (set /a TOTAL_TASKS+=CNT_VID) else if "!PROCESS_VIDEOS!"=="0" (set /a TOTAL_TASKS+=CNT_VID)
if "!COPY_OTHERS!"=="1" (set /a TOTAL_TASKS+=CNT_OTHER)
if !TOTAL_TASKS! equ 0 set "TOTAL_TASKS=1"

for /f "usebackq delims=" %%F in ("!TEMP_LIST!") do (
    set /a CURRENT_IDX+=1
    call :PROCESS_DISPATCHER "%%F"
    
    set /a "SEC_LEFT=TIME_EST_SEC - CURRENT_EST_PASSED"
    if !SEC_LEFT! lss 0 set "SEC_LEFT=0"
    if !SEC_LEFT! lss 60 (set "TIME_LEFT_STR=<1 мин") else (set /a "M_LEFT=SEC_LEFT / 60" & set "TIME_LEFT_STR=!M_LEFT! мин")
    for %%I in ("%%F") do set "FNAME=%%~nxF"
    title Обработка [!CURRENT_IDX!/!TOTAL_TASKS!] ^| осталось ~!TIME_LEFT_STR! ^| !FNAME!
)

if exist "!TEMP_LIST!" del "!TEMP_LIST!" >nul

title Media Optimizer v5.4 STABLE - ГОТОВО
echo ------------------------------------------------------------------------------
echo.
echo %C_GREEN%ГОТОВО! Обработано файлов: !CURRENT_IDX!%C_RESET%
echo Папка результата: "!TARGET_DIR!\"
if "!IS_DRAG_FILES!"=="0" start "" "!TARGET_DIR!"
pause
exit

:: =================================================================================================
::      ВСПОМОГАТЕЛЬНЫЕ БЛОКИ
:: =================================================================================================
:NO_FILES
echo %C_RED%Файлы не найдены.%C_RESET%
pause
goto MAIN_MENU

:INSTALL_FFMPEG
echo %C_RED%FFmpeg не найден.%C_RESET% Установка через winget...
winget install Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
echo Перезапустите скрипт.
pause
exit

:INSTALL_MAGICK
echo %C_RED%ImageMagick не найден.%C_RESET% Установка через winget...
winget install ImageMagick.ImageMagick --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
echo Перезапустите скрипт.
pause
exit

:: =================================================================================================
::      ФУНКЦИЯ ОБРАБОТКИ ФАЙЛА (ДИСПЕТЧЕР)
:: =================================================================================================
:PROCESS_DISPATCHER
set "FULL_SRC=%~1"
for %%I in ("!FULL_SRC!") do (
    set "F_NAME=%%~nI"
    set "F_EXT=%%~xI"
    set "F_DIR=%%~dpI"
)

if "!SAME_FOLDER_MODE!"=="0" (
    echo "!F_NAME!" | findstr /i /c:"!SUFFIX_RESIZED!" >nul
    if !errorlevel! equ 0 (
        echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_GRAY%[ПРОПУСК]%C_RESET% "!FULL_SRC!"
        goto :EOF
    )
)

:: === ОПРЕДЕЛЕНИЕ ТИПА ФАЙЛА ===
set "IS_PHOTO=0"
set "IS_VIDEO=0"

if /i "!F_EXT!"==".jpg"  set "IS_PHOTO=1"
if /i "!F_EXT!"==".jpeg" set "IS_PHOTO=1"
if /i "!F_EXT!"==".png"  set "IS_PHOTO=1"
if /i "!F_EXT!"==".gif"  set "IS_PHOTO=1"
if /i "!F_EXT!"==".tiff" set "IS_PHOTO=1"
if /i "!F_EXT!"==".webp" set "IS_PHOTO=1"
if /i "!F_EXT!"==".heic" set "IS_PHOTO=1"
if /i "!F_EXT!"==".heif" set "IS_PHOTO=1"
if /i "!F_EXT!"==".avif" set "IS_PHOTO=1"
if /i "!F_EXT!"==".svg"  set "IS_PHOTO=1"
if /i "!F_EXT!"==".flif" set "IS_PHOTO=1"
if /i "!F_EXT!"==".bpg"  set "IS_PHOTO=1"

if /i "!F_EXT!"==".mp4"  set "IS_VIDEO=1"
if /i "!F_EXT!"==".mkv"  set "IS_VIDEO=1"
if /i "!F_EXT!"==".wmv"  set "IS_VIDEO=1"
if /i "!F_EXT!"==".webm" set "IS_VIDEO=1"
if /i "!F_EXT!"==".m4v"  set "IS_VIDEO=1"
if /i "!F_EXT!"==".ts"   set "IS_VIDEO=1"
if /i "!F_EXT!"==".mts"  set "IS_VIDEO=1"

:: === РАСЧЁТ СТОИМОСТИ ДЛЯ ТАЙМЕРА ===
set "FILE_COST=0"
if "!IS_PHOTO!"=="1" (
    if "!PROCESS_PHOTOS!"=="1" (
        set "IS_MAGICK=0"
        if /i "!F_EXT!"==".heic" set "IS_MAGICK=1"
        if /i "!F_EXT!"==".heif" set "IS_MAGICK=1"
        if /i "!F_EXT!"==".avif" set "IS_MAGICK=1"
        if /i "!F_EXT!"==".svg"  set "IS_MAGICK=1"
        if /i "!F_EXT!"==".flif" set "IS_MAGICK=1"
        if /i "!F_EXT!"==".bpg"  set "IS_MAGICK=1"
        if "!IS_MAGICK!"=="1" (set "FILE_COST=3") else (set "FILE_COST=1")
    )
    if "!PROCESS_PHOTOS!"=="0" set "FILE_COST=1"
)
if "!IS_VIDEO!"=="1" (
    if "!PROCESS_VIDEOS!"=="1" set "FILE_COST=300"
    if "!PROCESS_VIDEOS!"=="0" set "FILE_COST=1"
)
if "!IS_PHOTO!"=="0" if "!IS_VIDEO!"=="0" if "!COPY_OTHERS!"=="1" set "FILE_COST=1"
set /a "CURRENT_EST_PASSED+=FILE_COST"

:: === ФОРМИРОВАНИЕ ЦЕЛЕВОГО ПУТИ ===
set "REL_PATH=!FULL_SRC:%IN_DIR%=!"
if "!REL_PATH:~0,1!"=="\" set "REL_PATH=!REL_PATH:~1!"
set "FULL_TARGET_PATH=!TARGET_DIR!\!REL_PATH!"
for %%Z in ("!FULL_TARGET_PATH!") do set "FINAL_DIR=%%~dpZ"

if not exist "!FINAL_DIR!" mkdir "!FINAL_DIR!" 2>nul

:: === МАРШРУТИЗАЦИЯ ПО НАСТРОЙКАМ ===
if "!IS_PHOTO!"=="1" (
    if "!PROCESS_PHOTOS!"=="-1" (
        echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_GRAY%[ПРОПУСК]%C_RESET% "!FULL_SRC!"
        goto :EOF
    ) else if "!PROCESS_PHOTOS!"=="0" (
        goto W_COPY_PHOTO
    ) else goto W_PHOTO_PROCESS
)

if "!IS_VIDEO!"=="1" (
    if "!PROCESS_VIDEOS!"=="-1" (
        echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_GRAY%[ПРОПУСК]%C_RESET% "!FULL_SRC!"
        goto :EOF
    ) else if "!PROCESS_VIDEOS!"=="0" (
        goto W_COPY_VIDEO
    ) else goto W_VIDEO_PROCESS
)

if "!COPY_OTHERS!"=="1" goto W_COPY_OTHER
echo %C_WHITE%[!CURRENT_IDX!/!TOTAL_TASKS!]%C_RESET% %C_GRAY%[ПРОПУСК]%C_RESET% "!FULL_SRC!"
goto :EOF
