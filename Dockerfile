FROM ruby:2.7.0
MAINTAINER zan.loy@gmail.com

RUN gem install bundler
COPY . /app
WORKDIR /app
RUN bundle install

CMD ["bms.rb"]
