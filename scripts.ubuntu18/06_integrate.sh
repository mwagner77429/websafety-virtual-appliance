#!/bin/bash

# all packages are installed as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# integrate with apache
a2dissite 000-default
a2ensite websafety

# replace the squid config
if [ ! -f /etc/squid/squid.conf.default ]; then
    cp -f /etc/squid/squid.conf /etc/squid/squid.conf.default
fi
cp -f squid.conf /etc/squid/squid.conf

# create squid storage for mimicked ssl certificates
SSL_DB=/var/spool/squid_ssldb
if [ -d $SSL_DB ]; then
	rm -Rf $SSL_DB
fi

# see what squid we have now installed
/usr/sbin/squid -v | grep "ersion 3." > /dev/null
if [ $? -eq 0 ]; then

	echo "Creating SSLDB for version 3 in $SSL_DB ..."

	# this is version 3
	/usr/lib/squid/ssl_crtd -c -s $SSL_DB

else

	echo "Creating SSLDB for version 4 in $SSL_DB ..."

	# this is version 4
	/usr/lib/squid/security_file_certgen -c -s $SSL_DB -M 4MB

fi

if [ $? -ne 0 ]; then
    echo "Error $? while initializing SSL certificate storage, exiting..."
    exit 1
fi
chown -R proxy:proxy $SSL_DB

# reset owner of installation path
chown -R websafety:websafety /opt/websafety

# restart all daemons
systemctl start wsicapd && service apache2 restart && service squid restart
