:: PLEASE NOTE: This script has been automatically generated by conda-smithy. Any changes here
:: will be lost next time ``conda smithy rerender`` is run. If you would like to make permanent
:: changes to this script, consider a proposal to conda-smithy so that other feedstocks can also
:: benefit from the improvement.

:: INPUTS (required environment variables)
:: CONDA_BLD_PATH: path for the conda-build workspace
:: CI: azure, or unset
:: MINIFORGE_HOME: where to install the base conda environment

setlocal enableextensions enabledelayedexpansion

call :start_group "Provisioning build tools"
if "%MINIFORGE_HOME%"=="" set "MINIFORGE_HOME=%USERPROFILE%\Miniforge3"
:: Remove trailing backslash, if present
if "%MINIFORGE_HOME:~-1%"=="\" set "MINIFORGE_HOME=%MINIFORGE_HOME:~0,-1%"

if exist "%MINIFORGE_HOME%\conda-meta\history" (
    echo Build tools already installed at %MINIFORGE_HOME%.
) else (
    where micromamba.exe >nul 2>nul
    if !errorlevel! == 0 (
        set "MICROMAMBA_EXE=micromamba.exe"
        echo "Found micromamba in PATH"
    ) else (
        set "MAMBA_ROOT_PREFIX=!MINIFORGE_HOME!-micromamba-!RANDOM!"
        set "MICROMAMBA_VERSION=1.5.10-0"
        set "MICROMAMBA_URL=https://github.com/mamba-org/micromamba-releases/releases/download/!MICROMAMBA_VERSION!/micromamba-win-64"
        set "MICROMAMBA_TMPDIR=!TMP!\micromamba-!RANDOM!"
        set "MICROMAMBA_EXE=!MICROMAMBA_TMPDIR!\micromamba.exe"

        echo Downloading micromamba !MICROMAMBA_VERSION!
        echo if not exist "!MICROMAMBA_TMPDIR!" mkdir "!MICROMAMBA_TMPDIR!"
        echo certutil -urlcache -split -f "!MICROMAMBA_URL!" "!MICROMAMBA_EXE!"
        if not exist "!MICROMAMBA_TMPDIR!" mkdir "!MICROMAMBA_TMPDIR!"
        certutil -urlcache -split -f "!MICROMAMBA_URL!" "!MICROMAMBA_EXE!"
        if !errorlevel! neq 0 exit /b !errorlevel!
    )
    echo Creating environment
    call "!MICROMAMBA_EXE!" create --yes --root-prefix "!MAMBA_ROOT_PREFIX!" --prefix "!MINIFORGE_HOME!" ^
        --channel conda-forge ^
        --file environment.yaml
    if !errorlevel! neq 0 exit /b !errorlevel!
    echo Moving pkgs cache from !MAMBA_ROOT_PREFIX! to !MINIFORGE_HOME!
    move /Y "!MAMBA_ROOT_PREFIX!\pkgs" "!MINIFORGE_HOME!" >nul
    if !errorlevel! neq 0 exit /b !errorlevel!
    echo Removing !MAMBA_ROOT_PREFIX!
    del /S /Q "!MAMBA_ROOT_PREFIX!" >nul
    del /S /Q "!MICROMAMBA_TMPDIR!" >nul
)
call :end_group

call :start_group "Configuring conda"

if "%CONDA_BLD_PATH%" == "" (
    set "CONDA_BLD_PATH=C:\bld"
)

:: Activate the base conda environment
echo Activating "%MINIFORGE_HOME%"
call "%MINIFORGE_HOME%\Scripts\activate"

:: Set basic configuration
echo Setting up configuration
conda.exe config --env --set always_yes yes
if !errorlevel! neq 0 exit /b !errorlevel!
conda.exe config --env --set channel_priority strict
if !errorlevel! neq 0 exit /b !errorlevel!
conda.exe config --env --set solver libmamba
if !errorlevel! neq 0 exit /b !errorlevel!

setup_conda_rc .\ ".\recipes" .\.ci_support\%CONFIG%.yaml
if !errorlevel! neq 0 exit /b !errorlevel!

echo Run conda_forge_build_setup
call run_conda_forge_build_setup
if !errorlevel! neq 0 exit /b !errorlevel!

if not "%CI%" == "" (
    echo Force fetch origin/main
    git fetch --force origin main:main
    if !errorlevel! neq 0 exit /b !errorlevel!
)
echo Removing recipes also present in main
cd recipes
for /f "tokens=*" %%a in ('git ls-tree --name-only main -- .') do rmdir /s /q %%a && echo Removing recipe: %%a
cd ..

:: make sure there is a package directory so that artifact publishing works
if not exist "%CONDA_BLD_PATH%\win-64\" mkdir "%CONDA_BLD_PATH%\win-64\"
if not exist "%CONDA_BLD_PATH%\win-arm64\" mkdir "%CONDA_BLD_PATH%\win-arm64\"
if not exist "%CONDA_BLD_PATH%\noarch\" mkdir "%CONDA_BLD_PATH%\noarch\"
:: Make sure CONDA_BLD_PATH is a valid channel; only do it if noarch/repodata.json doesn't exist
:: to save some time running locally
if not exist "%CONDA_BLD_PATH%\noarch\repodata.json" conda index "%CONDA_BLD_PATH%"

echo Index %CONDA_BLD_PATH%
conda.exe index "%CONDA_BLD_PATH%"
if !errorlevel! neq 0 exit /b !errorlevel!

call :end_group

echo Building all recipes
python .ci_support\build_all.py
if !errorlevel! neq 0 exit /b !errorlevel!

call :start_group "Inspecting artifacts"

:: inspect_artifacts was only added in conda-forge-ci-setup 4.6.0; --all-packages in 4.9.3
WHERE inspect_artifacts >nul 2>nul && inspect_artifacts --all-packages || echo "inspect_artifacts needs conda-forge-ci-setup >=4.9.3"

call :end_group

exit

:: Logging subroutines

:start_group
if /i "%CI%" == "github_actions" (
    echo ::group::%~1
    exit /b
)
if /i "%CI%" == "azure" (
    echo ##[group]%~1
    exit /b
)
echo %~1
exit /b

:end_group
if /i "%CI%" == "github_actions" (
    echo ::endgroup::
    exit /b
)
if /i "%CI%" == "azure" (
    echo ##[endgroup]
    exit /b
)
exit /b
