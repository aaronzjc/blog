---
layout: post
title: "Go Web从开发到部署"
date:   2019-09-16 22:00:00 +0800
categories: golang web
---
自己最近在写一个Golang的web项目。从写下第一行代码，到最终整个小网站能够运行呈现出来，幕后的事情也是挺多的。实践下来，整套开发流程非常流畅舒服，遂总结一下，供感兴趣的人了解。

项目使用到的技术栈和开发工具如下

* 开发：Goland，Go，Vue
* 版本：Git
* 编译构建：make，Docker
* 持续集成：Drone
* 反向代理：nginx

## 项目介绍

地址: [https://github.com/aaronzjc/mu](https://github.com/aaronzjc/mu)

`MU`是一个非常简单的热榜聚合网站。会定时去获取自己经常访问的几个站点的指定内容，然后存储至Redis中，供集中展示。整个项目的架构如图

![图片]({{ site.url }}/assert/imgs/goweb_0.png)

应用分为两部分。一个是命令行部分，定时获取内容；一个是http服务，提供前端展示。因此，最终会部署两个应用。

## 开发

本地开发使用的IDE是Goland。也可以使用VSCode 搭配Go插件开发，但是，VSC的Go插件支持的不太好。

项目使用GOMOD做包管理。目前没有使用web开发框架，主要是因为逻辑非常简单，原生的http包够用了。

Github仓库有dev和master两个分支。因为项目ci/cd是基于master分支，如果在master分支开发，会频繁触发部署，没有必要，也不建议这么干。所以一般在dev分支进行开发，等功能开发完成以后，再merge到master分支，触发打包构建部署等过程。

## 构建

从其他的Go项目学到的，使用make进行构建。理论上也可以把构建流程放到ci文件。但是这样就会导致ci文件比较复杂，日后如果换个ci工具，可能还需要再写一套。

makefile内容很简单，构建两个可执行文件，放到项目bin目录。

```text
GO111MODULE=on
.PHONY: crawler
crawler:
   CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/crawler ./cron/main.go
.PHONY: mu
mu:
   CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/mu ./server/main.go
.PHONY: clean
clean:
   -rm ./bin/*
```

值得注意的细节是，这里要开启`CGO_ENABLED=0`，即静态编译。因为，最终应用是打包成镜像执行。为了维持镜像大小，使用的是alpine基础容器。这个容器里面没有标准Go运行环境，如果不使用静态编译，会执行失败，报`exec user … not found`的错误。

CI/CD工具使用的是自建的Drone。之前写过好几篇关于Drone的文章了，也算比较熟悉。也可以使用其他自己比较熟悉的工具。

```yaml
kind: pipeline
name: default

steps:
  - name: build crawler&mu
    image: golang:1.13-stretch
    commands:
      - make crawler
      - make mu

  - name: release crawler
    image: plugins/docker
    settings:
      repo: uhub.service.ucloud.cn/memosa/crawler
      target: crawler
      tags: latest
      username:
        from_secret: docker_user
      password:
        from_secret: docker_password
      registry: uhub.service.ucloud.cn

  - name: release mu
    image: plugins/docker
    settings:
      repo: uhub.service.ucloud.cn/memosa/mu
      target: mu
      tags: latest
      username:
        from_secret: docker_user
      password:
        from_secret: docker_password
      registry: uhub.service.ucloud.cn

  - name: deploy
    image: appleboy/drone-ssh
    settings:
      host: 152.32.170.64
      username: jincheng
      password:
        from_secret: host_password
      port: 22
      script:
        - sudo docker service update --with-registry-auth --force --image image_name:latest mu_crawler
        - sudo docker service update --with-registry-auth --force --image image_name:latest  mu_mu

trigger:
  branch:
    - master
```

CI/CD一共分4个步骤。构建，执行make生成两个可执行文件。注意，这里需要使用带make工具的景象；打包镜像，因为两个Dockerfile非常相似，这里使用Docker的分阶段构建，构建两个镜像；部署，直接使用插件，ssh到服务器执行目录，启动服务。

关于Drone怎么使用，可以参考之前的文章，也可以上官方阅读文档了解。实际构建效果图

![图片]({{ site.url }}/assert/imgs/goweb_1.png)

### 部署

上面介绍完Drone自动化构建部署。最后，介绍下具体是怎么部署运行的。之前提到过，应用最终是通过Docker运行的。所以，首先需要打包一个Docker镜像。

```dockerfile
FROM alpine:3.7 as crawler
ENV APP_ENV production
RUN apk add --no-cache ca-certificates tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN mkdir /app
COPY ./bin/crawler /app/
WORKDIR /app
CMD ["./crawler"]

FROM alpine:3.7 as mu
ENV APP_ENV production
RUN apk add --no-cache ca-certificates tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN mkdir -p /app/public
COPY ./bin/mu /app/
COPY ./public /app/public
WORKDIR /app
EXPOSE 7980
CMD ["./mu"]
```

打包镜像很简单，将前面编译出来的可执行文件，放到指定目录，然后执行。启动容器方式也很简单

```shell
docker run -d -v /path/to/app.json:/app/app.json image_name:tag app_crawler
docker run -d -p 7980:7980 -v /path/to/app.json:/app/app.json image_name:tag app_mu
```

用这种方式去部署没问题，也可以使用其他方式，例如k8s等。我这里图简单，是使用Swarm+DockerStack的方式来部署的。

关于swarm如何部署，可以阅读文档直接在命令行下部署。我使用的是一个开源管理软件`Portainer`。首先在Portainer上建好`app.json`
配置文件，然后建立这么一个stack部署文件，再发布就好了

```yaml
version: '3.7'
services:
  crawler:
    image: uhub.service.ucloud.cn/memosa/crawler:latest
    deploy:
      replicas: 1
    configs:
      - source: app_mu_config
        target: /app/app.json
  mu:
    image: uhub.service.ucloud.cn/memosa/mu:latest
    deploy:
      replicas: 1
    ports:
      - 7980:7980
    configs:
      - source: app_mu_config
        target: /app/app.json
configs:
  app_mu_config:
    external: true
```

容器启动以后，还需要部署一个nginx在前面做反向代理，将域名请求代理到服务上。这里我并没有在后端服务上去支持https，而是在nginx这一层做的https处理。

如果整个过程没问题的话，服务就可以访问了。然后，后面更新代码，会走CI去自动拉镜像更新服务。这样，就完成整个自动化部署过程了。来一个运行状态效果图

![图片]({{ site.url }}/assert/imgs/goweb_2.png)

体验非常好。

## 最后

做web开发，开发其实是其中一个环节，后面其实还有很多东西都需要了解。
