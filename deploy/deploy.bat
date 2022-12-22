@echo off

::set HTTP_PROXY=http://direct1.proxy.i2:8080

call setenv.bat

set which_platform=%1

if "%which_platform%" == "" (
set mode=manuel
goto choix_plateforme
) else (
set mode=planifie
goto deploiement
)

:choix_plateforme
echo Plateforme de production : prod
echo Plateforme beta : beta

echo.
echo Vers quelle plateforme souhaitez-vous deployer l'application ?
set /p which_platform=
::set /p which_platform=Vers quelle plateforme souhaitez-vous deployer ?

echo ----------------
echo Vous allez deployer vers : %which_platform%
pause

:deploiement
echo Deploiement de l'application %which_platform%
%R_PATH%\Rscript.exe deploy.R %which_platform%

if "%mode%" == "manuel" (pause)
