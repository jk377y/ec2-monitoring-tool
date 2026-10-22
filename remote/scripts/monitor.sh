#!/bin/bash

# grabs some basic info about the server
SERVER_NAME=$(hostname) # the name of the host, probably 10.10.10.xxx with the EC2 labs
CHECK_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ") # the time of the check in UTC

# print the info so I can make sure it's working
echo "Server: $SERVER_NAME" # print the hostname to the terminal
echo "Checked: $CHECK_TIME" # print the current time to the terminal
