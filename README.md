# ec2metadata-proxycache

[![Build and Publish](https://github.com/lifeofguenter/ec2metadata-proxycache/workflows/build%20and%20publish/badge.svg?branch=master)](https://github.com/lifeofguenter/ec2metadata-proxycache/actions?query=branch%3Amaster+workflow%3A%22build+and+publish%22)
[![Docker Pulls](https://img.shields.io/docker/pulls/lifeofguenter/ec2metadata-proxycache?style=flat)](https://hub.docker.com/r/lifeofguenter/ec2metadata-proxycache)

A dead simple nginx based proxy cache for [aws ec2 instance metadata service](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html).

Unfortunately IMDS is a [rate limited service](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html#instancedata-throttling), which fortunately is relatively
safe to cache.

## Usage

Run on the host:

```bash
$ sudo useradd -u 65321 -m -d /var/lib/proxy_user -s /sbin/nologin proxy_user
$ docker pull --quiet lifeofguenter/ec2metadata-proxycache:latest
$ docker run \
  -d \
  -m 128m \
  -u 65321 \
  -p "127.0.0.1:12345:8080" \
  --restart always \
  --name ec2metadata-proxycache \
  lifeofguenter/ec2metadata-proxycache:latest
```

Optionally if you are running dockerd on that host, add the following arg:

```bash
-p "$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+'):12345:8080"
```

On the host itself, run the following to forward all IMDS requests to the proxy:

```bash
iptables -t nat -A OUTPUT -m owner ! --uid-owner proxy_user -d 169.254.169.254 -p tcp -m tcp --dport 80 -j DNAT --to-destination 127.0.0.1:12345
```

Inside containers, run the following to forward all IMDS requests to the proxy:

```bash
iptables -t nat -A OUTPUT -d 169.254.169.254 -p tcp -m tcp --dport 80 -j DNAT --to-destination "$(ip route | awk '/default/ { print $3 }'):12345"
```
