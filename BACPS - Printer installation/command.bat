#!/bin/bash

#Set mount point location
mntLocation=/tmp/NL-Canon-Drivers

#create the folder used to mount the dmg
mkdir $mntLocation

#mount the dmg
hdiutil attach -readonly "UFRII_v10.19.9_Mac.dmg" -mountpoint $mntLocation

#install the pkg contained in the dmg
installer -pkg $mntLocation/UFRII_LT_LIPS_LX_Installer.pkg -target /

#dismount the dmg
hdiutil detach $mntLocation

#remove the temp mount location
rmdir $mntLocation

#add the printers
lpadmin -p First_Floor -L "First Floor" -E -v lpd://192.168.100.47  -P /Library/Printers/PPDs/Contents/Resources/CNPZUIRA8585ZU.ppd.gz -o printer-is-shared=false
lpadmin -p Second_Floor -L "Second Floor" -E -v lpd://192.168.100.9  -P /Library/Printers/PPDs/Contents/Resources/CNPZUIRA6555ZU.ppd.gz -o printer-is-shared=false
