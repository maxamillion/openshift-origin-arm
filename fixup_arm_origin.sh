#!/bin/bash
#
# Unfortunately as of httpd-2.4.6-2.fc19.armv7hl there is an issue with the 
# mod_auth_digest module so we need to not load it until this issue is resolved
#
#
# This script effectively does a quick/dirty clean up by just commenting it out
# from being loaded.

# Fix for httpd configs
printf "Fixing httpd configurations to disable mod_auth_digest (broken on ARM)... \n"
for i in $( \
  egrep -r '^LoadModule auth_digest_module modules\/mod_auth_digest.so' \
  /etc/httpd/ | awk -F: '{ print $1 }' );
do  
  sed -i 's/LoadModule auth_digest_module modules\/mod_auth_digest.so/#LoadModule auth_digest_module modules\/mod_auth_digest.so/g' $i;  
  printf "Cleaned up $i\n"
done

#Fix for rpm installed cartridges not in openshift cartridge repo
for i in $( \
  egrep -r '^LoadModule auth_digest_module modules\/mod_auth_digest.so' \
  /usr/libexec/openshift/cartridges/ | awk -F: '{ print $1 }' );
do  
  sed -i 's/LoadModule auth_digest_module modules\/mod_auth_digest.so/#LoadModule auth_digest_module modules\/mod_auth_digest.so/g' $i;  
  printf "Cleaned up $i\n"
done

# Fix for cartridges installed in the openshift cartridge repo
for i in $( \
  egrep -r '^LoadModule auth_digest_module modules\/mod_auth_digest.so' \
  /var/lib/openshift/.cartridge_repository/ | awk -F: '{ print $1 }' );
do  
  sed -i 's/LoadModule auth_digest_module modules\/mod_auth_digest.so/#LoadModule auth_digest_module modules\/mod_auth_digest.so/g' $i;  
  printf "Cleaned up $i\n"
done

# Fix for lib64 on 32-bit system.
#
# FIXME: Need to figure out what creates this dir during deploy but breaks
#        things so we fix them here.
# 
# the cartridges will handle 32-bit vs 64-bit dynamically based on /usr/lib and
# /usr/lib64 so we need to make sure that /usr/lib64 doesn't exist on 32-bit ARM
#
printf "Making sure /usr/lib64 doesn't exist on 32-bit platform...\n"
if [[ -d /usr/lib64 ]]; then
  printf "/usr/lib64 found, removing... "
  /usr/bin/rm -fr /usr/lib64
  printf "DONE\n"
  printf "Reinstalling OpenShift Origin cartridge local repositories... "
  /usr/sbin/oo-admin-cartridge --recursive -a install -s /usr/libexec/openshift/cartridges/
  printf "\n"
  printf "Restarting mcollective... "
  /usr/bin/systemctl reload mcollective.service
  printf "DONE\n"
fi

