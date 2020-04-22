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
#export cluster_name=${cluster_name:-WWBank}
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


###########################################################################################################
#
###########################################################################################################

###########################################################################################################
#
###########################################################################################################

###########################################################################################################
#
###########################################################################################################

