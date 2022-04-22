ECHO OFF
REM RESTORING CAN BE FROM REMOTE SERVER TO LOCAL SERVER ONLY

REM COMPANY NAME OR PREFIX
set COMPANY=DATABASE

REM SET PATH TO SAVE THE FILES e.g. D:\backup, COULD BE SHARED FOLDER FOR REMOTE BACKUP
set BACKUPPATH=C:\SHAREDFOLDER
REM LOCAL TEMP DIRECTORY TO COPY BAK FILES TO REPLICATION 
set DEFAULTLOCALPATH=C:\

REM SET NAME OF THE SERVER AND INSTANCE FROM
set SERVERNAMEFROM=localhost
REM SET NAME OF THE SERVER AND INSTANCE TO
set SERVERNAMETO=localhost

REM SET LIST OF DATABASES
set list=DB1 DB2 DB3 DB4 DB5
REM SET NUMBER OF BACKUPS ALLOWED
set maxback=3

REM FROM AUTH DATA
set FROMUSER=sa
set FROMKEY=pwd

REM TO AUTH DATA
set TOUSER=sa
set TOKEY=pwd

REM ------------------CREATING AND DELETING FOLDERS--------------------

REM CREATE BACKUP GENERAL FOLDER
IF not exist %BACKUPPATH% (mkdir %BACKUPPATH%)

REM CLEAR OLDER BACKUP
set /a maxback -= 1
set /a count = 0
set /a delcount = 1
setlocal enableextensions enabledelayedexpansion
(for /f %%D in ('dir %BACKUPPATH% /a:d /b /-N /o-n') do ( 
	Echo.%%D | findstr /C:"BACKUP">nul && (
		if !count! geq %maxback% ( 
			echo DELETING %BACKUPPATH%\%%D FOLDER...
			set "DELETEDFOLDERS[!delcount!]=%%D.zip"	
			set /a delcount += 1				
			rd /s /q %BACKUPPATH%\%%D
		) 				
		set /a count += 1
	)		
))
set /a delcount -= 1

REM GET TIMESTAMP FOR FOLDER NAME
For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%b%%a)
For /f "tokens=1-2 delims=/:" %%a in ("%TIME%") do (set mytime=%%a%%b)
set DATESTAMP=%mydate%%mytime: =0%

REM DELETE TEMP_BACKUP FOLDER IF EXIST
IF EXIST %F% rd /s /q %BACKUPPATH%\%COMPANY%_BACKUP_%DATESTAMP%
REM CREATE TEMP FOLDER
MKDIR %BACKUPPATH%\%COMPANY%_BACKUP_%DATESTAMP%

REM GOTO End
REM ------------------CREATING NEW BACKUP--------------------

(for %%a in (%list%) do ( 
	echo CREATING BACKUP OF %%a DATABASE...
	SQLCMD -S %SERVERNAMEFROM% -U %FROMUSER% -P %FROMKEY% -Q "BACKUP DATABASE %%a TO DISK = N'%BACKUPPATH%\%COMPANY%_BACKUP_%DATESTAMP%\%%a.bak' WITH INIT, NOUNLOAD, NOSKIP, NAME = N'Backup Automatico de %%a ', STATS = 10" -o %BACKUPPATH%\%COMPANY%_BACKUP_%DATESTAMP%\log.txt
))


REM GOTO End
REM ------------------UPLOAD TO DRIVE----------------------------------
REM ------------------3D PARTY SOFTWARE gdrive.exe IS NEEDED IN THE SAME FOLDER OF BACKUP.BAT FILE, PREVIOUS CONFIGURATION OF GDRIVE.EXE IS NEEDED TO CONNECT TO GOOGLE DRIVE

REM MOVING TO BACKUP FILE FOLDER TO USE gdrive.exe
cd %~dp0

echo CREATING TEMP FOLDER...
REM CREATE BACKUP GENERAL FOLDER
IF not exist %DEFAULTLOCALPATH% (mkdir %DEFAULTLOCALPATH%)

MKDIR %DEFAULTLOCALPATH%%COMPANY%_BACKUP_%DATESTAMP%
ECHO COPYING BACKUP FILES TO LOCAL FOLDER %DEFAULTLOCALPATH%%COMPANY%_BACKUP_%DATESTAMP%...
REM BRING BAK FILES TO LOCAL
XCOPY /s /i %BACKUPPATH%\%COMPANY%_BACKUP_%DATESTAMP% %DEFAULTLOCALPATH%%COMPANY%_BACKUP_%DATESTAMP% /E

REM REMOVING DATA FROM GOOGLE DRIVE
(for /L %%i in (1,1,%delcount%) do (
	set var=""
	echo REMOVING !DELETEDFOLDERS[%%i]! ELEMENT FROM GOOGLE DRIVE...
	for /F "tokens=1-4" %%a IN ('gdrive.exe list --no-header -q "name contains '!DELETEDFOLDERS[%%i]!' "') do set var=%%a	
	if !!var!!=="" (echo FOLDER !!DELETEDFOLDERS[%%i]!! NOT DETECTED IN GOOGLE DRIVE) else ( START /MIN gdrive.exe delete !!var!!)		
))

echo ZIPING BACKUP FOLDER...
powershell Compress-Archive -LiteralPath '%DEFAULTLOCALPATH%%COMPANY%_BACKUP_%DATESTAMP%' -DestinationPath "%DEFAULTLOCALPATH%%COMPANY%_BACKUP_%DATESTAMP%.zip"

echo UPLOADING %DEFAULTLOCALPATH%%COMPANY%_BACKUP_%DATESTAMP%.zip TO GOOGLE DRIVE...
START /MIN /w gdrive.exe upload %DEFAULTLOCALPATH%%COMPANY%_BACKUP_%DATESTAMP%.zip

REM GOTO End
REM REMOVE LOCAL BACKUP IN CASE STORED IN DRIVE
REM rd /s /q %BACKUPPATH%


GOTO End
REM ------------------RESTORING LATEST BACKUP--------------------

REM RESTORE FROM LOCAL BAK FILES
(for %%a in (%list%) do ( 
	echo RESTORING %%a DATABASE...
	SQLCMD -S %SERVERNAMETO% -U %TOUSER% -P %TOKEY% -Q "USE master ALTER DATABASE %%a SET single_user WITH ROLLBACK IMMEDIATE RESTORE DATABASE %%a FROM DISK='%BACKUPPATH%\%COMPANY%_BACKUP_%DATESTAMP%\%%a.bak'" -o %BACKUPPATH%\%COMPANY%_BACKUP_%DATESTAMP%\log.txt
))

:End
REM REMOVE TEMPORAL FOLDER
rd /s /q %DEFAULTLOCALPATH%

EXIT /B n

