#!/bin/bash

# Precompile app
cd /home/app/crucible
RAILS_ENV=production rake assets:precompile

# Start background job
su root -c 'export PATH=$PATH:/usr/local/bin/ruby ; RAILS_ENV=production /home/app/crucible/bin/delayed_job -n3 start'

# Start nginx
/sbin/my_init
