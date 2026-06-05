#!/system/bin/sh

SKIPUNZIP=0

ASH_STANDALONE=0

ui_print "Extracting certificates"

unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2

ui_print "Installation successful. After restarting your phone, check the system certificates to see if your certificate is active."

ui_print " "

set_perm_recursive $MODPATH 0 0 0755 0644