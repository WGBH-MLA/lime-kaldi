FROM ruby:2.7.4

COPY app/ /root/app
RUN bundle install
RUN chmod +x /root/app/download.rb

# uses the ENV vars from job to know guid!
CMD /root/app/download.rb
