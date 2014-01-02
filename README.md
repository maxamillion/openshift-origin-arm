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

    yum install -y puppet bind git

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
the name doesn't really matter. Note to change the `YOUR_BIND_TSIG_KEY` with the
key output from the `cat /var/named/Kexample.com.*.key  | awk '{print $8}'` 
command we ran above.

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

If you run into any issues or have found a resolution to any ARM specific
issues, feel free to file an issue ticket on this repo or ping me on 
`#openshift-dev` on `irc.freenode.net`, nick: `maxamillion`

##### Known Issues
1. postgresql cartridge does not work at this time on ARM (due to pgdata arch specific optimizations, [this pull request should resolve the issue](https://github.com/openshift/origin-server/pull/4392)) (fixup script handles this in the mean time)
1. /usr/lib64 gets created during deployment process but not sure why (fixup script handles fixing this)

## Building Origin ARM packages

There was an old method that included a script from this repo but it's far more
clean of a method to use mockchain.

##### Steps to build:
###### Step 1 - Prep the SRPMS
Download all SRPMS and place them somewhere (doesn't matter where, we'll tell
mockchain where they are.
   
Optionally you can build SRPMS from source using the following (note, this requires
you have the `tito` utility installed which you can install with `yum -y install tito`)

    git clone https://github.com/openshift/origin-server.git
    cd origin-server
    for pkg in $(find . -name \*.spec); do
      pushd $(dirname $pkg)
        tito build --test --srpm # use --test if you want nightlies, omit for latest stable tag
      popd
    done

Now you will find a bunch of SRPMS in /tmp/tito and you can either mockchain from
there or move them elsewhere. Your choice.

##### Step 2 - Run the mockchain
The following command will log to the build directory output by the chainbuild 
command and result in the filename mockchain.log, we're also adding the Origin 
dependencies repository to the mock config for the chainbuild run. Also, pass 
`--recurse` so that mockchain will handle circular dependencies for us, which 
does exist because of the console.

    mockchain -r fedora-19-armhfp \
        --log mockchain.log \
        -a https://mirror.openshift.com/pub/origin-server/release/3/fedora-19/dependencies/armhfp/ \
        --recurse /tmp/tito/*.src.rpm # Or where ever your SRPMS actually are.

From here mockchain will output it's progress as well as inform you of where 
you can find the resulting packages.
