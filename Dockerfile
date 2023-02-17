FROM jekyll/jekyll:4.3.0 as build
RUN mkdir -p /dist/_site
COPY . /dist
WORKDIR /dist
RUN chown -R jekyll:jekyll /dist
RUN jekyll build 

FROM nginx as dist 
COPY --from=build /dist/_site /usr/share/nginx/html