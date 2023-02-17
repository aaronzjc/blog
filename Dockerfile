FROM jekyll/jekyll:4 as build
RUN mkdir -p /dist/_site
COPY . /dist
WORKDIR /dist
RUN chown -R jekyll:jekyll /dist
RUN bundle install && bundle exec jekyll build

FROM nginx as dist 
COPY --from=build /dist/_site /usr/share/nginx/html