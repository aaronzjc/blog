---
layout: post
title: "CentOS 7.0搭建Gogs服务"
date:   2017-05-08 10:00:00 +0800
categories: linux
---

## 概述

之前写过一篇[Linux上搭建Git服务]({{ site.url }}/linux/2016/06/02/linux-git-server.html)的笔记，简单介绍了，如何搭建一个Git服务，可以提交代码到服务器，并且在远程更新时，自动发布到正式线上。

最近，在折腾一个Python项目时，觉得以前的方式未免太原始，手动了。于是，便有了这次这个实践。实践之前，查了一下，目前比较好的Git服务产品，有Gitlab, Gogs等。Gitlab的运行要求太高了，更复杂，我比较喜欢light-weight的东西。于是选择了Gogs。经过一番折腾，最后也是成功运行了起来，效果不错。

## 环境 & 步骤

我的阿里云环境如下

+ Cent OS 7.0
+ Git 1.8.3.1
+ MariaDB 5.5.52

整个的搭建步骤如下

+ 安装gogs
+ service启动gogs
+ 配置Nginx反向代理
+ SSH配置

好了，下面就是开始了。

## gogs搭建

#### 下载MySQL

安装完MySQL后，需要创建一个数据库给gogs。

#### 创建一个git用户

gogs推荐使用git用户来启动服务。这里，服务器创建这么一个用户

{% highlight shell %}
$ userdel -r git // 清空git用户
$ groupadd git // 新建git组
$ adduser git -g git // 创建git用户,设置git组
$ passwd git // 设置密码
{% endhighlight %}

#### 运行gogs

我使用的是二进制方式安装的，也可以通过包管理方式，但是发现是第三方支持的，最后还是选择了稳定一点的二进制方式。

{% highlight shell %}
$ wget https://dl.gogs.io/0.11.4/linux_amd64.tar.gz
$ tar zxvf linux_amd64.tar.gz
$ cd gogs
$ ./gogs web -p 9090
{% endhighlight %}

如上的命令，就下载启动一个gogs服务，打开浏览器输入`x.x.x.x:9090`, 就可以访问gogs的配置页面了。

![图片]({{ site.url }}/assert/imgs/gogs_1.png)

配置好之后，注册用户，即可开始使用Gogs了。界面和Github有几分神似。项目管理等，也是类似，很熟悉。

![图片]({{ site.url }}/assert/imgs/gogs_2.png)

注意，阿里云，Cent OS 7.0系统对于端口控制的很严格，好像必须手动开启端口，才能运行。这里，手动开启防火墙端口命令。如果启动之后访问，发现访问拒绝，可以试试如下命令。

{% highlight shell %}
$ firewall-cmd --add-port=9090/tcp --zone=public --permanent # 开启端口
$ firewall-cmd --reload # 重新加载配置
$ firewall-cmd --query-port=9090/tcp # 查看端口是否开启
{% endhighlight %}

#### service方式启动

上面运行起来了gogs服务，通过在命令行下启动。也可以使用后台进程nohup，将gogs挂起，一直在后台运行。但是，我们更期望将gogs作为一项服务运行，方便管理。

gogs的`scripts`目录下，有很多文件夹，里面有很多脚本，就是用来部署gogs服务的。我这里，将gogs作为Linux service启动。所以，进入到systemd目录下，有gogs.service文件。修改相关的字段，然后复制到`/etc/systemd/system`里面。接着启动即可。

{% highlight shell %}
$ systemctl enable gogs # 开启该服务
$ systemctl start gogs # 启动该服务
$ systemctl status gogs # 查看启动状态
$ # journalctl -u gogs # 查看错误日志
{% endhighlight %}

不出问题的话，gogs就作为一个服务启动了。依然是在浏览器中输入`x.x.x.x:9000`方式登录管理界面。

#### Nginx反向代理

服务启动之后，我们也肯定不希望，一直以IP+port的方式来访问。所以，这里需要使用到Nginx来代理一下子。

提到这里，就简单的说下自己对于正向代理和反向代理的理解。通常，正向代理，就像使用VPN一样。客户端发出请求，代理服务器接收请求，替我们去访问目标服务器，然后拿到结果，再返回给我们，正向代理代理的是客户端这边的请求；而反向代理服务器，像Nginx这样，做的是啥子呢？举个例子，对于Python的Web应用部署，有很多部署方式选择，最终启动后，在本地监听某一个端口。但是外界无法通过域名访问直接访问到各个端口的服务，这里，就通过Nginx来做这个，当访问时，将域名的请求指向不同的服务器端口处理，因此，反向代理，其实代理的是后端的应用。

理解到这里，我们之前已经启动了一个后端的服务器作为Git服务。但是不能通过域名访问，因此需要Nginx来做这么一个代理。

{% highlight shell %}
$ yum install nginx
$ vim /etc/nginx/conf.d/default.conf # 编辑配置
$ systemctl start nginx
{% endhighlight %}

配置如下

{% highlight nginx %}
server {
  listen          80;
  server_name     x.x.cn;
  location / {
    proxy_pass      http://localhost:9090;
  }
}
{% endhighlight %}

至此，就大功告成了。可以完美的访问自己的Git服务器了。

#### SSH配置

为什么会有SSH这一章呢？

在如上步骤之后，clone和push都没问题了。谁知道，踩了一个SSH的坑。本来很简单的东西，被自己绕进去了半天。是这样的，当使用http方式clone项目时，没问题。但是使用ssh方式就有问题了，提示如下的错误

{% highlight nginx %}
$ git clone ssh-url
fatal: 'memosa/evernote.git' does not appear to be a git repository
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
{% endhighlight %}

查了半天issue，都没能解决。尝试着，生成ssh的key，复制到控制面板。或者，重置authorize_keys，都无效。崩溃之余，自己偶然解决了。

原因就是，本地存在多个key的时候，必须明确指定ssh连接用到的key文件。如果你的ssh是git@git-server，那么需要做如下配置

{% highlight shell %}
$ vim ~/.ssh/config
# gogs
HOST git-server
    HostName git-server
    IdentityFile ~/.ssh/gogs_rsa
    User git
{% endhighlight %}

至此，才算是完整的配置好了。

## 下一步

配置一个Git服务只能算是完成了一半的工作。配置Git服务，只是保证了我们的项目能够进行管理，合作开发。下一步要做的，就是部署。当代码提交时，部署至正式代码库。

之前的文章里面用的是Git Hooks来做的，当提交时，触发响应的事件，执行对应的脚本。gogs中一样的，需要做的是，配置响应的hooks。来做代码部署等。

部署完了之后，还要学会使用git-flow工作流来做项目开发，争取让自己有一个更加好的开发方式。

## 最后

实践之后，才能更好的理解，整个流程，步骤是在做什么，都在解决什么问题。