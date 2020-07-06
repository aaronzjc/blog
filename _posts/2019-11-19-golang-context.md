---
layout: post
title: "Go Context深入学习"
date:   2019-11-18 22:00:00 +0800
categories: golang
---
## 介绍

因为Go语言协程的便利性，开发中，经常会启动多个协程来并行的处理任务。例如，M协程里面开启A，B两个协程去处理一些事情。然后B协程在执行时，又启动了另外两个B1，B2协程去做其他的处理。那么问题来了，如果此时，B协程因为一些错误，执行异常或者超时了。后续的B1，B2协程怎么处理呢？我们期望的结果是B1，B2也不执行了。

这样的场景在Web开发中算是比较常见的。通常一个系统可能涉及到调用多个接口服务去处理逻辑，很难保证每个接口都能百分百快速响应。当无法保证稳定性时，只能期望在某一个服务超时时，我们能快速返回，中断后续的执行。如果在普通的过程调用中，可以很好地控制。但是涉及到协程时，就会比较麻烦。看看实现这样的一个超时中断，可以怎么做。

```go
package main

import (
    "fmt"
    "sync"
    "time"
)

var wg = sync.WaitGroup{}

func main() {
    e := make(chan struct{})
    wg.Add(1)

    // 启动一个协程
    go func() {
        defer wg.Done()
        ch := make(chan int)

        // 这里开启一个协程处理耗时的任务，也可以不用开启协程，用同步的方式
        go func() {
            time.Sleep(time.Second*2)
            ch <- 1
            fmt.Println("hello")
        }()
        select {
        case <- ch:        
            fmt.Println("A Done")
        case <- e:
            // 如果收到终止信号，这里不执行任务退出了
            fmt.Println("A Cancel")
        }
    }()

    // 启动一个定时任务，1s后发送终止信号
    time.AfterFunc(time.Second, func() {
        e <- struct{}{}
    })

    wg.Wait()
}
```

上面的例子就是使用通道实现了一个，超时取消后续任务的逻辑。

## Context包

好了。上面介绍了一种开发中的协程控制场景。然后回到正题，对于上述的场景，谷歌官方给出了自己的解决方案，那就是`Context`包。

### 基本用法

先看一个如何使用`Context`包的例子

```go
package main

import (
    "context"
    "fmt"
    "time"
)

func main() {
    // 给main协程设置一个1s超时context
    ctx, _ := context.WithTimeout(context.Background(), time.Second)
    fmt.Println(time.Now().Format("2006-01-02 15:04:05"))

    ch := make(chan struct{})
    go func() {
        time.Sleep(time.Second * 2)
        ch <- struct{}{}
    }()
    select {
    case <- ctx.Done():
        fmt.Println("cancel -1 at " + time.Now().Format("2006-01-02 15:04:05"))
    case <- ch:
        fmt.Println("Done sleep 2s")
    }

    fmt.Println(time.Now().Format("2006-01-02 15:04:05"))
}
```

上面就是使用`context.WithTimeout`设置一个超时`Context`的示例。他会在1秒后关闭`ctx.Done`通道。然后被`select`监听到，执行后续流程。最终`main`执行完毕，退出，其他协程也会终止。

也可以使用`context.WithCancel`设置一个手动取消的`Context`。下面就是，在一个单独的协程中，2s后手动`cancel`

```go
func main() {
    // 给main协程设置一个1s超时context
    ctx, cancel := context.WithCancel(context.Background())
    fmt.Println(time.Now().Format("2006-01-02 15:04:05"))

    // ...

    go func() {
        time.Sleep(time.Second * 2)
        cancel()
    } ()

    select {
    case <- ctx.Done():
        fmt.Printf("cancal at %s\n", dl.Format("2006-01-02 15:04:05"))
    }
    fmt.Println(time.Now().Format("2006-01-02 15:04:05"))
}
```

此时可以看到打印了一个`done sleep 1s`。因为2秒的时间足够执行完这个协程了。

### 提供的方法

`Context`包有如下几个方法用于初始化

+ context.Background

空`Context`。不包含取消方法，一般作为顶层`Context`使用。通常用在`main`函数里面。

+ context.TODO

同`Background`，也是一个空`Context`。当不确定当前应该用什么`Context`时，就用这个。

+ context.WithCancel

返回一个手动取消的`Context`。

+ context.WithTimeout

返回一个超时自动取消的`Context`。接收一个时长参数。

+ context.WithDeadline

依然是超时自动取消，只是参数是截止时间，不是时长。同`WithTimeout`。

+ context.WithValue

可以携带值的`Context`。

### 设计思想

首先，理解一下`协程树`的概念。在开发中，协程调用关系整体而言就像一个树结构。`main`方法中启动几个协程，然后，这几个协程在执行中，可能又会各自启动一些协程，等等。虽然协程没有父子的关系，启动后都是各自独立运行。但是业务逻辑上，是有一定上下游关系的。例如，某个协程执行异常了，其后续的协程往往也不应该执行。

有了树的概念后，就好处理他们的控制关系了。文章开头的例子，就可以构造如下的`协程树`了

![图片](/assert/imgs/context_0.png)

然后再说说，`Context`包是如何控制取消的。其本质和开头的例子并没有区别。每个`Context`，都是一个包含了`done`字段的结构体。`done`字段就是一个无缓存通道。当执行`cancel`方法时，会关闭这个通道。然后，`select`这个通道的阻塞语句就会收到取消的信号，这时候开发人员就可以处理终止流程了。

再看下上图。`B`协程有两个子协程。在初始化时，会将`B1`和`B2`的`Context`记录在`B`的子Context数组中。这样，当`B`收到取消信号时，他自然能够根据子Context数组，去通知`B1`和`B2`取消操作了。

如下是根据上图关系，构造的一个示例

```go
package main

import (
    "context"
    "fmt"
    "sync"
    "time"
)

func LogT(msg string) {
    fmt.Println(time.Now().Format("2006-01-02 15:04:05") + " : " + msg)
}

func ToughJob(s time.Duration, ch chan int, name string) {
    time.Sleep(time.Second * s)
    LogT("job " + name + " Done")
    ch <- 1
}

func A(ctx context.Context) {
    defer wg.Done()
    aCtx, _ := context.WithCancel(ctx)
    fmt.Println("this is A")
    ch := make(chan int)
    go ToughJob(2, ch, "A")

    select {
    case <- ch:
        LogT("A Done")
    case <- aCtx.Done():
        LogT("A Cancel")
    }
}

func B(ctx context.Context) {
    bCtx, cancel := context.WithCancel(ctx)

    fmt.Println("this is B")
    ch := make(chan int)
    go ToughJob(2, ch, "B")

    go func() {
        // time.Sleep(time.Second)
        cancel()
    }()

    select {
    case <- ch:
        LogT("B Done")
        // do B1, B2
        wg.Add(2)
        go Bb(bCtx, "B1")
        go Bb(bCtx, "B2")
    case <- ctx.Done():
        LogT("B Cancel")
        cancel()
    }
    wg.Done()
}

func Bb(ctx context.Context, name string) {
    defer wg.Done()
    fmt.Println("this is " + name)

    select {
    case <- time.After(time.Second * 2):
        LogT("job " + name + " Done")
    case <- ctx.Done():
        LogT(name + " Cancel")
    }
}

var wg = sync.WaitGroup{}

func main() {
    LogT("start")

    ctx, cancel := context.WithCancel(context.Background())
    wg.Add(2)
    go A(ctx)
    go B(ctx)

    //go func() {
    //    time.Sleep(time.Second*3)
    //    cancel()
    //}()

    LogT("end")
    wg.Wait()
}
```

最后在我的电脑输出结果是

```text
2019-11-19 16:56:52 : start
2019-11-19 16:56:52 : end
this is B
this is A
2019-11-19 16:56:54 : job A Done
2019-11-19 16:56:54 : job B Done
2019-11-19 16:56:54 : A Done
2019-11-19 16:56:54 : B Done
this is B2
2019-11-19 16:56:54 : B2 Cancel
this is B1
2019-11-19 16:56:54 : B1 Cancel
```

`A`和`B`各自执行2s。然后`B`在2s执行完后，有一个协程终止后续执行，所以整个程序只执行了2s的时间。可以看到`B1`和`B2`开启后，立刻就结束了。

## 实现原理

前面的示例，应该熟悉了`Context`包是怎么使用，以及广度上的执行原理。接下来看下包源码是怎么实现的。这个包也不复杂，才几百行，所以推荐阅读一下。

鉴于篇幅，很多内容自己看，可能比我表达的更加清晰。所以这里只介绍几个我觉得比较核心的地方。

首先，就是最重要的`Context`接口了

```go
type Context interface {
    // 返回中断截止时间
    Deadline() (deadline time.Time, ok bool)

    // 通道。用于select语句。监听终止信号。一般通道可以是任意类型，使用struct {}类型，是因为空结构体不需要内存。
    Done() <-chan struct{}

    // 终止的原因
    Err() error

    // Context可以携带的值
    Value(key interface{}) interface{}
}
```

上面介绍的`WithTimeout`方法等，返回的各个`Context`结构体，都实现了该接口。一共定义了如下几个`Context`结构体

```go
// 空Context。Background和TODO会返回此类型。它实现的接口方法啥都没干。所以此Context不会终止。
type emptyCtx int

// WithCancel会返回此结构体。比较核心。
type cancelCtx struct {
    Context

    mu       sync.Mutex            // 锁。保护下面的字段，读写安全的
    done     chan struct{}         // 懒初始化。在调用Done方法时初始化。当执行第一个cancel方法时关闭。
    children map[canceler]struct{} // 子协程的Context
    err      error                 // 第一个cancel调用时设置为非nil
}

// 定时Context，WithTimeout和WithDeadline会返回此类型
type timerCtx struct {
    cancelCtx   // 他也包含了cancelCtx
    timer *time.Timer // 定时器

    deadline time.Time // 截止时间
}
```

然后，看看`WithCancel`方法是怎么初始化`Context`结构体的

```go
func newCancelCtx(parent Context) cancelCtx {
    return cancelCtx{Context: parent}
}

// 初始化cancelContext，接收一个父Context作为参数。
func WithCancel(parent Context) (ctx Context, cancel CancelFunc) {
    c := newCancelCtx(parent)
    // 广播cancel
    propagateCancel(parent, &c) 
    // 返回当前初始化的Context，以及当前Context的cancel调用方法
    return &c, func() { c.cancel(true, Canceled) }
}

// 广播cancel。主要是挂载当前Context到父Context下等。
func propagateCancel(parent Context, child canceler) {
    // 如果父Context的done是nil。这里直接返回。说明其父Context是根，父Context永远不会cancel
    if parent.Done() == nil {
        return
    }
    // 这里往上遍历，直到找到父辈的cancelContext。
    if p, ok := parentCancelCtx(parent); ok {
        p.mu.Lock()
        if p.err != nil {
            // 如果父Context已经调用了cancel，这里就cancel当前协程。
            child.cancel(false, p.err)
        } else {
            // 如果父Context的子Context没有初始化，这里初始化，然后，添加进去
            if p.children == nil {
                p.children = make(map[canceler]struct{})
            }
            p.children[child] = struct{}{}
        }
        p.mu.Unlock()
    } else {
        // 如果父辈没有找到cancelContext，就开一个协程监听是否cancel。我还没弄清楚走到这里的场景。
        go func() {
            select {
            case <-parent.Done():
                child.cancel(false, parent.Err())
            case <-child.Done():
            }
        }()
    }
}
```

再对比下`WithDeadline`的初始化

```go
func WithDeadline(parent Context, d time.Time) (Context, CancelFunc) {
    // 如果父Context的截止时间早于当前Context。那就不必设置截止时间了，反正到时候父Context会自动取消子Context。
    if cur, ok := parent.Deadline(); ok && cur.Before(d) {
        return WithCancel(parent)
    }

    // 初始化timerCtx
    c := &timerCtx{
        cancelCtx: newCancelCtx(parent),
        deadline:  d,
    }
    // 广播cancel，挂载子Context等。同上面。
    propagateCancel(parent, c)

    // 计算当前时间到截止的时长。如果时长小于等于0，说明过了，立刻取消。
    dur := time.Until(d)
    if dur <= 0 {
        c.cancel(true, DeadlineExceeded) // deadline has already passed
        return c, func() { c.cancel(false, Canceled) }
    }
    c.mu.Lock()
    defer c.mu.Unlock()

    // 如果时长大于0，且当前没被取消，那么设置定时器，过dur久之后，执行取消操作。
    if c.err == nil {
        c.timer = time.AfterFunc(dur, func() {
            c.cancel(true, DeadlineExceeded)
        })
    }
    return c, func() { c.cancel(true, Canceled) }
}
```

最后，看下`Done`和`cacel`方法是怎么配合，发出信号的

```go
func (c *cancelCtx) Done() <-chan struct{} {
    c.mu.Lock()
    // 初始化chan
    if c.done == nil {
        c.done = make(chan struct{})
    }
    d := c.done
    c.mu.Unlock()
    return d
}


func (c *cancelCtx) cancel(removeFromParent bool, err error) {
    if err == nil {
        panic("context: internal error: missing cancel error")
    }
    c.mu.Lock()
    if c.err != nil {
        c.mu.Unlock()
        return
    }
    c.err = err
    if c.done == nil {
        c.done = closedchan
    } else {
        // 执行完Done，然后再次执行cancel，就会关闭这个chan。
        close(c.done)
    }
    // 广播子Context，执行取消操作。
    for child := range c.children {
        // NOTE: acquiring the child's lock while holding parent's lock.
        child.cancel(false, err)
    }
    c.children = nil
    c.mu.Unlock()

    if removeFromParent {
        removeChild(c.Context, c)
    }
}
```

`Context`包内容大致如此。

## 最后

参考资料

+ [go context](https://blog.golang.org/context)
+ [Pipeline And Cancellation](https://blog.golang.org/pipelines)
