#!/bin/bash

DB_USER=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/dbUser)
DB_PASS=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/dbPass)
DB_HOST=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/dbHost)
DB_NAME=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/dbName)


cd /tmp/ || exit
touch .env
echo DB_HOST=$DB_HOST >> .env
echo DB_NAME=$DB_NAME >> .env
echo DB_USER=$DB_USER >> .env
echo DB_PASSWORD=$DB_PASS >> .env
echo PORT=3000 >> .env
echo DB_DIALECT=postgres >> .env
echo MAILGUN_DOMAIN=verifyemail.cloudwebappserver.com >> .env
echo MAILGUN_API_KEY=4b552d5c1cd188486cde6483ae5b49aa-f68a26c9-47f153c2 >> .env

sudo cp /tmp/.env /opt/csye6225/webapp/


sudo systemctl daemon-reload
sudo systemctl restart google-cloud-ops-agent
sudo systemctl enable csye
sudo systemctl start csye
sudo systemctl status csye
