#!/bin/bash

#Set variables
drvName="TOSHIBA_ColorMFP.dmg.gz"
dmgName="TOSHIBA_ColorMFP.dmg"
pkgName="TOSHIBA ColorMFP.pkg"

#Set mount point location
mntLocation=/tmp/NL-Print-Drivers

#create the folder used to mount the dmg
mkdir $mntLocation

#unzip the file
gunzip $drvName

#mount the dmg
hdiutil attach -readonly $dmgName -mountpoint $mntLocation

#install the pkg contained in the dmg
installer -pkg "$mntLocation/$pkgName" -target /

#dismount the dmg
hdiutil detach $mntLocation

#remove the temp mount location
rmdir $mntLocation

#add the printers
lpadmin -p Corner_Toshiba_Printer -E -v ipp://10.1.10.50  -P /Library/Printers/PPDs/Contents/Resources/TOSHIBA_ColorMFP.gz -o printer-is-shared=false

#put the settings in place
cp Corner_Toshiba_Printer.ppd /private/etc/cups/ppd