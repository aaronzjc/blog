---
layout: post
title: "解决微信文章图片反盗链"
date:   2017-04-07 10:00:00 +0800
categories: web
---

## 概述
问题是这样的，业务需要做一个养生专题文章列表，文章都是公众号里面的内容。问题来了，当把微信公众号的文章嵌入在iframe标签中，发现文章的图片显示不了。查了知道是，微信的反盗链设置，情有可原。但是我们的文章是自己写的，所以，问题还是得解决。

## 解决思路
首先，文章链接在浏览器中打开是没问题的，但是在iframe中打开有问题，说明图片会判断域是否一致。不一致，就替换为那个难看的图片。

其次，微信的文章，图片真实链接是在img的data-src属性上。

因此，这里解决思路如下：

1. 替换img的src为data-src的值
2. 解决盗链的问题

因此，我这里做的是，将iframe指向的文章转为指向服务器的一个处理。处理的逻辑就是，将文章爬下来，然后做步骤1的操作。

解决盗链的问题，处理方式，是做一个服务器中转，将图片的链接指向到自己的服务器上的一个请求。服务器再去请求这个图片，下载下来，返回给前端。优化方面，可以将图片地址缓存，下次直接走自己服务器取了，而不用再次去爬下来。

代码说明如下

{% highlight html %}
<!--旧的方式-->
<iframe src="article-url"></iframe>

<!--新的方式-->
<iframe src="serverHandler(article-url)"></iframe>
{% endhighlight %}


服务器端的处理是

{% highlight php %}
<?php
function serverHandler($url) {
    $html = Http::Get($url);
    // 替换图片的src为data-src
    $html = str_replace("data-src", "src", $html);
    // 替换为中转
    $html = preg_replace('@http://mmbiz.qpic.cn[^\s]+(jpeg|png)@i', 'imageHandle($0)', $html);
}

function imageHandle($url) {
    $fileName = md5($url);
    if (file_exist($fileName)) {
        echo fileGet($fileName);exit;
    }
    $img = Http::Get($url);
    echo $img;
}
{% endhighlight %}

## 最后
上面用一些简要的代码，描述了下，大概思路。就是这样。
