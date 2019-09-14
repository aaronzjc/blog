---
layout: post
title: "Linux上搭建Git服务器"
date:   2016-06-02 10:00:00 +0800
categories: linux
---
## 概述
项目开发中，为了方便开发和协作，需要用到各种版本控制工具来管理代码。当我本地修改了代码之后，能够快速的同步到服务器，更新服务器端的代码。这样，其他人能访问最新的项目。常见的版本控制工具有SVN，GIT等集中式和分布式代表。这里简单介绍我在一个CentOS服务器上搭建Git服务器的过程和遇到的问题。

## 搭建过程

### 创建用户
首先新建一个用户`git`来管理项目。

{% highlight shell %}
userdel -r git # 首先清除用户
groupadd git # 创建git用户组
adduser git -g git # 创建用户git，并归属于git组
passwd git # 给git用户设置
{% endhighlight %}

这一块在搭建时，遇到的问题是用户权限相关。理清楚

### 初始化Git目录
下面就初始化了一个空的Git目录

{% highlight shell %}
cd /WORK
mkdir git.git
git init --bare # 初始化一个裸仓库
{% endhighlight %}

理论上完成上面异步，就实现了Git服务器的搭建。开发者就可以clone项目，修改push了。

### 本地Clone
在用户本地，Clone服务器上的项目，然后本地修改提交。

{% highlight shell %}
git remote add origin git@*.*.*:/WORK/git.git
git pull origin master
vim index.php
git add.
git commit -m 'test file'
git push origin master
{% endhighlight %}

这里，我创建了一个index.php文件，push到了服务器的git仓库。但是，用户并不能访问到这个文件，还需要初始化一个新的git目录作为代码发布目录。
如下，新建一个目录，作为我们的项目代码发布目录。也就是用户访问的地方。然后clone仓库里面的代码到这个目录下

{% highlight shell %}
cd /WORK
mkdir test
cd test
git clone /WORK/git.git ./
{% endhighlight %}

最后，配置Apache指向创建的test目录，然后访问域名`test.memosa.xyz`即可访问到index.php的内容了。到这里，我们就算是搭建好了一个Git服务器了。

但是仅仅做到这一步依然不够，自己实际开发中，发现有两个地方还是不方便的。第一，我本地修改了项目之后，并不能直接同步到test目录。也就是还得登录更新test目录，才能发布更新；第二，每次在本地git提交的时候，都需要输入ssh的密码，实在不方便，需要配置免密码登陆。

好，接下来就是解决这两个问题了。

### Git Hooks自动部署
在自动发布代码的时候，我们期望的是，当本地更新push到Git服务器之后，自动在test目录执行pull操作更新项目代码。查阅之后，发现Git是有这么一个东西支持的。叫做`hooks`(钩子)。按照指示，在git.git目录下，有一个目录叫`hooks`，里面包含如下等文件:

{% highlight shell %}
-rwxr-xr-x. 1 git git  248 6月   2 22:38 post-update.sample
-rwxr-xr-x. 1 git git  398 6月   2 20:17 pre-applypatch.sample
...
{% endhighlight %}

其中post-update.sample就是控制提交时的处理，我们将提交时的操作写在这个脚本里面，当提交代码时就会自动执行了。首先，重命名文件，去掉后缀

{% highlight shell %}
mv post-update.sample post-update
{% endhighlight %}

接着，编辑post-update文件内容

{% highlight plaintext %}
#!/bin/sh
unset $(git rev-parse --local-env-vars)
cd /WORK/Test # 进入到项目发布目录
git pull origin master
{% endhighlight %}

然后，回到本地，再次修改提交。就可以发现，服务器端的代码自动发布了。解决了第一个问题。

实际在配置时，并没有这么顺利，我遇到的坑就是因为目录的权限问题，导致执行失败的，当然也是因为自己对权限不理解不深刻。

### SSH免密码登录服务器
第二个问题就是SSH认证的问题了。解决方法有两个，一个是使用Mac上的一个小工具`ssh-copy-id`。另一个方法是一步一步来自己配置了。前者这个工具本质上是一样的，只是帮助我们配置了而已。这里介绍第二种方法，一步一步来。

首先生成一个SSH密钥

{% highlight shell %}
ssh-keygen -t rsa # 输入文件名，如果有多个key文件，注意使用不同名字
scp ~/.ssh/git_rsa.pub git@182.61.4.125:~ # 复制key文件到服务器home目录
{% endhighlight %}

生成key之后，复制公钥文件至服务器的`~/.ssh/authorized_keys`文件中，追加写入，一个key一行。
如果没有.ssh目录，需要先创建.ssh目录

{% highlight shell %}
mkdir .ssh
chmod 700 .ssh # .ssh目录的权限
{% endhighlight %}

注意authorized_keys的权限600或644。

{% highlight shell %}
cat git_rsa.pub >> ~/.ssh/authorized_keys # 将key追加到authorized_keys文件
{% endhighlight %}

当本地存在多个key文件时，需要配置SSH的config文件:

{% highlight shell %}
vim ~/.ssh/config
# 文件内容
# my GIT server
Host git-server
    HostName *.*.*.*
    IdentityFile ~/.ssh/git_rsa
    User git
{% endhighlight %}

然后，配置好上面的一步之后，在本地shell下即可免密码登录了。

{% highlight shell %}
ssh git-server
...
{% endhighlight %}

## 最后
又是一番折腾，不过很久也没折腾了。忙的有点懵了。还是更喜欢自己这样折腾，学习一点新的东西。

参考资料

+ [Linux用户权限](https://wiki.archlinux.org/index.php/Users_and_groups)
+ [服务器上部署Git](https://git-scm.com/book/zh/v1/%E6%9C%8D%E5%8A%A1%E5%99%A8%E4%B8%8A%E7%9A%84-Git-%E5%9C%A8%E6%9C%8D%E5%8A%A1%E5%99%A8%E4%B8%8A%E9%83%A8%E7%BD%B2-Git)
+ [SSH multiple identity files](http://superuser.com/questions/268776/how-do-i-configure-ssh-so-it-dosent-try-all-the-identity-files-automatically)
