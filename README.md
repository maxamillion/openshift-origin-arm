# Tech Preview - OpenShift Origin on Fedora 19 ARM

ARM build scripts and misc for building/installing/running OpenShift Origin on 
Fedora 19 ARM

## Installing Origin on ARM

#####Requirements
* Fedora 19 ARM (armhfp) and compatible device
* Spare time
* Patience (not verified to be ready for prime time, there may be dragons)

Most of these instructions are from the 
[OpenShift Puppet Install Docs](http://openshift.github.io/documentation/oo_deployment_guide_puppet.html) 
with adaptations where needed. The goal is to no eventually no longer require 
custom install documentation.

Install puppet and bind

    yum install -y puppet bind

Install dependency puppet modules because we're going to install using the
Origin puppet master branch so puppet won't auto install the deps for us.
Then clone the master repo. (Need ntp and stdlib, but ntp pulls in stdlib
for us).

    puppet module install puppetlabs/ntp
    git clone https://github.com/openshift/puppet-openshift_origin.git /etc/puppet/modules/openshift_origin

Now we need to generate the BIND TSIG Key (we will need to put this in our
puppet config).

    #Using example.com as the cloud domain
    /usr/sbin/dnssec-keygen -a HMAC-MD5 -b 512 -n USER -r /dev/urandom -K /var/named example.com
    cat /var/named/Kexample.com.*.key  | awk '{print $8}'

Set the hostname.

    echo "broker.example.com" > /etc/hostname
    hostname broker.example.com

Now we need to create our puppet config, I call mine `configure_origin.pp` but
the name doesn't really matter.

    class { 'openshift_origin' :
      # Components to install on this host:
      roles          => ['broker','named','activemq','datastore','node'],

      # The FQDNs of the OpenShift component hosts; for a single-host
      # system, make all values identical.
      broker_hostname            => 'broker.example.com',
      node_hostname              => 'broker.example.com',
      named_hostname             => 'broker.example.com',
      datastore_hostname         => 'broker.example.com',
      activemq_hostname          => 'broker.example.com',

      # BIND / named config
      # This is the key for updating the OpenShift BIND server
      bind_key                   => 'YOUR_BIND_TSIG_KEY',
      # The domain under which applications should be created.
      domain                     => 'example.com',
      # Apps would be named <app>-<namespace>.example.com
      # This also creates hostnames for local components under our domain
      register_host_with_named   => true,
      # Forward requests for other domains (to Google by default)
      conf_named_upstream_dns    => ['8.8.8.8'],

      # Auth OpenShift users created with htpasswd tool in /etc/openshift/htpasswd
      broker_auth_plugin         => 'htpasswd',
      # Username and password for initial openshift user
      openshift_user1            => 'openshift',
      openshift_password1        => 'password',

      # To enable installing the Jenkins cartridge:
      install_method             => 'yum',
      repos_base                 => 'https://mirror.openshift.com/pub/origin-server/release/3/fedora-19/',
      jenkins_repo_base          => 'http://pkg.jenkins-ci.org/redhat',

      #Enable development mode for more verbose logs
      development_mode           => true,

      # Set if using an external-facing ethernet device other than eth0
      #conf_node_external_eth_dev => 'eth0',

      #If using with GDM, or have users with UID 500 or greater, put in this list
      #node_unmanaged_users       => ['user1'],
    }

At this point we should be good to go to run our puppet deploy. Take note that
this takes a long time. On a Calxeda HighBank quad-core with 4GB of RAM it took
about 30 minutes. There's a lot going on here.

     puppet apply --verbose configure_origin.pp

Once this is complete we need to run out "fixup" script because at the time of
this writing there are a couple issues that occur during the deploy that are
still yet to be tracked down to their root cause but the end goal is to work 
these issues out and not require this step. 

    git clone https://github.com/maxamillion/openshift-origin-arm.git ~/openshift-origin-arm
    ~/openshift-origin-arm/fixup_arm_origin.sh

At this point you should be able to reboot your system and have a functional
OpenShift Origin PaaS running on ARM. However if you would like, you don't have
to reboot but you'd have to know the order in which to start services and it's 
just easier. (I know, I know ... rebooting linux is terrible, feel free to read
the docs and learn the order to start services if you care enough)

From here we can install the rhc gem and setup using our local system (or if you
have DNS setup properly you can do this on an external system)

    gem install rhc
    rhc setup --server=broker.example.com

From here you should consult the [rhc documentation](https://access.redhat.com/site/documentation/en-US/OpenShift_Online/2.0/html/User_Guide/index.html)
if you are not familiar with using OpenShift. There is also a lot of great
material [here.](https://www.openshift.com/developers/documentation)

For more information about OpenShift Origin install with puppet or in general
please reference the following URLs:
* http://openshift.github.io/documentation/
* http://openshift.github.io/documentation/oo_deployment_guide_puppet.html

## Building Origin ARM packages

This is rather crude right now, but depending on the amount of success found 
in the early runs will determine how refined this process gets.

For now the process is effectively:

    git clone https://github.com/maxamillion/openshift-origin-arm.git ~/
    cd /path/to/dir/of/SRPMs/
    ln -s ~/openshift-origin-arm/arm_build_oss_fedora.sh ./
    ./arm_build_oss_fedora.sh

Once the build script is done it will tell you that the resulting rpms can be
found in /var/tmp/build_oss_arm/ or a subdirectory therein if you prefer.
* NOTE: Every time you run this script it will wipe the contents of 
/var/tmp/build_oss_arm/ .... so keep that in mind.


Also note, there is no cross compile options at this time. This script is meant
to be run on the an ARM device running Fedora 19 armhfp.

For mock, it turns out I need to use a custom config because one of our packages
depends on another one of our packages and we haven't gotten a chance to get it
into Fedora proper just yet.

    cp fedora-19-armhfp-custom.cfg /etc/mock/
    chown root:mock /etc/mock/fedora-19-armhfp-custom.cfg

Also for the dependencies, the version of libvirt-sandbox needed for Origin on 
F19 needs a newer version of libvirt so build that one first and then toss it
in the custom mock repo in /var/tmp/origin-deps/
* NOTE: Not needed anymore, this is in the Origin deps repo now.

