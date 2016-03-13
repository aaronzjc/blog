---
layout: post
title: "MAMP安装swoole扩展"
date:   2016-03-13 10:00:00 +0800
categories: php
---
最近想学习swoole框架，涉及到安装部分，遇到一些小坑。在此记录一下。

swoole安装方式有两种，一种是使用pecl一键安装，这种方式最简单。另一种方式是源码编译安装。OS X自带一个PHP，但是版本过低，我使用的是MAMP集成环境，直接集成了Apache和PHP等工具，PHP版本是5.6.10。在命令行中默认输入php，使用的是系统自带的PHP，此版本的PHP版本过低，也不包括PECL工具。所以，我们要使用适合于PHP 5.6.10版本的swoole，得单独处理一下。

## PECL方式
MAMP自带了各个版本的PHP环境，目录在`/Applications/MAMP/bin/php`。我使用的是5.6.10版本，对应的目录是`/Applications/MAMP/bin/php/php5.6.10`，如果使用PECL，对应的命令为：
{% highlight shell %}
/Applications/MAMP/bin/php/php5.6.10/bin/pecl install swoole
{% endhighlight %}

## 源码编译方式
源码编译方式，稍显复杂。得指定对应的版本，和安装一些系统工具。根据swoole官网上的文档，需要系统有如下要求：

* php-5.3.10 或更高版本
* gcc-4.4 或更高版本
* make
* autoconf

### 安装autoconf
使用homebrew安装，homebrew真是太方便了。
{% highlight shell %}
brew install autoconf
{% endhighlight %}

### 下载PHP源码
编译PHP扩展需要PHP源码。但是MAMP没有包含PHP的源码，需要自己下载。在[PHP官网](http://www.php.net/releases/)下载相应版本的源码，然后解压之后重命名文件夹为php。复制文件夹至`/Applications/MAMP/bin/php/php5.6.10/include`。

然后生成PHP的头文件。运行如下命令
{% highlight shell %}
cd /Applications/MAMP/bin/php/php5.6.10/include/php
./configure --with-php-config=/Applications/MAMP/bin/php/php5.6.10/bin/php-config
{% endhighlight %}
下面就是编译扩展了

### 编译扩展
下载swoole的源码，编译过程，phpize, configure, make, make install。只是，这里需要手动指定一下使用的PHP版本。不然，会默认使用系统的PHP。命令如下：
{% highlight shell %}
cd /path/to/your/module/source
/Applications/MAMP/bin/php/php5.6.10/bin/phpize
./configure --with-php-config=/Applications/MAMP/bin/php/php5.6.10/bin/php-config
make
sudo make install
{% endhighlight %}
然后，在PHP的扩展目录`/Applications/MAMP/bin/php/php5.6.10/lib/php/extensions??`里面就会看到swoole.so文件了。如果没看到，手动复制，swoole源码module目录编译生成的swoole.so文件至此。

最后，更新php.ini文件，增加如下一行:
{% highlight shell %}
extension=swoole.so
{% endhighlight %}
打印phpinfo()，即可查看是否安装成功。

## 测试
下面是官网的例子，这里用来简单的测试一下swoole。新建PHP代码(swoole_demo.php):
{% highlight php %}
<?php
$http = new swoole_http_server("0.0.0.0", 9501);

$http->on('request', function ($request, $response) {
    var_dump($request->get, $request->post);
    $response->header("Content-Type", "text/html; charset=utf-8");
    $response->end("<h1>Hello Swoole. #".rand(1000, 9999)."</h1>");
});

$http->start();
{% endhighlight %}
在命令行下，运行:
{% highlight shell %}
php swoole_demo.php # 注意这里的PHP版本
{% endhighlight %}
打开浏览器，输入127.0.0.1:9501/?hello=swoole，会看到Hello Swoole。

完

参考资料

* [Compile PHP extensions for MAMP](http://verysimple.com/2013/11/05/compile-php-extensions-for-mamp/)
