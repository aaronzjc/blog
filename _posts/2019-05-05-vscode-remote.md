---
layout: post
title: "VSCode远程开发尝鲜"
date:   2019-05-05 10:00:00 +0800
categories: php 
---

前两天微软在PyCon[发布](https://code.visualstudio.com/blogs/2019/05/02/remote-development)了一个重磅产品，`VSCode Remote Development Pack`。之前提过，VSCode和开发者走的很近。因此，在充分听取开发者的意见，了解开发者的需求之后。VSCode团队开发出了这么一个产品，用于改善开发者的开发体验。

VSCode远程开发组件包括3个扩展

- Remote-WSL, 可以让你在Windows开发环境下，基于Windows Sub Linux Sys来做Linux环境的应用开发。
- [Remote-SSH](https://code.visualstudio.com/docs/remote/ssh), 可以让你在本地，基于SSH，做远程开发。
- Remote-Containers，可以让你使用Docker容器作为开发环境。

我尝试了一下`Remote-SSH`扩展，远程开发就像和本地开发一样。体验非常好。

一般在开发时，可能会遇到如下的场景

1. 仿真测试的时候，执行异常了，但是没有打日志，想修改代码进行调试。这时候，要么本地修改提交，然后在仿真环境更新代码；要么，直接在仿真环境用Vim修改代码。两者体验都不丝滑。
2. 开发环境对配置要求非常高。
3. 等

这个扩展就是为了解决以上的这类问题。让开发者在远程机器上直接写代码，还能用上VSCode的丰富扩展特性，极大的方便一些场景下的开发。下面就结合PHP开发流程，简单介绍下这个扩展。

### 设置代码仓库

首先新建一个空仓库，然后，在你的测试机上clone这个代码库

{% highlight shell %}
$ git clone git@github.com:aaronzjc/remote-ssh-demo.git
$ pwd
/home/memosa/remote-ssh-demo
{% endhighlight %}

### 配置ssh免密登录

配置免密码登录

{% highlight shell %}
$ ssh-copy-id -i ~/.ssh/id_rsa.pub memosa@IP
$ 输入登录密码
{% endhighlight %}

配置别名登录

{% highlight shell %}
$ vim ~/.ssh/config
# file ~/.ssh/config
Host dev
    Hostname IP
    Port 22
    User root
    IdentityFile ~/.ssh/id_rsa
{% endhighlight %}

### 安装&配置&示例

下载VSCode Insider版本。搜索扩展商店`Remote Development`。安装重启。

输入命令或者点击左下角，选择`Remote-ssh: Connect to Host`，然后选择上一步配置好的`dev`地址。接着，VSCode就自动帮我们连接到远端服务器了。打开上一步clone的目录，就可以愉快的进行开发了。

![图片]({{ site.url }}/assert/imgs/remotessh.png)

左下角可以看到ssh连接的地址。新建一个测试文件，写一点测试代码(VSCode本身的代码编辑特性都可用)

![图片]({{ site.url }}/assert/imgs/remotessh_1.png)

我们开发之后，想预览效果，一般会在本地终端起`php -S 127.0.0.1:7788`这样的命令，在浏览器中查看效果。

这里VSCode的另外两个功能，也很好的解决了这个问题：一个是远程终端。这时候，你打开一个终端窗口，连接到的是远程服务器，可以直接在VSCode里面执行服务器命令，这和本地开发的体验非常一致。另一个就是端口映射。可以将服务器监听的端口，映射到本地电脑，然后在本地访问。解决了一些本地访问不到服务器IP的情况。

这样，开发在本地，查看效果在本地。真正的本地开发体验。看示例，首先在服务器启动PHP监听

![图片]({{ site.url }}/assert/imgs/remotessh_2.png)

然后，选择端口映射，输入`7788`，配置完成，会收到这样的提示，然后，在浏览器中访问，没得问题。

![图片]({{ site.url }}/assert/imgs/remotessh_3.png)

![图片]({{ site.url }}/assert/imgs/remotessh_4.png)

真的很神奇。做到这一步，我感觉非常惊喜了。不得不说，VSCode这个功能做的也太好了。但是还有最后一步，开发完了，肯定要提交到Git上。因为VSCode集成了Git，可以直接点点鼠标提交刚才修改的文件。然后同步至Github。大功告成。

### 总结

我目前的工作流程可能还用不上。但是这个扩展提供了一个开发流程方案，以后会持续关注，探索，融合到自己的工具栈。

还想说，微软真的是对开发者太友好了，能够了解开发者的需求，并落地到解决方案。我很看好VSCode未来的发展。

最后，VSCode发布了3个扩展，`Remote-WSL`可能自己现在用不上，就不尝试了。但是，另外一个`Remote-Containers`，看了一下介绍，很感兴趣，也会尝试下。