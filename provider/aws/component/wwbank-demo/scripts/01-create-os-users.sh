#!/bin/bash


groupadd finance
groupadd business_dev
groupadd contractor
groupadd csr
groupadd etl
groupadd intern
groupadd iadm_analyst
groupadd oadm_analyst


useradd -g hadoop admin
useradd -g finance john_finance
useradd -g business_dev mark_bizdev
useradd -g contractor jeremy_contractor
useradd -g csr diane_csr
useradd -g etl log_monitor
useradd -g etl etl_user
useradd -g intern scott_intern
useradd rangerlookup

groupadd us_employee
groupadd eu_employee
groupadd analyst
groupadd hr
groupadd dpo

useradd -g analyst joe_analyst
useradd -g hr kate_hr
useradd -g hr sasha_eu_hr
useradd -g hr ivanna_eu_hr
useradd -g dpo michelle_dpo
useradd -g iadm_analyst iadm_user
useradd -g oadm_analyst oadm_user

#below users should also be added to us_employee or eu_employee
usermod -a -G us_employee joe_analyst
usermod -a -G us_employee kate_hr
usermod -a -G eu_employee sasha_eu_hr
usermod -a -G eu_employee ivanna_eu_hr
usermod -a -G eu_employee michelle_dpo



echo supersecret1 > passwd.txt
echo supersecret1 >> passwd.txt

passwd joe_analyst < passwd.txt
passwd ivanna_eu_hr < passwd.txt
passwd etl_user < passwd.txt
passwd scott_intern < passwd.txt
passwd iadm_user < passwd.txt
passwd oadm_user < passwd.txt

rm -f passwd.txt
