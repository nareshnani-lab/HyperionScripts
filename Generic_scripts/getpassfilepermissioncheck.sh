filename=/hyp_util/scripts/getpass/.data/getpassdat
filepermissions=`stat -c %a $filename`
maildetails=corp.hyperion.dba@sherwin.com
echo "$filepermissions"
if [ $filepermissions = '644' ] ; then

echo " File Permissions for $filename is correct.. "

else

echo " File Permissions for $filename is wrong.Correcting now.. "

chmod 644 $filename

statusfile=$?

if [ $statusfile -eq 0 ] ; then
echo " File permissions are corrected.. "
filepermissionsstatus1=`stat -c %a $filename`

echo " Corrected Permissions for $filename.Now Permissions for the file is $filepermissionsstatus1 " | mailx -s "Corrected Permissions for file $filename.." $maildetails


else
echo " Unable to correct Permissions for $filename.Please login into server and correct manually.. "
filepermissionsstatus2=`stat -c %a $filename`

echo "Unable to correct Permissions for file $filename.Please login into server correct manually.. Current Permission of the file $filename is $filepermissionsstatus2.. " | mailx -s "Unable to correct Permissions for file $filename.Please login into server correct manually.." $maildetails


fi

fi
