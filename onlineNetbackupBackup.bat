@echo off
REM
REM --------------------------------------------------------------------
REM onllineNetbackupBackup.bat
REM
REM $Id: onlineNetbackupBackup.bat,v 1.16 2018/09/06 07:18:37 db2admin Exp db2admin $
REM
REM Description:
REM Online Netbackup Backup script for Windows (policy / schedule set in db2.conf)
REM
REM Usage:
REM   onllineNetbackupBackup.bat
REM
REM $Name:  $
REM
REM ChangeLog:
REM $Log: onlineNetbackupBackup.bat,v $
REM Revision 1.16  2018/09/06 07:18:37  db2admin
REM change the status delimiter
REM
REM Revision 1.14  2018/08/21 05:19:20  db2admin
REM add script name to the record
REM
REM Revision 1.13  2018/08/20 07:14:56  db2admin
REM modify script to use "setlocal enabledelayedexpansion"
REM
REM Revision 1.11  2018/08/20 04:20:47  db2admin
REM allow the script to convert times to 24hr format
REM
REM Revision 1.10  2018/08/20 00:03:06  db2admin
REM add in code to send back status information to 192.168.1.1 during the execution of the backup
REM
REM Revision 1.9  2010/10/28 04:36:06  db2admin
REM script to take a backup of a Db2 database uusing netbackup
REM
REM Revision 1.8  2010/03/01 00:24:38  db2admin
REM send email if failure
REM
REM Revision 1.7  2009/08/19 02:30:34  db2admin
REM Change target machine name to 192.168.1.1
REM
REM Revision 1.6  2009/03/17 01:12:25  db2admin
REM correct error in script that prevented backup
REM
REM Revision 1.4  2009/02/13 05:23:00  db2admin
REM Add in copy of backup details to 192.168.1.1 (not currently workin)
REM
REM Revision 1.3  2008/12/21 22:21:15  m08802
REM Add in the include logs parameter
REM
REM Revision 1.2  2008/12/09 22:34:17  db2admin
REM Correct problem with LOAD name
REM
REM Revision 1.1  2008/09/25 22:36:42  db2admin
REM Initial revision
REM
REM --------------------------------------------------------------------

REM ##############################################################################
REM #  This script back ups the database (ONLINE)                                #
REM #  It creates an execution log in logs/backup_%DB%.log                       #
REM ##############################################################################
if (%3) == () ( 
  set LOAD="C:\Progra~1\VERITAS\NetBackup\bin\nbdb2.dll"
) else (
  set LOAD=%3
)

FOR /f "tokens=2-5 delims=/ " %%i in ('date /t') do (
  set DATE_TS=%%k_%%j_%%i
)

FOR /f "tokens=1-2 delims=/: " %%i in ('time /t') do (
  set TIME_RF=%%i_%%j
)

set TS=%DATE_TS%_%TIME_RF%

FOR /f "tokens=1-2 delims=/: " %%i in ('hostname') do (
  set machine=%%i
)
set DB2INSTANCE=%1
set DB=%2
set DO_UNQSCE_FLAG=0
set BACKUPCMD=
set STATUS=Started
set MSG=
set STATUSFILE=%TEMP%\backup_status_%machine%_%DB2INSTANCE%_%DB%
set STATUSFILENAME=backup_status_%machine%_%DB2INSTANCE%_%DB%
set SEND_EMAIL=0
set SEND_FILE=0
set OUTPUT_FILE="C:\Documents and Settings\db2admin\logs\onlineBackup_%DB%.log"
set OUTPUT_LOG="C:\Docume~1\db2admin\logs\%machine%_%DB2INSTANCE%_%DB%.log"

echo "Subject: Online Backup for %DB%" >%OUTPUT_FILE%
echo "Copying Status to 192.168.1.1" >>%OUTPUT_FILE%
echo "STATUSFILE: %STATUSFILE%" >>%OUTPUT_FILE%
FOR /f "tokens=2-5 delims=/ " %%i in ('date /t') do ( set DATE_TS=%%k-%%j-%%i)
setlocal ENABLEDELAYEDEXPANSION 
FOR /f "tokens=1-3 delims=/: " %%i in ('time /t') do ( 
  set TIME_TS=%%i:%%j:00
  if "%%k" == "PM" (
    set /a "Hour=%%i+12"
    set TIME_TS=!Hour!:%%j:00
    echo .... %%i .... %%j .... %%k.... Hour: !Hour! >>%OUTPUT_FILE%
  )
)
set STARTED=%DATE_TS% %TIME_TS%
echo Started: %STARTED% .... %TIME_TS% >>%OUTPUT_FILE%
echo DB2#%STARTED%#%STARTED%#%machine%#%DB2INSTANCE%#%DB%#ONLINE#%STATUS%#%~nx0#%BACKUPCMD%# >%STATUSFILE%_1
if exist "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_1" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%
if exist "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_1" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%
if exist "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_1" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%

echo "Transferring to realtimeBackupStatus\%STATUSFILENAME% from %STATUSFILE%_1" >>%OUTPUT_FILE%

echo  "**** Start: Online Backup of %DB% ****" >>%OUTPUT_FILE%
REM ##############################################################################
REM # Connect to Database                                                        #
REM ##############################################################################
@date /T  >>%OUTPUT_FILE%
@time /T  >>%OUTPUT_FILE%
echo "*--- Connect to DB ---*" >>%OUTPUT_FILE%
db2 connect to %DB% >>%OUTPUT_FILE%
set RC0=%errorlevel%
if %RC0% == 0 goto rc0_00 
  echo " DB2 Connect failed with RC = %RC0% " >>%OUTPUT_FILE%
  set SEND_EMAIL=1
  set STATUS=Failed at connect
  set MSG=%RC0%
  goto cleanup
:rc0_00
  echo " DB2 Connect successful " >>%OUTPUT_FILE%
  REM ############################################################################
  REM # Reset the Connection                                                     #
  REM ############################################################################
  @time /T  >>%OUTPUT_FILE%
  echo "*--- Reset the connection ----*" >>%OUTPUT_FILE%
  db2 connect reset
  set RC2=%errorlevel%
  if %RC2% == 0 goto rc2_00
    echo " DB2 Connect reset failed with RC = %RC2% " >>%OUTPUT_FILE%
    set SEND_EMAIL=1
    set STATUS=Failed at reset
    set MSG=%RC2%
    goto cleanup
:rc2_00
    echo " DB2 Connect reset successful " >>%OUTPUT_FILE%
    REM ############################################################################
    REM # Perform backup.                                                          #
    REM ############################################################################
    set BACKUPCMD=db2 backup database %DB% ONLINE LOAD %LOAD% include logs
    echo "Copying Status to 192.168.1.1" >>%OUTPUT_FILE%
    FOR /f "tokens=2-5 delims=/ " %%i in ('date /t') do ( set DATE_TS=%%k-%%j-%%i)
    REM need to strip out the hour before the for loop to initialise it (alternatively could have used "setlocal ENABLEDELAYEDEXPANSION"
    FOR /f "tokens=1-3 delims=/: " %%i in ('time /t') do ( 
      set TIME_TS=%%i:%%j:00
      if "%%k" == "PM" (
        set /a "Hour=%%i+12"
        set TIME_TS=!Hour!:%%j:00
        echo .... %%i .... %%j .... %%k.... Hour: !Hour! >>%OUTPUT_FILE%
      )
    )
    set CTIME=%DATE_TS% %TIME_TS%
    echo "Copying Status to 192.168.1.1" >>%OUTPUT_FILE%
    echo DB2#%STARTED%#%CTIME%#%machine%#%DB2INSTANCE%#%DB%#ONLINE#%STATUS%#%~nx0#%BACKUPCMD%#%MSG% >%STATUSFILE%_2
    if exist "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_2" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%
    if exist "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_2" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%
    if exist "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_2" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%

    @time /T  >>%OUTPUT_FILE%
    echo  "*-- Backup the database --*" >>%OUTPUT_FILE%
    echo "%TS% %machine% %DB2INSTANCE% %DB%" >%OUTPUT_LOG%
    db2 backup database %DB% ONLINE LOAD %LOAD% include logs >>%OUTPUT_LOG%
    set RC3=%errorlevel%
    if %RC3% == 0 goto rc3_00
      set SEND_EMAIL=1
      echo " DB2 Backup failed with RC = %RC3% " >>%OUTPUT_FILE%
      set STATUS=Failed
      set MSG=%RC3%
      goto cleanup
:rc3_00
      echo " Backup of %DB% successful " >>%OUTPUT_FILE%
      set STATUS=Successful
      set SEND_FILE=1
      echo 

:cleanup

:emailchk
if NOT %SEND_EMAIL% == 0 (
  
  REM Send an email
  if "%DB%" EQU "" (
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of UNKNOWN failed" mpl_it_dba_udb@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  ) ELSE (
    REM echo cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of %DB% failed" mpl_it_dba_udb@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of %DB% failed" mpl_it_dba_udb@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB%. To rerun this backup log on to server %machine%, open up task scheduler, open up the DBA sub folder and then run the entry that has a description of Backup_%database%" %OUTPUT_FILE%  %OUTPUT_LOG%
  )
)

if NOT %SEND_FILE% == 0 (
  echo "Copying Backup details file to 192.168.1.1" >>%OUTPUT_FILE%
  if exist "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" "%OUTPUT_LOG%" db2admin@192.168.1.1:LatestBackups
  if exist "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" "%OUTPUT_LOG%" db2admin@192.168.1.1:LatestBackups
  if exist "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" "%OUTPUT_LOG%" db2admin@192.168.1.1:LatestBackups
)

echo "Copying Finish Status to 192.168.1.1" >>%OUTPUT_FILE%
FOR /f "tokens=2-5 delims=/ " %%i in ('date /t') do ( set DATE_TS=%%k-%%j-%%i)
REM need to strip out the hour before the for loop to initialise it (alternatively could have used "setlocal ENABLEDELAYEDEXPANSION"
FOR /f "tokens=1-3 delims=/: " %%i in ('time /t') do ( 
  set TIME_TS=%%i:%%j:00
  if "%%k" == "PM" (
    set /a "Hour=%%i+12"
    set TIME_TS=!Hour!:%%j:00
    echo .... %%i .... %%j .... %%k.... Hour: !Hour! >>%OUTPUT_FILE%
  )
)
set CTIME=%DATE_TS% %TIME_TS%
echo DB2#%STARTED%#%CTIME%#%machine%#%DB2INSTANCE%#%DB%#ONLINE#%STATUS%#%~nx0#%BACKUPCMD%#%MSG% >%STATUSFILE%_3
if exist "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_3" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%
if exist "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_3" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%
if exist "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" "%STATUSFILE%_3" db2admin@192.168.1.1:realtimeBackupStatus/%STATUSFILENAME%

