FROM ruby:2.4

COPY Gemfile /opt/
COPY tasks.rb /opt/Rakefile

WORKDIR /opt/

RUN bundle install

ENV "COUNT=30"
ENV "QUEUE=files"

ENTRYPOINT [ "rake", "resque:workers" ]
