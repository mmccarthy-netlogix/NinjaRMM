$SORC="\\192.168.7.8\WINRATER"
$DEST="C:\Program Files (x86)\Winrater"

ROBOCOPY $SORC $DEST /E /ZB /DCOPY:T /COPYALL /MIR /SEC /R:1 /W:1 /NP