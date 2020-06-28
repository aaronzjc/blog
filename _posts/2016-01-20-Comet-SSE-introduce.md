---
layout: post
title: "Comet及SSE简单了解"
date:   2016-01-20 17:21:00 +0800
categories: web
---
## 前言

在web开发，最基础的协议是HTTP协议。HTTP是单向通信的，也就是客户端请求服务器，服务器应答，然后一个请求就结束了。这其中，服务器永远是被动的处理。这样设计的好处是使得HTTP协议足够简单。但是，面向后来web的不断发展，对实时性的要求也不断提高。我们希望在服务器发生变化时，能够及时的告知客户端进行响应。但是起初HTTP的设计是不能实现服务器向客户端推送消息的，于是衍生了很多方式来实现实时性的需求，例如，轮询，Ajax长轮询等，统称为comet技术。随着HTTP2的发布，websocket的提出也原生支持了浏览器和服务器的双工通信，这个才是未来的主流。

简单介绍其中一些我了解的。

## Ajax轮询

轮询是最简单粗暴的一种方式。原理就是浏览器每隔一段时间，发送请求询问服务器。服务器进行查询，是否有数据，无论有么有数据都返回给客户端结果。如下图：

![polling](/assert/imgs/comet_sse_1.png)

## Ajax长轮询

长轮询就是在上面的轮询之上进行了改善。当浏览器发送一个请求之后，服务器不立刻返回，而是阻塞这个请求。阻塞的过程中，服务器不断检查是否有新的数据，如果有新的数据，那服务器马上返回这个数据，请求结束。如果服务器达到一个设定的阻塞时间都没有新的数据，则也返回失败。客户端收到响应后，再次发送一个请求。

![long-polling](/assert/imgs/comet_sse_2.png)

这种方式相比之上的好处是减少了发送的请求数，但是，依然有很多是无用的请求。缺点也明显，就是阻塞服务器占用了资源。

## iframe

这种方式是在页面中设置一个隐藏的iframe，然后iframe指向一个请求。页面加载的时候，里面的iframe发起对服务器的请求，服务器将这个请求挂起，这样服务器就可以不断的向客户端吐数据了，而不会结束了。

## SSE(Server Sent Event)

最近才了解到这个东西。十分强大，方便。可以解决我们上面的大部分需求了。基于这个技术，服务器就可以通过发送消息的形式不断的向客户端吐数据了。页面加载后，执行JS，实例化一个EventSource对象，请求后台的页面。然后，后台就可以接受这个请求，源源不断发送数据了。

![long-polling](/assert/imgs/comet_sse_3.png)

下面是一个小例子：

### 客户端

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>EventSource</title>
    <script src="https://raw.githubusercontent.com/Yaffle/EventSource/master/eventsource.js" charset="utf-8"></script>
  </head>
  <body>
    <div id="content">
    </div>
    <script type="text/javascript">
        var es = new EventSource('index.php');
        es.addEventListener('open', function (e) {
            document.getElementById("content").innerHTML += "连接已建立: " + e.data;
        }, false);
        es.addEventListener('message', function (e) {
            console.log(e);
            document.getElementById("content").innerHTML += "<br/>" + "收到消息: " + e.data;
        });
    </script>
  </body>
</html>
```

### 服务器端

```php
<?php
header("Content-Type: text/event-stream");
header("Cache-Control: no-cache");
header("Access-Control-Allow-Origin: *");
for ($i=10; $i>2; $i--)
{
    echo "data: " . "tik {$i} tac \n\n";
    ob_flush();
    flush();
    sleep(1);
}
```

## WebSocket

websocket实现了客户端和服务器的双工通信。也就是建立连接之后，服务器和客户端可以相互发送数据。HTTP 2.0中，websocket也得到支持。
过程是，页面执行JS，发起一个websocket连接请求。经过三次握手之后，服务器和客户端建立连接。然后就可以通信了。和平常socket通信一样的过程。
![long-polling](/assert/imgs/comet_sse_4.png)

## 最后

以上就是简单的介绍，实际中应用时还需深入的了解学习。

参考以下：

* [Mozilla SSE](https://developer.mozilla.org/zh-CN/docs/Server-sent_events)
* [What are Long-Polling, Websocket...](http://stackoverflow.com/questions/11077857/what-are-long-polling-websockets-server-sent-events-sse-and-comet)
