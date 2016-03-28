---
layout: post
title: "Laravel中使用Websocket推送通知"
date:   2016-03-28 10:00:00 +0800
categories: php
---
## 概述
之前在工作时，对新浪微博的消息通知很感兴趣。然后，自己后来断断续续了解了这一块的相关知识。现在，在使用Laravel搭建后台项目的时候，想到这么个点。就应用了一下。推送技术主要是通过Websocket，来达到客户端和服务器的通信。服务器有消息了，主动发送消息给浏览器，浏览器在接收消息的事件中进行响应处理发送通知。另一个比较重要的点就是，消息一般是我们的应用程序产生的，但是和浏览器通信的是Websocket服务器。应用程序和Websocket服务器之间也需要通信。

应用程序和Websocket服务器通信使用的是Redis的PUB/SUB功能。PUB/SUB，即发布/订阅。消费者订阅一定的频道，然后发布者有消息时，发布消息到指定的频道上，对应订阅该频道的消费者即可接收到发布的消息。

最后，整个大致流程图如下

![ws]({{ site.url }}/assert/imgs/ws_push_main.png)

整个过程可以简化为:

* 前端页面初始化，连接到Websocket服务器
* Websocket服务器在接受连接时，根据连接的用户订阅指定的频道，例如{user:123}
* 应用程序产生通知，发布消息到{user:123}频道
* Websocket服务器接收到订阅的消息通知，推送给浏览器
* 浏览器接收到通知，进行处理

## 推送Demo

### Redis

[Redis](http://redis.io/) 是一个开源（BSD许可）的，内存中的数据结构存储系统，它可以用作数据库、缓存和消息中间件。内置了丰富的数据结构和方便的功能操作。

Redis的PUB/SUB功能:

> SUB/PUB
>
> Client1: SUBCRIBE TEST  # 订阅频道
>
> Client2: PUBLISH TEST "hello redis"  # 发布消息到频道

测试如下:
![redi]({{ site.url }}/assert/imgs/redis_subpub.png)

### Laravel发布通知
Laravel应用需要首先安装Predis包：
{% highlight shell %}
$ composer require predis/predis
{% endhighlight %}
后台消息部分，这里随机一个0-10的数字，然后发布到Redis频道
{% highlight php %}
<?php
// ...
$cnt = rand(0,10);
Redis::publish('push:message:1', json_encode(['cnt' => $cnt], JSON_UNESCAPED_UNICODE));
// ...
{% endhighlight %}

### Websocket服务器

这里使用swoole来编写Websocket服务器。[swoole](http://wiki.swoole.com/)是一个高性能的PHP网络通信扩展。很强大。
这里，建立一个Laravel自定义命令，来管理server。
{% highlight shell %}
$ php artisan make:command SwooleServer
{% endhighlight %}
Swoole服务器在启动时，监听客户端的连接事件，客户端连接时，订阅对应频道消息：
{% highlight php %}
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Redis;
use Swoole\Websocket\Server;

class SwooleServer extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'swoole:server';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'websocket server using swoole';

    /**
     * Create a new command instance.
     *
     * @return void
     */
    public function __construct()
    {
        parent::__construct();
    }

    /**
     * Execute the console command.
     *
     * @return mixed
     */
    public function handle()
    {
        // start a server
        $server = new Server('0.0.0.0', 9501);

        $server->on('open', function (Server $server, $request){
            $uid = $request->fd;
            //subscribe messages from redis
            Redis::subscribe(['push:message:1'], function($message) use($server, $uid) {
                echo "notify: ".$message."\n";
                $server->push($uid, $message);
            });
        });

        $server->on('message', function(Server $server, $frame) {
            echo "received from {$frame->fd}:{$frame->data}\n";
            $server->push($frame->fd, 'welcome, i heard you.');
        });

        $server->on('close', function($ser, $fd){
            echo "client {$fd} closed\n";
        });

        $server->start();

    }
}
{% endhighlight %}

### 客户端

客户端只需要在页面加载时，连接Websocket服务器，然后，在接收到消息时，更新页面：
{% highlight javascript %}
// client.js
var socket = new WebSocket('ws://localhost:9501/?uid=1');
socket.onopen = function(event) {
    var badge = document.getElementById('msg-cnt');
    badge.innerHTML = 0;
    console.log('Connected: ' + event);
}
socket.onmessage = function(event) {
    var badge = document.getElementById('msg-cnt');
    var data = JSON.parse(event.data);
    badge.innerHTML = data.cnt;

    console.log("Received: " + data);
}
socket.onclose = function(event) {
    console.log("Closed..");
}
{% endhighlight %}

### Demo展示

下面是最终的效果。点击发送时，系统生成0-10的随机数，然后发送到Redis，最后通过Websocket服务器通知客户端。更新右上角的数字。
![Gif]({{ site.url }}/assert/imgs/push_demo_gif.gif)

## 最后

这里，做到这里就实现了一个基本的Demo了。但是实际的应用中，还是远远不够的。对比微博的功能，应该能够实现消息通知之后，如果用户没有查看的话，应该能够在下次登录时继续显示，等。还得慢慢学习了。

## 参考资料

* [Laravel Redis](https://laravel.com/docs/5.2/redis)
* [在 laravel 5 實作瀏覽器推播通知](http://jigsawye.com/2015/12/22/push-notification-to-user-in-laravel-5/)
