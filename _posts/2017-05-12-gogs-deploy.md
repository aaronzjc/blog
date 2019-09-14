---
layout: post
title: "webhooks自动部署"
date:   2017-05-12 10:00:00 +0800
categories: linux
---

上一篇文章[《Gogs》](http://memosa.cn/linux/2017/05/08/centos-gogs.html)里面，介绍了如何使用Gogs，搭建自己的Git服务。但是，有了Git服务，只是有了一个地方来保存我们的项目，还需要一个地方保存正式代码。因此，需要一个项目部署，当仓库收到推送时，自动更新到代码库。

之前用githooks做过这个事情。githooks可以在代码push时，触发一个脚本，脚本的内容就是进入到我们的正式项目目录，然后执行`git pull`命令，很简单。

这里，我们使用和githooks类似的东西`Webhooks`，来做同样的事情。

webhooks，顾名思义，就是Web钩子。本质是当Web服务中一个动作触发的时候，自动推送一个事件到我们指定的URL。至于收到推送之后做的事情，那就全看自己的想象了，如github上所说。我也没咋想象，也就是当push代码时，通知服务器端进行代码拉取。

### 后端服务

首先，我需要一个后端服务，接受事件推送。那就用flask建了一个简单的web服务接受git推送吧，代码如下

{% highlight python %}
# -*- coding: utf-8 -*-
from config import Config
from flask import Flask, request, make_response
import os
import json
import subprocess

# push事件的脚本
push = "event-push.sh"

app = Flask(__name__)

@app.route("/")
@app.route("/index")
def index():
    '''判断服务是否正常运行'''
    return "Running"

@app.route("/default", methods=["post"])
def default():
    '''默认的代码发布'''
    data = request.get_json()
    config = Config()
    if not data['repository']['name']:
        return make_response(json.dumps({"success": False}))
    
    # 执行shell脚本
    subprocess.call([config.script(push), config.repository(data['repository']['name']), data['repository']['ssh_url']])
    return make_response(json.dumps({"success": True}))

if __name__ == "__main__":
    app.run()
{% endhighlight %}

如上，在接收到push请求之后，执行一个shell脚本。shell脚本的内容就是，到正式代码库执行`git pull`。所以，其实，我还是用的shell来做代码拉取。代码如下

{% highlight shell %}
#!/bin/bash

# 进入到配置的项目主目录，不存在则退出
if [ ! -x "$1" ]; then
    mkdir $1
    cd $1
else
    cd $1
fi

# 如果不存在.git目录，表明是空的。clone一下
if [ ! -x "$1/.git" ]; then
    git clone $2 ./
fi

git pull
{% endhighlight %}

这就是全部的后端处理逻辑。

将flask应用跑起来之后，到Gogs仓库配置webhook到这个URL就可以了

![图片]({{ site.url }}/assert/imgs/webhooks_1.png)

至此，就大功告成了我们的Git服务搭建。

如上的东西用githooks也可以做。但是用webhooks做的话，可以更加灵活，易于管理。后面会将自己的flask部署放到github上。