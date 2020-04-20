#!/bin/bash


###########################################################################################################
# Set some variables:
###########################################################################################################
export host=$(hostname -f)
export realm=${realm:-CLOUDERA.COM}
export domain=${domain:-cloudera.com}
export kdcpassword=${kdcpassword:-supersecret1}

###########################################################################################################
# Install MIT Kerberos
###########################################################################################################
yum -y install krb5-server krb5-workstation krb5-libs krb5-auth-dialog

###########################################################################################################
# Create the krb5.conf file
###########################################################################################################

cat <<EOF > /etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = $realm
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5
 default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5
 permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5 

[realms]
 $realm = {
  kdc = $host
  admin_server = $host
 }

[domain_realm]
 .$domain = $realm
 $domain = $realm
EOF

###########################################################################################################
#  make copy of kdc.conf
###########################################################################################################
mv /var/kerberos/krb5kdc/kdc.conf{,.original}

###########################################################################################################
# create new kdc.conf 
###########################################################################################################
cat <<EOF > /var/kerberos/krb5kdc/kdc.conf
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88
[realms]
 ${realm} = {
 acl_file = /var/kerberos/krb5kdc/kadm5.acl
 dict_file = /usr/share/dict/words
 admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
 supported_enctypes = aes256-cts-hmac-sha1-96:normal aes128-cts-hmac-sha1-96:normal arcfour-hmac-md5:normal
 max_renewable_life = 7d
}
EOF

###########################################################################################################
# set the kdc admin pwd and start the services 
###########################################################################################################

echo $kdcpassword > passwd
echo $kdcpassword >> passwd
sudo kdb5_util create -s < passwd


sudo service krb5kdc start
sudo service kadmin start
sudo chkconfig krb5kdc on
sudo chkconfig kadmin on

sudo kadmin.local -q "addprinc admin/admin" < passwd
sudo kadmin.local -q "addprinc cloudera-scm/admin" < passwd
rm -f passwd

###########################################################################################################
# create new kadm5.acl 
###########################################################################################################
cat <<EOF > /var/kerberos/krb5kdc/kadm5.acl
*/admin@$realm	 *
EOF

###########################################################################################################
# restart krb5adc and kadmin
###########################################################################################################
sudo service krb5kdc restart
sudo service kadmin restart

echo "Waiting for KDC to restart..."
sleep 10

sudo service krb5kdc status
sudo service kadmin status

kadmin.local -q "modprinc -maxrenewlife 7day krbtgt/${realm}@${realm}"

echo "For testing KDC run below:"
echo kadmin -p admin/admin -w $kdcpassword -r $realm -q \"get_principal admin/admin\"

echo kadmin -p cloudera-scm/admin -w $kdcpassword -r $realm -q \"get_principal cloudera-scm/admin\"

echo "KDC setup complete"





