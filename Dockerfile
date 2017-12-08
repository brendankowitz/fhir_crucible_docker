FROM       ubuntu:14.04
MAINTAINER FHIR

#Install Ruby / Rails
ENV RUBY_MAJOR="2.2" \ RUBY_VERSION="2.2.5" \ DB_PACKAGES="libsqlite3-dev" \ RUBY_PACKAGES="ruby2.2 ruby2.2-dev"

RUN apt-get update \
&& DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \ 
build-essential \ 
curl \ 
libffi-dev \ 
libgdbm-dev \ 
libncurses-dev \ 
libreadline6-dev \ 
libssl-dev \ 
libyaml-dev \ 
zlib1g-dev \ 
&& rm -rf /var/lib/apt/lists/*

RUN echo 'gem: --no-document' >> /.gemrc

RUN mkdir -p /tmp/ruby \ 
&& curl -L "http://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.5.tar.bz2" \ 
	| tar -xjC /tmp/ruby --strip-components=1 \ 
&& cd /tmp/ruby \ 
&& ./configure --disable-install-doc \ 
&& make \ 
&& make install \ 
&& gem update --system \ 
&& rm -r /tmp/ruby

# RUN gem install --no-document bundler

# see update.sh for why all "apt-get install"s have to stay as one long line RUN apt-get update && curl --silent --location https://deb.nodesource.com/setup_0.12 | bash - && apt-get install -y nodejs --no-install-recommends && rm -rf /var/lib/apt/lists/* 

# see http://guides.rubyonrails.org/command_line.html#rails-dbconsole RUN apt-get update && apt-get install -y mysql-client postgresql-client libsqlite3-dev --no-install-recommends && rm -rf /var/lib/apt/lists/* 

ENV RAILS_VERSION 4.2.3 
RUN gem install rails --version "$RAILS_VERSION"

# Install Bower

RUN apt-get update \ 
 && apt-get install -y nodejs \ 
 && apt-get install -y npm \ 
 && npm install bower -g \ 
 && ln -s /usr/bin/nodejs /usr/bin/node

# Installation steps based on http://docs.mongodb.org/manual/tutorial/install-mongodb-on-ubuntu/

# Install MongoDB.
RUN \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
  echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' > /etc/apt/sources.list.d/mongodb.list && \
  apt-get update && \
  apt-get install -y mongodb-org && \
  rm -rf /var/lib/apt/lists/*

# Define working directory.
# Define mountable directories.
VOLUME ["/data/db"]
WORKDIR /data

# Install Apache
RUN apt-get update && apt-get install -y apache2 && \ 
gem install passenger

RUN apt-get install -y libcurl4-openssl-dev apache2-prefork-dev libapr1-dev libaprutil1-dev

RUN yes | passenger-install-apache2-module

# Install git
RUN apt-get update && apt-get install -y git

# Crucible Sourcecode
RUN cd /data && \
git clone https://github.com/fhir-crucible/crucible.git && \
cd crucible && \ 
bundle install && \ 
bower install --allow-root

VOLUME ["/data/crucible/public"]

RUN sed -i 's/config\.force_ssl\ \=\ true/config\.force_ssl\ \=\ false/g' /data/crucible/config/environments/production.rb && \
tail -100 /data/crucible/config/environments/production.rb

RUN mongod --fork --syslog && \
cd /data/crucible && bundle exec rake assets:precompile RAILS_ENV=production

RUN echo "LoadModule passenger_module /usr/local/lib/ruby/gems/2.2.0/gems/passenger-5.1.12/buildout/apache2/mod_passenger.so" > /etc/apache2/conf-available/passenger.conf && \
echo "<IfModule mod_passenger.c>" >> /etc/apache2/conf-available/passenger.conf && \
echo "PassengerRoot /usr/local/lib/ruby/gems/2.2.0/gems/passenger-5.1.12" >> /etc/apache2/conf-available/passenger.conf && \
echo "PassengerDefaultRuby /usr/local/bin/ruby" >> /etc/apache2/conf-available/passenger.conf && \
echo "</IfModule>" >> /etc/apache2/conf-available/passenger.conf

RUN echo "<VirtualHost *:80>" > /etc/apache2/sites-available/crucible.conf && \
echo "DocumentRoot /data/crucible/public" >> /etc/apache2/sites-available/crucible.conf && \
echo "<Directory /data/crucible/public>" >> /etc/apache2/sites-available/crucible.conf && \
echo "          Require all granted" >> /etc/apache2/sites-available/crucible.conf && \
echo "          AllowOverride all" >> /etc/apache2/sites-available/crucible.conf && \
echo "          Options -MultiViews" >> /etc/apache2/sites-available/crucible.conf && \
echo "          AddOutputFilterByType DEFLATE text/css application/x-javascript application/javascript text/javascript" >> /etc/apache2/sites-available/crucible.conf && \
echo "       </Directory>" >> /etc/apache2/sites-available/crucible.conf && \
echo " </VirtualHost>" >> /etc/apache2/sites-available/crucible.conf && \
rm /etc/apache2/sites-enabled/000-default.conf && \
ln -s /etc/apache2/sites-available/crucible.conf /etc/apache2/sites-enabled/crucible.conf && \
service apache2 restart

RUN echo "#!/bin/bash" > /etc/init.d/delayed-job && \
echo "#" >> /etc/init.d/delayed-job && \
echo "# delayed job" >> /etc/init.d/delayed-job && \
echo "#" >> /etc/init.d/delayed-job && \
echo "# chkconfig: - 99 15" >> /etc/init.d/delayed-job && \
echo "# description: start, stop, restart God (bet you feel powerful)" >> /etc/init.d/delayed-job && \
echo "#" >> /etc/init.d/delayed-job && \
echo "" >> /etc/init.d/delayed-job && \
echo "RETVAL=0" >> /etc/init.d/delayed-job && \
echo "" >> /etc/init.d/delayed-job && \
echo 'case "$1" in' >> /etc/init.d/delayed-job && \
echo "    start)" >> /etc/init.d/delayed-job && \
echo "      cd /data/crucible" >> /etc/init.d/delayed-job && \
echo "      su root -c 'service apache2 start'" >> /etc/init.d/delayed-job && \
echo "      su root -c 'mongod --fork --syslog'" >> /etc/init.d/delayed-job && \
echo "      su root -c 'export PATH=$PATH:/usr/local/bin/ruby ; RAILS_ENV=production bin/delayed_job -n3 start'" >> /etc/init.d/delayed-job && \
echo "      RETVAL=$?" >> /etc/init.d/delayed-job && \
echo "      ;;" >> /etc/init.d/delayed-job && \
echo "    stop)" >> /etc/init.d/delayed-job && \
echo "      cd /data/crucible" >> /etc/init.d/delayed-job && \
echo "      su root -c 'mongod --stop'" >> /etc/init.d/delayed-job && \
echo "      su root -c 'export PATH=$PATH:/usr/local/bin/ruby ; RAILS_ENV=production bin/delayed_job stop'" >> /etc/init.d/delayed-job && \
echo "      RETVAL=$?" >> /etc/init.d/delayed-job && \
echo "      ;;" >> /etc/init.d/delayed-job && \
echo "    restart)" >> /etc/init.d/delayed-job && \
echo "      cd /data/crucible" >> /etc/init.d/delayed-job && \
echo "      su root -c 'mongod --stop'" >> /etc/init.d/delayed-job && \
echo "      su root -c 'mongod --fork --syslog'" >> /etc/init.d/delayed-job && \
echo "      su root -c 'export PATH=$PATH:/usr/local/bin/ruby ; RAILS_ENV=production bin/delayed_job restart'" >> /etc/init.d/delayed-job && \
echo "      RETVAL=$?" >> /etc/init.d/delayed-job && \
echo "      ;;" >> /etc/init.d/delayed-job && \
echo "    status)" >> /etc/init.d/delayed-job && \
echo "      cd /data/crucible" >> /etc/init.d/delayed-job && \
echo "      su root -c 'export PATH=$PATH:/usr/local/bin/ruby ; RAILS_ENV=production bin/delayed_job status'" >> /etc/init.d/delayed-job && \
echo "      RETVAL=$?" >> /etc/init.d/delayed-job && \
echo "      ;;" >> /etc/init.d/delayed-job && \
echo "    *)" >> /etc/init.d/delayed-job && \
echo "      echo 'Usage: delayed-job {start|stop|restart|status}'" >> /etc/init.d/delayed-job && \
echo "      exit 1" >> /etc/init.d/delayed-job && \
echo "  ;;" >> /etc/init.d/delayed-job && \
echo "esac" >> /etc/init.d/delayed-job && \
echo "exit $RETVAL" >> /etc/init.d/delayed-job

RUN chmod a+x /etc/init.d/delayed-job && update-rc.d delayed-job defaults

# Define default command.

CMD ["/etc/init.d/delayed-job", "start"]

# Expose ports.
#   - 27017: process
#   - 28017: http
EXPOSE 27017
EXPOSE 28017
EXPOSE 80
