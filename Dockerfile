FROM jekyll/builder:3.8 as build
RUN mkdir /dist
ADD . /dist
WORKDIR /dist
RUN jekyll build 

FROM nginx as dist 
COPY --from=build /dist/_site /usr/share/nginx/html