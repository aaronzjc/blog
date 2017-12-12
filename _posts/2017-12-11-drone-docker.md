---
layout: post
title: "Drone+Docker部署示例"
date:   2017-12-11 10:00:00 +0800
categories: Dev
---
## 概述

上一篇文章里，简单介绍了一下Gogs+Drone搭建基础的CI/CD环境。最后也给了一个使用rsync方式自动部署的例子。很简单，很方便。

然而，现在Docker技术很🔥。使用Docker部署的技术也越来越成熟，应用也很广泛。大家都知道，Docker是容器技术，容器的好处就是可以将项目和项目运行环境打包成一个整体进行发布。前面介绍的rsync方式，只负责在生产环境配置好了之后，部署项目代码。部署生产环境也是开发中一个麻烦的地方，需要安装一堆东西，还得注意版本。有了Docker，这些过程就简单多了。

OK，下面简单介绍下涉及的东西和踩的坑。

## Docker介绍

官网：[https://www.docker.com/](https://www.docker.com/)

Docker是什么？Docker是一个开源的引擎，可以方便将自己的应用打包成一个可移植的容器，容器类似于一个轻量级的虚拟机。

Docker里面有三个很重要的东西：镜像(image)，容器(container)，和仓库(repository)。镜像和容器就类似于面向对象里面的类和对象。镜像通过Dockerfile来进行构建，容器通过实例化镜像来运行。仓库就是存储镜像的地方。Docker提供一个registry来保存多个镜像仓库，每个镜像仓库里面可以存储多个镜像的版本。

Docker常用的命令有以下这么些

{% highlight shell %}
docker build -t friendlyname . # 根据当前目录的Dockerfile构建一个镜像，标签是friendlyName
docker run -p 4000:80 friendlyname  # 运行刚才构建好的镜像，并绑定端口
docker run -d -p 4000:80 friendlyname  # 和上面一样，但是指定在后台运行
docker container ls  # 容器列表
docker container ls -a  # 所有容器
docker container stop <hash>  # 停止容器
docker container kill <hash>  # 强制停止容器
docker container rm <hash>  # 删除容器
docker container rm $(docker container ls -a -q)  # 删除所有容器
docker image ls -a  # 镜像列表
docker image rm <image id>  # 删除镜像
docker image rm $(docker image ls -a -q)  # 删除所有镜像
docker login  # CLI登录，登录了才能push镜像到仓库
docker tag <image> username/repository:tag  # 给镜像打一个远程标签
docker push username/repository:tag  # git push
docker run username/repository:tag  # git pull & run
{% endhighlight %}

从上面的命令可以看出基本的镜像使用的大致流程

1. 本地编写好Dockerfile和项目代码等。
2. 构建镜像
3. 推送到远程仓库
4. 其他小伙伴拉取镜像运行

## Registry

Registry上面介绍过了，是用来存放镜像的地方。类似于Github的东西。Docker官方有一个Registry，Docker Hub。但是对于企业来说，有些镜像比较隐私，不希望放在上面，并且，对于国内来说，访问Docker Hub比较慢。Docker官方也考虑到了这点，所以提供了一个Registry镜像来方便的搭建自己私有的Registry。

我的服务器配置很渣，跑一个Registry费资源。这里不介绍如何搭建一个私有Registry了。幸好阿里云提供了免费的Registry服务，但是需要自己开通一下。

控制面板：产品服务-->容器服务

![阿里云]({{ site.url }}/assert/imgs/docker_1.png)

进入到个人容器管理平台

![阿里云]({{ site.url }}/assert/imgs/docker_2.png)

这样我们就拥有了一个自己的Registry。以后的镜像就可以推送到这个仓库了。

## Drone的部署示例

好了，熟悉了上面的流程之后。再回过头梳理一下，整个开发+自动部署的流程。

1. 开发机开发代码，编写好Dockerfile
2. 上传代码至Gogs，触发webhook
3. Drone根据webhook，执行一系列流程，进行镜像打包构建，上传至Registry
4. 部署机器拉取最新的镜像，运行
5. 部署成功

下面是一个实际的例子。Demo项目很简单，就是一个单PHP文件，镜像也很简单，就是添加这个文件，执行`php -S 0.0.0.0:8065`。

`Dockerfile`文件

{% highlight text %}
FROM php

ADD index.php /var/www/

EXPOSE  8065

WORKDIR /var/www/

CMD ["php", "-S", "0.0.0.0:8065"]
{% endhighlight %}

`.drone.yml`文件

{% highlight yaml %}
workspace:
  base: /root
  path: src/gogs/memosa/docker-demo

pipeline:
  test:
    image: bash
    commands:
      - echo "Hello world"

  build:
    image: plugins/docker
    username: docker_name
    password: docker_pass
    repo: repo_url
    tags: latest
    registry: registry_url
    mirror: docker_mirror

  deploy:
    image: appleboy/drone-ssh
    host:
      - your_host
    username: your_name
    password: your_pass
    port: 22
    command_timeout: 300 # ssh命令行执行超时时间，300秒
    script:
      - docker pull repo_url:latest
      - docker rm -f docker-demo || true # 这里这样是因为如果不存在docker-demo，rm会报错
      - docker run -d -p 8065:8065 --name docker-demo repo_url
{% endhighlight %}

Drone实际运行的效果就是下面这样的

![Drone]({{ site.url }}/assert/imgs/docker_3.png)

Drone其中有些不太方便的点

1. Docker插件，似乎并没有一个缓存，每次build都会重新下载
2. 网络不好的时候，build和push的过程会很漫长

## 一些坑

Cent OS 上运行Docker，安装好Docker之后，执行`docker run -p 8065:8065 xxx`，出现错误信息

> iptables -t nat -A PRETROUTING -p tcp -d 192.168.43.190 -j DNAT --to-destination

解决办法是，重启Docker，然后执行`iptables-save`。

## 最后

上面简单的介绍了这种方案，算是入门级别了，只介绍了一个最简单的单容器部署。真实的应用中，会涉及到多容器部署，编排。值得学习。Drone确实挺好用的，以后应该会有潜力。