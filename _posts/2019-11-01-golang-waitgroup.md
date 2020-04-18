---
layout: post
title: "sync.WaitGroup实现原理详解"
date:   2019-10-31 22:00:00 +0800
categories: golang
---
`sync.WaitGroup`是官方提供的一个包，用于控制协程同步。通常场景，我们需要等待一组协程都执行完成以后，做后面的处理。如果不使用这个包的话，可能会像下面这样去实现

{% highlight go %}
package main

import "fmt"

const SIZE = 3

func main() {
    ch := make(chan int, 3)
    for i := 0;i<SIZE;i++ {
        go func(i int) {
            ch <- i
        }(i)
    }
    for i := 0;i<SIZE;i++ {
        fmt.Println(<- ch)
    }
}
{% endhighlight %}

使用for-select也是可以的。接着，看下使用官方提供的包可以怎么做

{% highlight go %}
package main

import (
    "fmt"
    "sync"
)

func main() {
    wg := sync.WaitGroup{}
    for i := 0;i<3;i++ {
        wg.Add(1)
        go func(i int) {
            fmt.Printf("hello %d \n", i)
            wg.Done()
        }(i)
    }
    wg.Wait()
}
{% endhighlight %}

对比下，下面的方式更加简单，便于理解。那么问题来了，`sync.WaitGroup`是怎么实现协程同步的呢？跳转到包的定义，发现这个包实现很简单，100多行的代码，于是学习了下。

## 实现思路
`sync.WaitGroup`底层是使用计数器和信号量来实现同步的。

首先介绍两个函数

> runtime_Semacquire(s \*uint32)  
> 此函数会阻塞直到信号量\*s的值大于0，然后原子减这个值。 
> 
> runtime_Semrelease(s \*uint32, lifo bool, skipframes int)   
> 此函数执行原子增信号量的值，然后通知被runtime_Semacquire阻塞的协程，一种简单的唤醒策略。

具体的实现思路是：

有两个计数器: 等待协程数`v`，等待计数器`w`。

当执行`Add(n)`操作时，`v`加上传入的值，通常是1，表明有一个协程需要等待。

当执行`Wait`操作时，里面有一个死循环，会判断`v`的值是否为0。如果是，则表明等待的协程都执行完了，退出；如果不是0，则会将`w`计数器的值加1，执行`runtime_Semacquire`阻塞协程，减信号量。

当执行`Done`时，其本质是执行`Add(-1)`，这时候，将`v`减1。如果减了以后，`v`依然大于0，表明还有协程没完成，退出。否则，表明所有的协程都执行完成了，这时候会根据`w`数量，执行`runtime_Semrelease`加信号量。和前面的`runtime_Semacquire`方法一增一减，来控制等待，告知所有执行`Wait`阻塞的协程执行完毕了。

大致思路就是如此，如果没有理解，也没关系，可以结合下面的实现细节来看。

接下来看下这100多行代码实现的细节。说实话，看的比较吃力，但是都弄清楚了，还是非常有收获的。

## 实现细节

### 前置知识

在开始之前，先熟悉几个知识点

#### 内存对齐

首先，思考下，对于如下的结构体，占用的内存是多少呢？

{% highlight go %}
package main

import (
    "fmt"
    "unsafe"
)

type T struct {
    a byte // byte类型占用1个字节
    b int32 // int32占用4个字节
    c int8 // int8占用1个字节
}

func main() {
    t := T{}
    fmt.Printf("t size : %d, aligh = %d\n", unsafe.Sizeof(t), unsafe.Alignof(t))
}

{% endhighlight %}

按照各个类型占用的大小相加，1+4+1=6，可能会得出这个结构体占用6个字节的结论。然而实际上不是的，最终输出的结果是12！

这就是内存对齐导致的。内存读取不是一个字节一个字节读取的，而是一块一块读取的。假设一个变量占2个字节，内存一次读取4个字节，如果不使用内存对齐的话，在访问该变量时，读取4个字节后，另外2个字节还需要额外剔除掉，这就会对性能造成一点点影响。如果执行内存对齐，则填充2个字节，只需要访问一次，不需要额外操作就可以获取该变量了。

所以，看到这，应该会对内存对齐有点小感兴趣了。操作系统读取内存块的大小称为访问粒度，不同系统不一样；内存对齐的系数也是如此。上面代码打印出来的补齐系数是4字节，byte变量占用1个字节，因为b变量占用4个字节，不需要对齐，因此，会给a变量填充3个字节。如下就是这个结构体的内存布局

![图片]({{ site.url }}/assert/imgs/wg_1.png)

这就是这个结构体占用12个字节的原因。可以试试改变a和b的顺序，看看结构体的内存占用！这也是开发中一个优化点，将占用小的变量放结构体前面。内存管理的学问很深呀。

#### 数组和unsafe.Pointer

我们知道，数组在内存中是一个连续的内存块。对于这么一个变量`[3]int32{1,2,3}`，在内存中是这样的

{% highlight text %}
# 3 * 32位    
000...001   000...010   000...100      
{% endhighlight %}

然后再来了解`unsafe.Pointer`这个类型。这个东西很神奇，看文档介绍

> + 任何指针类型都可以转换成Pointer 
> + Pointer可以转换成任意的指针类型
> + uintptr可以被转化为Pointer 
> + Pointer可以被转化为uintptr

后两个不管，看前两点，Pointer可以转换成任意指针类型。试试如下代码

{% highlight go %}
a := [3]int32{1,2,3}
b := (*uint64)(unsafe.Pointer(&a))
fmt.Println(*b) // 8589934593: 000...001  000...010
{% endhighlight %}

神奇之处在于，我们凭空构造了一个指向内存中64位数据的uint64指针，真正的直接操作内存。看到这里，我试了下，能否直接定义一个*uint64，指向这个数组的地址，然后得到相同的结果呢？

{% highlight go %}
a := [3]int32{1,2,3}
var c *uint64 = &a // 报错了
{% endhighlight %}

最后答案是不可以的，报错了，不同指针类型不能相互转换。

#### CAS(比较交换，compare and swap)原子操作

摘自wiki[比较并交换](https://zh.wikipedia.org/wiki/%E6%AF%94%E8%BE%83%E5%B9%B6%E4%BA%A4%E6%8D%A2)

> 原子操作的一种，可用于在多线程编程中实现不被打断的数据交换操作，从而避免多线程同时改写某一数据时由于执行顺序不确定性以及中断的不可预知性产生的数据不一致问题。 该操作通过将内存中的值与指定数据进行比较，当数值一样时将内存中的数据替换为新的值。

#### 位运算

位运算应该算是一个基础知识，但是自己学习时总是会忽略，因为自己开发中用的很少。这里，再捡起来学习一下。

{% highlight go %}
package main

import "fmt"

func main() {
    var a uint8 = 3

    fmt.Println(a >> 1) // 1
    fmt.Println(a << 1) // 6
}
{% endhighlight %}

### 实现细节

`sync.WaitGroup`结构体定义如下

{% highlight go %}
type WaitGroup struct {
    noCopy noCopy // 防止copy

    // 64位值: 高32位是协程计数器，低32位是等待计数器
    // 64位原子操作需要满足64位对齐，32位比编译器不能保证这点。
    // 因此，分配12字节128位。对齐的8个字节作为上面的计数器状态值，另外的4个字节存储信号量。
    // 因此，可以看出，Go中允许的协程总数是2^32个。
    state1 [3]uint32
}
{% endhighlight %}

这个结构体定义是优化过的，原先的结构体定义如下，

{% highlight go %}
type WaitGroup struct {
    noCopy noCopy // 防止copy
    
    state1 [12]byte
    sema   uint32
}
{% endhighlight %}

原先使用了12字节数组来存储状态信息，其中8字节用于64位对齐，另外4个字节浪费了。因此，在后来的版本中被优化了。具体的说明参见[这里](https://github.com/golang/go/issues/19149)。

接着是，获取状态值函数，函数返回状态值和信号量。用到了之前提到的点，根据数组的64位数据构造了一个uint64指针。

> 不同系统，数据存储顺序不同        
> 64位系统: (等待计数器)(协程计数器)(信号量)               
> 其他: (信号量)(等待计数器)(协程计数器)    

{% highlight go %}
func (wg *WaitGroup) state() (statep *uint64, semap *uint32) {
    if uintptr(unsafe.Pointer(&wg.state1))%8 == 0 {
        return (*uint64)(unsafe.Pointer(&wg.state1)), &wg.state1[2]
    } else {
        return (*uint64)(unsafe.Pointer(&wg.state1[1])), &wg.state1[0]
    }
}
{% endhighlight %}

然后，看下`Add`函数的实现，这里跳过里面关于`race`部分。完整的实现如下

{% highlight go %}
func (wg *WaitGroup) Add(delta int) {
    // 获取状态值和信号量
    statep, semap := wg.state()
    
    // 原子操作，这里的位操作是将delta，加到高位，也就是协程计数器上。
    state := atomic.AddUint64(statep, uint64(delta)<<32)
    v := int32(state >> 32) // v是协程计数器
    w := uint32(state) // w是等待计数器
    
    // 如果协程计数器小于0，报错。
    if v < 0 {
        panic("sync: negative WaitGroup counter")
    }
    
    // 如果等待计数器不等于0，表明已经有Wait调用在等待，此时，再调Add会报错
    if w != 0 && delta > 0 && v == int32(delta) {
        panic("sync: WaitGroup misuse: Add called concurrently with Wait")
    }
    
    // 如果协程计数器大于0，表明，执行Add添加操作，直接返回
    // 或者等待计数器等于0，可以直接退出。
    if v > 0 || w == 0 {
        return
    }
    
    // 能走到这里，一般是最后一个Done执行。这里不等，就可能出现了并发调用导致状态不一致。
    if *statep != state {
        panic("sync: WaitGroup misuse: Add called concurrently with Wait")
    }

    // 将等待计数器清0
    *statep = 0
    
    // 根据等待计数器的数量，发送N次信号量加操作
    // 如果这里semap等于0了，则阻塞的wait方法会监听到，然后重新检查协程是否全部执行完毕，最后退出
    for ; w != 0; w-- {
        runtime_Semrelease(semap, false, 0)
    }
}
{% endhighlight %}

`Done`方法就不介绍了，他执行的就是`Add(-1)`。

最后，看下`Wait`方法的实现

{% highlight go %}
func (wg *WaitGroup) Wait() {
    // 获取状态
    statep, semap := wg.state()

    for {
        // 原子获取状态值
        state := atomic.LoadUint64(statep)
        v := int32(state >> 32) // 获取协程计数器
        w := uint32(state) // 获取等待计数器
        
        // 协程计数器为0，表明都执行完了，这里退出
        if v == 0 { 
            return
        }
        
        // cas，将等待计数器+1
        // wait操作是可以在多个协程中同时并发存在的。
        if atomic.CompareAndSwapUint64(statep, state, state+1) {
            // 就是在这里阻塞，等待信号量大于0以后，会执行下面操作
            runtime_Semacquire(semap)
            if *statep != 0 {
                panic("sync: WaitGroup is reused before previous Wait has returned")
            }
            return
        }
    }
}
{% endhighlight %}

如上，就是整个`sync.WaitGroup`包实现原理。

参考资料

+ [Golang内存对齐](https://ms2008.github.io/2019/08/01/golang-memory-alignment/)
+ [内存布局工具](http://golang-sizeof.tips/?t=Ly8gU2FtcGxlIGNvZGUKc3RydWN0IHsKCWEgYnl0ZQoJYiBpbnQzMgoJYyBpbnQ4Cn0K)