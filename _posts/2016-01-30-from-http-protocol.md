---
layout: post
title: "Web后端漫谈"
date:   2016-02-02 23:00:00 +0800
categories: web
---
## 前言
做PHP开发快一年了，从最开始的搭建LAMP环境写下第一行PHP代码，到现在接触越来越多的概念和技术。对Web后端的流程也从最开始的朦朦胧胧到现在熟悉基本轮廓了。这里流程并不是完整的系统开发流程，而是一个web请求的产生到最后的响应，其中所经历的一些阶段。整个阶段说起来涉及到的东西很多，但是，仔细回想起来，所有的东西联系的又是十分的紧密。就像一根线一样，串在一起。

写这么一篇文章，是想从自己的角度，尽可能逻辑清晰，通俗的将这些东西串联到一起。也是对自己理解的Web的一个整理。有些地方我可能没了解到那个深度就没写出来，可能有些知识还理解错了。但是不写出来，可能就很难发觉了。

## 请求
计算机科学家为了方便计算机进行通信，制定出了一套完整的网络通信协议，也就是我们熟知的TCP/IP协议。基于这套协议，我们就可以很方便的和不同的计算机进行通信，例如文件传输等。Web中的HTTP协议即是基于此之上的一套应用层协议。HTTP协议的不同之处在于，他由一次浏览器请求发起而产生，伴随服务器的响应而结束。不会保持连接状态。这样一问一答的形式让HTTP协议十分的简单。因为是在TCP/IP之上，所以也包含了三次握手等基本的连接过程。

早期的互联网主要是，图片，html网页等静态资源。用户通过使用浏览器，输入资源的地址(URL: uniform resource location)来请求服务器，服务器收到用户的请求之后，根据用户请求的URL来查找服务器的指定资源并返回给用户。这是起初的形式。后来，随着技术的发展，网站希望能在用户访问的时候动态的生成资源，数据返回给用户。动态网站就此诞生了。动态网站涉及到的技术主要有用来产生数据的后端语言，存储数据的数据库。这里面值得思考的就是，浏览器发送给服务器的请求，服务器如何通过请求来和后端的语言进行协作，获取后端语言产生的动态数据，最后响应给用户。

## 客户端
通常，我们将发送请求的一方称为客户端。客户端一般是进行请求连接的一方，其本质是根据提供的IP以及端口来连接另一台计算机通信的一套程序。浏览器是一种特殊的客户端软件，其默认的连接端口是80。

## Web服务器
Web服务器就是响应请求的一方。其本质是一套能绑定在指定端口，解析HTTP协议，并返回指定格式的响应的应用程序。因为HTTP是基于TCP/IP协议的，而TCP/IP协议又是通过socket来进行通信的。所以我们可以很简单的自己就实现一个HTTP服务器。只需要绑定到指定端口，监听请求，返回指定HTTP协议格式的内容即可。因为本身HTTP协议也十分的简单，所以，看下面的一个Python实现的HTTP服务器的小例子，这里对于所有的连接都返回一段固定的字符串：
```python
from socket import *

s = socket(AF_INET, SOCK_STREAM)
s.bind(('127.0.0.1', 8099)) # 绑定指定端口

str = '''HTTP/1.1 200 ok
Connection: close
Content-Length: 11
Content-Type: text/html
Server: Python/server

from python
'''

s.listen(1)
while True:
    con, addr = s.accept()
    print('Connected - ', addr)
    data = str
    con.send(bytes(data, encoding='UTF-8'))
    con.close()
```
运行结果

![Python Http]({{site.baseurl}}/static/assert/imgs/from_http_1.png)

上面的示例只是简单的构造了一个简单响应。实际中的服务器程序还需要对请求进行分析，处理多个连接等。复杂的多。服务器的简单介绍就到此为止。

## PHP与Apache
再次回到流程上面，前面介绍了，用户发送请求，服务器获取请求然后处理请求，返回响应数据。对于Web开发而言，数据一般是通过PHP等后端语言开发执行之后的输出结果。那么这里，服务器是如何和这些后端应用程序打交道的呢？也就是，后端程序打印一段数据，服务器是怎么获取到，然后将这个数据再返回给浏览器。

从PHP与Apache说起。PHP在Apache下可以以CGI和mod_php等方式运行。

### CGI
CGI(Common Gateway Interface)通用网关接口。描述了外部应用程序与服务器通信的标准。CGI允许Web服务器调用外部的应用程序执行，并将执行结果返回给服务器。具体执行的流程是，外部请求请求CGI脚本，Web服务器收到相应的请求之后，去检查cgi目录是否存在对应的CGI脚本，如果存在，则启动一个外部应用程序进程来执行这个脚本，脚本执行结束，返回数据，进程关闭。因为语言无关性，所以任何后端语言程序只要符合CGI标准，都可以作为CGI脚本。显然，某些方面来看，因为需要反复启动外部应用程序进程，所以CGI效率应该是很低的。但是也有其应用方面，如果是密集型计算，可以用一些静态语言，像C来开发CGI脚本，性能就是其他语言无法媲美的。[Apache CGI文档说明](https://httpd.apache.org/docs/2.2/howto/cgi.html)

![CGI]({{site.baseurl}}/static/assert/imgs/from_http_2.jpg)

### mod_php方式
这种方式是平常配置LAMP最常见的方式。一般使用这种方式时，需要配置PHP，以及PHP处理的后缀名。其思路是将PHP解释器集成至Apache服务器中，作为服务器的一部分来运行。当启动服务器的时候，预先加载PHP的运行环境。然后，服务器接收到对于PHP脚本的请求时，Apache调用PHP解释器来对脚本进行解释，运行，并返回相应的结果。

![mod_php]({{site.baseurl}}/static/assert/imgs/from_http_3.jpg)

如上是PHP和Apache协作的两种方式。服务器和后端程序之间的通信就是如此。这里有一个[资源](http://www.slideshare.net/aimeemaree/a-look-at-fastcgi-modphp-architecture)讲解了几种方式的流程，十分的清晰。上述图片来源自此。

插播一张图，下面的图是PHP语言的核心架构。结合上面的理解，也有一个更加清晰的认识了。

![php_arch]({{site.baseurl}}/static/assert/imgs/from_http_4.png)

注意其中的SAPI(Server Application Programming Interface 服务端编程接口)部分。SAPI通过一系列函数，实现了PHP与外围数据的交互。

## HTTP协议

作为Web开发人员，必须十分清楚HTTP的一些基本概念和知识。请求和响应，一些请求头，响应信息等。还有进阶一些的就是https，websocket等。推荐一本书《图解HTTP》，挺浅显易懂的。

说一点自己的感悟就是，HTTP协议这东西对我来说，很难一次性看完一本书就掌握了整个体系知识。很多小的点都是知道有这么一个东西，然后实际开发时，踩坑了，或者需要用到了，才会回过头了解这部分，理解的才会深刻一些。

## Web后端语言
比较熟悉的Web后端语言有PHP, Python, Ruby等。Web后端程序开发，一般要处理的就是数据，展示。涉及到很多很多了，存储数据就是数据库知识。数据库又有关系型数据库和非关系型数据库，关系型数据库又有如何设计结构。数据量大了之后，数据库方面如何进行部署，减轻压力，提高效率，优化库等。前端展示方面，模板引擎等。

因为后端涉及到的东西实在是太多了，博主了解的也不深入，不广，就不叙述了。

参考

* 《图解HTTP》
* [Apache CGI文档说明](https://httpd.apache.org/docs/2.2/howto/cgi.html)
