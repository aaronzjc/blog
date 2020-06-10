---
layout: post
title: "Innodb索引"
date:   2020-06-09 20:00:00 +0800
categories: devops
---

> 能介绍下`Innodb`的索引结构吗？

每个后端开发，不管面试还是被面试，基本都聊过这个问题。只要稍有准备，大部分人都能说的出来。

> Innodb使用B+树作为索引结构。只有叶子节点存储数据，叶子节点组成一个循环链表，方便遍历。
>
> 索引又分为聚簇索引和非聚簇索引。Innodb默认会根据主键生成聚簇索引，如果不存在主键，则会选择第一个唯一非空索引作为聚簇索引。如果不存在唯一索引，则会生成一个隐藏的主键作为聚簇索引。Innodb的数据存储在聚簇索引的叶子节点。非聚簇索引存储的是主键的值，首先找到主键，然后再去聚簇索引查找数据。
> 
> 索引满足最左匹配原则。

如果不能立刻想到这些内容，可能就得去复习复习了。

很久一段时间，自己是把这些内容当做一个知识来学习。并没有去深层次的追究底层。为什么索引有最左匹配原则？聚簇索引和非聚簇索引真如上面说的吗？于是，花一点时间实践了下。

MySQL中，页是最小的磁盘操作单位。页默认大小是16K，可以调整参数修改。如上所说，`Innodb`使用B+树作为索引结构。B+树是一种平衡树，查找效率非常高。每个B+树叶子节点对应一个数据页，每页可存储多条数据记录。B+树的每次查询，也是查询到指定的页，然后将页载入内存，最终查到想要的数据。

`最左匹配`是指B+树中查找时，进行比较的逻辑。例如对于(a, b, c)这样一个联合索引，可以简单理解，B+树的键即是`abc`三个字段的值的拼接。当进行查找的时候，匹配的顺序自然先比较a字段，然后比较b和c。

对于`不等于`和`like "%"`这些情况，因为其进行扫描的时候会覆盖到绝大部分索引数据。这时候通过索引去查数据，不如直接在聚簇索引上遍历来的快，所以也不一定会用到索引。

接下来，分析表数据文件，看看是不是真的如此。

首先，按照如下的建表语句建表，包含一个主键索引和一个联合索引

{% highlight sql %}
CREATE TABLE `test` (
`id` int(11) unsigned NOT NULL AUTO_INCREMENT,
`name` varchar(64) DEFAULT NULL,
`age` varchar(11) DEFAULT NULL,
`phone` char(11) DEFAULT NULL,
PRIMARY KEY (`id`),
KEY `name_phone_idx` (`name`,`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
{% endhighlight %}

然后写个脚本，插入一些数据

{% highlight php %}
<?php
$pdo = new PDO("mysql:dbname=mu;host=127.0.0.1;port=3307", "root", "root");
$sql = "insert into test(`name`, `age`, `phone`) value (?,?,?)";
$st = $pdo->prepare($sql);
for ($i=0;$i<100;$i++) {
    $st->execute(["user_" . $i, "age_" . $i, "13111111111" + $i]);
}
{% endhighlight %}

MySQL的表数据文件通常放在`/var/lib/mysql/table_name`里面，后缀是`ibd`。使用16进制编辑器打开测试表的表数据文件。

`0xc000`的位置，即为数据页开始的地方。观察下图

![图片]({{ site.url }}/assert/imgs/innodb_1.png)

小框标记的16进制数，转成10进制，即是我们表中的主键值。后面跟着的一串就是`(name, age, phone)`字段的值，可以看到，就是简单的顺序存储。主键索引没有什么复杂的了。

继续往下找，可以找到非聚簇索引存储的值

![图片]({{ site.url }}/assert/imgs/innodb_2.png)

和聚簇索引类似的存储结构。不过这时候键是`(name, phone)`两个字段的拼接。小红框的值转成10进制，就是对应的主键ID值。所以，联合索引在进行查找的时候，确实按照字段的顺序来的。

关于索引的内容就介绍到这。

其实还有很多更深的知识。例如，文章提到的`0xc000`是数据页开始的位置，`Innodb`的数据存储结构是如何的呢。这些都可以了解了解。

参考资料

+ 《MySQL技术内幕: Innodb存储引擎》
+ [分析数据文件的工具](https://github.com/qingdengyue/david-mysql-tools)