#!/bin/bash
set -e -x
## Single node C7 install
## A bit of brute force, not the most elegant scripting
## Based on https://docs.google.com/document/d/15_ibyJGhfdVge7jIZP_h4iA2369lC8PdCnvHYKwg9iU/edit?ts=5dd6295e#
## Nov 22, 2019

CLDR_REPO_USER="YourUserID"
CLDR_REPO_PASS="YourUserPass"

yum install -y wget

DB_PASSWORD="supersecret1"

#CLDR_MGR_BASEURL="https://archive.cloudera.com/p/cm7"
CLDR_MGR_BASEURL="https://$CLDR_REPO_USER:$CLDR_REPO_PASS@$archive.cloudera.com/p/cm7"

CLDR_MGR_VER_URL="$CLDR_MGR_BASEURL/7.0.3/redhat7/yum"

##CLDR includes an rpm for openjdk8 in the repo
OPENJDK_RPM_URL="$CLDR_MGR_VER_URL/RPMS/x86_64/openjdk8-8.0+232_9-cloudera.x86_64.rpm"
OPEN_JAVA_HOME="/usr/java/jdk1.8.0_232-cloudera"

##Indicate which JDK you want… TODO add Oracle option
JDK_RPM_URL="$OPENJDK_RPM_URL"
JAVA_HOME="$OPEN_JAVA_HOME"

PG_REPO_URL="https://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/pgdg-redhat96-9.6-3.noarch.rpm"

PG_HOME_DIR="/var/lib/pgsql/9.6"

#LOCAL_TIMEZONE="America/Los_Angeles"
#LOCAL_TIMEZONE="Europe/London"
#LOCAL_TIMEZONE="America/New_York"
LOCAL_TIMEZONE="America/Chicago"

################################################


if [ getenforce != Disabled ]
then  setenforce 0;
fi

ln -sf /usr/share/zoneinfo/$LOCAL_TIMEZONE /etc/localtime

## turn off Transparent Huge pages
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled


#  turn off swappiness
sysctl vm.swappiness=10

echo "vm.swappiness = 10" >> /etc/sysctl.conf

#wget $CLDR_MGR_VER_URL/cloudera-manager-trial.repo -P /etc/yum.repos.d/
wget $CLDR_MGR_VER_URL/cloudera-manager.repo -P /etc/yum.repos.d/

# Update the UserName and PWD in the repo here:
sed -i "s/username=changeme/username=$CLDR_REPO_USER/g" /etc/yum.repos.d/cloudera-manager.repo
sed -i "s/password=changeme/username=$CLDR_REPO_PASS/g" /etc/yum.repos.d/cloudera-manager.repo


## Import the GPG Key
rpm --import $CLDR_MGR_VER_URL/RPM-GPG-KEY-cloudera

## Clear the yum cache
yum clean all

#install java
rpm -ivh $JDK_RPM_URL

## Install CM Server & Agent
yum -y install cloudera-manager-server cloudera-manager-agent

## Install Postgresql repo for Redhat
yum -y install $PG_REPO_URL

## Install PG 9.6
yum -y install postgresql96-server postgresql96-contrib postgresql96 postgresql-jdbc*


## setup the jdbc connetor
cp /usr/share/java/postgresql-jdbc.jar /usr/share/java/postgresql-connector-java.jar
chmod 644 /usr/share/java/postgresql-connector-java.jar

echo 'LC_ALL="en_US.UTF-8"' >> /etc/locale.conf
## TODO - Is this really a requirement? do we support any other of utf-8 compat locale? fr_FR.UTF-8, de-DE.UTF-8 ?

## Initialize Postgresql
/usr/pgsql-9.6/bin/postgresql96-setup initdb


## Start Postgres service and config it for restart on reboot
systemctl enable postgresql-9.6
systemctl start postgresql-9.6

## Allow listeners from any host
sed -e 's,#listen_addresses = \x27localhost\x27,listen_addresses = \x27*\x27,g' -i $PG_HOME_DIR/data/postgresql.conf

## Increase number of connections
sed -e 's,max_connections = 100,max_connections = 300,g' -i  $PG_HOME_DIR/data/postgresql.conf

## Save the original & replace with a new pg_hba.conf
mv $PG_HOME_DIR/data/pg_hba.conf $PG_HOME_DIR/data/pg_hba.conf.orig

cat <<EOF > $PG_HOME_DIR/data/pg_hba.conf
  # TYPE  DATABASE        USER            ADDRESS                 METHOD
  local   all             all                                     peer
  host    scm             scm            0.0.0.0/0                md5
  host    das             das            0.0.0.0/0                md5
  host    hive            hive           0.0.0.0/0                md5
  host    hue             hue            0.0.0.0/0                md5
  host    oozie           oozie          0.0.0.0/0                md5
  host    ranger          rangeradmin    0.0.0.0/0                md5
  host    rman            rman           0.0.0.0/0                md5
  host    hbase           hbase          0.0.0.0/0                md5
  host    phoenix         phoenix        0.0.0.0/0                md5  
EOF

chown postgres:postgres $PG_HOME_DIR/data/pg_hba.conf
chmod 600 $PG_HOME_DIR/data/pg_hba.conf


## Restart Postgresql
systemctl restart postgresql-9.6

## Create a DDL file for all our Db’s
cat <<EOF > ~/create_ddl_c703.sql
CREATE ROLE das LOGIN PASSWORD 'supersecret1';
CREATE ROLE hive LOGIN PASSWORD 'supersecret1';
CREATE ROLE hue LOGIN PASSWORD 'supersecret1';
CREATE ROLE oozie LOGIN PASSWORD 'supersecret1';
CREATE ROLE rangeradmin LOGIN PASSWORD 'supersecret1';
CREATE ROLE rman LOGIN PASSWORD 'supersecret1';
CREATE ROLE scm LOGIN PASSWORD 'supersecret1';
CREATE ROLE hbase LOGIN PASSWORD 'supersecret1';
CREATE ROLE phoenix LOGIN PASSWORD 'supersecret1';
CREATE DATABASE das OWNER das ENCODING 'UTF-8';
CREATE DATABASE hive OWNER hive ENCODING 'UTF-8';
CREATE DATABASE hue OWNER hue ENCODING 'UTF-8';
CREATE DATABASE oozie OWNER oozie ENCODING 'UTF-8';
CREATE DATABASE ranger OWNER rangeradmin ENCODING 'UTF-8';
CREATE DATABASE rman OWNER rman ENCODING 'UTF-8';
CREATE DATABASE scm OWNER scm ENCODING 'UTF-8';
CREATE DATABASE hbase OWNER hbase ENCODING 'UTF-8';
CREATE DATABASE phoenix OWNER phoenix ENCODING 'UTF-8';
EOF


## Run the sql file to create the schema for all DB’s
sudo -u postgres psql < ~/create_ddl_c703.sql

## Run the prepare script for SCM db
/opt/cloudera/cm/schema/scm_prepare_database.sh postgresql scm scm supersecret1

## TODO - Do we have to do this for C7??
sudo -u postgres psql -c 'ALTER DATABASE hive SET standard_conforming_strings=off;'
sudo -u postgres psql -c 'ALTER DATABASE oozie SET standard_conforming_strings=off;'

## Install rng-tools,  we are expecting to see values over 1000, anything less than 100-200 and rngd isnt working
yum -y install rng-tools
cp /usr/lib/systemd/system/rngd.service /etc/systemd/system/
systemctl daemon-reload
systemctl start rngd


#time issues for clock offset in aws	
echo "server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4" >> /etc/chrony.conf
systemctl restart chronyd


## Set up AutoTLS
#JAVA_HOME="$JAVA_HOME" /opt/cloudera/cm-agent/bin/certmanager --location /opt/cloudera/CMCA setup --configure-services

## Start the CM Server
systemctl start cloudera-scm-server

## Install MIT Kerberos
#yum -y install krb5-server krb5-workstation

echo "If you wish, tail the log file and wait for  \": Started Jetty server\""
echo "\"tail -f /var/log/cloudera-scm-server/cloudera-scm-server.log\""
echo "login to CM  \"http://`curl ifconfig.me`:7180\" user:admin, pwd:admin"

exit 0
