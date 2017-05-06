FROM ruby:2.4

WORKDIR /opt/

COPY Gemfile /opt/
RUN bundle install

ENV "COUNT=10"
ENV "QUEUE=files"

COPY tasks.rb /opt/Rakefile

ENTRYPOINT [ "rake", "resque:workers" ]
