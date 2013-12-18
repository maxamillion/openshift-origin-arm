#!/bin/bash
#
# Unfortunately as of httpd-2.4.6-2.fc19.armv7hl there is an issue with the 
# mod_auth_digest module so we need to not load it until this issue is resolved
#
#
# This script effectively does a quick/dirty clean up by just commenting it out
# from being loaded.

# Fix for httpd configs
for i in $( \
  grep -r 'LoadModule auth_digest_module modules/mod_auth_digest.so' \
  /etc/httpd/ | awk -F: '{ print $1 }' );
do  
  sed -i 's/LoadModule mod_auth_digest.so\/mod_auth_digest.so/#LoadModule mod_auth_digest.so\/mod_auth_digest.so/g' $i;  
  printf "Cleaned up $i\n"
done

#Fix for rpm installed cartridges not in openshift cartridge repo
for i in $( \
  grep -r 'LoadModule auth_digest_module modules/mod_auth_digest.so' \
  /usr/libexec/openshift/cartridges/ | awk -F: '{ print $1 }' );
do  
  sed -i 's/LoadModule auth_digest_module modules\/mod_auth_digest.so/#LoadModule auth_digest_module modules\/mod_auth_digest.so/g' $i;  
  printf "Cleaned up $i\n"
done

# Fix for cartridges installed in the openshift cartridge repo
for i in $( \
  grep -r 'LoadModule auth_digest_module modules/mod_auth_digest.so' \
  /var/lib/openshift/.cartridge_repository/ | awk -F: '{ print $1 }' );
do  
  sed -i 's/LoadModule auth_digest_module modules\/mod_auth_digest.so/#LoadModule auth_digest_module modules\/mod_auth_digest.so/g' $i;  
  printf "Cleaned up $i\n"
done
