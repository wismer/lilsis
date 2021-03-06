lilsis
======

A littlesis rails app. Must run in parallel to the PHP app (https://github.com/littlesis-org/littlesis).


Installation
------------

FIRST GET RVM, RUBY 2.1.2, RAILS 4.1:
- http://blog.coolaj86.com/articles/installing-ruby-on-ubuntu-12-04.html
- https://gorails.com/setup/ubuntu/14.04


Install [qt](http://www.qt.io/developers/). Install redis and run "redis-server" or change cache store or disable cache.

- git clone git@github.com:skomputer/lilsis.git
- git submodule update
- edit database.yml.sample
- edit lilsis.yml.sample
- bundle update
- rake db:migrate
- rake legacy:convert_data
- rake db:seed
- rake ts:rebuild
- whenever --update-cron lilsis
- RAILS_ENV=production bin/delayed_job start
- RAILS_ENV=production rake assets:precompile
- RAILS_ENV=production rails s
- go to http://localhost:3000

You will also need to configure your web server to direct requests to the PHP or Rails app depending on the url, along the lines of this:

    <VirtualHost *:80>
      ServerName littlesis.local
      DocumentRoot /var/www/littlesis/web

      ProxyPass /admin http://127.0.0.1:3000/admin

      ProxyPass /assets http://127.0.0.1:3000/assets
      ProxyPass /images http://127.0.0.1:3000/images
      ProxyPass /fonts http://127.0.0.1:3000/assets

      ProxyPass /users http://127.0.0.1:3000/users
      ProxyPass /notes http://127.0.0.1:3000/notes
      ProxyPass /groups http://127.0.0.1:3000/groups
      ProxyPass /campaigns http://127.0.0.1:3000/campaigns
      ProxyPass /hubs http://127.0.0.1:3000/hubs

      ProxyPass /entities http://127.0.0.1:3000/entities
      ProxyPass /rails_entities http://127.0.0.1:3000/entities
      ProxyPass /lists http://127.0.0.1:3000/lists

      ProxyPass /maps http://127.0.0.1:3000/maps

      ProxyPass /home/notes http://127.0.0.1:3000/home/notes
      ProxyPass /home/groups http://127.0.0.1:3000/home/groups
      ProxyPass /home/maps http://127.0.0.1:3000/home/maps
      ProxyPass /home/dashboard http://127.0.0.1:3000/home/dashboard
      ProxyPass /home/dismiss http://127.0.0.1:3000/home/dismiss
      ProxyPass /entities/search_by_name http://127.0.0.1:3000/entities/search_by_name
      ProxyPass /edits http://127.0.0.1:3000/edits
      ProxyPass /image_galleries http://127.0.0.1:3000/image_galleries
      ProxyPass /oligrapher http://127.0.0.1:3000/oligrapher
      ProxyPass /bootsy http://127.0.0.1:3000/bootsy
      ProxyPass /delayed_job http://127.0.0.1:3000/delayed_job

      # development only:
      ProxyPass /__better_errors http://127.0.0.1:3000/__better_errors

      <Directory /var/www/littlesis/web>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        allow from all
      </Directory>

      Alias /sf "/usr/lib/php/pear/data/symfony/web/sf/"
      <Directory "/usr/lib/php/pear/data/symfony/web/sf/">
        Options Indexes MultiViews FollowSymLinks
        AllowOverride All
        Order allow,deny
        Allow from All
      </Directory>
      
    </VirtualHost>
