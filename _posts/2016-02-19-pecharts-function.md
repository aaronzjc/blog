---
layout: post
title: "PHP通过JSON传递JS函数"
date:   2016-02-19 10:00:00 +0800
categories: web
---
在做PECharts开发时，遇到一个问题，就是如何传递JS函数。ECharts的option中有些选项可以配置匿名函数，作为一个后端封装，也应该提供这样的方式来让开发者者在后端传递function。然后再说遇到的问题。

PHP中的json_encode方式是不能将PHP闭包转化为函数的。例如下面这样：
{% highlight php %}
<?php
$option = [
    'func' => function(){alert('hello world');}
];
echo json_encode($option);
/* {"func":{}} */
{% endhighlight %}
既然这种方式不行，那试试字符串的方式呢？
{% highlight php %}
<?php
$option = [
    'func' => 'function(){alert("hello world");}'
];
echo json_encode($option);
/* {"func":"function(){alert(\"hello world\");}"} */
{% endhighlight %}
这样，似乎可以将函数传递过去了，但是还是不行，因为这里的函数是字符串，并不是可执行的。如果能去掉引号就可以了。

所以，这里的思路即是如此。先将option中的function字符串特殊标记出来，然后，最后json_encode时，替换引号和特殊标记，再返回给客户端就好了。
就像下面的流程：
{% highlight php %}
<?php
$option = [
    'func' => 'function(){alert("hello world");}'
];
/* 第一步: 将函数特殊标记出来 */
$option = [
    'func' => '{-function(){alert("hello world");}-}'
];

/* 第二步: 记录需要替换的部分, json_encode一下 */
/* {"func":"{-function(){alert(\"hello world\");}-}"} */
$val = 'function(){alert("hello world");}';

/* 第三步: 替换 */
$option = st_replace('\"{-' . $val . '-}\"', $val, $option);
{% endhighlight %}
如上就是处理的逻辑。实际中，数组存在多个函数需要传递。所以，需要遍历数组，标记出所有的函数，最后进行替换。上代码：
{% highlight php %}
<?php
private function handleFunc(&$arr, &$map) {
    foreach ($arr as $k => &$v) {
        // 这里粗略的可以判断是一个function
        if (is_array($v)) {
            $this->handleFunc($v, $map);
        } elseif (strpos($v, 'function(') === 0) {
            $key = md5($v);
            $map[$key] = $v;
            $v = $key;
        }
    }
}

public function getOptionJson($format = false) {
    if ($format) {
        $this->handleFunc($this->option, $map);
        $re = json_encode($this->option, JSON_UNESCAPED_UNICODE);
        foreach ($map as $k => $v) {
            $re = str_replace('"'. $k .'"', $v, $re);
        }
    } else {
        $re = json_encode($this->option, JSON_UNESCAPED_UNICODE);
    }
    return $re;
}
{% endhighlight %}
就是这么一个过程。当然，返回给客户端之后，客户端其实也可以自己去重新赋值，但是，后台还是得提供这么一个方式，这样才完整。

参考资料

* [Sending Javascript Functions Over JSON](http://solutoire.com/2008/06/12/sending-javascript-functions-over-json/)
