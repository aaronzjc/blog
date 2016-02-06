---
layout: post
title: "PECharts文档"
date:   2016-02-05 23:00:00 +0800
categories: doc
---
## 前言

PECharts是在学习ECharts时，在公司老大的点拨下萌生的一个想法。他说目前ECharts方面还没有比较好的PHP封装，然后交给我学习一下这个做的试试看。我之前想的是，这种前端东西框架还能在后端封装，不就是返回一个JSON吗?!然后，顺着这个思路，就有了之下的想法。

在使用时，ECharts 3.0 版本的发布，可以说是极大的简化了ECharts的使用。整个图表只需要一个option对象即可。所以，无论怎么变化，无论怎么开发。只要围绕这么一个对象即可。所以自己的理解是，后端不进行复杂的操作，只需要根据条件返回给前端一个格式化的JSON option即可。后端生成JSON，只需要构造一个完整的键值数组。所以问题是怎么优雅的生成这么一个数组了。从Monga框架学到的一个思路就是使用闭包函数来构造，着实喜欢。于是就有了这么一个东西。然后扩展开来，要是能够支持额外的功能，例如数组模板，结构处理就更好了。下面是文档。

v 0.0.1版本只是一个半成品，只包含基本的数组构造，模板支持还不够完善。兴许还有BUG？这里介绍简单的用法以及未来需要完善的点。

需要完善

* 未测试json中值为匿名函数的情况
* 自定义option模板

## PECharts

### 基本用法
下面这个例子是官网文档5分钟上手的示例：
{% highlight javascript %}
var option = {
    title: {
        text: 'ECharts 入门示例'
    },
    tooltip: {},
    legend: {
        data:['销量']
    },
    xAxis: {
        data: ["衬衫","羊毛衫","雪纺衫","裤子","高跟鞋","袜子"]
    },
    yAxis: {},
    series: [{
        name: '销量',
        type: 'bar',
        data: [5, 20, 36, 10, 10, 20]
    }]
};
{% endhighlight %}
一般情况下，后端使用PHP构造这么一个对象返回，代码如下：
{% highlight php %}
<?php
$option = [];
$option['title'] = ['text' => 'ECharts 入门示例'];
$option['tooltip'] = new stdClass;
$option['legend'] = ['data' => ['销量']];
$option['xAxis'] = ['data' => ["衬衫","羊毛衫","雪纺衫","裤子","高跟鞋","袜子"]];
$option['yAxis'] = new stdClass;
$option['series'][] = ['name' => '销量', 'type' => 'bar', 'data' => [5, 20, 36, 10, 10, 20]];
echo json_encode($option, JSON_UNESCAPED_UNICODE);
{% endhighlight %}
使用PECharts的构造方法如下：
{% highlight php %}
<? php
$option = new Option();
$optionJson = $option->init(function($option){
    $option->title = ['text' => 'ECharts 入门示例'];
    $option->tooltip('{}')->legend(['data' => ['销量']]);
    $option->xAxis(function($xAxis){
        $xAxis->data = ["衬衫","羊毛衫","雪纺衫","裤子","高跟鞋","袜子"];
    })->yAxis('{}');
    $option->series(function($series){
        $series->name = '销量';
        $series->type = 'bar';
        $series->data = [5, 20, 36, 10, 10, 20];
    }, true);
})->getOption();
echo $optionJson;
{% endhighlight %}
如上就是简单地数组构造。

### 使用介绍
{% highlight php %}
$option = new Option();
{% endhighlight %}
这里即实例化了一个option对象，这个对象包含的职责是初始化构造option的内容，还有一个额外的处理，具体如下。
init()函数构造option的内容。传入数组则是直接赋值，callback则进行'递归'式赋值。

这个暂时还未完善对模板的支持，如果完善了，则可以直接初始化的时候使用一个模板来快速的构造一个图表数组。这样，只需要对必要的部分赋值即可生成一个完整的option数组。因此，需要抽象出一些基础图表的共性。
{% highlight php %}
$option = new Option(Template::pie());
$option = new Option(Template::BlinBlin());
{% endhighlight %}
$option对象还可以对最后的option数组进行处理，例如饼图可能刚开始不对legend进行数据定义，希望根据series来动态的生成数据，这时候可以使用：
{% highlight php %}
$option->init(...)->autoLegend()->getOption();
{% endhighlight %}
上面就是提供的基础option方法，下面是核心构造部分。实现的代码其实也很简单。
{% highlight php %}
$option->title = ['text' => 'ECharts 入门示例'];
$option->tooltip('{}')->legend(['data' => ['销量']]);
$option->xAxis(function($xAxis){
    $xAxis->data = ["衬衫","羊毛衫","雪纺衫","裤子","高跟鞋","袜子"];
})->yAxis('{}');
$option->series(function($series){
    $series->name = '销量';
    $series->type = 'bar';
    $series->data = [5, 20, 36, 10, 10, 20];
}, true);
{% endhighlight %}
这里的原理是利用__call()和__set()来进行赋值。使用等于，则是对这个属性进行直接赋值，如果是函数调用，参数为字符串时，进行一些特殊处理，如上'{}'是空的对象;如果是数组，则是直接赋值;如果是匿名函数，则进行此逻辑。注意第二个参数，当值为true时，表明函数名对应的属性是一个列表对象[]，而不是{}，之后的所有相同函数名都应该带上true参数才行。例如:
{% highlight php %}
$option->series(function($series){
    $series->name = '销量';
    $series->type = 'bar';
    $series->data = [5, 20, 36, 10, 10, 20];
}, true)->series(function($series){
    $series->name = '销量';
    $series->type = 'bar';
    $series->data = [5, 20, 36, 10, 10, 20];
}, true);
{% endhighlight %}

## 最后
完。
