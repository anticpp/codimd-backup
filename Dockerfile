FROM ruby:2.6-alpine

WORKDIR /app/

RUN apk add postgresql-client
RUN apk add zip

COPY aliyun ./aliyun
COPY loop-dump.rb ./

CMD ["ruby", "./loop-dump.rb"]
