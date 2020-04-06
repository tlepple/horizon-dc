#!/bin/bash

#####################################################
# Function to install passwordless access to hosts
#####################################################
install_pwdless_access() {

	echo "-- Enable passwordless root login via rsa key"
	ssh-keygen -f ~/myRSAkey -t rsa -N ""
	mkdir ~/.ssh
	cat ~/myRSAkey.pub >> ~/.ssh/authorized_keys
	chmod 400 ~/.ssh/authorized_keys
	ssh-keyscan -H `hostname` >> ~/.ssh/known_hosts
	sed -i 's/.*PermitRootLogin.*/PermitRootLogin without-password/' /etc/ssh/sshd_config
	systemctl restart sshd

}

#####################################################
# Function to install jq
#####################################################
install_jq_cli() {

	#####################################################
	# first check if JQ is installed
	#####################################################
	log "Installing jq"

	jq_v=`jq --version 2>&1`
	if [[ $jq_v = *"command not found"* ]]; then
	  curl -L -s -o jq "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
	  chmod +x ./jq
	  cp jq /usr/bin
	else
	  log "jq already installed. Skipping"
	fi

	jq_v=`jq --version 2>&1`
	if [[ $jq_v = *"command not found"* ]]; then
	  log "error installing jq. Please see README and install manually"
	  echo "Error installing jq. Please see README and install manually"
	  exit 1 
	fi  

}
