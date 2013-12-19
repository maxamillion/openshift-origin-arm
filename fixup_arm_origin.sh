#!/bin/bash
#
# This script effectively does a quick/dirty clean up for issues
# found in the ARM deploy that don't effect x86_64

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
  printf "Reloading mcollective... "
  /usr/bin/systemctl reload mcollective.service
  printf "DONE\n"
fi

