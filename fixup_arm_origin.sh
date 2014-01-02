#!/bin/bash
#
# This script effectively does a quick/dirty clean up for issues
# found in the ARM deploy that don't effect x86_64

reinstall_cartridges() {
  printf "Reinstalling OpenShift Origin cartridge local repositories... "
  /usr/sbin/oo-admin-cartridge --recursive -a install -s /usr/libexec/openshift/cartridges/
  printf "\n"
  printf "Reloading mcollective... "
  /usr/bin/systemctl reload mcollective.service
  printf "DONE\n"
}

fix_lib64() {
  # Fix for lib64 on 32-bit system.
  #
  # FIXME: Need to figure out what creates this dir during deploy but breaks
  #        things so we fix them here.
  # 
  # the cartridges will handle 32-bit vs 64-bit dynamically based on /usr/lib and
  # /usr/lib64 so we need to make sure that /usr/lib64 doesn't exist on 32-bit ARM
  #
  printf "Making sure /usr/lib64 doesn't exist on 32-bit platform...\n"
  if [[ "$(getconf LONG_BIT)" -eq "32" ]]; then
    if [[ -d /usr/lib64 ]]; then
      printf "/usr/lib64 found, removing... "
      /usr/bin/rm -fr /usr/lib64
      printf "DONE\n"
      reinstall_cartridges
    fi
  else
    printf "Not a 32-bit platform, skipping.\n"
  fi
}

fix_pgdata() {
  # FIXME: This fixes the pgdata issue but it's a really ugly hack at present time.
  #
  # There is a way to prepare this template at build time but there's other work
  # needed to get that functional so this will have to do for now.
  printf "Fixing pgdata for postgresql cartridge...\n"

  pgdata_tmpdir=$(su postgres -c "mktemp -d /tmp/pgdata.XXXXX")
  su postgres -c "initdb -D $pgdata_tmpdir"

  pushd $pgdata_tmpdir > /dev/null 2>&1
    tar -czf /tmp/pgdata-template.tar.gz .
  popd > /dev/null 2>&1

  mv /tmp/pgdata-template.tar.gz \
    /usr/libexec/openshift/cartridges/postgresql/versions/9.2/conf/pgdata-template.tar.gz

  chown root:root /usr/libexec/openshift/cartridges/postgresql/versions/9.2/conf/pgdata-template.tar.gz

  restorecon /usr/libexec/openshift/cartridges/postgresql/versions/9.2/conf/pgdata-template.tar.gz
  
  reinstall_cartridges

  printf "DONE\n"
}


# Call fix functions (they are just functions for organization, nothing more)
fix_lib64
fix_pgdata
