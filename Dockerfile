FROM ruby:3.0

WORKDIR /app/

RUN apt-get update
RUN apt-get install postgresql-client -y
RUN apt-get install zip

COPY ./loop-dump.rb ./

CMD ["ruby", "./loop-dump.rb"]
