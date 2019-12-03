#!/bin/bash
 
read -p "Enter a REALM name: " REALM
REALM=$(echo ${REALM} | tr [a-z] [A-Z])
read -s -p "Enter a KDC password: " KDC_PASS
echo
read -s -p "Re-Enter the KDC password: " KDC_PASS2
echo
 
if [ ! "${KDC_PASS}" == "${KDC_PASS2}" ]; then
  echo "Passwords do NOT match!"
  exit 1
fi
 
read -s -p "Enter a password for the cloudera-scm/admin principal: " CM_PASS
echo
read -s -p "Re-Enter the password for the cloudera-scm/admin principal: " CM_PASS2
echo
 
if [ ! "${CM_PASS}" == "${CM_PASS2}" ]; then
  echo "Passwords do NOT match!"
  exit 1
fi
 
LOG_FILE='setup_kdc.log'
HOSTNAME=$(hostname -f)
DNS_SUFFIX=$(hostname -d)
KADM5_ACL='/var/kerberos/krb5kdc/kadm5.acl'
KDC_CONF='/var/kerberos/krb5kdc/kdc.conf'
KRB5_CONF='/etc/krb5.conf'
 
echo $(date) >> ${LOG_FILE}
 
# kadm5.acl
echo -n "Configuring ${KADM5_ACL}..."
echo "*/admin@${REALM} *" > ${KADM5_ACL}
echo 'done'
 
# kdc.conf
echo -n "Configuring ${KDC_CONF}..."
echo "[kdcdefaults]
kdc_ports = 88
kdc_tcp_ports = 88
 
[realms]
${REALM} = {
 acl_file = ${KADM5_ACL}
 dict_file = /usr/share/dict/words
 admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
 supported_enctypes = aes256-cts:normal aes128-cts:normal arcfour-hmac:normal
 max_renewable_life = 7d
}
" > ${KDC_CONF}
echo 'done'
 
# krb5.conf
echo -n "Configuring ${KRB5_CONF}..."
echo "[logging]
default = FILE:/var/log/krb5libs.log
kdc = FILE:/var/log/krb5kdc.log
admin_server = FILE:/var/log/kadmind.log
 
[libdefaults]
default_realm = ${REALM}
dns_lookup_realm = false
dns_lookup_kdc = false
ticket_lifetime = 24h
renew_lifetime = 7d
forwardable = true
udp_preference_limit = 1
 
[realms]
${REALM} = {
 kdc = ${HOSTNAME}
 admin_server = ${HOSTNAME}
}
 
[domain_realm]
.${DNS_SUFFIX} = ${REALM}
${DNS_SUFFIX} = ${REALM}
" > ${KRB5_CONF}
echo 'done'
 
# Create the KDC
echo -n "Creating realm ${REALM}..."
kdb5_util -s create -P ${KDC_PASS} >> ${LOG_FILE} 2>&1
echo 'done'
 
# Start and enable the KDC and kadmin at boot
echo -n 'Starting KDC...'
systemctl start krb5kdc >> ${LOG_FILE} 2>&1
echo 'done'
echo -n 'Starting kadmin...'
systemctl start kadmin >> ${LOG_FILE} 2>&1
echo 'done'
systemctl enable krb5kdc >> ${LOG_FILE} 2>&1
systemctl enable kadmin >> ${LOG_FILE} 2>&1
 
# Add the Cloudera Manager administrative principal
echo -n 'Creating cloudera-scm/admin principal...'
kadmin.local -q "addprinc -pw ${CM_PASS} cloudera-scm/admin@${REALM}" >> ${LOG_FILE} 2>&1
echo 'done'
echo
echo 'Completed!'
