#!/bin/bash
#
# arm_build_oss_fedora.sh
#
#   This script will build all opensource components using mock on a 
#   ARM device in order to create a "cleanly built" repository for arm. 
#   Attempting to mimic having an actual build system the best we can.
# 
# Author: Adam Miller <admiller@redhat.com>
#         Adam Miller <maxamillion@fedoraproject.org>

f_ctrl_c() {
  printf "\n*** Exiting ***\n"
  exit $?
}
     
# trap int (ctrl-c)
trap f_ctrl_c SIGINT

# "Global" variables
mock_target="fedora-19-armhfp"
declare -a failed_builds

f_usage() {
cat <<EOF
Usage: arm_build_oss_fedora.sh [Origin_Directory]
EOF
  exit 1
}

mock_working_dir=/var/tmp/build_oss_arm/$2

# check mock stuff 
if ! mock --version &> /dev/null; then
  printf "ERROR: mock not installed or not in current \$PATH\n"
  exit 2
fi
if [[ ! -f /etc/mock/${mock_target}.cfg ]]; then
  printf "ERROR: $mock_target is an invalid mock build target\n"
  printf "\tNo /etc/mock/${mock_target}.cfg found\n"
  exit 3
fi

# clean the old build working dir
if [[ -d $mock_working_dir ]]; then
  rm -fr $mock_working_dir
fi
mkdir -p $mock_working_dir

# Run through the SRPMS
for i in $(find $1 -name \*.src.rpm)
do
  mock -r ${mock_target}-arm $i
  if [[ "$?" != "0" ]]; then
    failed_builds+=( "$i" )
  else
    # NOTE: This is subject to failure if the config choses a different rootdir
    #       but all defaults don't do anything that silly
    mv /var/lib/mock/${mock_target}/result/*.rpm $mock_working_dir
  fi
done

if [[ -z $failed_builds ]]; then
  printf "Build: SUCCESS\n"
else
  printf "Build: FAILURE\nThe following packages failed to build:\n"
  for f in ${failed_builds[@]}
  do
    printf "${f}\n"
  done
fi

printf "All successfull builds can be found in $mock_working_dir\n"
