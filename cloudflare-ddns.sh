#!/bin/sh

auth_email="cloudflar@email.com"                                       # The email used to login 'https://dash.cloudflare.com'
auth_method="global"                                 # Set to "global" for Global API Key or "token" for Scoped API Token
auth_key="*****"                                       # Your API Token or Global API Key
zone_identifier="*****"                                  # Can be found in the "Overview" tab of your domain
record_name="subdomain.domain.com"                                      # Which record you want to be synced
ttl=3600                                             # Set the DNS TTL (seconds)
proxy="true"  
# Definir el path del archivo de log
# This is the internal path of the container where the logs will be record
LOG_FILE="/var/log/cloudflare-ddns.log"

easylog() {
  local message="$1"
  
  echo -e "$message"
  echo -e "$message" >> "$LOG_FILE"
}

###########################################
## Check if we have a public IP
###########################################
ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
if [[ $ret -ne 0 ]]; then # In the case that cloudflare failed to return an ip.
    # Attempt to get the ip from other websites.
    # El código de retorno ($?) es 0 si grep encontró una coincidencia, y diferente de 0 si no
    # Si no se obtiene ip de cloudflare, usa una de estas dos. Que ya devuelve la IP en formato correcto.
    ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
else
    # Extract just the ip from the ip line from cloudflare.
    ip=$(echo $ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
fi

# Use regex to check for proper IPv4 format.
if [[ ! $ip =~ ^$ipv4_regex$ ]]; then
    easylog "$(date) - DDNS Updater: Failed to find a valid IP."
    exit 2
fi

###########################################
## Check and set the proper auth header
###########################################
if [[ "${auth_method}" == "global" ]]; then
  auth_header="X-Auth-Key:"
else
  auth_header="Authorization: Bearer"
fi

###########################################
## Seek for the A record
###########################################

easylog "$(date) - DDNS Updater: Check Initiated"
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
                      -H "X-Auth-Email: $auth_email" \
                      -H "$auth_header $auth_key" \
                      -H "Content-Type: application/json")

###########################################
## Check if the domain has an A record
###########################################
if [[ $record == *"\"count\":0"* ]]; then
  easylog "$(date) - DDNS Updater: Record does not exist, perhaps create one first? (${ip} for ${record_name})"
  exit 1
fi

###########################################
## Get existing IP
###########################################
old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
# Compare if they're the same
if [[ $ip == $old_ip ]]; then
  easylog "$(date) - DDNS Updater: IP ($ip) for ${record_name} has not changed."
  exit 0
fi


###########################################
## Set the record identifier from result
###########################################
record_identifier=$(echo "$record" | sed -E 's/.*"id":"([A-Za-z0-9_]+)".*/\1/')

###########################################
## Change the IP@Cloudflare using the API
###########################################
update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                     -H "X-Auth-Email: $auth_email" \
                     -H "$auth_header $auth_key" \
                     -H "Content-Type: application/json" \
                     --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":$ttl,\"proxied\":${proxy}}")

case "$update" in
  *"\"success\":false"*)
    easylog "$(date) - DDNS Updater Failed: (old ip: $old_ip) (new ip: $ip) for $record_name DDNS failed for $record_identifier ($ip). DUMPING RESULTS:\n$update"
    exit 0;;
  *"\"success\":true"*)
    easylog "$(date) - DDNS Updater Succed: (old ip: $old_ip) (new ip: $ip) for $record_name"
    exit 0;;
esac