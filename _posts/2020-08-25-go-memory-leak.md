---
layout: post
title: "Go内存泄露"
date:   2020-08-24 22:00:00 +0800
categories: golang
---
自从`Mu`做了一次升级后，出现一个奇怪的问题。服务器每隔一两天，就会出现CPU占用率100%和磁盘读写100%，最后导致服务器挂了。第一反应是，CPU和磁盘负载高，肯定是运行了什么计算和IO很重的程序。但是服务器并没有这种服务，所以很懵。

![img](/assert/imgs/memleak/3.png)

由于服务器负载满了的时候无法ssh登录，为了定位问题，于是写了一个cron脚本，每5分钟记录`top`命令的情况。最终发现了一些端倪。

![img](/assert/imgs/memleak/0.png)

图片显示`commander`占用内存比较高，过段时间再查看，甚至达到了20%以上。我是2G内存，这个占用就比较离谱了。所以果断得出结论是自己的代码出现了内存泄露。

回到最开始CPU和磁盘占用100%的问题。真实场景，应该是代码出现内存泄露，导致服务器内存和交换空间满了，于是频繁的处理磁盘交换等。

知道是内存泄露了，接下来就是定位是哪块位置异常了。

## Go内存分析

Go项目内存分析，可以使用官方提供的`net/http/pprof`模块。只要在项目中引入这个包，然后启动一个http服务器，即可在网页中查看当前程序的内存使用情况

我们在`commander`模块的入口处，加上内存分析

```golang
package main

import (
    "log"
    "mu/internal/app/commander"
    "net/http"
    _ "net/http/pprof" // 引入 pprof 模块
)

func main() {
    // 初始化
    commander.InitCommander()

    // 启动一个页面查看报告
    go func() {
        log.Println(http.ListenAndServe("0.0.0.0:6060", nil))
    }()

    addr := ":7970"
    commander.RegisterRpcServer(addr)
}
```

这时候，浏览器中打开`http://127.0.0.1:6060/debug/pprof/`，可以看到如下的页面

![img](/assert/imgs/memleak/1.png)

一眼就看出这个协程的数量多少是有点问题。然后刷新页面，发现这个协程的数量还在不断的增长。点进去就发现问题所在了

![img](/assert/imgs/memleak/2.png)

基本上都是Redis相关的协程。到这一步大致就能反应过来了，肯定是代码里面使用了Redis连接，没有Close的原因。最后也确实如此。至此，我们就使用`net/http/pprof`包定位了内存泄露的问题。

这里也能看出PHP和Go语言的不同之处了。PHP脚本执行完，过段时间进程就关了，即使有没有释放的资源也会自动释放。Go这种常驻的就不一样，需要开发人员对自己的代码更加严格。

这个内存泄露有两种解决方法，一种是在每次使用Redis连接后，在后面及时的Close掉。另一种是，使用全局Redis连接池。

另外还有一个优化点是，限制Docker容器的资源占用。

## Redis包

我在项目中使用的是`github.com/go-redis/redis`包处理Redis连接。在上一步知道问题所在后，脑海中依然很迷惑，我每次`NewClient`怎么会导致协程越来越多呢？这个包开辟的协程是做啥子了？

带着这个问题，粗略的看了一下代码。这个包在初始化的时候，并不是直接连接Redis，而是启动了一个Redis连接池。每次`NewClient`时，如果设置了超时时间(不设置有默认值)，则会开启一个定时清理过期的连接。这也就是为什么看到Redis协程不断增长的原因。

既然这个包内部实现了Redis连接池，那么我们在项目中也就没必要每次使用完后关闭了。用完关闭这种方式反而会让性能降低，因为每次都得初始化连接。所以，最终的解决方案是使用全局的Redis连接池处理Redis相关逻辑。要注意的是，使用全局连接池，就不能手动Close了。

```golang
var (
    client *redis.Client
    once sync.Once
)

func RedisConn() *redis.Client {
    if client == nil {
        // 确保只初始化一次
        once.Do(func() {
            cnf := config.NewConfig()
            client = redis.NewClient(&redis.Options{
            Addr:     fmt.Sprintf("%s:%d",cnf.Redis.Host, cnf.Redis.Port),
                Password: cnf.Redis.Password,
                DB:       0,
            })
        })
    }

    return client
}
```