openshift-origin-arm
====================

ARM build scripts and misc for building OpenShift Origin on Fedora ARM


This is rather crude right now, but depending on the amount of success found 
in the early runs will determine how refined this process gets.

For now the process is effectively:

    git clone https://github.com/maxamillion/openshift-origin-arm.git ~/
    cd /path/to/dir/of/SRPMs/
    ln -s ~/arm_build_oss_fedora.sh ./
    ./arm_build_oss_fedora.sh

Once the build script is done it will tell you that the resulting rpms can be
found in /var/tmp/build_oss_arm/ or a subdirectory therein if you prefer.


Also note, there is no cross compile options at this time. This script is meant
to be run on the an ARM device running Fedora 19 armv7hl.

For mock, it turns out I need to use a custom config because on of our packages
depends on another one of our packages and we haven't gotten a chance to get it
into Fedora proper just yet.

    cp fedora-19-armhfp-custom.cfg /etc/mock/
    chown root:mock /etc/mock/fedora-19-armhfp-custom.cfg


Also for the dependencies, the version of libvirt-sandbox needed for Origin on 
F19 needs a newer version of libvirt so build that one first and then toss it
in the custom mock repo in /var/tmp/origin-deps/

    
