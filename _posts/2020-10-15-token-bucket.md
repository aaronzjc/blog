---
layout: post
title: "限流和令牌桶算法"
date:   2020-10-15 22:00:00 +0800
categories: deep-in
---
## 介绍

开发中，为了尽可能保证服务的稳定性，对于流量高的请求，通常会做一些限流操作。目前限流算法，常见的有如下几个

+ 计数器
+ 滑动窗口
+ 漏桶
+ 令牌桶

计数器比较简单。服务维护一个计数器，每次请求来了就自增。当超过规定的值时，拒绝服务。过了这个时间范围，则计数器重置。配合Redis，实现起来也特别方便。对于1分钟发多少条验证码等简单的限流需求够用了。它有一个缺点，就是控制不够精确。例如，限制1分钟100次请求，可能当前分钟前30s请求了100次，下一轮的前30s请求了100次。在系统看来是正常的，但是实际是超出了1分钟100次这个限制的。

滑动窗口，就是将时间分片，每个窗口维持一个计数器。然后请求来了，判断过去的窗口中的请求总数是否超过。例如，将1分钟按照秒划分为60个时间窗口。每个窗口都维持一个计数器。当请求来时，判断前60s中所有的请求数。这样控制的更加精细，但是耗费的成本更高。

漏桶算法，顾名思义，当请求进来时，就相当于往一个桶里倒水。然后有一个出口固定消费桶里的水。当进水速度超过漏水速度，就会溢出。表现为拒绝服务。它的缺点是，没办法应对突发的大流量。严格意义来说，这个也不能怪漏桶算法，因为确实突发流量的请求速率大于系统的承受能力，被拒绝也没毛病。

![img](/static/assert/imgs/bucket_1.png)

令牌桶算法，相比漏桶算法更复杂，它能够允许一定程度的突然流量。它的思路是，以恒定速率往桶里放入令牌，当每次有请求来的时候，首先从桶里取一个令牌。如果桶里没令牌了，可以执行拒绝或者其他操作。为什么它可以应对突发流量？当突发流量进来时，只要桶里有足够的令牌，这部分流量是能正常访问的。

![img](/static/assert/imgs/bucket_2.png)

通常会将漏桶和令牌桶算法进行比较。其实这两个算法应对的场景有些差别。漏桶是严格的按照管理员的要求，超过这个速率就可以拒绝了。令牌桶则是，在后端系统能够承担住的情况下，允许一定的突发流量，不要搞的那么死嘛。看开发人员的取舍。

## Go令牌桶算法

前面介绍过了几种限流算法，令牌桶算法算是比较有意思的。研究了一下Go语言官方提供的令牌桶算法实现`time/rate`，不是很复杂，实现的思路也很好。

首先思考，实现一个令牌桶算法需要的元素。一个固定大小的桶`bucket`，令牌生成的速率`limit`，以及一个令牌数，即计数器`tokens`。天真的我刚开始认识这个算法时，还想怎么生成令牌呢。这样的话，桶按照固定的速率增加计数器的值，每个请求来的时候，计数器减一。当计数器小于0的时候，即表示没有令牌了。

这里有一个关键点就是怎么按照固定的速率增加计数器的值。其实没必要真的起一个协程来增加计数器的值。Go中的实现方案是，每次请求来的时候，计算上次拿令牌的时间和当前时间，看看这段时间能够生成多少个令牌，然后，再动态修改计数器的值。除此之外，它还支持预支令牌。因为，既然知道当前剩余令牌数和生成速率，自然能算出要等待多久。

首先，看看怎么使用

```golang
package main

import (
    "context"
    "fmt"
    "golang.org/x/time/rate"
    "log"
    "net/http"
    "time"
)

func main() {
    // 初始化一个限流器，每秒生成一个令牌，桶大小是4
    lim := rate.NewLimiter(rate.Every(time.Second), 4)
    
    /**
     * 简单粗暴的拦截，如果超过了，就拒绝。
     * 示例：
     * 2020-10-15 17:18:33 允许
     * 2020-10-15 17:18:34 允许
     * 2020-10-15 17:18:34 允许
     * 2020-10-15 17:18:35 允许
     * 2020-10-15 17:18:35 允许
     * 2020-10-15 17:18:35 允许
     * 2020-10-15 17:18:36 不允许
     * 2020-10-15 17:18:36 不允许
     * 2020-10-15 17:18:36 不允许
     * 2020-10-15 17:18:36 允许
     */
    http.HandleFunc("/allow", func(w http.ResponseWriter, req *http.Request) {
        if lim.Allow() {
            fmt.Println(time.Now().Format("2006-01-02 15:04:05"), "允许")
        } else {
            fmt.Println(time.Now().Format("2006-01-02 15:04:05"), "不允许")
        }
    })
    
    /**
     * 带预定的拦截，如果令牌不够，则等待生成足够令牌再处理。
     * 如下，观察开始时间和结束时间。可以看到，令牌不够时，等待了才处理。
     * 示例：
     * start at  2020-10-15 17:32:57 handle at  2020-10-15 17:32:57  allow
     * start at  2020-10-15 17:32:58 handle at  2020-10-15 17:32:58  allow
     * start at  2020-10-15 17:32:58 handle at  2020-10-15 17:32:59  allow
     * start at  2020-10-15 17:32:59 handle at  2020-10-15 17:33:01  allow # 等待了2s
     * start at  2020-10-15 17:32:59 handle at  2020-10-15 17:33:03  allow # 等待了24
     * start at  2020-10-15 17:33:02 handle at  2020-10-15 17:33:05  allow 
     * start at  2020-10-15 17:33:04 handle at  2020-10-15 17:33:07  allow 
     */
    http.HandleFunc("/reserve", func(w http.ResponseWriter, req *http.Request) {
        start := time.Now().Format("2006-01-02 15:04:05")
        r := lim.ReserveN(time.Now(), 2)
        if !r.OK() {
            fmt.Println("异常")
        }
        time.Sleep(r.Delay())
        fmt.Println("start at ", start, "handle at ", time.Now().Format("2006-01-02 15:04:05"), " allow")
    })
    /**
     * 带context的等待，阻塞直到生成足够的令牌。
     * 如下，当令牌不够时，等待后才处理。因为设置了超时，所以系统判断超时时间内无法生成足够的令牌，报错了。
     * 示例：
     * start at  2020-10-15 17:34:43 handle at  2020-10-15 17:34:43  allow
     * start at  2020-10-15 17:34:44 handle at  2020-10-15 17:34:44  allow
     * start at  2020-10-15 17:34:44 handle at  2020-10-15 17:34:44  allow
     * start at  2020-10-15 17:34:45 handle at  2020-10-15 17:34:45  allow
     * start at  2020-10-15 17:34:45 handle at  2020-10-15 17:34:45  allow
     * start at  2020-10-15 17:34:45 handle at  2020-10-15 17:34:45  allow
     * start at  2020-10-15 17:34:46 handle at  2020-10-15 17:34:46  allow
     * rate: Wait(n=1) would exceed context deadline
     * start at  2020-10-15 17:34:46 handle at  2020-10-15 17:34:47  allow # 进行了等待
     * start at  2020-10-15 17:34:47 handle at  2020-10-15 17:34:48  allow # 进行了等待
     */
    http.HandleFunc("/wait", func(w http.ResponseWriter, req *http.Request) {
        start := time.Now().Format("2006-01-02 15:04:05")
        ctx, _ := context.WithTimeout(context.TODO(), time.Second)
        err := lim.WaitN(ctx, 1)
        if err != nil {
            fmt.Println(err)
            return
        }
        fmt.Println("start at ", start, "handle at ", time.Now().Format("2006-01-02 15:04:05"), " allow")
    })
    log.Fatal(http.ListenAndServe(":7080", nil))
}
```

接下来，看看其中核心的实现

```golang
package rate

import (
    "context"
    "fmt"
    "math"
    "sync"
    "time"
)

// 生成Token速率
type Limit float64

/**
 * 这个结构体提供了3个底层限流方法。AllowN, WaitN, ReserveN。
 * 底层真正起到限流的是ReserveN方法。
 */
type Limiter struct {
    // 生成Token速率
    limit Limit
    // 桶的大小
    burst int

    // 锁，并发处理
    mu     sync.Mutex
    // 当前桶里的Tokens数
    tokens float64
    // 上次更新tokens的时间，用于比较，当前时间和这个时间之间能生成多少个Tokens
    last time.Time
    // 上次消费完的时间
    lastEvent time.Time
}

// 初始化一个令牌桶限流器
func NewLimiter(r Limit, b int) *Limiter {
    return &Limiter{
        limit: r,
        burst: b,
    }
}

// 简写
func (lim *Limiter) Allow() bool {
    return lim.AllowN(time.Now(), 1)
}

// 发生请求时，请求所对应的令牌桶预定信息。
type Reservation struct {
    ok        bool
    lim       *Limiter
    // 请求获取的Token数
    tokens    int
    // 能够执行的时间
    timeToAct time.Time
    // 预定时的速率
    limit Limit
}

// 简写
func (lim *Limiter) Reserve() *Reservation {
    return lim.ReserveN(time.Now(), 1)
}

// 这个是Wait的底层
func (lim *Limiter) WaitN(ctx context.Context, n int) (err error) {
    // 如果请求的大于桶大小，则报错
    if n > lim.burst && lim.limit != Inf {
        return fmt.Errorf("rate: Wait(n=%d) exceeds limiter's burst %d", n, lim.burst)
    }
    // 检查ctx有没有被cancel掉
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
    }
    
    // 比较ctx的超时时间，如果有的话，设置一个最久等待时间
    now := time.Now()
    waitLimit := InfDuration
    if deadline, ok := ctx.Deadline(); ok {
        waitLimit = deadline.Sub(now)
    }
    // 获取一个预定。具体做了啥，待会再看。
    r := lim.reserveN(now, n, waitLimit)
    if !r.ok {
        // 这里表明，在ctx超时之前，都没办法获取到足够的Token。
        return fmt.Errorf("rate: Wait(n=%d) would exceed context deadline", n)
    }
    // 计算要等多久
    delay := r.DelayFrom(now)
    if delay == 0 {
        return nil
    }
    t := time.NewTimer(delay)
    defer t.Stop()
    select {
    case <-t.C:
        // 等待时间到了
        return nil
    case <-ctx.Done():
        // ctx超时了
        r.Cancel()
        return ctx.Err()
    }
}

// 预定N个Token
func (lim *Limiter) reserveN(now time.Time, n int, maxFutureReserve time.Duration) Reservation {
    lim.mu.Lock()

    // 如果没有限制Token生成速率，则直接返回成功
    if lim.limit == Inf {
        lim.mu.Unlock()
        return Reservation{
            ok:        true,
            lim:       lim,
            tokens:    n,
            timeToAct: now,
        }
    }

    // 计算上次Token获取时间到当前时间，又生产了多少个Token。并更新限流器状态。就是在这里处理的Token生成。
    now, last, tokens := lim.advance(now)

    // 从桶里拿n的Token
    tokens -= float64(n)

    // 如果Token小于0，表明没有足够Token。计算需要等待多久，才能拿到这么多Token。
    var waitDuration time.Duration
    if tokens < 0 {
        waitDuration = lim.limit.durationFromTokens(-tokens)
    }

    // 判断能否有效获取n个Token
    ok := n <= lim.burst && waitDuration <= maxFutureReserve

    // 初始化一个预定
    r := Reservation{
        ok:    ok,
        lim:   lim,
        limit: lim.limit,
    }
    if ok {
        r.tokens = n
        r.timeToAct = now.Add(waitDuration)
    }

    // 如果能够预定，则更新限流器状态。Tokens的值可以为负数。
    if ok {
        lim.last = now
        lim.tokens = tokens
        lim.lastEvent = r.timeToAct
    } else {
        lim.last = last
    }

    lim.mu.Unlock()
    return r
}

// 生成Token，更新限流器状态
func (lim *Limiter) advance(now time.Time) (newNow time.Time, newLast time.Time, newTokens float64) {
    // 上次拿Token的时间。如果在当前时间后面，
    last := lim.last
    if now.Before(last) {
        last = now
    }

    // 首先，计算把桶装满Token需要的时间。然后看，上次拿Token到现在经过的时间。如果后面的时间更大，那就修正为前面的时间。
    maxElapsed := lim.limit.durationFromTokens(float64(lim.burst) - lim.tokens)
    elapsed := now.Sub(last)
    if elapsed > maxElapsed {
        elapsed = maxElapsed
    }

    // 再次计算，距离上次拿Token到现在，生成了多少个Token。如果溢出了，则返回桶的大小。
    delta := lim.limit.tokensFromDuration(elapsed)
    tokens := lim.tokens + delta
    if burst := float64(lim.burst); tokens > burst {
        tokens = burst
    }

    return now, last, tokens
}
```

令牌桶的核心实现就是上面的内容。