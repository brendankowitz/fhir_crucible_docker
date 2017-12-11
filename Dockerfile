FROM phusion/passenger-ruby22
MAINTAINER FHIR

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Start Nginx / Passenger
RUN rm -f /etc/service/nginx/down

# Remove the default site
RUN rm /etc/nginx/sites-enabled/default

# Add the nginx info
ADD nginx.conf /etc/nginx/sites-enabled/crucible.conf

# Install Bower
RUN apt-get update \ 
 && apt-get install -y nodejs \ 
 && apt-get install -y npm \ 
 && apt-get install -y git \ 
 && npm install bower -g \ 
 && ln -s /usr/bin/nodejs /usr/bin/node

# Prepare folders
RUN mkdir /home/app

# Crucible Sourcecode
RUN cd /home/app && \
git clone https://github.com/fhir-crucible/crucible.git && \
cd crucible && \ 
bundle install && \ 
bower install --allow-root

RUN sed -i 's/config\.force_ssl\ \=\ true/config\.force_ssl\ \=\ false/g' /data/crucible/config/environments/production.rb && \

RUN sed -i 's/secret_key_base\:\ \<\%\=\ ENV\[\"SECRET\_KEY\_BASE\"\]\ \%\>/secret_key_base\:\ 474aab81ebc3a7f32ac02b97ffc2d149c1133ca5c5bb291dcdf35c7fcacd6822f916df7459c8d331279341760d42b23375d66245ababc464d12cf6bae0347c52/g' /data/crucible/config/secrets.yml

RUN mongod --fork --syslog && \
cd /data/crucible && bundle exec rake assets:precompile RAILS_ENV=production

# Install MongoDB.
RUN \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
  echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' > /etc/apt/sources.list.d/mongodb.list && \
  apt-get update && \
  apt-get install -y mongodb-org

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*  
