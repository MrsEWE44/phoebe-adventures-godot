@echo off
setlocal EnableExtensions
cd /d "%~dp0"

rem Allow the script to run when Windows reports a different checkout owner.
set "GIT_CONFIG_COUNT=1"
set "GIT_CONFIG_KEY_0=safe.directory"
set "GIT_CONFIG_VALUE_0=%CD%"

set "COMMIT_MESSAGE=%~1"
if "%COMMIT_MESSAGE%"=="" set "COMMIT_MESSAGE=Update project"

where git >nul 2>&1
if errorlevel 1 (
  echo Git was not found in PATH.
  exit /b 1
)

git rev-parse --show-toplevel >nul 2>&1
if errorlevel 1 (
  echo This folder is not a Git repository.
  echo Run: git init -b main
  echo Then add your GitHub remote:
  echo git remote add origin https://github.com/MrsEWE44/phoebe-adventures-godot.git
  exit /b 1
)

git lfs version >nul 2>&1
if errorlevel 1 (
  echo Git LFS is required for the large video and audio assets.
  echo Install Git LFS, run "git lfs install", then run this script again.
  exit /b 1
)
git lfs install --local

for /f "delims=" %%B in ('git branch --show-current') do set "BRANCH=%%B"
if "%BRANCH%"=="" (
  git switch -c main
  set "BRANCH=main"
)

git add -A
git diff --cached --quiet
if not errorlevel 1 (
  echo No file changes to commit. Continuing with remote synchronization.
) else (
  git commit -m "%COMMIT_MESSAGE%"
  if errorlevel 1 exit /b 1
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
  echo No remote named origin is configured.
  echo Add it once with:
  echo git remote add origin https://github.com/MrsEWE44/phoebe-adventures-godot.git
  echo Local commit is complete; nothing was pushed.
  exit /b 0
)

git fetch origin
if errorlevel 1 exit /b 1
git show-ref --verify --quiet "refs/remotes/origin/%BRANCH%"
if not errorlevel 1 (
  git merge-base HEAD "origin/%BRANCH%" >nul 2>&1
  if errorlevel 1 (
    echo Remote has an unrelated initial commit; merging it once.
    git merge --allow-unrelated-histories --no-edit "origin/%BRANCH%"
  ) else (
    git pull --rebase origin "%BRANCH%"
  )
  if errorlevel 1 (
    echo Remote synchronization stopped. Resolve the conflict, then run this script again.
    exit /b 1
  )
)

git push --set-upstream origin "%BRANCH%"
if errorlevel 1 exit /b 1
echo GitHub push completed on branch %BRANCH%.
endlocal
