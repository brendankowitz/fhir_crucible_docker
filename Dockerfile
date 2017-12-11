FROM phusion/passenger-ruby22
MAINTAINER FHIR

# Set correct environment variables.
RUN mkdir /home/root && chmod 755 /home/root
ENV HOME /home/root

# Use baseimage-docker's init system.
# CMD ["/sbin/my_init"]

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
 && apt-get install tzdata -y \
 && npm install bower -g

# Crucible Sourcecode
RUN cd /home/app && \
git clone https://github.com/fhir-crucible/crucible.git && \
cd crucible && \ 
gem install tzinfo-data && \
bundle install && \ 
bower install --allow-root && \
bundle update --local

RUN sed -i 's/config\.force_ssl\ \=\ true/config\.force_ssl\ \=\ false/g' /home/app/crucible/config/environments/production.rb

RUN sed -i 's/secret_key_base\:\ \<\%\=\ ENV\[\"SECRET\_KEY\_BASE\"\]\ \%\>/secret_key_base\:\ 474aab81ebc3a7f32ac02b97ffc2d149c1133ca5c5bb291dcdf35c7fcacd6822f916df7459c8d331279341760d42b23375d66245ababc464d12cf6bae0347c52/g' /home/app/crucible/config/secrets.yml

RUN sed -i 's/localhost\:27017/db\:27017/g' /home/app/crucible/config/mongoid.yml

RUN echo "" >> /home/app/crucible/log/production.log
RUN echo "" >> /home/app/crucible/log/delayed_job.log

# RUN cd /home/app/crucible/ && chmod -R 777 *
RUN cd /home/app/crucible/ && chmod -R 755 *

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*  

ADD Startup.sh /home/app/
RUN chmod a+x /home/app/Startup.sh

CMD ["/home/app/Startup.sh"]
