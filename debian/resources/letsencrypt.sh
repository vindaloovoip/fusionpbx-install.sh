#!/bin/sh

# FusionPBX - Install
# Mark J Crane <markjcrane@fusionpbx.com>
# Copyright (C) 2018
# All Rights Reserved.
      
#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ./config.sh

#remove dehyrdated letsencrypt script
#rm -R /etc/dehydrated/
#rm /usr/local/sbin/dehydrated
#rm -R /usr/src/dehydrated
#rm -R /usr/src/dns-01-manual
#rm -R /var/www/dehydrated

#request the domain name, email address and wild card domain
read -p 'Domain Name: ' domain_name
read -p 'Email Address: ' email_address

#wildcard detection
wilcard_domain=$(echo $domain_name | cut -c1-1)
if [ "$wilcard_domain" = "*" ]; then
        wilcard_domain="y"
else
        wilcard_domain="n"
fi

#get and install dehydrated
cd /usr/src && git clone https://github.com/lukas2511/dehydrated.git
cd /usr/src/dehydrated
cp dehydrated /usr/local/sbin
mkdir -p /var/www/dehydrated
mkdir -p /etc/dehydrated/certs

#remove the wildcard and period
if [ .$wilcard_domain = ."y" ]; then
      domain_name=$(echo "$domain_name" | cut -c3-255)
fi

#create an alias when using wildcard dns
#if [ .$wilcard_domain = ."y" ]; then
#  echo "*.$domain_name > $domain_name" > /etc/dehydrated/domains.txt
#fi

#manual dns hook
cd /usr/src
git clone https://github.com/owhen/dns-01-manual.git
cd /usr/src/dns-01-manual/
cp hook.sh /etc/dehydrated/hook.sh
chmod 755 /etc/dehydrated/hook.sh

#copy config and hook.sh into /etc/dehydrated
cd /usr/src/dehydrated
cp docs/examples/config /etc/dehydrated
#cp docs/examples/hook.sh /etc/dehydrated

#vim /etc/dehydrated/config
#sed "s#CONTACT_EMAIL=#CONTACT_EMAIL=$email_address" -i /etc/dehydrated/config

#make sure the nginx ssl directory exists
mkdir -p /etc/nginx/ssl

#accept the terms
dehydrated --register --accept-terms --config /etc/dehydrated/config

#wildcard domain
if [ .$wilcard_domain = ."y" ]; then
  dehydrated --cron --domain *.$domain_name --alias $domain_name --config /etc/dehydrated/config --out /etc/dehydrated/certs --challenge dns-01 --hook /etc/dehydrated/hook.sh
fi

#single domain
if [ .$wilcard_domain = ."n" ]; then
  dehydrated --cron --domain $domain_name --config /etc/dehydrated/config --config /etc/dehydrated/config --out /etc/dehydrated/certs --challenge dns-01 --hook /etc/dehydrated/hook.sh
fi

#update nginx config
sed "s@ssl_certificate         /etc/ssl/certs/nginx.crt;@ssl_certificate /etc/dehydrated/certs/$domain_name/fullchain.pem;@g" -i /etc/nginx/sites-available/fusionpbx
sed "s@ssl_certificate_key     /etc/ssl/private/nginx.key;@ssl_certificate_key /etc/dehydrated/certs/$domain_name/privkey.pem;@g" -i /etc/nginx/sites-available/fusionpbx

#read the config
/usr/sbin/nginx -t && /usr/sbin/nginx -s reload

#make sure the freeswitch directory exists
mkdir -p /etc/freeswitch/tls

#make sure the freeswitch certificate directory is empty
rm /etc/freeswitch/tls/*

#combine the certs into all.pem
cat /etc/dehydrated/certs/$domain_name/fullchain.pem > /etc/freeswitch/tls/all.pem
cat /etc/dehydrated/certs/$domain_name/privkey.pem >> /etc/freeswitch/tls/all.pem
#cat /etc/dehydrated/certs/$domain_name/chain.pem >> /etc/freeswitch/tls/all.pem

#copy the certificates
cp /etc/dehydrated/certs/$domain_name/cert.pem /etc/freeswitch/tls
cp /etc/dehydrated/certs/$domain_name/chain.pem /etc/freeswitch/tls
cp /etc/dehydrated/certs/$domain_name/fullchain.pem /etc/freeswitch/tls
cp /etc/dehydrated/certs/$domain_name/privkey.pem /etc/freeswitch/tls

#add symbolic links
ln -s /etc/freeswitch/tls/all.pem /etc/freeswitch/tls/agent.pem
ln -s /etc/freeswitch/tls/all.pem /etc/freeswitch/tls/tls.pem
ln -s /etc/freeswitch/tls/all.pem /etc/freeswitch/tls/wss.pem
ln -s /etc/freeswitch/tls/all.pem /etc/freeswitch/tls/dtls-srtp.pem

#set the permissions
chown -R www-data:www-data /etc/freeswitch/tls
