---
layout: post
title: "实现一个Vue无限加载插件"
date:   2017-04-07 10:00:00 +0800
categories: web
---

## 概述
前端开发中，有很多通用的组件。上拉无限加载就是其中一个。无限加载常用在长列表上，相比于传统的分页方式，无限加载更智能，体验更胜一筹。当然，开发复杂性上，也更高一点。网上已经有很多对应的插件了，这里，说下无限加载的原理，并实践开发一个对应的Vue组件。

## 基础知识
无限加载是这样工作的，用户浏览列表，滚动到容器的底部时，自动触发自定义的事件，请求新的数据。然后，插入到页面之中，不断的如此循环。

根据上面的简单说明，这里，关键点就在于怎么判断到达底部？有这么一个公式

> 滚动的高度 + 容器的高度 == 整个内容的高度

根据这个，我们就可以判断出，当前滚动到底了。下面，实际开发一个例子。

## 一个滚动例子
无限加载有两个场景，一种是，滚动的元素是DOM的某一个容器；另一种是，滚动的是整个页面。这两者，在获取上面提到的距离，有一定的差异性。

<iframe width="100%" height="300" src="//jsrun.pro/D9kKp/embedded/all/light/" allowfullscreen="allowfullscreen" frameborder="0"></iframe>

简单说明下，其中用到的三个高度值，具体指的是啥子高度

![图片]({{ site.url }}/assert/imgs/is.jpg)

简要说明

+ `ele.scrollHeight` 文档的整个高度
+ `ele.scrollTop,window.scrollY` 文档滚动的高度
+ `ele.offsetHeight,window.innerHeight` 容器的高度，包含border,scrollBar
+ `ele.clientHeight`  不包含border,scrollBar的容器高度

## Vue插件
实现一个无限加载的插件，需要暴露给外界的接口是，滚动的元素，当前状态，滚动到底的事件处理。很简单。
 
[代码看这里](https://github.com/aaronzjc/Personal_Toys/tree/master/BlogDemos/InfiniteScroll)
