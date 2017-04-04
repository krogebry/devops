FROM ruby:2.4

COPY Gemfile /opt/
COPY tasks.rb /opt/Rakefile

WORKDIR /opt/

RUN bundle install

ENV "COUNT=10"
ENV "QUEUE=files"

ENTRYPOINT [ "rake", "resque:workers" ]
