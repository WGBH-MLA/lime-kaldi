FROM ruby:2.7

# get curl cron vim
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --force-yes  -y1 curl cron vim

# get kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

# get aws-cli
COPY awscli-exe-linux-x86_64.zip /root/awscli-exe-linux-x86_64.zip
RUN unzip /root/awscli-exe-linux-x86_64.zip && /root/aws/install

WORKDIR /root
COPY queue-control-cron /var/spool/cron/crontabs/root
RUN touch /var/log/queue-control.log

ADD app/ app/
WORKDIR /root/app/
RUN chmod +x /root/app/check_number_pods.sh
RUN gem install bundler
RUN bundle install

# bundler recommends using these if you havin trubb
# ENV GEM_HOME="/usr/local/bundle"
# ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH
CMD service cron start && tail -f /var/log/queue-control.log
