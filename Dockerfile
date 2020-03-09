FROM ruby:2.7.0
MAINTAINER zan.loy@gmail.com

EXPOSE 5000

RUN gem install bundler foreman
COPY . /app
WORKDIR /app
RUN bundle install

CMD ["foreman", "start"]
