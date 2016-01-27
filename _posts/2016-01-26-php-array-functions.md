---
layout: post
title: "PHP中常用数组函数"
date:   2016-01-26 23:00:00 +0800
categories: php
---
数组应该是PHP中比较强大重要的数据类型了，控制灵活，可以构造各种数据集。PHP语言内置了很多有用的数组操作函数，有时候恰当的使用这些函数可以极大的减少代码量，提高开发效率。简单介绍一些比较有用的函数。

* [array_map](#arraymap)
* [array_reduce](#arrayreduce)
* [array_slice](#arrayslice)
* [array_pop](#arraypop)
* [array_flip](#arrayflip)
* [array_keys](#arraykeys)
* [array_rand](#arrayrand)
* [array_merge](#arraymerge)
* [array_column](#arraycolumn)
* [array_filter](#arrayfilter)
* [array_unique](#arrayunique)
* [array_unshift](#arrayunshift)
* [array_intersect](#arrayintersect)
* [其他](#section)

### array_map

{% highlight php %}
array array_map(callback $callback, array $array1[, array $...])
{% endhighlight %}
参数
{% highlight txt %}
callback
回调函数

array
数组
...
{% endhighlight %}
示例
{% highlight php %}
<?php
$arr = ['i', 'love', 'u'];
print_r(array_map(function($ele){
     return strlen($ele);
}, $arr));
/* [1, 4, 1] */
{% endhighlight %}

### array_reduce
{% highlight php %}
mixed array_reduce(array $arr, callback $callback [, mixed $initial])
{% endhighlight %}
该函数，迭代的将回调函数应用于数组中的每一个元素进行计算，最后返回一个单一的值。说到这里还是很迷惑，下面会具体分析。

参数
{% highlight txt %}
array
数组

callback
mixed callback(mixed $carry, mixed $item)
$carry是每次迭代的返回元素，$item是每次进行迭代的当前元素。
这个回调函数十分特别，特别之处在于其每次的返回元素都会作为下次迭代的$carry参数与下次迭代的$item进行计算。有很强的'递归'的感觉。

$initial
作为第一次迭代的$carry参数，如果不存在，则为null
{% endhighlight %}
示例
{% highlight php %}
<?php
$arr = [1,2,3,4,5];
var_dump(array_reduce($arr, function($carrior, $item) {
    $carrior *= $item;
    return $carrior;
})); /* 0; 因为，没有传递$initial参数，所以初始值为NULL，所以结果为 0*1*2*3*4*5=0  */
var_dump(array_reduce($arr, function($carrior, $item) {
    $carrior += $item;
    return $carrior;
}, 1)); /* 16; 1+1+2+3+4+5=16  */
{% endhighlight %}
之所以，将这两个函数放在一起说，是因为涉及到一个挺有意思的东西。函数式编程中有个很重要的思想是map/reduce。map就是对列表中每个元素进行操作，reduce就是对列表中的每个元素进行迭代操作。map/reduce在大数据领域也有很重要的应用，大致思路也是分解合并。

### array_slice
{% highlight php %}
array array_slice(array $array, int $offset[, int $length = NULL [, bool $preserve_keys = false ]])
{% endhighlight %}
截取数组的某一部分返回。$offset为索引，可以为负数。为负数的时候，从后面往前算。
示例
{% highlight php %}
<?php
$arr = [1,2,3,4,5,6]
print_r(array_slice($arr, 1, 3)); /* [2,3,4] */
print_r(array_slice($arr, -2, 1)); /* [4] */
{% endhighlight %}

### array_pop
{% highlight php %}
mixed array_pop ( array &$array )
{% endhighlight %}
返回数组的最后一个元素，这里使用的是引用，所以数组会改变。与之相对应得是array_shift。

### array_flip
{% highlight php %}
array array_flip ( array $array )
{% endhighlight %}
返回键值互换的数组。如果原数组存在相同值，互换后，最后一个相同值对应的键值会覆盖之前的。
示例
{% highlight php %}
<?php
$arr= [
    'a' => 1,
    'b' => 1,
    'c' => 2,
    'd' => 1
];
print_r(array_flip($arr)); /* [1 => 'd', 2 => 'c'] */
{% endhighlight %}

### array_keys
{% highlight php %}
array array_keys ( array $array [, mixed $search_value = null [, bool $strict = false ]] )
{% endhighlight %}
返回数组的键构成的数组。如果存在$search，则返回该元素的所有键名构成的数组。
示例
{% highlight php %}
<?php
$arr= [
    'a' => 1,
    'b' => 1,
    'c' => 2,
    'd' => 1
];
print_r(array_keys($arr));
print_r(array_keys($arr, 1));
{% endhighlight %}

### array_rand
{% highlight php %}
mixed array_rand ( array $array [, int $num = 1 ] )
{% endhighlight %}
返回数组中随机的一个或多个元素

### array_merge
{% highlight php %}
array array_merge ( array $array1 [, array $... ] )
{% endhighlight %}
合并两个或多个数组，后面的元素累积在之前的数组，如果键名是字符串，则之后重复键名的值会覆盖之前的。比较坑的是'1'算数字键名。和1同。
示例
{% highlight php %}
<?php
$a = [1, 'a' => 2,3,4,5];
$b = ['a', 'a' => 'b', 'c', 'e'];
$c = [0 => 'c1', '1' => 'c2'];
print_r(array_merge($a,$b,$c));
/*
[0] => 1
[a] => b
[1] => 3
[2] => 4
[3] => 5
[4] => a
[5] => c
[6] => e
[7] => c1
[8] => c2
*/
{% endhighlight %}

### array_column
{% highlight php %}
array array_column ( array $input , mixed $column_key [, mixed $index_key = null ] )
{% endhighlight %}
返回$input中对应$column_key键名的值数组，如果指定了$index_key，则$index_key键对应的值作为返回值得键。

### array_filter
{% highlight php %}
array array_filter ( array $array [, callable $callback [, int $flag = 0 ]] )
{% endhighlight %}
返回$callback过滤后的数组。
示例
{% highlight php %}
<?php
$a = [1, 'a' => 2,3,4,5];
print_r(array_filter($a,function($ele) {
    return ($ele > 3);
})); /* [ 2 => 4, 3 => 5],保持键名 */
{% endhighlight %}

### array_unique
{% highlight php %}
array array_unique ( array $array [, int $sort_flags = SORT_STRING ] )
{% endhighlight %}
去掉数组中重复值。$sort_flags可选，对结果排序。
参数
{% highlight php %}
$sort_flags
SORT_REGULAR 常规比较
SORT_NUMERIC 按照数字进行比较
SORT_STRING 作为字符串比较
SORT_LOCALE_STRING 基于本地设置
{% endhighlight %}

### array_unshift
{% highlight php %}
int array_unshift ( array &$array , mixed $value1 [, mixed $... ] )
{% endhighlight %}
将给定的元素前插至数组中。所有的数字索引会从0开始重新索引。

### array_intersect
{% highlight php %}
array array_intersect ( array $array1 , array $array2 [, array $... ] )
{% endhighlight %}
以$array1为标准，返回这些数组中共同的元素。保持键名。
示例
{% highlight php %}
<?php
$a = ['a', 'b', 100 => 'c'];
$b = ['c', 'd', 'e'];
$c = ['f'];
print_r(array_intersect($a, $b)); /* [100 => 'c'] */
{% endhighlight %}

### 其他数组相关
ksort(array &$arr, int $flag)
对数组按照键名排序，排序方式可选

usort(array &$arr, callback $call)
对数组按照指定的函数排序

$arr=$arr1+$arr2+...

以$arr1为标准，后面出现键名相同的元素被舍弃。其他的进行追加。注意和array_merge的区别。一个是覆盖一个是舍弃。

示例
{% highlight php %}
<?php
$a = ['a' => 1,'b' => 2,'c' => 3,4,5];
$b = ['a' => 'a', 'b' => 'b', 'c' => 'c'];
print_r($a + $b); /* ['a' => 1, 'b' => 2, 'c' => 3, 4, 5] */
print_r(array_merge($a, $b)); /* ['a' => 'a', 'b' => 'b', 'c' => 'c', 4, 5] */
{% endhighlight %}
