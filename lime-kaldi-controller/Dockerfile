FROM ruby:2.7.3

# get curl cron vim
# ruby iamge needs groff and less to install awscli 
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --force-yes  -y1 groff curl cron vim less

# get kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

# get aws-cli
WORKDIR /root
COPY awscli-exe-linux-x86_64.zip /root/awscli-exe-linux-x86_64.zip
RUN unzip /root/awscli-exe-linux-x86_64.zip && aws/install

COPY queue-control-cron /var/spool/cron/crontabs/root
RUN crontab /var/spool/cron/crontabs/root
RUN touch /var/log/queue-control.log

ADD app/ app/
WORKDIR /root/app/
RUN chmod +x /root/app/check_number_pods.sh
RUN gem install bundler
RUN bundle install

CMD /usr/sbin/cron -f && tail -f /var/log/queue-control.log
