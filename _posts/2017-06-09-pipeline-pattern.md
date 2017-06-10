---
layout: post
title: "管道，流水线模式"
date:   2017-06-10 10:00:00 +0800
categories: web
---
## 概述

在程序设计中，管道，流水线的设计是个人非常喜欢的一个模式。这个模式将解决问题的方法分解为一个一个的模块，有序处理。对于不同的模块，额外的又可以打不同的补丁，做额外的监听等。最后，当整个流水线走下来的时候，所有的事情也都做完了。过程很清晰。

最近学习了一个很简单的PHP管道框架`league/pipeline`，设计很简单，但是功能很灵活强大。这里看了源代码之后，记录下自己的理解和一些改造。

## 理解

管道的过程就是，将前一个的操作输出作为第二个操作的输入，这样不断的执行，直到最后一个操作执行完成。用代码表示就是如下

{% highlight php %}
<?php
$stages = [stageOne, stageTwo, stageThree];
$payload = Input;

foreach ($stages as $stage) {
    $payload = $stage($payload);
}

echo $payload;
{% endhighlight %}

将上面的代码放大，实现一个完善的管道过程，只要做这么几件事：

+ 添加中间处理
+ 执行中间处理

还可以再添加中间处理的时候，校验数据等。

最后实际的使用效果是这样的

{% highlight php %}
<?php
spl_autoload_register();

// 只要是callable的对象都是可以作为中间处理

$stageOne = function($payload) {
    return $payload * 10;
};
$stageTwo = function($payload) {
    return $payload + 1;
};

class Stage {
    public static function stageOne($payload) {
        return $payload . "->stageOne";
    }

    public static function stageTwo($payload) {
        return $payload . "->stageTwo";
    }
}

$pipeOne = new Pipeline();
$pipeOne->pipe($stageOne)->pipe($stageTwo);
$pipeline = new Pipeline();
$result = $pipeline->pipe($pipeOne)->pipe([Stage::class, "stageOne"])->pipe([Stage::class, "stageTwo"])->process(10);
echo $result; // 101->stageOne->stageTwo
{% endhighlight %}

我模仿`league\pipeline`实现的代码在[这里](https://github.com/aaronzjc/Personal_Toys/tree/master/BlogDemos/pipeline)。主要不同的是，league里面添加中间处理是复制的$this，我觉得用链式调用会更好一点。

## Laravel中间件的实现

理解了上面简单的例子，下面就来理解一个复杂一点的东西。Laravel框架以设计优雅著称，其中间件就是一个典型的管道模式的设计。看下Laravel是怎么设计的。

Laravel请求的处理函数在`Illuminate\Foundation\Http::handler()`中，再进一步剔除无关代码，最后实际的请求处理代码如下

{% highlight php %}
<?php
protected function sendRequestThroughRouter($request)
{   
    $this->app->instance('request', $request); // 获取请求的实例
    Facade::clearResolvedInstance('request');
    $this->bootstrap(); // 初始化启动相关
    /**
    * 下面才是请求的处理过程，显然，这里是一个标准的管道过程
    */
    return (new Pipeline($this->app))
                ->send($request)
                ->through($this->app->shouldSkipMiddleware() ? [] : $this->middleware)
                ->then($this->dispatchToRouter());
}
{% endhighlight %}

上面的代码中，`send`方法和`through`做一些初始化相关的事情。真正的中间件流程在`then`方法中。

`then`方法的代码异常复杂，什么返回匿名函数里面再返回匿名函数。这里，根据框架里面的代码来理解太复杂了。我自己写了一个精简化的demo，剔除了和框架相关的东西，只保留了Laravel中间件核心理解的部分。

{% highlight php %}
<?php
// 中间件定义
$pipes = [
    function($args, Closure $callback) {
        echo $args . "-1\n";
        return $callback($args);
    },
    function($args, Closure $callback) {
        echo $args . "-2\n";
        return $callback($args);
    },
    function($args, Closure $callback) {
        echo $args . "-3\n";
        return $callback($args);
    },
];
// 初始化的参数
$init = function($args){
    echo "init\n";
    return $args;
}
// 中间件装载
$re = array_reduce($pipes, function($stack, $pipe){
    return function($pass) use($stack, $pipe){
        // 包裹函数wrapper
        return call_user_func($pipe,$pass, $stack);
    };
},$init);
// 中间件执行
call_user_func($re, "fuck");
{% endhighlight %}

`array_reduce`就是执行完成之后返回三个包裹函数

{% highlight php %}
<?php
// wrapper3
function wrapper3($pass) use($wrapper2, $pipe3) {
    return call_user_func($pipe3, $pass, $wrapper2);
}
// wrapper2
function wrapper2($pass) use($wrapper1, $pipe2) {
    return call_user_func($pipe2, $pass, $wrapper1);
}
// wrapper1
function wrapper1($pass) use($wrapper0, $pipe1) {
    return call_user_func($pipe1, $pass, $wrapper0);
}
// warpper0
function wrapper0($args){
    echo "init\n";
    return $args;
}

// 执行入口
call_user_func($wrapper3, "hello");
{% endhighlight %}

按照如上的拆分走下来，就形成一条流水线了。主要是通过`$callback($args)`串起来的。真的有点绕的，但是本质还是和最开始的一样，根据一个数组，然后线性的一个一个过程的执行。

## 最后
管道模式的理解就大致这些内容吧。

最近做另一个爬虫项目，觉得用流水线来改造会很适合。抓取源数据，经过管道一步一步的加工，最后得到自己想要的格式的数据，然后存储下来。
