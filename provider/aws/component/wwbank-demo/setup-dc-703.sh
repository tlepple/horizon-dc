#!/bin/bash


###########################################################################################################
#  Load some utility functions
###########################################################################################################
. ../../utils.sh
. ~/horizon-dc/bin/cm_utils.sh

###########################################################################################################
# Set some variables:
###########################################################################################################
export enable_kerberos=${enable_kerberos:-true}      ## whether kerberos is enabled on cluster
export atlas_host=${atlas_host:-$(hostname -f)}      ##atlas hostname (if not on current host). Override with your own
export ranger_password=${ranger_password:-supersecret1}
export atlas_pass=${atlas_pass:-supersecret1}
export kdc_realm=${kdc_realm:-CLOUDERA.COM}
export host=$(hostname -f)
export CM_HOST=${CM_HOST:-$(hostname -f)}



###########################################################################################################
#  install nc & jq 
###########################################################################################################
yum install -y nc

#  install jq from util function
install_jq_cli

###########################################################################################################
# setup OS Users & groups
###########################################################################################################
./scripts/01-create-os-users.sh

echo "Waiting 60s for Ranger usersync..."
sleep 60
echo

###########################################################################################################
#  Import Ranger items
###########################################################################################################
ranger_curl="curl -u admin:${ranger_password}"
ranger_url="http://localhost:6080/service"


${ranger_curl} -X POST -H "Content-Type: application/json" -H "Accept: application/json" ${ranger_url}/public/v2/api/roles  -d @- <<EOF
{
   "name":"Admins",
   "description":"",
   "users":[
   ],
   "groups":[
      {
         "name":"etl",
         "isAdmin":false
      }
   ],
   "roles":[
   ]
}
EOF



${ranger_curl} ${ranger_url}/public/v2/api/servicedef/name/hive \
  | jq '.options = {"enableDenyAndExceptionsInPolicies":"true"}' \
  | jq '.policyConditions = [
{
	  "itemId": 1,
	  "name": "resources-accessed-together",
	  "evaluator": "org.apache.ranger.plugin.conditionevaluator.RangerHiveResourcesAccessedTogetherCondition",
	  "evaluatorOptions": {},
	  "label": "Resources Accessed Together?",
	  "description": "Resources Accessed Together?"
},{
	"itemId": 2,
	"name": "not-accessed-together",
	"evaluator": "org.apache.ranger.plugin.conditionevaluator.RangerHiveResourcesNotAccessedTogetherCondition",
	"evaluatorOptions": {},
	"label": "Resources Not Accessed Together?",
	"description": "Resources Not Accessed Together?"
}
]' > hive.json

${ranger_curl} -i \
  -X PUT -H "Accept: application/json" -H "Content-Type: application/json" \
  -d @hive.json ${ranger_url}/public/v2/api/servicedef/name/hive
sleep 10

#Import Ranger policies
echo "Importing Ranger policies..."
echo
cd ./policies

resource_policies=$(ls Ranger_Policies_ALL_*.json)
tag_policies=$(ls Ranger_Policies_TAG_*.json)

#import resource based policies
${ranger_curl} -X POST -H "Content-Type: multipart/form-data" -H "Content-Type: application/json" -F "file=@${resource_policies}" -H "Accept: application/json"  -F "servicesMapJson=@servicemapping-all.json" "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=hdfs,tag,hbase,yarn,hive,knox,kafka,atlas,solr"

echo

#import tag based policies
${ranger_curl} -X POST -H "Content-Type: multipart/form-data" -H "Content-Type: application/json" -F "file=@${tag_policies}" -H "Accept: application/json"  -F "servicesMapJson=@servicemapping-tag.json" "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=tag"

cd ..

echo
echo "Sleeping for 45s..."
sleep 45
echo

###########################################################################################################
# Create KDC users and keytabs
###########################################################################################################
echo "Creating users in KDC..."
kadmin.local -q "addprinc -randkey joe_analyst/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey kate_hr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey log_monitor/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey diane_csr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey jermy_contractor/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey mark_bizdev/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey john_finance/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey ivanna_eu_hr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey etl_user/$(hostname -f)@${kdc_realm}"

echo
echo "Creating user keytabs..."
mkdir -p /etc/security/keytabs
cd /etc/security/keytabs
kadmin.local -q "xst -k joe_analyst.keytab joe_analyst/$(hostname -f)@${kdc_realm}"    
kadmin.local -q "xst -k log_monitor.keytab log_monitor/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k diane_csr.keytab diane_csr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k jermy_contractor.keytab jermy_contractor/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k mark_bizdev.keytab mark_bizdev/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k john_finance.keytab john_finance/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k ivanna_eu_hr.keytab ivanna_eu_hr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k kate_hr.keytab kate_hr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k etl_user.keytab etl_user/$(hostname -f)@${kdc_realm}" 
chmod +r *.keytab

kinit -kt /etc/security/keytabs/etl_user.keytab  etl_user/$(hostname -f)@${kdc_realm}
hdfs dfs -mkdir -p /apps/hive/share/udfs/
hdfs dfs -put /opt/cloudera/parcels/CDH/lib/hive/lib/hive-exec.jar /apps/hive/share/udfs/
hdfs  dfs -chown -R hive:hadoop  /apps


###########################################################################################################
# 
###########################################################################################################
echo "Importing data..."
echo

cd /root/horizon-dc/provider/aws/component/wwbank-demo

./scripts/02-create-hdfs-user-folders.sh
./scripts/03-copy-data-to-hdfs-dc.sh
hdfs dfs -ls -R /hive_data

echo
echo "Create hive tables..."
echo
beeline  -n etl_user -f ./data/HiveSchema-dc.hsql
beeline  -n etl_user -f ./data/TransSchema-dc.hsql

echo
echo "enable PAM auth for zeppelin, Hue..."
echo
setfacl -m user:zeppelin:r /etc/shadow
setfacl -m user:hue:r /etc/shadow

###########################################################################################################
# Zeppelin Stuff
###########################################################################################################
echo
echo "setup of zeppelin items..."
sleep 5

cd ./interpreters/



#login to zeppelin and grab cookie 
echo
cookie=$( curl -i --data "userName=etl_user&password=supersecret1" -X POST http://$(hostname -f):8885/api/login | grep HttpOnly  | tail -1  )
echo "$cookie" > cookie.txt

#Create shell interpreter setting
echo
curl -b ./cookie.txt -X POST http://$(hostname -f):8885/api/interpreter/setting -d @./shell.json
echo

#Create jdbc interpreter setting
echo
hivejar=$(ls /opt/cloudera/parcels/CDH/jars/hive-jdbc-3*-standalone.jar)
sed -i.bak "s|__hivejar__|${hivejar}|g" ./jdbc.json
KEYTABLOCATION=$(find /var/run/cloudera-scm-agent/process/ -type f ! -empty -printf "%T@ %Tc %p\n" | sort -z | grep zeppelin.keytab | head -n1 |awk '{ print $9 }')
sed -i.bak "s|__keytablocation__|${KEYTABLOCATION}|g" ./jdbc.json
KRBPRINCIPAL=zeppelin/$(hostname -f)@CLOUDERA.COM
sed -i.bak "s|__krbprincipal__|${KRBPRINCIPAL}|g" ./jdbc.json
echo

curl -b ./cookie.txt -X POST http://$(hostname -f):8885/api/interpreter/setting -d @./jdbc.json
echo

#list all interpreters settings - jdbc and sh should now be added
echo
curl -b ./cookie.txt http://$(hostname -f):8885/api/interpreter/setting | python -m json.tool | grep "id"
echo

#import zeppelin notebooks
cd /var/lib/zeppelin/notebook
mkdir 2EKX5F5MF
cp "/root/horizon-dc/provider/aws/component/wwbank-demo/zeppelin/notebooks/Demos _ Security _ WorldWideBank _ Joe-Analyst.json"  ./2EKX5F5MF/note.json

mkdir 2EMPR5K29
cp "/root/horizon-dc/provider/aws/component/wwbank-demo/zeppelin/notebooks/Demos _ Security _ WorldWideBank _ Ivanna EU HR.json" ./2EMPR5K29/note.json

mkdir 2EKHXD4H3
cp "/root/horizon-dc/provider/aws/component/wwbank-demo/zeppelin/notebooks/Demos _ Security _ WorldWideBank _ etl_user.json" ./2EKHXD4H3/note.json

mkdir 2EZM9PAXV
cp "/root/horizon-dc/provider/aws/component/wwbank-demo/zeppelin/notebooks/Demos _ Hive ACID.json" ./2EZM9PAXV/note.json

mkdir 2EXWA1114
cp "/root/horizon-dc/provider/aws/component/wwbank-demo/zeppelin/notebooks/Demos _ Hive Merge.json" ./2EXWA1114/note.json


chown -R  zeppelin:zeppelin /var/lib/zeppelin/notebook 

###########################################################################################################
#
###########################################################################################################
echo
echo "atlas classification items..."
echo
cd /root/horizon-dc/provider/aws/component/wwbank-demo/scripts

sed -i.bak "s/21000/31000/g" env_atlas.sh
sed -i.bak "s/localhost/${atlas_host}/g" env_atlas.sh
sed -i.bak "s/ATLAS_PASS=admin/ATLAS_PASS=${atlas_pass}/g" env_atlas.sh

./04-atlas-import-classification.sh

echo "hbase and kafka items..."
./05-create-hbase-kafka-dc.sh
echo

echo "Sleeping for 60s..."
echo
sleep 60

echo "associate entities with tags..."
echo
./06-associate-entities-with-tags-dc.sh

###########################################################################################################
# 
###########################################################################################################

export cluster_name=$(curl -X GET -u admin:admin http://localhost:7180/api/v40/clusters/  | jq '.items[0].name' | tr -d '"')

echo "restarting Zeppelin to see imported notebooks..."
echo

# restart Zeppelin (call to functions)
restart_service zeppelin

sleep 15s

 # check for 5 min if status is started
 echo "Check to see if service is started (for 5 min max)"
    counter=0

    while [ $counter -lt 300 ]; do
        get_service_state zeppelin
        if [ ${CURRENT_SERVICE_STATE} != 'STARTED' ]; then
            echo "Current Status is --> " ${CURRENT_SERVICE_STATE}
            echo "sleeping for 20s"
            echo;
            sleep 20s
            let counter=counter+20
        else
            echo "Zeppelin is started!"
            break
        fi
    done

echo
echo "Setup Complete"

#  call echo connections...

echo
echo

. ~/horizon-dc/bin/echo_service_conns.sh

exit 0
###########################################################################################################
#
###########################################################################################################
