---
---

#  Install demo materials into CDP-DC Cluster

---
---

```
#  login as root
sudo -i

# change to the install directory
cd /root/horizon-dc/provider/aws/component/wwbank-demo

# run the script
. setup-wwbank.sh

```

---
---

* Save the output of the above command for reference later

###  Sample Output (these IPs are unique to your cluster build):

```
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          ------------------------------   Public IP Links:       -------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------

          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          |          Service              |                       URL                                              
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          | Cloudera Manager              |       http://18.217.86.36:7180                                       
          ---------------------------------------------------------------------------------------------------------
           --------------------------------------------------------------------------------------------------------
          | Ranger                        |       http://18.217.86.36:6080                                       
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          | Atlas                         |       http://18.217.86.36:31000                                      
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          | Zeppelin                      |       http://18.217.86.36:8885                                       
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          | Hue                           |       http://18.217.86.36:8888                                       
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          | DAS                           |       http://18.217.86.36:30800                                      
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------
          | Schema Registry               |       http://18.217.86.36:7788                            		 
          ---------------------------------------------------------------------------------------------------------
          ---------------------------------------------------------------------------------------------------------

```
---
---

# Give the demo - Command Line

---
---


###  Sample Hive queries (run as user 'joe_analyst') in `beeline`

---

#####  Become user `joe_analyst`

```

# set the kerberos keytab for user joe_analyst
export kdc_realm=CLOUDERA.COM  
kinit -kt /etc/security/keytabs/joe_analyst.keytab joe_analyst/$(hostname -f)@${kdc_realm}

```

##### Inspect the keytab and verify you are user `joe_analyst`

```
klist

```

##### Example output:

```
Ticket cache: FILE:/tmp/krb5cc_0
Default principal: joe_analyst/ip-10-0-8-19.us-east-2.compute.internal@CLOUDERA.COM

Valid starting       Expires              Service principal
06/17/2020 13:26:07  06/18/2020 13:26:07  krbtgt/CLOUDERA.COM@CLOUDERA.COM
	renew until 06/24/2020 13:26:07

```

#####  Connect to `beeline`

```
beeline -n joe_analyst -p supersecret1

```

#####  Example query of showing a `masking` policy

```
SELECT surname, streetaddress, country, age, password, nationalid, ccnumber, mrn, birthday FROM worldwidebank.us_customers limit 5;
```

##### Example query showing a `prohibition` policy

```
select zipcode, insuranceid, bloodtype from worldwidebank.ww_customers;
```

#####  Example query showing a `tag based deny (EXPIRED_ON)` policy

```
select fed_tax from finance.tax_2015;
```

#####  Example query showing a `tag based deny (DATA_QUALITY)` policy

```
select * from cost_savings.claim_savings limit 5;
```

#####  Exit `beeline`

```
!q

# or
!quit
```

---
---

### Sample SparkSQL queries for user `joe_analyst`

---

#####  Set the keytab for user `joe_analyst`

```
kinit -kt /etc/security/keytabs/joe_analyst.keytab joe_analyst/$(hostname -f)@${kdc_realm}

```

#####  Start the Spark Shell

```
spark-shell --jars /opt/cloudera/parcels/CDH/jars/hive-warehouse-connector-assembly*.jar     --conf spark.sql.hive.hiveserver2.jdbc.url="jdbc:hive2://$(hostname -f):10000/default;"    --conf "spark.sql.hive.hiveserver2.jdbc.url.principal=hive/$(hostname -f)@${kdc_realm}"    --conf spark.security.credentials.hiveserver2.enabled=false

import com.hortonworks.hwc.HiveWarehouseSession
import com.hortonworks.hwc.HiveWarehouseSession._
val hive = HiveWarehouseSession.session(spark).build()
```

#####  SparkSQL Query example `masking` policy

```
hive.execute("SELECT surname, streetaddress, country, age, password, nationalid, ccnumber, mrn, birthday FROM worldwidebank.us_customers").show(10)
```

#####  SparkSQL Query example `prohibition` policy

```
hive.execute("select zipcode, insuranceid, bloodtype from worldwidebank.ww_customers").show(10)
```

#####  SparkSQL Query example `tag based deny (DATA_QUALITY)` policy

```
hive.execute("select * from cost_savings.claim_savings").show(10)
```

#####  Exit Spark Shell

```
:q
```

---
---

###  Sample Hive queries (run as user 'kate_hr') in `beeline`

---

#####  Become user `kate_hr`

```

# set the kerberos keytab for user kate_hr 
export kdc_realm=CLOUDERA.COM
kinit -kt /etc/security/keytabs/kate_hr.keytab kate_hr/$(hostname -f)@${kdc_realm}
```

##### Inspect the keytab and verify you are user `kate_hr`

```
klist

```

##### Example output:

```
Ticket cache: FILE:/tmp/krb5cc_0
Default principal: kate_hr/ip-10-0-8-19.us-east-2.compute.internal@CLOUDERA.COM

Valid starting       Expires              Service principal
06/17/2020 13:44:14  06/18/2020 13:44:14  krbtgt/CLOUDERA.COM@CLOUDERA.COM
	renew until 06/24/2020 13:44:14
```

#####  Connect to `beeline`

```
beeline -n kate_hr -p supersecret1

```

#####  Example query of showing a `masking` policy

```
SELECT surname, streetaddress, country, age, password, nationalid, ccnumber, mrn, birthday FROM worldwidebank.us_customers limit 5;
```

##### Example query showing a `prohibition` policy

```
select zipcode, insuranceid, bloodtype from worldwidebank.ww_customers;
```

#####  Example query showing a `tag based deny (EXPIRED_ON)` policy

```
select fed_tax from finance.tax_2015;
```

#####  Example query showing a `tag based deny (DATA_QUALITY)` policy

```
select * from cost_savings.claim_savings limit 5;
```

#####  Exit `beeline`

```
!q

# or
!quit
```

