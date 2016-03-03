# Dockproxy

Dockproxy is a nginx based proxy container meant to be placed in front of the docker registry. Both legacy (v1) and v2 versions can be attached at the same time.

This build integrates http auth via the [Auth PAM](http://web.iti.upv.es/~sto/nginx/) module available in the nginx-extras package.

### Contents
 * [Configuration and Usage](#configuration-and-Usage)
  * [TL;DR](#tl-dr)
  * [LDAP Config](#ldap-config)
  * [SSL Cert Generation](#ssl-cert-generation)
  * [Usage](#usage)
 * [Troubleshooting](#troubleshooting)
  * [Authentication Errors](#authentication-errors)
  * [Proxy Errors](#proxy-errors)
 * [Advanced Configuration and Tuning](#advanced-configuration-and-tuning)
  * [Nginx-lua](#nginx-lua)
  * [Worker and Connection Tuning](#worker-and-connection-tuning)

---



## Configuration and Usage

#### TL;DR

1. Adjust ldap conf in `nslcd/nslcd.conf`
2. Place ssl cert ( **dockproxy.key** and **dockproxy.crt** ) in `config/etc/nginx/ssl`
3. Build and take your pick of executing the following:
 * If not using a linked container:

```
docker run -d -p 443:443 \
-e REG_V1_ADDR=[registry_v1_address] \
-e REG_V1_PRT=[registry_v1_port] \
-e REG_V1_SEARCH=[enabled|disabled]
-e REG_V2_ADDR=[registry_v2_address] \
-e REG_V2_PRT=[registry_v2_port] \
-e BIND_PASSWORD=[bind_password] \
dockproxy
```

 * If using a linked container:

```
docker run -d -p 443:443 \
-e REG_V1_SEARCH=[enabled|disabled] \
--link docker-registry-v1:DOCKREG_V1 \
--link docker-registry-v2:DOCKREG_V2 \
-e BIND_PASSWORD=[bind_password] \
dockproxy
```

----------


I just need to get this out of the way:

**DO NOT USE WITHOUT CONFIGURING THE NEEDED SCRIPTS FIRST.**

Before building the image the ldap config must be modified and new ssl certs generated.


#### LDAP Config
The file `nslcd/nslcd.conf` requires several base settings to work correctly. What is included in the example configuration is the minimum requirements needed for nginx to authenticate users against Active Directory. For alternate configurations or further information please see the Arthur de Jong's [nss-pam-ldapd repo](https://github.com/arthurdejong/nss-pam-ldapd).

##### Example Configuration:

```
uid nslcd
gid nslcd

ldap_version 3
tls_reqcert never
ignorecase yes
referrals no

uri ldaps://example.com
base dc=example,dc=com
binddn cn=imauser,cn=users,dc=example,dc=com
bindpw imasecret

filter passwd (objectClass=user)
map    passwd    uid    sAMAccountName
 
filter shadow (objectClass=user)
map    shadow    uid    sAMAccountName
```



* `uri` - The LDAP uri. Most likely `uri ldaps://yourdomaincontrollerhere`
* `base` - The base DN used as the search base.
* `binddn` - the user account used to do the authentication
* `bindpw` - The password for the accout used in the `binddn` statement.
*  `filter passwd` and `filter shadow` - You can restrict access to specific groups using these statements. If you wish to allow all authenticated users, the defaults are sufficient. Otherwise, restricting it to a specific group would be something along the lines of:

```
filter passwd (&(objectClass=user)(memberOf=cn=DockerUsers,ou=Groups,dc=example,dc=com))
map    passwd    uid    sAMAccountName

filter shadow (&(objectClass=user)(memberOf=cn=DockerUsers,ou=Groups,dc=example,dc=com))
map    shadow    uid    sAMAccountName
```
* `map passwd` and `map shadow` - For Active Directory, just leave these to the default map to `sAMAccountName`


----------
#### SSL Config
The nginx config is looking for `dockproxy.key` and `dockproxy.crt`. These should be placed in the `config/etc/nginx/ssl/` folder when the container is built.

For building and testing purposes, execute the following in the dockproxy folder to generate a cert:

`openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/ssl/dockproxy.key -out nginx/ssl/dockproxy.crt`

----------
#### Usage

Usage is pretty simple. After building the container with the needed config changes. Just execute the following:

```
docker run -d -p 443:443 \
-e REG_V1_ADDR=[registry_v1_address] \
-e REG_V1_PRT=[registry_v1_port] \
-e REG_V1_SEARCH=[enabled|disabled]
-e REG_V2_ADDR=[registry_v2_address] \
-e REG_V2_PRT=[registry_v2_port] \
-e REDPILL=[enabled|disabled] \
-e BIND_PASSWORD=[bind_password] \
dockproxy
```

Where `REG_V1_ADDR` is the IP address of legacy docker registry, `REG_V2_ADDR` is the IP of the new (docker 1.6+) registry. and `REG_V1_PRT` / `REG_V2_PRT` is the port. In both cases, if htey are not set - it will default to 5000.

A better option (if running the containers on the same host), is to simply link the containers together with the link alias called `DOCKREG_V1` and `DOCKREG_V2`. The init script will parse the link information and connect to the docker registry.

```
docker run -d -p 443:443 \
-e REG_V1_SEARCH=[enabled|disabled] \
-e REDPILL=[enabled|disabled] \
-e BIND_PASSWORD=[bind_password] \
--link docker-registry-v1:DOCKREG_V1 \
--link docker-registry-v2:DOCKREG_V2 \
dockproxy
```

----------

## Troubleshooting

#### Authentication Errors
Can't get ldap auth working right? Theres a utility to help with that.

Libpam-ldap has a handy debugging mode (`nslcd -d`) for working through these sort of things. Just do the following.

1. Launch the container: `docker run -it -p 443:443 --link docker-registry:DOCKREG dockproxy /bin/bash`
2. start nginx `service nginx start`
3. launch `nslcd -d`

Then attempt to login to the proxy via a browser and watch the output from `nslcd`.


#### Proxy Errors

Did you use a DNS name instead of an IP? If you used a DNS name and it's changed IPs you're gonna have a bad time...

By default nginx does not attempt to re-resolve an address. For this it requires a resolver. Please see the [nginx docs](http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver) for more information, and adjust the config as needed.

#### Redpill
Redpill (`config/redpill.sh`) is a small bash script that monitors both Nginx and nslcd. If either should fail unexpectantly too many times in a row, supervisor will set them into a failed state. Once in a failed state, redpill will kill supervisor causing the container to terminate. This can be turned off by setting the environment variable `REDPILL` equal to `disabled`.


----------

## Advanced Configuration and Tuning

#### Nginx-lua

Dockproxy passes the environment variables to Nginx via the [Nginx Lua Module](http://wiki.nginx.org/HttpLuaModule). The Lua module is quite powerful and adds some great flexibility, and to be honest there is significantly more there than I want to cover --so I'll just include a bit on what is used in dockproxy: Passing Environment variables.

If there are other environment variables that you wish to pass, the main thing to remember is that they must first be declared in `nginx/nginx.conf` in the form of `ENV [environment variable name];` e.g.:

```
ENV REG_ADDR;
ENV REG_PRT;
```

You can then later set a variable equal to their value via the `set_by_lua` directive. Please note that `set_by_lua` can **ONLY** be used in the `server`, `server if`, `location`, or `location if` context. These can then be used later in the form of `$variable_name`.

Here is an example:

```
server {
    set_by_lua $reg_addr 'return os.getenv("REG_ADDR")';
    set_by_lua $reg_prt 'return os.getenv("REG_PRT")';

    listen 80 default_server;

    location / {
    proxy_pass http://$reg_addr:$reg_prt;
    }
 }
```

----------
#### Worker and Connection Tuning

To be honest, I haven't taken the time to sit down with wireshark and watch how many connection a docker image pull can initiate, but in general you want to have 1 `worker_process` per core. Normally, it's about 2 worker connections per user at point in time. Adjust as needed for your environment. If anyone has any better info, please pass it along.



