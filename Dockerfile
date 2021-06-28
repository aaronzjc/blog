FROM jekyll/builder:3.8 as build
RUN jekyll build 

FROM nginx as dist 
COPY --from=build ./_site /usr/share/nginx/html