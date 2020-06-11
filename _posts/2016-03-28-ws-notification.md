---
layout: post
title: "PHP使用Websocket推送通知"
date:   2016-04-23 10:00:00 +0800
categories: web
---
## 概述
系统开发中，实时消息推送是一个很常见的需求。整体过程而言也没有那么复杂,如果不考虑实时性和性能这些，更简单，客户端轮询服务器的消息表即可。建立Web实时通信和传统通信不同的是，因为浏览器和http服务器之间不能进行双向通信，所以需要借助Websocket这么一个桥梁来连接两者。用户的应用产生消息之后，首先发送给Websocket服务器，Websocket服务器收到消息，再发送给已经建立连接的客户端。

大致过程如下：

![ws]({{ site.url }}/assert/imgs/ws_push_main.png)

整个过程可以简化为:

* 前端页面初始化，连接到Websocket服务器
* 应用程序产生通知，连接Websocket服务器，发送消息
* Websocket服务器接收到应用程序发送的消息，转发给浏览器
* 浏览器接收到通知，进行页面响应

## 推送Demo

### Websocket服务器

这里使用swoole来编写Websocket服务器。[swoole](http://wiki.swoole.com/)是一个高性能的PHP网络通信扩展。很强大。
这里，建立一个Laravel自定义命令，来管理server。
```shell
$ php artisan make:command SwooleServer
```
服务器端值得注意的是，需要用到一个全局的数据结构来管理用户，和用户的连接，当用户刷新浏览器之后，需要更新一下用户key绑定的连接符。这样，当消息再次到达时，能够准确的发送出去。
```php
<?php

$server = new Server('0.0.0.0', 9501);

$table = new Table(1024);
$table->column('uid', Table::TYPE_INT);
$table->column('fd', Table::TYPE_INT);
$table->create();

$server->table = $table;

$server->on('open', function (Server $server, $request){
    echo "connected\n";
    if (isset($request->get['uid'])) {
        $uid = $request->get['uid'];
        $server->table->set($uid, ['uid' => $uid, 'fd' => $request->fd]);
    }
});

$server->on('message', function(Server $server, $frame) {
    echo "received from {$frame->fd}:{$frame->data}\n";
    $msg = json_decode($frame->data, true);
    $user = $server->table->get($msg['user_id']);
    if ($user) {
        $server->push($user['fd'], $frame->data);
    }
});

$server->on('close', function($server, $fd){
    echo "client {$fd} closed\n";
    $server->table->del($this->user);
});

$server->start();
```

### 客户端

客户端只需要在页面加载时，连接Websocket服务器，然后，在接收到消息时，更新页面：
```javascript
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
```

### PHP应用程序

PHP应用程序产生消息之后，需要发送给Websocket服务器。这里说个插曲，之前关于这块，看的是网上的例子，使用Redis来连接应用程序和WS服务器通信。但是他们的WS服务器使用的是Node。我在使用Redis和Swoole这个干时，错误了。因为Redis的订阅操作是阻塞的，所以Swoole不能这么干。

PHP发送消息需要用到PHP的Websocket客户端库来连接，发送消息。有些实现很简单，这里我使用的是这个库[websocket-php](https://github.com/Textalk/websocket-php)。发送消息代码：

```php
<?php
$cli = new WebsocketClient('ws://localhost:9501');
if (!$cli) {echo 'Connect Error!';exit;}
$cli->send(json_encode($msg->toArray(), JSON_UNESCAPED_UNICODE));
```

### Demo展示

略

## 最后

在折腾完整个过程之后，深刻的理解到，整个东西其实并不是很复杂。需要捋清楚整个两端过程。
