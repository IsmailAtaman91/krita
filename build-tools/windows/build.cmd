@echo off

setlocal enabledelayedexpansion
goto begin


:: Subroutines

:find_on_path out_variable file_name
set %1=%~f$PATH:2
goto :EOF


:get_dir_path out_variable file_path
set %1=%~dp2
goto :EOF


:get_full_path out_variable file_path
setlocal
set FULL_PATH=%~f2
if not exist "%FULL_PATH%" (
    set FULL_PATH=
) else (
    if exist "%FULL_PATH%\" (
        set FULL_PATH=
    )
)
endlocal & set "%1=%FULL_PATH%"
goto :EOF


:get_full_path_dir out_variable file_path
setlocal
set FULL_PATH=%~dp2
if not exist "%FULL_PATH%" (
    set FULL_PATH=
)
endlocal & set "%1=%FULL_PATH%"
goto :EOF


:prompt_for_string out_variable prompt
set /p %1=%~2^>
goto :EOF


:prompt_for_positive_integer out_variable prompt
setlocal
call :prompt_for_string USER_INPUT "%~2"
if "%USER_INPUT%" == "" set USER_INPUT=0
set /a RESULT=%USER_INPUT%
if not %RESULT% GTR 0 (
    set RESULT=
)
endlocal & set "%1=%RESULT%"
goto :EOF


:prompt_for_file out_variable prompt
setlocal
:prompt_for_file__retry
call :prompt_for_string USER_INPUT "%~2"
if "%USER_INPUT%" == "" (
    endlocal
    set %1=
    goto :EOF
)
call :get_full_path RESULT "%USER_INPUT%"
if "%RESULT%" == "" (
    echo Input does not point to valid file!
    set USER_INPUT=
    goto prompt_for_file__retry
)
endlocal & set "%1=%RESULT%"
goto :EOF


:prompt_for_dir out_variable prompt
setlocal
:prompt_for_dir__retry
call :prompt_for_string USER_INPUT "%~2"
if "%USER_INPUT%" == "" (
    endlocal
    set %1=
    goto :EOF
)
call :get_full_path_dir RESULT "%USER_INPUT%\"
if "%RESULT%" == "" (
    echo Input does not point to valid dir!
    set USER_INPUT=
    goto prompt_for_dir__retry
)
endlocal & set "%1=%RESULT%"
goto :EOF


:has_target out_variable folder
setlocal
set RESULT=
if exist "%~2" (
    set RESULT=1
)
endlocal & set "%1=%RESULT%"
goto :EOF

:usage
echo Usage:
echo %~n0 [--no-interactive] [ OPTIONS ... ]
echo.
echo Basic options:
echo --no-interactive                Run without interactive prompts
echo                                 When not specified, the script will prompt
echo                                 for some of the parameters.
echo --jobs ^<count^>                  Set parallel jobs count when building
echo                                 Defaults to no. of logical cores
echo --skip-deps                     Skips (re)building of deps
echo --skip-krita                    Skips (re)building of Krita
echo --cmd                           Launch a cmd prompt instead of building.
echo                                 The environment is set up like the build
echo                                 environment with some helper command macros.
echo --dev                           Activate developer options, like 'CodeBlocks'
echo                                 generator and BUILD_TESTING
echo.
echo Path options:
echo --src-dir ^<dir_path^>            Specify Krita source dir
echo                                 If unspecified, this will be determined from
echo                                 the script location.
echo --download-dir ^<dir_path^>       Specify deps download dir
echo                                 Can be omitted if --skip-deps is used
echo --deps-build-dir ^<dir_path^>     Specify deps build dir
echo                                 Can be omitted if --skip-deps is used
echo --deps-install-dir ^<dir_path^>   Specify deps install dir
echo --krita-build-dir ^<dir_path^>    Specify Krita build dir
echo                                 Can be omitted if --skip-krita is used
echo --krita-install-dir ^<dir_path^>  Specify Krita install dir
echo                                 Can be omitted if --skip-krita is used
echo.
goto :EOF
:usage_and_exit
call :usage
exit /b
:usage_and_fail
call :usage
exit /b 100


:: ----------------------------
:begin

echo Krita build script for Windows
echo.


:: command-line args parsing
set ARG_NO_INTERACTIVE=
set ARG_JOBS=
set ARG_SKIP_DEPS=
set ARG_SKIP_KRITA=
set ARG_SRC_DIR=
set ARG_DOWNLOAD_DIR=
set ARG_DEPS_BUILD_DIR=
set ARG_DEPS_INSTALL_DIR=
set ARG_KRITA_BUILD_DIR=
set ARG_KRITA_INSTALL_DIR=
set ARG_PLUGINS_BUILD_DIR=
set ARG_CMD=
set ARG_DEV=
:args_parsing_loop
set CURRENT_MATCHED=
if not "%1" == "" (
    if "%1" == "--no-interactive" (
        set ARG_NO_INTERACTIVE=1
        set CURRENT_MATCHED=1
    )
    if "%1" == "--jobs" (
        if not "%ARG_JOBS%" == "" (
            echo ERROR: Arg --jobs specified more than once 1>&2
            echo.
            goto usage_and_fail
        )
        set /a "ARG_JOBS=%2"
        if not !ARG_JOBS! GTR 0 (
            echo ERROR: Arg --jobs is not a positive integer 1>&2
            echo.
            goto usage_and_fail
        )
        shift /2
        set CURRENT_MATCHED=1
    )
    if "%1" == "--skip-deps" (
        set ARG_SKIP_DEPS=1
        set CURRENT_MATCHED=1
    )
    if "%1" == "--skip-krita" (
        set ARG_SKIP_KRITA=1
        set CURRENT_MATCHED=1
    )
    if "%1" == "--dev" (
        set ARG_DEV=1
        set CURRENT_MATCHED=1
    )
    if "%1" == "--src-dir" (
        if not "%ARG_SRC_DIR%" == "" (
            echo ERROR: Arg --src-dir specified more than once 1>&2
            echo.
            goto usage_and_fail
        )
        if not exist "%~f2\" (
            echo ERROR: Arg --src-dir does not point to a directory 1>&2
            echo.
            goto usage_and_fail
        )
        call :get_dir_path ARG_SRC_DIR "%~f2\"
        shift /2
        set CURRENT_MATCHED=1
    )
    if "%1" == "--download-dir" (
        if not "%ARG_DOWNLOAD_DIR%" == "" (
            echo ERROR: Arg --download-dir specified more than once 1>&2
            echo.
            goto usage_and_fail
        )
        if "%~f2" == "" (
            echo ERROR: Arg --download-dir does not point to a valid path 1>&2
            echo.
            goto usage_and_fail
        )
        call :get_dir_path ARG_DOWNLOAD_DIR "%~f2\"
        shift /2
        set CURRENT_MATCHED=1
    )
    if "%1" == "--deps-build-dir" (
        if not "%ARG_DEPS_BUILD_DIR%" == "" (
            echo ERROR: Arg --deps-build-dir specified more than once 1>&2
            echo.
            goto usage_and_fail
        )
        if "%~f2" == "" (
            echo ERROR: Arg --deps-build-dir does not point to a valid path 1>&2
            echo.
            goto usage_and_fail
        )
        call :get_dir_path ARG_DEPS_BUILD_DIR "%~f2\"
        shift /2
        set CURRENT_MATCHED=1
    )
    if "%1" == "--deps-install-dir" (
        if not "%ARG_DEPS_INSTALL_DIR%" == "" (
            echo ERROR: Arg --deps-install-dir specified more than once 1>&2
            echo.
            goto usage_and_fail
        )
        if "%~f2" == "" (
            echo ERROR: Arg --deps-install-dir does not point to a valid path 1>&2
            echo.
            goto usage_and_fail
        )
        call :get_dir_path ARG_DEPS_INSTALL_DIR "%~f2\"
        shift /2
        set CURRENT_MATCHED=1
    )
    if "%1" == "--krita-build-dir" (
        if not "%ARG_KRITA_BUILD_DIR%" == "" (
            echo ERROR: Arg --krita-build-dir specified more than once 1>&2
            echo.
            goto usage_and_fail
        )
        if "%~f2" == "" (
            echo ERROR: Arg --krita-build-dir does not point to a valid path 1>&2
            echo.
            goto usage_and_fail
        )
        call :get_dir_path ARG_KRITA_BUILD_DIR "%~f2\"
        shift /2
        set CURRENT_MATCHED=1
    )
    if "%1" == "--krita-install-dir" (
        if not "%ARG_KRITA_INSTALL_DIR%" == "" (
            echo ERROR: Arg --krita-install-dir specified more than once 1>&2
            echo.
            goto usage_and_fail
        )
        if "%~f2" == "" (
            echo ERROR: Arg --krita-install-dir does not point to a valid path 1>&2
            echo.
            goto usage_and_fail
        )
        call :get_dir_path ARG_KRITA_INSTALL_DIR "%~f2\"
        shift /2
        set CURRENT_MATCHED=1
    )
    if "%1" == "--plugins-build-dir" (
        if not "%ARG_PLUGINS_BUILD_DIR%" == "" (
            echo ERROR: Arg --plugins-build-dir specified more than once 1>&2
            echo.
            goto usage_and_fail
        )
        if "%~f2" == "" (
            echo ERROR: Arg --plugins-build-dir does not point to a valid path 1>&2
            echo.
            goto usage_and_fail
        )
        call :get_dir_path ARG_PLUGINS_BUILD_DIR "%~f2\"
        shift /2
        set CURRENT_MATCHED=1
    )
    if "%1" == "--cmd" (
        set ARG_CMD=1
        set CURRENT_MATCHED=1
    )
    if "%1" == "--help" (
        goto usage_and_exit
    )
    if not "!CURRENT_MATCHED!" == "1" (
        echo ERROR: Unknown option %1 1>&2
        echo.
        goto usage_and_fail
    )
    shift /1
    goto args_parsing_loop
)

if "%ARG_NO_INTERACTIVE%" == "1" (
    echo Non-interactive mode
) else (
    echo Interactive mode
    :: Trick to pause on exit
    call :real_begin
    pause
    exit /b !ERRORLEVEL!
)
:real_begin
echo.


if "%ARG_SKIP_DEPS%" == "1" (
    if "%ARG_SKIP_KRITA%" == "1" (
        echo Both deps and Krita will be skipped.
    ) else (
        echo Building of deps will be skipped.
    )
) else (
    if "%ARG_SKIP_KRITA%" == "1" (
        echo Building of Krita will be skipped.
    ) else (
        echo Both deps and Krita will be built.
    )
)


:: Check environment config

if "%CMAKE_EXE%" == "" (
    call :find_on_path CMAKE_EXE cmake.exe
    if "!CMAKE_EXE!" == "" (
        if not "%ARG_NO_INTERACTIVE%" == "1" (
            call :prompt_for_file CMAKE_EXE "Provide path to cmake.exe"
        )
        if "!CMAKE_EXE!" == "" (
            echo ERROR: CMake not found! 1>&2
            exit /b 102
        )
        call :get_dir_path CMAKE_BIN_DIR "!CMAKE_EXE!"
    ) else (
        echo Found CMake on PATH: !CMAKE_EXE!
        if not "%ARG_NO_INTERACTIVE%" == "1" (
            choice /c ny /n /m "Is this correct? [y/n] "
            if errorlevel 3 exit 255
            if not errorlevel 2 (
                call :prompt_for_file CMAKE_EXE "Provide path to cmake.exe"
                if "!CMAKE_EXE!" == "" (
                    echo ERROR: CMake not found! 1>&2
                    exit /b 102
                )
                call :get_dir_path CMAKE_BIN_DIR "!CMAKE_EXE!"
            )
        )
        call :get_dir_path CMAKE_BIN_DIR "!CMAKE_EXE!"
    )
)
echo CMake: %CMAKE_BIN_DIR%

if "%SEVENZIP_EXE%" == "" (
    call :find_on_path SEVENZIP_EXE 7z.exe
    if "!SEVENZIP_EXE!" == "" (
        set "SEVENZIP_EXE=%ProgramFiles%\7-Zip\7z.exe"
        if "!SEVENZIP_EXE!" == "" (
            set "SEVENZIP_EXE=%ProgramFiles(x86)%\7-Zip\7z.exe"
        )
        if "!SEVENZIP_EXE!" == "" (
            echo 7-Zip not found
        )
    )
)
if "%SEVENZIP_EXE%" == "" (
    echo 7-Zip: %SEVENZIP_EXE%
)

if "%MINGW_BIN_DIR%" == "" (
    call :find_on_path MINGW_BIN_DIR_MAKE_EXE mingw32-make.exe
    if "!MINGW_BIN_DIR_MAKE_EXE!" == "" (
        if not "%ARG_NO_INTERACTIVE%" == "1" (
            call :prompt_for_file MINGW_BIN_DIR_MAKE_EXE "Provide path to mingw32-make.exe of mingw-w64"
        )
        if "!MINGW_BIN_DIR_MAKE_EXE!" == "" (
            echo ERROR: mingw-w64 not found! 1>&2
            exit /b 102
        )
        call :get_dir_path MINGW_BIN_DIR "!MINGW_BIN_DIR_MAKE_EXE!"
    ) else (
        call :get_dir_path MINGW_BIN_DIR "!MINGW_BIN_DIR_MAKE_EXE!"
        echo Found mingw on PATH: !MINGW_BIN_DIR!
        if not "%ARG_NO_INTERACTIVE%" == "1" (
            choice /c ny /n /m "Is this correct? [y/n] "
            if errorlevel 3 exit 255
            if not errorlevel 2 (
                call :prompt_for_file MINGW_BIN_DIR_MAKE_EXE "Provide path to mingw32-make.exe of mingw-w64"
                if "!MINGW_BIN_DIR_MAKE_EXE!" == "" (
                    echo ERROR: mingw-w64 not found! 1>&2
                    exit /b 102
                )
                call :get_dir_path MINGW_BIN_DIR "!MINGW_BIN_DIR_MAKE_EXE!"
            )
        )
    )
)
echo mingw-w64: %MINGW_BIN_DIR%

if "%PYTHON_BIN_DIR%" == "" (
    call :find_on_path PYTHON_BIN_DIR_PYTHON_EXE python.exe
    if "!PYTHON_BIN_DIR_PYTHON_EXE!" == "" (
        if not "%ARG_NO_INTERACTIVE%" == "1" (
            call :prompt_for_file PYTHON_BIN_DIR_PYTHON_EXE "Provide path to python.exe of Python 3.6.2"
        )
        if "!PYTHON_BIN_DIR_PYTHON_EXE!" == "" (
            echo ERROR: Python not found! 1>&2
            exit /b 102
        )
        call :get_dir_path PYTHON_BIN_DIR "!PYTHON_BIN_DIR_PYTHON_EXE!"
    ) else (
        call :get_dir_path PYTHON_BIN_DIR "!PYTHON_BIN_DIR_PYTHON_EXE!"
        echo Found Python on PATH: !PYTHON_BIN_DIR!
        if not "%ARG_NO_INTERACTIVE%" == "1" (
            choice /c ny /n /m "Is this correct? [y/n] "
            if errorlevel 3 exit 255
            if not errorlevel 2 (
                call :prompt_for_file PYTHON_BIN_DIR_PYTHON_EXE "Provide path to python.exe of Python 3.6.2"
                if "!PYTHON_BIN_DIR_PYTHON_EXE!" == "" (
                    echo ERROR: Python not found! 1>&2
                    exit /b 102
                )
                call :get_dir_path PYTHON_BIN_DIR "!PYTHON_BIN_DIR_PYTHON_EXE!"
            )
        )
    )
)
echo Python: %PYTHON_BIN_DIR%

@REM Translation tools

if "%KRITA_GIT_DIR%" == "" (
    call :find_on_path KRITA_GIT_EXE_DIR git.exe
    if NOT "!KRITA_GIT_EXE_DIR!" == "" (
        call :get_dir_path KRITA_GIT_DIR "!KRITA_GIT_EXE_DIR!"
        echo Found Git on PATH: !KRITA_GIT_DIR!
    )
) else echo Git found on %KRITA_GIT_DIR%

if "%KRITA_NINJA_DIR%" == "" (
    call :find_on_path KRITA_NINJA_EXE_DIR ninja.exe
    if NOT "!KRITA_NINJA_EXE_DIR!" == "" (
        call :get_dir_path KRITA_NINJA_DIR "!KRITA_NINJA_EXE_DIR!"
        echo Found Ninja on PATH: !KRITA_NINJA_DIR!
    )
) else echo Ninja found on %KRITA_NINJA_DIR%

if "%SVN_DIR%" == "" (
    call :find_on_path SVN_EXE_DIR svn.exe
    if NOT "!SVN_EXE_DIR!" == "" (
        call :get_dir_path SVN_DIR "!SVN_EXE_DIR!"
        echo Found SVN on PATH: !SVN_DIR!
    )
) else echo SVN found on %SVN_DIR%

if "%PERL_DIR%" == "" (
    call :find_on_path PERL_EXE_DIR perl.exe
    if NOT "!PERL_EXE_DIR!" == "" (
        call :get_dir_path PERL_DIR "!PERL_EXE_DIR!"
        echo Found Perl on PATH: !PERL_DIR!
    )
) else echo Perl found on %PERL_DIR%

if "%ARG_SKIP_DEPS%" == "1" goto skip_windows_sdk_dir_check

if "%WindowsSdkDir%" == "" if not "%ProgramFiles(x86)%" == "" set "WindowsSdkDir=%ProgramFiles(x86)%\Windows Kits\10"
if "%WindowsSdkDir%" == "" set "WindowsSdkDir=%ProgramFiles(x86)%\Windows Kits\10"
if exist "%WindowsSdkDir%\" (
    pushd "%WindowsSdkDir%"
    if exist "bin\x64\fxc.exe" (
        set HAVE_FXC_EXE=1
        if "%WindowsSdkVerBinPath%" == "" set "WindowsSdkVerBinPath=%WindowsSdkDir%"
    ) else (
        for /f "delims=" %%a in ('dir /a:d /b "bin\10.*"') do (
            if exist "bin\%%a\x64\fxc.exe" (
                set HAVE_FXC_EXE=1
                if "%WindowsSdkVerBinPath%" == "" set "WindowsSdkVerBinPath=%WindowsSdkDir%\bin\%%a\"
            )
        )
    )
    popd
)
set QT_ENABLE_DYNAMIC_OPENGL=ON
if not "%HAVE_FXC_EXE%" == "1" (
    set WindowsSdkDir=
    echo Windows SDK 10 with fxc.exe not found
    echo Qt will *not* be built with ANGLE ^(dynamic OpenGL^) support.
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this ok? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            exit /b 102
        )
    )
    set QT_ENABLE_DYNAMIC_OPENGL=OFF
) else echo Windows SDK 10 with fxc.exe found on %WindowsSdkDir%

:skip_windows_sdk_dir_check

if not "%ARG_JOBS%" == "" (
    set "PARALLEL_JOBS=%ARG_JOBS%"
)
if "%PARALLEL_JOBS%" == "" (
    echo Number of logical CPU cores detected: %NUMBER_OF_PROCESSORS%
    echo Enabling %NUMBER_OF_PROCESSORS% parallel jobs
    set PARALLEL_JOBS=%NUMBER_OF_PROCESSORS%
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this correct? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            call :prompt_for_positive_integer PARALLEL_JOBS "Provide no. of parallel jobs"
            if "!PARALLEL_JOBS!" == "" (
                echo ERROR: Invalid job count! 1>&2
                exit /b 102
            )
        )
    )
)
echo Parallel jobs count: %PARALLEL_JOBS%

if not "%ARG_SRC_DIR%" == "" (
    set "KRITA_SRC_DIR=%ARG_SRC_DIR%"
)
if "%KRITA_SRC_DIR%" == "" (
    :: Check whether this looks like to be in the source tree
	set "_temp=%~dp0"
	if "!_temp:~-21!" == "\build-tools\windows\" (
        if exist "!_temp:~0,-21!\CMakeLists.txt" (
            if exist "!_temp:~0,-21!\3rdparty\CMakeLists.txt" (
                set "KRITA_SRC_DIR=!_temp:~0,-21!\"
                echo Script is running inside Krita src dir
            )
        )
    )
)
if "%KRITA_SRC_DIR%" == "" (
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        call :prompt_for_dir KRITA_SRC_DIR "Provide path of Krita src dir"
    )
    if "!KRITA_SRC_DIR!" == "" (
        echo ERROR: Krita src dir not found! 1>&2
        exit /b 102
    )
)
echo Krita src: %KRITA_SRC_DIR%

if "%ARG_SKIP_DEPS%" == "1" goto skip_deps_args_check

if not "%ARG_DOWNLOAD_DIR%" == "" (
    set "DEPS_DOWNLOAD_DIR=%ARG_DOWNLOAD_DIR%"
)
if "%DEPS_DOWNLOAD_DIR%" == "" (
    set DEPS_DOWNLOAD_DIR=%CD%\d\
    echo Using default deps download dir: !DEPS_DOWNLOAD_DIR!
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this ok? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            call :prompt_for_dir DEPS_DOWNLOAD_DIR "Provide path of depps download dir"
        )
    )
    if "!DEPS_DOWNLOAD_DIR!" == "" (
        echo ERROR: Deps download dir not set! 1>&2
        exit /b 102
    )
)
echo Deps download dir: %DEPS_DOWNLOAD_DIR%

if not "%ARG_DEPS_BUILD_DIR%" == "" (
    set "DEPS_BUILD_DIR=%ARG_DEPS_BUILD_DIR%"
)
if "%DEPS_BUILD_DIR%" == "" (
    set DEPS_BUILD_DIR=%CD%\b_deps\
    echo Using default deps build dir: !DEPS_BUILD_DIR!
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this ok? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            call :prompt_for_dir DEPS_BUILD_DIR "Provide path of deps build dir"
        )
    )
    if "!DEPS_BUILD_DIR!" == "" (
        echo ERROR: Deps build dir not set! 1>&2
        exit /b 102
    )
)
echo Deps build dir: %DEPS_BUILD_DIR%

:skip_deps_args_check

if not "%ARG_DEPS_INSTALL_DIR%" == "" (
    set "DEPS_INSTALL_DIR=%ARG_DEPS_INSTALL_DIR%"
)
if "%DEPS_INSTALL_DIR%" == "" (
    set DEPS_INSTALL_DIR=%CD%\i_deps\
    echo Using default deps install dir: !DEPS_INSTALL_DIR!
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this ok? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            call :prompt_for_dir DEPS_INSTALL_DIR "Provide path of deps install dir"
        )
    )
    if "!DEPS_INSTALL_DIR!" == "" (
        echo ERROR: Deps install dir not set! 1>&2
        exit /b 102
    )
)
echo Deps install dir: %DEPS_INSTALL_DIR%

if "%ARG_SKIP_KRITA%" == "1" goto skip_krita_args_check

if not "%ARG_KRITA_BUILD_DIR%" == "" (
    set "KRITA_BUILD_DIR=%ARG_KRITA_BUILD_DIR%"
)
if "%KRITA_BUILD_DIR%" == "" (
    set KRITA_BUILD_DIR=%CD%\b\
    echo Using default Krita build dir: !KRITA_BUILD_DIR!
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this ok? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            call :prompt_for_dir KRITA_BUILD_DIR "Provide path of Krita build dir"
        )
    )
    if "!KRITA_BUILD_DIR!" == "" (
        echo ERROR: Krita build dir not set! 1>&2
        exit /b 102
    )
)
echo Krita build dir: %KRITA_BUILD_DIR%

@REM Plugins also need the download dir
if not "%ARG_DOWNLOAD_DIR%" == "" (
    set "PLUGINS_DOWNLOAD_DIR=%ARG_DOWNLOAD_DIR%"
)
if "%PLUGINS_DOWNLOAD_DIR%" == "" (
    set PLUGINS_DOWNLOAD_DIR=%CD%\d\
    echo Using default deps download dir: !PLUGINS_DOWNLOAD_DIR!
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this ok? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            call :prompt_for_dir PLUGINS_DOWNLOAD_DIR "Provide path of plugins download dir"
        )
    )
    if "!PLUGINS_DOWNLOAD_DIR!" == "" (
        echo ERROR: Plugins download dir not set! 1>&2
        exit /b 102
    )
)
echo Plugins download dir: %PLUGINS_DOWNLOAD_DIR%

if not "%ARG_PLUGINS_BUILD_DIR%" == "" (
    set "PLUGINS_BUILD_DIR=%ARG_PLUGINS_BUILD_DIR%"
)
if "%PLUGINS_BUILD_DIR%" == "" (
    set PLUGINS_BUILD_DIR=%CD%\b_plugins\
    echo Using default plugins build dir: !PLUGINS_BUILD_DIR!
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this ok? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            call :prompt_for_dir PLUGINS_BUILD_DIR "Provide path of plugins build dir"
        )
    )
    if "!PLUGINS_BUILD_DIR!" == "" (
        echo ERROR: Plugins build dir not set! 1>&2
        exit /b 102
    )
)
echo Plugins build dir: %PLUGINS_BUILD_DIR%

if not "%ARG_KRITA_INSTALL_DIR%" == "" (
    set "KRITA_INSTALL_DIR=%ARG_KRITA_INSTALL_DIR%"
)
if "%KRITA_INSTALL_DIR%" == "" (
    set KRITA_INSTALL_DIR=%CD%\i\
    echo Using default Krita install dir: !KRITA_INSTALL_DIR!
    if not "%ARG_NO_INTERACTIVE%" == "1" (
        choice /c ny /n /m "Is this ok? [y/n] "
        if errorlevel 3 exit 255
        if not errorlevel 2 (
            call :prompt_for_dir KRITA_INSTALL_DIR "Provide path of Krita install dir"
        )
    )
    if "!KRITA_INSTALL_DIR!" == "" (
        echo ERROR: Krita install dir not set! 1>&2
        exit /b 102
    )
)
echo Krita install dir: %KRITA_INSTALL_DIR%

:skip_krita_args_check

echo.


if not "%ARG_NO_INTERACTIVE%" == "1" (
    choice /c ny /n /m "Is the above ok? [y/n] "
    if errorlevel 3 exit 255
    if not errorlevel 2 (
        exit /b 1
    )
    echo.
)

:: Initialize clean PATH
set "PATH=%SystemRoot%\system32;%SystemRoot%;%SystemRoot%\System32\Wbem;%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\"
set "PATH=%PYTHON_BIN_DIR%;%MINGW_BIN_DIR%;%PATH%"
if NOT "%KRITA_GIT_DIR%" == "" (
    set "PATH=%PATH%;%KRITA_GIT_DIR%"
)
if NOT "%KRITA_NINJA_DIR%" == "" (
    if NOT "%KRITA_NINJA_DIR%" == "%MINGW_BIN_DIR%" (
        set "PATH=%PATH%;%KRITA_NINJA_DIR%"
    )
)
if NOT "%SVN_DIR%" == "" (
    set "PATH=%PATH%;%SVN_DIR%"
)
if NOT "%CMAKE_BIN_DIR%" == "" (
    set PATH=%PATH%;%CMAKE_BIN_DIR%
)

echo Creating dirs...
if NOT "%ARG_SKIP_DEPS%" == "1" (
    mkdir %DEPS_DOWNLOAD_DIR%
    if errorlevel 1 (
        if not exist "%DEPS_DOWNLOAD_DIR%\" (
            echo ERROR: Cannot create deps download dir! 1>&2
            exit /b 103
        )
    )
    mkdir %DEPS_BUILD_DIR%
    if errorlevel 1 (
        if not exist "%DEPS_BUILD_DIR%\" (
            echo ERROR: Cannot create deps build dir! 1>&2
            exit /b 103
        )
    )
    mkdir %DEPS_INSTALL_DIR%
    if errorlevel 1 (
        if not exist "%DEPS_INSTALL_DIR%\" (
            echo ERROR: Cannot create deps install dir! 1>&2
            exit /b 103
        )
    )
)
if NOT "%ARG_SKIP_KRITA%" == "1" (
    mkdir %KRITA_BUILD_DIR%
    if errorlevel 1 (
        if not exist "%KRITA_BUILD_DIR%\" (
            echo ERROR: Cannot create Krita build dir! 1>&2
            exit /b 103
        )
    )
    mkdir %PLUGINS_DOWNLOAD_DIR%
    if errorlevel 1 (
        if not exist "%PLUGINS_DOWNLOAD_DIR%\" (
            echo ERROR: Cannot create plugins download dir! 1>&2
            exit /b 103
        )
    )
    mkdir %PLUGINS_BUILD_DIR%
    if errorlevel 1 (
        if not exist "%PLUGINS_BUILD_DIR%\" (
            echo ERROR: Cannot create plugins build dir! 1>&2
            exit /b 103
        )
    )
    mkdir %KRITA_INSTALL_DIR%
    if errorlevel 1 (
        if not exist "%KRITA_INSTALL_DIR%\" (
            echo ERROR: Cannot create Krita install dir! 1>&2
            exit /b 103
        )
    )
)

echo.


set CMAKE_BUILD_TYPE=RelWithDebInfo
set QT_ENABLE_DEBUG_INFO=OFF

set KRITA_GENERATOR=MinGW Makefiles
set KRITA_BUILD_TESTING=OFF
set KRITA_INSTALL_BENCHMARKS=OFF

if NOT "%KRITA_NINJA_DIR%" == "" (
    set KRITA_GENERATOR=Ninja
)

if "%ARG_DEV%" == "1" (
    set KRITA_GENERATOR=CodeBlocks - %KRITA_GENERATOR%
    set KRITA_BUILD_TESTING=ON
    set KRITA_INSTALL_BENCHMARKS=ON
)

if "%KRITA_BRANDING%" == "" (
    rem Check Jenkins job name
    if "%JOB_NAME%" == "Krita_Nightly_Windows_Build" (
        set KRITA_BRANDING=Next
    ) else (
        if "%JOB_NAME%" == "Krita_Stable_Windows_Build" (
            set KRITA_BRANDING=Plus
        )
    )
)

:: Paths for CMake
set "BUILDDIR_DOWNLOAD_CMAKE=%DEPS_DOWNLOAD_DIR:\=/%"
set "BUILDDIR_DOWNLOAD_CMAKE=%BUILDDIR_DOWNLOAD_CMAKE: =\ %"
set "BUILDDIR_PLUGINS_DOWNLOAD_CMAKE=%PLUGINS_DOWNLOAD_DIR:\=/%"
set "BUILDDIR_PLUGINS_DOWNLOAD_CMAKE=%BUILDDIR_PLUGINS_DOWNLOAD_CMAKE: =\ %"
set "BUILDDIR_DEPS_INSTALL_CMAKE=%DEPS_INSTALL_DIR:\=/%"
set "BUILDDIR_DEPS_INSTALL_CMAKE=%BUILDDIR_DEPS_INSTALL_CMAKE: =\ %"
set "BUILDDIR_KRITA_INSTALL_CMAKE=%KRITA_INSTALL_DIR:\=/%"
set "BUILDDIR_KRITA_INSTALL_CMAKE=%BUILDDIR_KRITA_INSTALL_CMAKE: =\ %"
set "BUILDDIR_PLUGINS_INSTALL_CMAKE=%KRITA_INSTALL_DIR:\=/%"
set "BUILDDIR_PLUGINS_INSTALL_CMAKE=%BUILDDIR_KRITA_INSTALL_CMAKE: =\ %"

if not "%PERL_DIR%" == "" (
    :: Safety measure for Strawberry Perl injecting pkg-config in the PATH
    if exist "%PERL_DIR%\pkg-config.bat" (
        echo Found unpatched Strawberry Perl, ignoring due to its pkg-config introducing external binaries.
        set "PATH=%PATH%;%DEPS_INSTALL_DIR%\Strawberry\perl\bin"
    ) else (
        echo Found patched Strawberry Perl, it is safe to use.
        set "PERL_EXECUTABLE=%PERL_DIR%\perl.exe"
        set "PERL_EXECUTABLE=!PERL_EXECUTABLE:\=/!"
        set "PERL_EXECUTABLE=!PERL_EXECUTABLE: =\ !"
        set "PATH=%PATH%;%PERL_DIR%"
    )
) else (
    set "PATH=%PATH%;%DEPS_INSTALL_DIR%\Strawberry\perl\bin"
)

set "PATH=%DEPS_INSTALL_DIR%\bin;%PATH%"

if not "%GETTEXT_SEARCH_PATH%" == "" (
    set "PATH=%PATH%;%GETTEXT_SEARCH_PATH%"
)

:: Prepare the CMake command lines
set CMDLINE_CMAKE_DEPS="%CMAKE_EXE%" "%KRITA_SRC_DIR%\3rdparty" ^
    -DSUBMAKE_JOBS=%PARALLEL_JOBS% ^
    -DQT_ENABLE_DEBUG_INFO=%QT_ENABLE_DEBUG_INFO% ^
    -DQT_ENABLE_DYNAMIC_OPENGL=%QT_ENABLE_DYNAMIC_OPENGL% ^
    -DPERL_EXECUTABLE=%PERL_EXECUTABLE% ^
    -DEXTERNALS_DOWNLOAD_DIR=%BUILDDIR_DOWNLOAD_CMAKE% ^
    -DINSTALL_ROOT=%BUILDDIR_DEPS_INSTALL_CMAKE% ^
    -G "%KRITA_GENERATOR%" ^
    -DCMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE%
    
set CMDLINE_CMAKE_KRITA="%CMAKE_EXE%" "%KRITA_SRC_DIR%\." ^
    -DBoost_DEBUG=OFF ^
    -DBOOST_INCLUDEDIR=%BUILDDIR_DEPS_INSTALL_CMAKE%/include ^
    -DBOOST_ROOT=%BUILDDIR_DEPS_INSTALL_CMAKE% ^
    -DBOOST_LIBRARYDIR=%BUILDDIR_DEPS_INSTALL_CMAKE%/lib ^
    -DCMAKE_PREFIX_PATH=%BUILDDIR_DEPS_INSTALL_CMAKE% ^
    -DCMAKE_INSTALL_PREFIX=%BUILDDIR_KRITA_INSTALL_CMAKE% ^
    -DBUILD_TESTING=%KRITA_BUILD_TESTING% ^
    -DINSTALL_BENCHMARKS=%KRITA_INSTALL_BENCHMARKS% ^
    -DHAVE_MEMORY_LEAK_TRACKER=OFF ^
    -DFOUNDATION_BUILD=ON ^
    -DUSE_QT_TABLET_WINDOWS=ON ^
    -DKRITA_ENABLE_PCH=OFF ^
    -DHIDE_SAFE_ASSERTS=ON ^
    -DBRANDING=%KRITA_BRANDING% ^
    -Wno-dev ^
    -G "%KRITA_GENERATOR%" ^
    -DCMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE%

set CMDLINE_CMAKE_PLUGINS="%CMAKE_EXE%" "%KRITA_SRC_DIR%\3rdparty_plugins" ^
    -DSUBMAKE_JOBS=%PARALLEL_JOBS% ^
    -DQT_ENABLE_DEBUG_INFO=%QT_ENABLE_DEBUG_INFO% ^
    -DQT_ENABLE_DYNAMIC_OPENGL=%QT_ENABLE_DYNAMIC_OPENGL% ^
    -DEXTERNALS_DOWNLOAD_DIR=%BUILDDIR_PLUGINS_DOWNLOAD_CMAKE% ^
    -DINSTALL_ROOT=%BUILDDIR_PLUGINS_INSTALL_CMAKE% ^
    -G "%KRITA_GENERATOR%" ^
    -DCMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE%

:: Launch CMD prompt if requested
if "%ARG_CMD%" == "1" (
    doskey cmake-deps=cmd /c "pushd %DEPS_BUILD_DIR% && %CMDLINE_CMAKE_DEPS%"
    doskey cmake-krita=cmd /c "pushd %KRITA_BUILD_DIR% && %CMDLINE_CMAKE_KRITA%"
    doskey make-deps=cmd /c "pushd %DEPS_BUILD_DIR% && "%CMAKE_EXE%" --build . --config %CMAKE_BUILD_TYPE% --target $*"
    doskey make-krita=cmd /c "pushd %KRITA_BUILD_DIR% && "%CMAKE_EXE%" --build . --config %CMAKE_BUILD_TYPE% --target install -- -j%PARALLEL_JOBS%"
    doskey make-plugins=cmd /c "pushd %PLUGINS_BUILD_DIR% && "%CMAKE_EXE%" --build . --config %CMAKE_BUILD_TYPE% --target $* -- -j%PARALLEL_JOBS%"
    echo.
    title Krita build - %KRITA_SRC_DIR% ^(deps: %DEPS_BUILD_DIR%, krita: %KRITA_BUILD_DIR%, plugins: %PLUGINS_BUILD_DIR%^)
    echo You're now in the build environment.
    echo The following macros are available:
    echo   cmake-deps
    echo     -- Run CMake for the deps.
    echo   make-deps ^<deps target^>
    echo     -- Run build for the specified deps target. The target name should
    echo        include the `ext_` prefix, e.g. `ext_qt`.
    echo   make-plugins ^<deps target^>
    echo     -- Build the specified plugin target. The target name should
    echo        include the `ext_` prefix, e.g. `ext_gmic`.
    echo   cmake-krita
    echo     -- Run CMake for Krita.
    echo   make-krita
    echo     -- Run build for Krita's `install` target.
    echo.
    echo For more info, type `doskey /macros` to view the macro commands.
    cmd /k
    exit
)


if "%ARG_SKIP_DEPS%" == "1" goto skip_build_deps

pushd %DEPS_BUILD_DIR%
if errorlevel 1 (
    echo ERROR: Cannot enter deps build dir! 1>&2
    exit /b 104
)

echo Running CMake for deps...

@echo on
%CMDLINE_CMAKE_DEPS%
@if errorlevel 1 (
    @echo ERROR: CMake configure failed! 1>&2
    @exit /b 104
)
@echo off
echo.

set EXT_TARGETS=patch zlib gettext openssl boost exiv2 fftw3 eigen3 jpeg lcms2
set EXT_TARGETS=%EXT_TARGETS% ocio openexr png icoutils tiff gsl
set EXT_TARGETS=%EXT_TARGETS% giflib qt libraw kwindowsystem drmingw
set EXT_TARGETS=%EXT_TARGETS% python sip pyqt
set EXT_TARGETS=%EXT_TARGETS% lzma quazip openjpeg libde265 libx265 libheif
set EXT_TARGETS=%EXT_TARGETS% seexpr mypaint webp jpegxl xsimd
set EXT_TARGETS=%EXT_TARGETS% freetype fontconfig poppler fribidi raqm unibreak
set EXT_TARGETS=%EXT_TARGETS% ffmpeg lager mlt

for %%a in (%EXT_TARGETS%) do (
    set TEST_HAS_TARGET=
    call :has_target TEST_HAS_TARGET_SELF "ext_%%a\"
    call :has_target TEST_HAS_KF5_TARGET "ext_frameworks\ext_%%a-prefix\"
    call :has_target TEST_HAS_HEIF_TARGET "ext_heif\ext_%%a-prefix\"
    if "!TEST_HAS_TARGET_SELF!" == "1" set TEST_HAS_TARGET=1
    if "!TEST_HAS_KF5_TARGET!" == "1" set TEST_HAS_TARGET=1
    if "!TEST_HAS_HEIF_TARGET!" == "1" set TEST_HAS_TARGET=1

    if defined TEST_HAS_TARGET (
        echo Building ext_%%a...
        "%CMAKE_EXE%" --build . --config %CMAKE_BUILD_TYPE% -j%PARALLEL_JOBS% --target ext_%%a
        if errorlevel 1 (
            echo ERROR: Building of ext_%%a failed! 1>&2
            exit /b 105
        )
    ) else (
        echo Skipping ext_%%a, using OS package...
    )
)
echo.

echo ******** Built deps ********
popd

:skip_build_deps

if "%ARG_SKIP_KRITA%" == "1" goto skip_build_krita

pushd %KRITA_BUILD_DIR%
if errorlevel 1 (
    echo ERROR: Cannot enter Krita build dir! 1>&2
    exit /b 104
)

echo Running CMake for Krita...

@echo on
%CMDLINE_CMAKE_KRITA%
@if errorlevel 1 (
    @echo ERROR: CMake configure failed! 1>&2
    @exit /b 104
)
@echo off
echo.

echo Building Krita...
"%CMAKE_EXE%" --build . --config %CMAKE_BUILD_TYPE% --target install -- -j%PARALLEL_JOBS%
if errorlevel 1 (
    echo ERROR: Building of Krita failed! 1>&2
    exit /b 105
)
echo.

echo ******** Built Krita ********
popd

pushd %PLUGINS_BUILD_DIR%
if errorlevel 1 (
    echo ERROR: Cannot enter plugins build dir! 1>&2
    exit /b 104
)

echo Running CMake for plugins...

@echo on
%CMDLINE_CMAKE_PLUGINS%
@if errorlevel 1 (
    @echo ERROR: CMake configure failed! 1>&2
    @exit /b 104
)
@echo off
echo.

set EXT_TARGETS=gmic

for %%a in (%EXT_TARGETS%) do (
    echo Building ext_%%a...
    "%CMAKE_EXE%" --build . --config %CMAKE_BUILD_TYPE% --target ext_%%a
    if errorlevel 1 (
        echo ERROR: Building of ext_%%a failed! 1>&2
        exit /b 105
    )
)
echo.

echo ******** Built plugins ********
popd

:skip_build_krita

echo Krita build completed!
