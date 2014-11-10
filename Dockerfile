# mrbobbytables/dockproxy
#
# VERSION   1.0.0
#
# CREATED ON Mon Nov 10 17:08:46 UTC 2014
#

FROM ubuntu:14.04

RUN apt-get update


#DEBIAN_FRONTEND=noniteractive is used to suppress prompts for libpam-ldapd
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get install -y nginx-extras \
    libpam-ldapd \
    supervisor

#Copy configs to their needed locations
COPY init.sh ./init.sh
COPY ./nslcd/nslcd.conf /etc/nslcd.conf
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx/dockproxy /etc/nginx/sites-available/dockproxy
COPY ./nginx/ssl/ /etc/nginx/ssl/
COPY ./supervisor/dockproxy.conf /etc/supervisord/conf.d/dockproxy.conf

# nslcd will complain about nslcd.conf being world-readable if permissions are not restricted.
# /etc/pam.d/nginx contains the ldap auth config for nginx
RUN chmod 640 /etc/nslcd.conf && \
    chmod +x init.sh && \
    echo 'auth\trequired\tpam_ldap.so\naccount\trequired\tpam_ldap.so' >> /etc/pam.d/nginx && \
    rm /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/dockproxy /etc/nginx/sites-enabled/dockproxy


EXPOSE 443

CMD ["./init.sh"]
