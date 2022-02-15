FROM ruby:3.0-alpine

WORKDIR /app/

RUN apk add postgresql-client
RUN apk add zip

COPY ./loop-dump.rb ./

CMD ["ruby", "./loop-dump.rb"]
