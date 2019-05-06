---
layout: post
title: "remote-container体验"
date:   2019-05-06 10:00:00 +0800
categories: php 
---

上一篇体验了VSCode的`remote-ssh`插件，在远程开发方面，体验非常好。但是，实际工作中，自己用的不是很多。毕竟，常规开发也不会直接在服务器上写代码，然后提交更新。自己对`remote-container`比较感兴趣，也顺势体验了下。

作为微软发布的3套件的其中之一，他的存在也是为了解决开发者的痛点。

以往，开发者要开发一个程序，首先需要本地安装配置对应的环境。遇到版本兼容问题，就真的欲哭无泪了。又或者，因为一些原因，需要在本地安装多个版本的程序。这都是比较痛苦的事情。得益于Docker的流行，环境问题得到了解决。越来越多的开发人员将Docker作为自己的开发环境了。在Docker中部署好对应的程序，然后将代码挂载到容器中，再映射几个端口。就得到了近乎于原生的开发体验。这个过程本身没什么问题，也比较流行了。

VSCode团队也是看到了这个趋势。于是开发了这么一个`remote-container`插件来更加方便的进行上诉的开发流程。插件的架构如下

![图片]({{ site.url }}/assert/imgs/vscode_rc_1.png)

如果观察3个插件的架构的话，会发现3个插件的架构图都非常类似。他把容器和远程机器和WSL都划分为了远程环境，也因此这3个扩展都是remote-*，哪怕不是真正的远程。在这3个环境的开发都是远程开发，VSCode抽象出了远程开发需要解决的问题，文件系统，终端处理，程序运行调试。要做的只是做好适配，针对不同的环境，做不同的适配，解决这几个问题。也是基于此思考，VSCode重新划分了扩展，将扩展分成本地扩展和远程扩展。这个架构抽象非常清晰，将复杂的问题，归结到了一类问题，然后提出统一的解决方案，再逐一根据平台特点去实现这个方案。值得学习。

说回来，我这里基于laravel项目开发，简单体验下这个过程。

### 体验过程

首先，初始化一个laravel项目。然后在VSCode中打开这个项目。

紧接着，选择`Remote-Container: Create Configuration ...`创建一个容器配置。这里，直接选择官方的PHP7的模板即可。创建好了之后，可以看到项目多了这么一个`.devcontainer`目录。里面就是容器开发配置。

![图片]({{ site.url }}/assert/imgs/vscode_rc_3.png)

官方的容器环境比较简单，这里，我修改了一下，安装了一些常用的扩展。完整的内容如下

{% highlight text %}
FROM php:7-cli

ENV COMPOSER_MIRROR=https://packagist.org \
    TIMEZONE=Asia/Shanghai

# 安装xdebug，yaf
RUN yes | pecl install xdebug \
	&& echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
	&& echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
	&& echo "xdebug.remote_autostart=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
	&& pecl install yaf \
	&& echo "extension=yaf.so" >> /usr/local/etc/php/conf.d/yaf.ini \
	&& docker-php-ext-install pdo_mysql 

# 安装Git，procps
RUN apt-get update && apt-get -y install git procps

# 安装composer
RUN curl -sS https://getcomposer.org/installer | php \
	&& mv composer.phar /usr/local/bin/composer \
	&& composer config -g repo.packagist composer $COMPOSER_MIRROR

# 清理
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
	
{% endhighlight %}

然后，在容器中启动。VSCode就会自动构建这个容器，并且，将我们的项目映射到容器里面。

![图片]({{ site.url }}/assert/imgs/vscode_rc_4.png)

可以看到，打开终端，也是直接进入到了容器里面。一如既往，我们启动一个PHP监听`php -S 127.0.0.1:7788`。然后，点击`Remote-Container: Forwaring Port..`，给容器里面的端口映射一个宿主机端口。这里，VSCode自动识别了我正在监听的端口，可以说很人性化了。

![图片]({{ site.url }}/assert/imgs/vscode_rc_5.png)

打开浏览器，访问正常。

![图片]({{ site.url }}/assert/imgs/vscode_rc_6.png)

整个过程和之前体验的`remote-ssh`有些相似，终端，调试，端口映射等。微软在远程开发上的理解很独到，也难怪这3个扩展都叫远程开发组件。

### 最后

`remote-container`我自己很喜欢，更加贴近于自己的开发体验。日后会尽量融入自己的日常，更加多的实践。感谢微软提供了这么好的工具，对VSCode好感倍增。