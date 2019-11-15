---
layout: post
title: "Go reflect学习"
date:   2019-11-14 22:00:00 +0800
categories: golang
---
反射提供了一种通过类型来检查自己数据结构的能力，它属于元编程的一种。各个语言实现反射的机制不同，有的语言或许还不支持反射。Go语言实现了运行时反射。

反射通常在很多框架中用到，主要是因为框架底层需要动态去获取数据类型，构造对象等。例如PHP框架`laravel`中的依赖注入，Go语言中的`json`包等。

鉴于目前Go语言没有泛型，Go语言中的反射赋予了它某种动态能力。例如，要实现一个通用的数组查找元素的方法，如果不使用反射，该如何实现呢？首先摆在面前的，就是函数参数类型的问题。Go语言的强类型使得我们没办法去定义一个通用的函数，接收不同类型的数组。看看如果使用反射，可以怎么实现。

{% highlight go %}
package main

func InArray(e interface{}, arr interface{}) (bool, int) {
    p := reflect.ValueOf(arr)
    switch p.Kind() {
    default:
        panic("not array or slice")
    case reflect.Slice, reflect.Array:break
    }
    for i := 0 ; i < p.Len(); i++ {
        if p.Index(i).Interface() == e {
            return true, i
        }
    }

    return false, -1
}

func main() {
    ok, idx := InArray("hello", []string{"hello", "hah"})
    fmt.Println(ok, idx)
}
{% endhighlight %}

## 反射基础

因为反射是基于类型系统，所以这里再来认识下Go中的类型。

{% highlight go %}
type myInt int 
var i int
var j myInt
{% endhighlight %}

对于如上的示例，i的类型是int，j的类型是myInt。尽管他们的底层都是int，但是i和j是不同的类型，所以他们不能相互赋值，除非进行强制类型转换。

另一个Go中比较重要的类型就是`interface{}`。对于任何实现了接口方法的类型，他就可以转换成该接口类型。接口类型底层存储了两个信息(value, type)。前者是该接口接收的复合数据值，后者是值对应的类型。举个例子

{% highlight go %}
package main

import (
    "fmt"
    "reflect"
)

type A interface {
    Hello()
}

type B interface {
    Hello()
}

type myInt int
func (i myInt) Hello() {
    fmt.Printf("i am int %d \n", i)
}

func main() {
    var i myInt = 10
    i.Hello()
    var a A; a = i
    a.Hello()
    fmt.Println(reflect.TypeOf(a), reflect.ValueOf(a))
    var b B; b = a.(B)
    b.Hello()
    fmt.Println(reflect.TypeOf(b), reflect.ValueOf(b))
}
{% endhighlight %}

myInt实现了A，B两个接口。当执行`a = i`时，接口类型a底层存储的是(10, myInt)。然后，因为myInt同样实现了接口B，因此，这里可以将a转换成接口B赋值给b。同样的，b底层存储的依然是(10, myInt)。

说到这里，就涉及到`interface{}`空接口类型了。空接口不包含任何方法，因此可以认为任何类型都实现了空接口。这也就是为什么空接口可以接收任何类型数据的原因。同样，我们将上面的b转换成空接口，看看底层信息。

{% highlight go %}
var c interface{}; c = b
fmt.Println(reflect.TypeOf(c), reflect.ValueOf(c))
{% endhighlight %}

结果依然是(10, myInt)。再次印证了，接口底层的存储。

## 反射三个能力

文档上说的是反射的3个法则，我觉得理解成能力更好一些，反射可以做到什么。

### 反射可以将接口值转成反射对象

前面说了，接口底层存储两个信息(value, type)。反射提供了两个方法来获取接口值对应的这两个信息：`reflect.ValueOf`和`reflect.TypeOf`。这两个方法都接收一个接口参数。他们的返回值对应反射中的两个重要对象：`reflect.Value`和`reflect.Type`。看个示例

{% highlight go %}
var s string
s = "hello world"
fmt.Println(reflect.TypeOf(s), reflect.ValueOf(s).String())
{% endhighlight %}

typeOf方法接收一个接口参数。Go语言中，除了map, chan等少数几个类型，其他的类型都是按值传递的。因此，这里会首先将s转换成接口类型。可以看到，这个接口类型展示了接收到的值的类型和数据。

### 反射可以将反射对象转换成接口值

上面介绍了将(接口值)->(反射对象)。同样的，反射也支持(反射对象)->(接口值)。这样看起来就圆满了很多。

{% highlight go %}
func (v Value) Interface() interface{}
{% endhighlight %}

反射提供了上面这个方法，支持上述的转换。转换成接口类型后，如果知道初始类型，那么可以很方便的还原一个数据了

{% highlight go %}
var s string
s = "hello world"
si := reflect.ValueOf(s).Interface().(string)
fmt.Println(si)
{% endhighlight %}

额外补充一下，这里`fmt.Println(reflect.ValueOf(s))`也是可以正确打印出来的。原因是fmt.Println接收interface{}参数。层层跟进，发现最后打印时，接口体的输出值刚好是`reflect.Value`类型！

### 要改变一个反射对象，该值必须能够被设置

这个规则的原话是`...value must be settable`。`settable`是反射底层一个很重要的标志。用于判断该值能够被修改，看一个例子

{% highlight go %}
rr := "hello world"
fmt.Println(reflect.ValueOf(rr).CanSet()) // false
reflect.ValueOf(rr).SetString("lol")
fmt.Println(rr)

// `panic: reflect: reflect.flag.mustBeAssignable using unaddressable value`
{% endhighlight %}

为什么修改这个值报错了呢？其实他们的机制类似于指针。我们知道，将一个变量赋值给另一个变量，修改另一个变量并不会改变初始的值。如果要修改初始的值，必须用到指针。反射也是如此。当调用`reflect.ValueOf(rr)`时，函数会复制一份rr的值，然后转换成`interface{}`类型。也就是反射操作的是副本，并不知道原始数据的真实地址，这就是报错`不可寻址`的原因。所以，要利用反射修改初始值，我们需要传递指针

{% highlight go %}
rr := "hello world"
rf := reflect.ValueOf(&rr)
fmt.Println(reflect.ValueOf(&rr), reflect.TypeOf(&rr)) // 0xc000088040 *string
fmt.Println(rf.CanSet()) // false
rf.SetString("lol")
fmt.Println(rr)

// `panic`: ...
{% endhighlight %}

这里传递指针依然不行，为什么呢？这里接口底层的存储(0xc000088040, *string)。我们这里修改的是rf的值，事实上，我们要修改的是*rf指向的值。使用`Elem()`方法可以获取指针指向的值。

{% highlight go %}
rr := "hello world"
rf := reflect.ValueOf(&rr).Elem()
fmt.Println(reflect.ValueOf(&rr).Elem(), reflect.TypeOf(&rr).Elem()) // hello world, string
fmt.Println(rf.CanSet()) // true
rf.SetString("lol")
fmt.Println(rr) // lol
{% endhighlight %}

#### struct

前面的string都是基础的变量，对于struct这种复杂类型的变量，反射同样提供了一些方法来修改它的值。来个示例

{% highlight go %}
package main

import (
    "fmt"
    "reflect"
)

type R struct {
    Name     string     `json:"name"`
    Age      int        `json:"age"`
}

func main() {
    r := R{
        Name: "peter",
        Age:  26,
    }

    // 打印该结构体类型
    rf := reflect.TypeOf(r)
    for i :=0; i < rf.NumField(); i++ {
        field := rf.Field(i)
        fmt.Println(field.Name, field.Type, field.Tag.Get("json"))
    }

    // 打印该结构体值
    rv := reflect.ValueOf(r)
    for i :=0; i < rf.NumField(); i++ {
        field := rf.Field(i)
        fmt.Println(field.Name, rv.FieldByName(field.Name))
    }

    // 修改结构体的值
    rp := reflect.ValueOf(&r).Elem()
    rp.FieldByName("Name").SetString("aaron")
    fmt.Println(r)
}
{% endhighlight %}

针对map类型，`reflect`包同样提供了很多方法，可以查看文档或者源码了解。

## 最后

`reflect`包里面的数据结构和实现也大致看了下，明白个大概但是不太好说清楚，就不继续深入写了。感兴趣的话，可以深入去看看，还是会有收获的。

反射是一个很重要的特性，如果要开发一个通用的框架，明白里面的一些特性会更方便一些。另外，[这里](https://github.com/a8m/reflect-examples)有大量反射的示例，可以看下有哪些实际的应用。

参考

+ [laws of reflection](https://blog.golang.org/laws-of-reflection)
+ [reflect examples](https://github.com/a8m/reflect-examples)