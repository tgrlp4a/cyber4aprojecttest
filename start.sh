#!/bin/sh

# Start Nginx
echo "Starting Nginx..."
/usr/sbin/nginx -g 'daemon off;'

# Start Wazuh agent
echo "Starting Wazuh agent..."
/etc/init.d/wazuh-agent start

# Check if Wazuh agent started successfully
if [ $? -ne 0 ]; then
  echo "Failed to start Wazuh agent"
  echo "Checking Wazuh logs for errors..."
  tail -n 50 /var/ossec/logs/ossec.log
  echo "Checking Wazuh agent status..."
  /etc/init.d/wazuh-agent status
  exit 1
fi

# Tail Wazuh logs in the background
tail -f /var/ossec/logs/ossec.log &
