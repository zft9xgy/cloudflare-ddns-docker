## Automated Cloudflare DNS Updater with Docker and Cronjob

Automatic container that updates the public IP in CloudFlare every 5 minutes using the CloudFlare API.

This is useful if you have a homelab you want to point to or you have a web server on your homelab but your ISP doesn't offer a dedicated IP or you don't want to pay for it. With cloudflare and this Docker container you can forget about changing your public IP manually, as it will always be up to date in the DNS.

Part of the original script is from [cloudflare-ddns-updater](https://github.com/K0p1-Git/cloudflare-ddns-updater). I just simplified things a bit and added the Docker deployment.

## Installation and usage

- This version only works with IP4, for use with IP6 check the repository above, which has the script in IP6.
- This version assumes that the registry is 'A'.

Installation

```sh
git clone https://github.com/zft9xgy/cloudflare-ddns-docker.git
cd cloudflare-ddns-docker
```

In the cloudflare-ddns.sh file you will have to modify the header data. You will get it from cloudflare.

In [this video from NetworkChuck](https://www.youtube.com/watch?v=rI-XxnyWFnM) you can see how to configure the script:

```sh
auth_email="cloudflare@email.com"   # The email used to login 'https://dash.cloudflare.com'
auth_method="global"                # "global" for Global API Key or "token" for Scoped API Token
auth_key="*******"                  # Your API Token or Global API Key
zone_identifier="*****"             # Can be found in the "Overview" tab of your domain
record_name="subdomain.domain.com"  # Which record you want to be synced
ttl=3600                            # Set the DNS TTL (seconds)
proxy="true"                        # Can be "true" or "false
```

Now set the frequency with which the script will run, for that in the Dockerfile modify this line. If you don't want to think too much, this script runs every 5 minutes, if you want to change it just change the 5 for the frequency in minutes. The minimum that cronjob allows is 1 minute.

I'm not sure about CloudFlare's API policy but I'm sure between 1-5 minutes will be no problem and it's more than enough so you won't have a big disruption in your web or service.

```Dockerfile
RUN echo "*/5 * * * * /usr/local/bin/cloudflare-ddns.sh" > /etc/crontabs/root
```

Where:

```sh
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of the month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday 7 is also Sunday on some systems)
# │ │ │ │ │ ┌───────────── command to issue
# │ │ │ │ │ │
# │ │ │ │ │ │
# * * * * * {Location of the script}
```

### Final step

```sh
sh buildandrun.sh
```

Or manully:

```sh
docker build -t name-of-your-image .
docker run -d --name name-of-the-container name-of-your-image
```

## How the cloudflare-ddns script works

- The current IP address of the machine is checked, i.e. your public IP address with the Cloudflare service, if it fails if you use ipify or icanhazip.
- In case these three services fail, the machine probably has a connection problem and the operation is stopped.
- A query is made to the cloudflare DNS records to check the IP of the record.
- If the cloudflare DNS IP is the same as the current IP, it does nothing and exits the run.
- If the cloudflare DNS IP and the current IP of the machine are different, it updates it and reports the result in LOG_FILE.

## Deployment with Docker

- Use a simple Docker image with curl installed.
- Copy the script and give it permission to run.
- Create a cronjob with a frequency of 5 minutes.
- Create the file where the logs will be saved inside the skip and run the crond in the foreground.

## Usefull commands

After everything is running, you can access the logs in real time like this:

```sh
# To see that the container is running.
docker ps

# To check the logs in the container running
docker logs -f cron-cloudflare-ddns

# To view the log file
docker exec -it cron-cloudflare-ddns sh
cd /var/log/
cat cloudflare-ddns.log

# To stop the container
docker stop cron-cloudflare-ddns

# To start the container
docker start cron-cloudflare-ddns

```
