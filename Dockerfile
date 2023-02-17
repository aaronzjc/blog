FROM ruby:alpine3.16 as build
RUN mkdir -p /dist/_site
COPY . /dist
WORKDIR /dist
RUN apk add git && bundle install && bundle exec jekyll build
RUN chown -R jekyll:jekyll /dist
RUN jekyll build 

FROM nginx as dist 
COPY --from=build /dist/_site /usr/share/nginx/html