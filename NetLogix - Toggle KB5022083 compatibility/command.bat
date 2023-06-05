if ($ENV:Install -eq "True") {
  .\kb5022083-compat.ps1 -install
} else {
  .\kb5022083-compat.ps1 -uninstall
}
