FROM jekyll/builder:4 as build
RUN mkdir -p /dist/_site
COPY . /dist
WORKDIR /dist
RUN jekyll build 

FROM nginx as dist 
COPY --from=build /dist/_site /usr/share/nginx/html