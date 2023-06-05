#!/bin/bash

if [ $usrConfirm = "true" ]
then
  /System/Library/Frameworks/ApplicationServices.framework/Frameworks/PrintCore.framework/Versions/A/printtool --reset -f
else
  echo "Set variable to True to remove all printers"
fi