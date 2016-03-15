---
layout: post
title: "使用Crontab执行计划任务"
date:   2016-03-15 10:00:00 +0800
categories: php
---
## 前言
开发中，很多地方需要使用到计划任务来解决。让程序在某一个时间点执行，或者每天什么时间点执行。例如，用户下单后x分钟内，如果不支付就取消订单；数据统计工作，分解成每天来统计等。这些任务可以通过crontab来解决。

## Crontab命令说明
> crontab
>
> -u 列出用户的crontab任务。例如，sudo crontab -u memosa -l。
>
> -e 编辑crontab任务。
>
> -l 列出用户的crontab任务。
>
> -r 删除当前用户的crontab任务。

### 任务格式说明
crontab任务格式如下
{% highlight plain text %}
minute   hour   day   month   week   command
{% endhighlight %}
crontab使用*和数字来指定时间，图片解释了每个时间的取值。
![crontab]({{ site.url }}/assert/imgs/crontab_1.png)
除了上面的常规数值之外，还可以使用一些特殊字符：
{% highlight plain text %}
*  代表所有的值，不指定时，表示符合该条件的任何一个点。例如，月份不指定时，表示每月都执行。
,  多字段可选。使用逗号隔开时，字段满足列表中的任何一个。
-  表示范围。
/  指定时间的间隔频率。例如，每5分钟执行，*/5。
{% endhighlight %}
对于command，需要是系统可执行的。并且，crontab文件中不允许命令换行，即使很长。

### 几个任务例子
每分钟执行一条命令
{% highlight shell %}
* * * * * /usr/bin/ls
{% endhighlight %}
每天凌晨3点执行php程序
{% highlight shell %}
0 3 * * * /usr/bin/php demp.php
{% endhighlight %}
每月1号和10号早上3点和下午1点，间隔15分钟执行
{% highlight shell %}
*/15 3,13 1,10 * * command
{% endhighlight %}

## 使用
打开终端，输入`crontab -e`，编辑crontab任务。保存后，会出现，`crontab installing new crontab`，表示新建成功。

![crontab_use]({{ site.url }}/assert/imgs/crontab_2.png)

这里，我新建的任务是，列出目录至ls.log文件。
{% highlight shell %}
* * * * * ls > /tmp/
{% endhighlight %}
查看当前用户的任务列表, 以及删除任务。

![crontab_l]({{ site.url }}/assert/imgs/crontab_4.png)

值得注意的是，当有crontab任务执行了，执行后会发送一封邮件给用户。

![crontab_mail]({{ site.url }}/assert/imgs/crontab_3.png)

可以打开`/var/mail/{$user_name}`查看，也可以使用命令`mail`来查看。

## 后续
后台定时任务管理。
