FROM ruby:2.7.4

# install aws cli
COPY awscli-exe-linux-x86_64.zip /root/awscli-exe-linux-x86_64.zip
WORKDIR /root
RUN unzip awscli-exe-linux-x86_64.zip && aws/install

COPY app/ /root/app
WORKDIR /root/app/
RUN bundle install
RUN chmod +x /root/app/download.rb

# uses the ENV vars from job to know guid!
CMD bundle exec ruby /root/app/download.rb
