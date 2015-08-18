FROM phusion/baseimage:latest
MAINTAINER Christian Duhard <christian.duhard@j2.com>

ENV INFLUXDB_VERSION 0.9.2.1
ENV PRE_CREATE_DB data
ENV INFLUXDB_DATA_USER data
ENV INFLUXDB_DATA_PW data

RUN apt-get -y update\
 && apt-get -y upgrade

# dependencies
RUN apt-get -y --force-yes install vim\
 nginx\
 python-dev\
 python-flup\
 python-pip\
 expect\
 git\
 memcached\
 sqlite3\
 libcairo2\
 libcairo2-dev\
 python-cairo\
 pkg-config\
 nodejs

# python dependencies
RUN pip install django==1.3\
 python-memcached==1.53\
 django-tagging==0.3.1\
 twisted==11.1.0\
 txAMQP==0.6.2

#install InfluxDB
RUN curl -s -o /tmp/influxdb_latest_amd64.deb https://s3.amazonaws.com/influxdb/influxdb_${INFLUXDB_VERSION}_amd64.deb && \
  dpkg -i /tmp/influxdb_latest_amd64.deb && \
  rm /tmp/influxdb_latest_amd64.deb && \
  rm -rf /var/lib/apt/lists/*
ADD conf/influxdb/config.toml /etc/influxdb/config.toml
ADD scripts/setup_influxdb.sh /tmp/setup_influxdb.sh
RUN /tmp/setup_influxdb.sh

ENV PRE_CREATE_DB **None**
ENV SSL_SUPPORT **False**
ENV SSL_CERT **None**

EXPOSE 8083 8086

# install graphite
RUN git clone -b 0.9.12 https://github.com/graphite-project/graphite-web.git /usr/local/src/graphite-web
WORKDIR /usr/local/src/graphite-web
RUN python ./setup.py install
ADD scripts/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD conf/graphite/ /opt/graphite/conf/

# install whisper
RUN git clone -b 0.9.12 https://github.com/graphite-project/whisper.git /usr/local/src/whisper
WORKDIR /usr/local/src/whisper
RUN python ./setup.py install

# install carbon
RUN git clone -b 0.9.12 https://github.com/graphite-project/carbon.git /usr/local/src/carbon
WORKDIR /usr/local/src/carbon
RUN python ./setup.py install

# install statsd
RUN git clone -b v0.7.2 https://github.com/etsy/statsd.git /opt/statsd
ADD conf/statsd/config.js /opt/statsd/config.js

# config nginx
RUN rm /etc/nginx/sites-enabled/default
ADD conf/nginx/nginx.conf /etc/nginx/nginx.conf
ADD conf/nginx/graphite.conf /etc/nginx/sites-available/graphite.conf
RUN ln -s /etc/nginx/sites-available/graphite.conf /etc/nginx/sites-enabled/graphite.conf

# init django admin
ADD scripts/django_admin_init.exp /usr/local/bin/django_admin_init.exp
RUN /usr/local/bin/django_admin_init.exp

# logging support
RUN mkdir -p /var/log/carbon /var/log/graphite /var/log/nginx
ADD conf/logrotate /etc/logrotate.d/graphite
RUN chmod 644 /etc/logrotate.d/graphite

# daemons
ADD daemons/carbon.sh /etc/service/carbon/run
ADD daemons/carbon-aggregator.sh /etc/service/carbon-aggregator/run
ADD daemons/graphite.sh /etc/service/graphite/run
ADD daemons/statsd.sh /etc/service/statsd/run
ADD daemons/nginx.sh /etc/service/nginx/run
ADD daemons/influxdb.sh /etc/service/influxdb/run

# cleanup
RUN apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# defaults
EXPOSE 80:80 2003:2003 8125:8125/udp

# Create volumes
VOLUME /opt/graphite
VOLUME /opt/graphite/storage
VOLUME /etc/nginx
VOLUME /opt/statsd
VOLUME /etc/logrotate.d
VOLUME /var/log
VOLUME /data

ENV HOME /root
CMD ["/sbin/my_init"]
