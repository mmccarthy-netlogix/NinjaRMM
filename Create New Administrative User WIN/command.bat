@ECHO OFF
REM add user redux build 2/seagull

echo Create New Administrative User
echo ================================

REM Password length check
set #=%cs_password%
set /a varPassLength=0
:loop1
if defined # (set #=%#:~1%&set /A varPassLength += 1&goto loop1)

REM Username length check
set #=%cs_username%
set /a varUserLength=0
:loop2
if defined # (set #=%#:~1%&set /A varUserLength += 1&goto loop2)

if %varUserLength% gtr 20 (
	echo ERROR: Username must be no greater than 20 characters in length.
	echo Please re-run this Component with a shorter username.
	exit 1
)

if %varPassLength% gtr 14 (
	echo ERROR: Password must be no greater than 14 characters in length.
	echo Please re-run this Component with a shorter password.
	exit 1
)

NET USER /add %cs_username% %cs_password%
NET LOCALGROUP administrators %cs_username% /add
echo Account %cs_username% added successfully.

if %usrNeverExpire% equ true (
	WMIC USERACCOUNT WHERE "Name='%cs_username%'" SET PasswordExpires=FALSE
	echo Account %cs_username% set to not expire.
)