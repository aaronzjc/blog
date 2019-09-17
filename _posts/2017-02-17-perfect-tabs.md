---
layout: post
title: "实现一个灵活的Vue Tab组件"
date:   2017-03-18 10:00:00 +0800
categories: web
---
## 概述
在web开发中，Tab的应用很广泛。分类显示的条目，大多使用Tab布局。封装一个灵活的Tab组件，可以减轻很多重复性的工作。

一个好的Tab组件封装，应该是可以自定义Tab分类的个数的。Tab项的内容也应该是能够自定义的，这样才能应对不同的场景。我在封装这么一个Vue Tab组件中，应用到的知识是Flex布局，和Vue组件slot。

## Tab结构
首先，自己定义一个Tab的DOM结构。

一个完美的Tab显示，应该是Tab的各个项宽度一样。因为Tab项的个数不一定，用普通的float等方式，宽度不太好控制。利用Flex布局，可以很完美的实现这样的效果，最后的代码和效果如下

<iframe width="100%" height="300" src="//jsrun.net/p4pKp/embedded/html,css,result/light/" allowfullscreen="allowfullscreen" frameborder="0"></iframe>

## 封装成Vue组件
很容易就想到一个Tab组件涉及的逻辑。外层传递一个Tab项的列表给这个组件，组件渲染结果，点击Tab项，切换不同的Tab。初步的封装，代码如下

{% highlight xml %}
<template id="super-tab">
<div class="super-tab">
   <div class="tab-item" v-for="tab,index in tabs" @click="tabSwitch(index)" :class="{'on': active == tab.id}>
       <div class="tab-item-content"><div>{{ tab.text }}</div></div>
   </div>
</div>
</template>
<script>
var VTab = Vue.extend({
    template: "#super-tab",
    props: ["tabs", "current"],
    data: function(){
        return {
            active: 0,
        };
    },
    created: function() {
        this.active = this.current;
    },
    methods: {
        tabSwitch: function(index) {
            this.$emit('tab-switch', {index: index}); // 通知外层
        }
    }
});
</script>
{% endhighlight %}

## 进一步思考
上面的代码封装了一个基础的Tab，能够满足一定的场景了。但是可配置性很弱。例如，一个Tab可能是上图标，下文字的形式；又或者，是两行文字的形式。因此，最好是能够让tab-item-content的这一部分自定义。

这里，就用到了Vue提供的slot。slot可以当做一个插槽，具体内容等用户传入即可。但是，slot的内容又和tab选项有关，所以，这里，需要将tabs遍历的tab项当做属性传递给slot。

因此，改良之后的Tab如下

{% highlight xml %}
<template id="super-tab">
<div class="super-tab">
   <div class="tab-item" v-for="tab,index in tabs" @click="tabSwitch(index)" :class="{'on': active == tab.id}">
       <div class="tab-item-content">
           <slot name="item" :tab="tab"><div>{{ tab.text }}</div></slot>
       </div>
   </div>
</div>
</template>
<script>
// No Changes
</script>
{% endhighlight %}

实际应用，是这样的

{% highlight xml %}
<v-tab :tabs="tabs" :current="current">
    <template slot="item" scope="props">
        <div class="icon" :class="[props.tab.icon]"></div>
        <div class="title">{{ props.tab.text }}</div>
    </template>
</v-tab>
{% endhighlight %}

至此，一个扩展性良好的Tab组件就完成了。

示例代码: [在这里](https://github.com/aaronzjc/Personal_Toys/tree/master/BlogDemos/Tab)
