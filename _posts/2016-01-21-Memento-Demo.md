---
layout: post
title: "备忘录模式及实战"
date:   2016-01-21 15:42:00 +0800
categories: web 技能
---
## 前言

前段日子，学习了设计模式相关的知识，了解了一些好玩的设计模式的思路和方式。然后，刚好最近遇到了一个需求，灵机一动想到了这个设计模式，然后实践了一次，挺不错的。

## 备忘录模式

在不改变对象内部状态的情况下，保存对象的状态，以便可以随时恢复相应的状态。

听起来十分的复杂，公式化。最简单明显的一个例子就是编辑器。编辑器可以打开文件进行编辑，然后编辑错了按下Ctrl+Z就可以后退到之前的编辑状态。特别神奇。理论上，在开发中有很多东西可以理解为一个对象，例如下面提到的图表。一个图表就是一个对象，展示的数据就是一个状态，当进行处理后，展示的数据动态更新了，也就是对应于状态改变。依次思路，就可以结合备忘录模式做一些事情了。还是先看备忘录模式的介绍吧。

### 主要角色

* 发起人(Originator): 创建一个备忘录对象管理器。并保存当前内部状态对象至备忘录管理器。
* 备忘录(Memento): 存储原始对象的内部状态。
* 备忘录管理器(CareTaker):  保存备忘录。

### 类图

略[见这里](http://nonfu.me/p/11458.html)

## PHP实例

关键点就是在对象内部设置一个备忘录管理器对象，然后实现存储状态和恢复状态。
{% highlight php %}
<?php
class Original {
    public $state = '';
    public $careTaker = NULL;
    public function __construct($state, $careTake){
        $this->state = $state;
        $this->careTaker = $careTake;
    }
    public function addMemento() {
        echo "Save " . $this->state . "\n";
        $this->careTaker->addMem(new Memento($this->state));
    }
    public function setMemento() {
        if ($mem = $this->careTaker->getMem()) {
            $this->state = $mem->getState();
        } else {
            echo 'Failed, reach the original state !' . "\n";
        }
    }
    public function editState($state) {
        //echo 'Set state ' . $state . "\n";
        $this->state = $state;
    }
    public function getState() {
        return $this->state;
    }
}
// 备忘录
class Memento{
    private $state = '';
    public function __construct($state) {
        $this->state = $state;
    }
    public function getState() {
        return $this->state;
    }
}
// 备忘录管理器
class CareTake{
    private $memList = array();
    public function addMem($mem) {
        $this->memList[] = $mem;
    }
    public function getMem() {
        return array_pop($this->memList);
    }
}
$careTake = new CareTake(); // 管理器
$origin = new Original('one', $careTake);  // 打开一个文件
$origin->addMemento(); // 初始状态,保存
$origin->editState('second'); // 编辑了第一次
$origin->addMemento(); // 保存
$origin->editState('third'); // 编辑第二次
$origin->addMemento(); // 保存
$origin->editState('four');
// 下面用户不断的回退
$origin->setMemento(); // 回退一次
echo 'First Ctrl+z : ' . $origin->getState() . "\n";
$origin->setMemento(); // 回退二次
echo 'Second Ctrl+z : ' . $origin->getState() . "\n";
$origin->setMemento(); // 回退三次, 回到原始状态
echo 'Third Ctrl+z : ' . $origin->getState() . "\n";
$origin->setMemento(); // 回退四次, 应该后退失败
echo 'Four Ctrl+z : ' . $origin->getState() . "\n";
{% endhighlight %}
如上就是PHP实现的简单的例子。之前也是，做到这里就没了。后来实际开发中，遇到一个需求，想到用备忘录模式是最合适不过了。

## 备忘录实例

在使用ECharts展示数据时，想到这么一个需求。初始时，有一个饼状图表，展示各个城市的订单情况，然后，用户期望点击饼图的中的各个城市，能够查看这个
城市的订单具体是那些平台的订单；这还没有完，用户很自然的会想，我点一下这个平台，得看一下这个平台下都是那些订单。然后，这之后具体能深入到第几层就看情况了。用户看完之后，如果整个页面只有这么一个图表，想回退的话，刷新一下浏览器就回退了。但是，做开发得考虑用户体验。所以，得提供一个回退功能，用户点一下，回退一次。

所以整个就是这么一个需求。用备忘录确实很合适。首先，复用一个图表对象，可以看做原始对象。然后，图表展示不同的内容，可以看做不同的状态。这样，就只需要考虑什么时候，保存状态，什么时候回退状态即可。下面是实际的效果(使用Chrome播放)。

<div class="video">
<video src="{{ site.url }}/assert/medias/echarts2.0.mov" controls="controls">
your browser does not support the video tag
</video>
</div>
主要代码如下
{% highlight javascript %}
function MeChart(ele) {
    var self = this;  // 保护this变量
    this.ele = ele;  // 初始化的DOM元素
    this.option = null;  // 当前设置的option，状态。
    this.charts = null;
    this.box = {
        mem:new Array(),  // 备忘录，option数组，栈
        addMem:function(){  // 添加备忘录
            this.mem.push(self.option);
        },
        getMem:function(){  // 获取前一个’状态’
            var e = this.mem.pop();
            return e?e:false;
        }
    };
    this.init = function () {
        self.charts = echarts.init(self.ele);
    };
    this.addMem = function () {  // 添加状态至备忘录
        self.box.addMem();
    };
    this.backSet = function () {  // 回退，恢复状态
        console.log(self);
        var memo = self.box.getMem();
        if (memo != false) {
            console.log(memo);
            self.option = memo;  // 将当前状态添加至当前状态，这里也是必须的
            //self.setOption(self.option);
            self.setOption(memo);
        }
    };
    // 下面是对echarts对象的一个代理。因为备忘录需要在原对象里面植入一个备忘录对象。而
    // echarts对象是引入的。所以，封装一个代理来接管echarts的方法。这个也是设计不合理的地方，因为如果echarts方法很多的话，
    // 我不可能封装全部的方法。但是在这里又是必须这样做的。
    this.hasMem = function() {  // 判断备忘录是否存在
        return self.box.mem.length > 0? true:false;
    };
    this.setOption = function(toption) {
        self.option = toption;
        self.charts.setOption(toption, true);
    };

    // ...
}
{% endhighlight %}

## 最后
完。

查看以下资料了解更多：

* [ECharts 3.0](http://echarts.baidu.com/index.html)
* [PHP设计模式范例](http://designpatternsphp-zh-cn.readthedocs.org/zh_CN/latest/)
* [23种设计模式PHP实现](http://nonfu.me/p/11370.html)
