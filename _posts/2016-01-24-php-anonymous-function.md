---
layout: post
title: "理解PHP中闭包和匿名函数"
date:   2016-01-24 23:00:00 +0800
categories: php
---
闭包是指在创建时封装周围状态的函数。也就是其中的变量不是在上下文中定义的，而是在代码块中定义的。

匿名函数就是没有名字的函数，PHP中是一个Closure对象。闭包函数和匿名函数等价。匿名函数多用作回调函数。
{% highlight php %}
<?php
$func = function(){
     echo 'Hello World!';
}
{% endhighlight %}
如上就定义了一个匿名函数，我们可以直接使用`$func()`来调用这个函数。

`附加状态`即是使用外部定义的变量。JS中，会自动封装外部的状态。
{% highlight javascript %}
var a = 'hello world';
(function() {
  console.log(a);
})();
{% endhighlight %}
闭包函数中，如果检查到没有定义a变量，会自动向上查找，直到找到全局定义的a变量。PHP中不会自动封装外部的状态，必须使用关键字use来附加:
{% highlight php %}
<?php
$do = 'welcome';
$t = function ($name) use($do) {
    echo $do . ' ' . $name;
};
$t('aaron'); // welcome aaron
{% endhighlight %}
PHP中闭包函数也是一个对象（Closure）。和其他的PHP对象一样，每个闭包实例都可以使用$this关键字获取闭包的内部状态。
下面看一下Closure类的定义：
{% highlight php %}
Closure  {
    /* 方法 */
    __construct  ( void )
    public static Closure bind  ( Closure  $closure  , object $newthis  [, mixed  $newscope  = 'static'  ] )
    public Closure bindTo  ( object $newthis  [, mixed  $newscope  = 'static'  ] )
}
{% endhighlight %}
其中的bindTo()方法十分有趣。使用这个方法，可以将闭包绑定到指定的对象上面。这样闭包函数内部的$this就指向了绑定的对象了。还有另一个方法bind()，这个方法和bindTo()一样，只是他是静态的。很多框架使用这个特性来将路由的URL映射到匿名回调函数上。可以做路由分发：
{% highlight php %}
$app->addRoute('/blog/post', function(){
     do something interesting things here;
});
{% endhighlight %}
匿名函数在许多框架中都有十分巧妙的使用。例如[Monga](https://github.com/thephpleague/monga)中进行数据集查询的写法，事件的回调函数等。

参考学习：

* 《Modern PHP》
