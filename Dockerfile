FROM docker:stable

MAINTAINER "Shivansh Saini" "shivansh.saini@headout.com"

LABEL 'name'='ECR Image Syncer Action'
LABEL 'maintainer'='Shivansh Saini <shivansh.saini@headout.com>'

LABEL 'com.github.actions.name'='ECR Image Syncer Action'
LABEL 'com.github.actions.description'=''
LABEL 'com.github.actions.icon'='send'
LABEL 'com.github.actions.color'='green'

RUN apk add --update --no-cache build-base python3-dev python3 libffi-dev libressl-dev bash git gettext curl jq
RUN curl -O https://bootstrap.pypa.io/get-pip.py \
 && python3 get-pip.py \
 && pip install --upgrade six awscli

COPY functions.sh /functions.sh
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
