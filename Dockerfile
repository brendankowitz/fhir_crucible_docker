FROM phusion/passenger-ruby22
MAINTAINER FHIR

# Set correct environment variables.
RUN mkdir /home/root && chmod 755 /home/root
ENV HOME /home/root

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
 && apt-get install -y tzdata \
 && npm install bower -g

# Crucible Sourcecode
RUN cd /home/app && \
git clone https://github.com/fhir-crucible/crucible.git && \
cd crucible && \ 
gem install tzinfo-data && \
bundle install && \ 
bower install --allow-root && \
bundle update --local

# Allow http access
RUN sed -i 's/config\.force_ssl\ \=\ true/config\.force_ssl\ \=\ false/g' /home/app/crucible/config/environments/production.rb

# Generate a new secret
RUN cd /home/app/crucible && \
SECRET=$(rake secret | tail -1) && \
head -n -1 /home/app/crucible/config/secrets.yml > /home/app/crucible/config/tmp.secrets.yml ; mv /home/app/crucible/config/tmp.secrets.yml /home/app/crucible/config/secrets.yml && \
echo "  secret_key_base: $SECRET" >> /home/app/crucible/config/secrets.yml

# Change connection string to connect to Mongo container
# ** NOTE: This line should be removed to host in Azure Container instance
RUN sed -i 's/localhost\:27017/db\:27017/g' /home/app/crucible/config/mongoid.yml

# Create log files
RUN echo "" >> /home/app/crucible/log/production.log
RUN echo "" >> /home/app/crucible/log/delayed_job.log

# Set folder permissions
RUN chown -R app:app /home/app/crucible
RUN cd /home/app/crucible/log && chmod -R 755 *

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*  

# Add and set startup scripts
ADD Startup.sh /home/app/
RUN chmod a+x /home/app/Startup.sh

CMD ["/home/app/Startup.sh"]
