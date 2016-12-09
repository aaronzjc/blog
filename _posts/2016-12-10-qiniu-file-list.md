---
layout: post
title: "七牛云一个函数的封装过程"
date:   2016-12-08 10:00:00 +0800
categories: php
---

## 概述
在接触七牛云开发时，用到这么一个接口，获取空间中所有的文件名。七牛提供了相关的接口，接口定义如下

{% highlight php %}
<?php
use Qiniu\Storage\BucketManager;
// ...
$bucketMgr = new BucketManager($auth);
$bucketMgr->listFiles($bucket, $prefix, $marker, $limit);
// ...
{% endhighlight %}

其中，$marker是查询结果的当前游标，根据此参数可以从当前结果位置往后继续查；$prefix是文件名的前缀，用于过滤文件；$limit是查询的数目限制。

问题就在这里了，接口默认是限制了一次请求的数目的，最多只能查询1000条数据。也就是说当$limit大于1000时，最后只会返回1000条。因此，这里需要封装这么一个方法，直接去查，返回所有的文件列表。

## 封装过程

### 递归

这是一个很清晰的递归的问题了。就是第一次查，如果后面还有数据，则，根据返回的$marker继续查，一直到$marker不存在了就结束。很好，很粗暴。封装时，用到了PHP中的闭包函数。在闭包里面定义递归函数，这样就不必在函数外再定义一个函数了。代码如下

{% highlight php %}
<?php

function listFiles($limit = 200, $prefix = '', $bucket = 'none', $marker = '') {
	$auth = self::getAuth();
	$bucketMgr = new BucketManager($auth);

	$re = []; // 结果集

	$option = [
		'bucket' => $bucket,
		'prefix' => $prefix,
		'marker' => $marker,
		'limit' => $limit
	];

  $recursion = function ($option, $bucketObj, &$re) use(&$recursion) {
      $total = count($re);$left = 0;
      // 如果限制了数目，且，达到了总数，则返回。否则，设置下次取的数目。递归去取。
      if ($option['limit'] > 0) {
          if ($total >= $option['limit']) {
              return;
          }
          $left = $option['limit'] - $total;
      }

      list($files, $marker, $err) = $bucketObj->listFiles($option['bucket'], $option['prefix'], $option['marker'], $left);
      if ($err) return;

      foreach ($files as $v) {
          $re[$v['key']] = $v['key'];
      }

      // 如果没有取完，则递归再去取
      if ($marker) {
          $option['marker'] = $marker;
          $recursion($option, $bucketObj, $re);
      }
  };
  $re = [];
  $recursion($option, $bucketMgr, $re);

	return array_values($re)?:[];
}
{% endhighlight %}

如上，就是递归的整个代码。有一个小坑就是，匿名闭包，那里使用的是`use (&$recursion)`而不是`use ($recursion)`，因为在定义这个函数时，$recursion还是NULL，按照值传递进去是无法执行的。参考这里(StackOverFlow)[http://stackoverflow.com/questions/2480179/anonymous-recursive-php-functions]。

### 非递归方式

通常，递归的方式会产生额外的开销。所以，这里想了另一种非递归方式来处理。非递归的方式，当遇到查询结尾时，直接退出循环即可。

{% highlight php %}
<?php

function listFiles($limit = 200, $prefix = '', $marker = '', $bucket = 'saasjs') {
    $auth = self::getAuth();
    $bucketMgr = new BucketManager($auth);

    $re = []; // 结果集

    $option = [
        'bucket' => $bucket,
        'prefix' => $prefix,
        'marker' => $marker,
        'limit' => $limit
    ];

    $left = $total = 0;
    while(true) {
        if ($option['limit'] > 0) {
            $left = $option['limit'] - $total;
            if ($left == 0) break;
        }

        $total = count($re);

        list($files, $marker, $err) = $bucketMgr->listFiles($option['bucket'], $option['prefix'], $option['marker'], $left);

        foreach ($files as $K => $v) {
            $re[$v['key']] = $v['key'];
        }

        if (!$marker) break;
        $option['marker'] = $marker;
    }

    return array_values($re)?:[];
}
{% endhighlight %}

如上，就是非递归方式。其实两者代码复杂度上来看，是差不多的。但是，我觉得循环比递归更好控制一些。

### 额外的优化

如上两种方式，最后都达到我们想要的结果。但是，考虑到实际中，还是不满意。因为，七牛云中的文件，系统运行时间长了之后，肯定是成千上万了。然后，如上两种简单方式，都是最后返回这个数组。试想一下，空间有10w文件。最后返回10w个元素的数组。内存开销也是蛮大的。

所以，聪明的读者，可能想到了，我的想法就是将返回结果改造成生成器。生成器占用的内存少，缺点是结果集只能迭代了。最后的修改后代码如下

{% highlight php %}
<?php
function listFiles($limit = 200, $prefix = '', $bucket = 'none', $marker = '') {
		$auth = self::getAuth();
		$bucketMgr = new BucketManager($auth);

		$re = []; // 结果集

		$option = [
			'bucket' => $bucket,
			'prefix' => $prefix,
			'marker' => $marker,
			'limit' => $limit
		];

    $recursion = function ($option, $bucketObj, &$re) use(&$recursion) {
        $total = count($re);$left = 0;
        // 如果限制了数目，且，达到了总数，则返回。否则，设置下次取的数目。递归去取。
        if ($option['limit'] > 0) {
            if ($total >= $option['limit']) {
                return;
            }
            $left = $option['limit'] - $total;
        }

        list($files, $marker, $err) = $bucketObj->listFiles($option['bucket'], $option['prefix'], $option['marker'], $left);
        if ($err) return;

        foreach ($files as $v) {
            $re[$v['key']] = $v['key'];
        }

        // 如果没有取完，则递归再去取
        if ($marker) {
            $option['marker'] = $marker;
            $recursion($option, $bucketObj, $re);
        }
    };
    $re = [];
    $recursion($option, $bucketMgr, $re);

		return array_values($re)?:[];
}
{% endhighlight %}

如上，就是递归的整个代码。有一个小坑就是，匿名闭包，那里使用的是`use (&$recursion)`而不是`use ($recursion)`，因为在定义这个函数时，$recursion还是NULL，按照值传递进去是无法执行的。参考这里[StackOverFlow](http://stackoverflow.com/questions/2480179/anonymous-recursive-php-functions)。

### 非递归方式

通常，递归的方式会产生额外的开销。所以，这里想了另一种非递归方式来处理。非递归的方式，当遇到查询结尾时，直接退出循环即可。

{% highlight php %}
<?php

function listFiles($limit = 200, $prefix = '', $marker = '', $bucket = 'saasjs') {
    $auth = self::getAuth();
    $bucketMgr = new BucketManager($auth);

    $re = []; // 结果集

    $option = [
        'bucket' => $bucket,
        'prefix' => $prefix,
        'marker' => $marker,
        'limit' => $limit
    ];

    $left = $total = 0;
    while(true) {
        if ($option['limit'] > 0) {
            $left = $option['limit'] - $total;
            if ($left == 0) break;
        }

        $total = count($re);

        list($files, $marker, $err) = $bucketMgr->listFiles($option['bucket'], $option['prefix'], $option['marker'], $left);

        foreach ($files as $K => $v) {
            yield $v['key'];
        }

        if (!$marker) break;
        $option['marker'] = $marker;
    }
}
{% endhighlight %}

## 最后

上面就是遇到的一个小问题。自己的思考过程，工作中，其实没多少时间去回顾自己写的东西。但是多想想还是有点收获的。
