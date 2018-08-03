#!/bin/bash

# Start background job
su root -c 'export PATH=$PATH:/usr/local/bin/ruby ; RAILS_ENV=production /home/app/crucible/bin/delayed_job -n3 start'

# Start nginx
/sbin/my_init
