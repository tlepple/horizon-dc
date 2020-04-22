#!/bin/bash


###########################################################################################################
#  Load Utilities 
###########################################################################################################
. ../../utils.sh

###########################################################################################################
# Set some variables:
###########################################################################################################
export atlas_host=${atlas_host:-$(hostname -f)}      ##atlas hostname (if not on current host). Override with your own
export ranger_password=${ranger_password:-supersecret1}
export atlas_pass=${atlas_pass:-supersecret1}
export kdc_realm=${kdc_realm:-CLOUDERA.COM}
export host=$(hostname -f)



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

###########################################################################################################
#  Import Ranger items
###########################################################################################################
iranger_curl="curl -u admin:${ranger_password}"
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
cd ./policies

resource_policies=$(ls Ranger_Policies_ALL_*.json)
tag_policies=$(ls Ranger_Policies_TAG_*.json)

#import resource based policies
${ranger_curl} -X POST -H "Content-Type: multipart/form-data" -H "Content-Type: application/json" -F "file=@${resource_policies}" -H "Accept: application/json"  -F "servicesMapJson=@servicemapping-all.json" "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=hdfs,tag,hbase,yarn,hive,knox,kafka,atlas,solr"

#import tag based policies
${ranger_curl} -X POST -H "Content-Type: multipart/form-data" -H "Content-Type: application/json" -F "file=@${tag_policies}" -H "Accept: application/json"  -F "servicesMapJson=@servicemapping-tag.json" "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=tag"

cd ..

echo "Sleeping for 45s..."
sleep 45

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

cd /root/horizon-dc/provider/aws/component/wwbank-demo

./scripts/02-create-hdfs-user-folders.sh
./scripts/03-copy-data-to-hdfs-dc.sh
hdfs dfs -ls -R /hive_data

echo "Create hive tables..."
beeline  -n etl_user -f ./data/HiveSchema-dc.hsql
beeline  -n etl_user -f ./data/TransSchema-dc.hsql

echo "enable PAM auth for zeppelin, Hue..."
setfacl -m user:zeppelin:r /etc/shadow
setfacl -m user:hue:r /etc/shadow

###########################################################################################################
#
###########################################################################################################
###########################################################################################################
#
###########################################################################################################
###########################################################################################################
#
###########################################################################################################
###########################################################################################################
#
###########################################################################################################
