FROM ruby:2.6.5-alpine
LABEL maintainer="zan.loy@gmail.com"

# Configure container to use EST
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/America/New_York /etc/localtime && \
    echo "America/New_York" > /etc/timezone && \
    apk del --purge tzdata
LABEL tz="America/New_York"

# Install deps
RUN apk add --no-cache build-base libstdc++ ruby-dev zlib-dev

# Setup VA certs
COPY ./certs/* /usr/local/share/ca-certificates/
RUN update-ca-certificates
LABEL va-certs="installed"

ENV APP_ENV production
ENV RACK_ENV production
# Per https://bundler.io/guides/bundler_docker_guide.html
ENV GEM_HOME /usr/local/bundle
ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH

WORKDIR /app

COPY Gemfile Gemfile.lock /app/

# Install application
RUN gem install bundler foreman && \
    bundle config set without 'development test' && \
    bundle install && \
    apk del --purge build-base ruby-dev zlib-dev

# Copy app files in
COPY . /app
EXPOSE 9292

#CMD ["foreman", "start"]
CMD ["rackup"]
