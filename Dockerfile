FROM alpine:latest
MAINTAINER zan.loy@gmail.com

# Per https://bundler.io/guides/bundler_docker_guide.html
ENV GEM_HOME /usr/local/bundle
ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH
ENV BUNDLE_SILENCE_ROOT_WARNING true

# Setup VA certs
COPY ./certs/* /usr/local/share/ca-certificates/
RUN apk add --update ca-certificates && \
    rm -rf /var/cache/apk/* && \
    update-ca-certificates
    
# Copy app files in and install gems
COPY . /app
WORKDIR /app

# Install deps
RUN apk add --update ruby ruby-dev zlib-dev build-base && \
    gem install bundler foreman io-console --no-document && \
    bundle install && \
    apk del --purge ruby-dev zlib-dev build-base && \
    rm -rf /var/cache/apk/*

EXPOSE 5000

CMD ["foreman", "start"]
