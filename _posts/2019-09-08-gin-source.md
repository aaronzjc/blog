---
layout: post
title: "Gin框架学习"
date:   2019-09-08 10:00:00 +0800
categories: golang
---

Gin是基于net/http库开发的一个Web框架，里面包含了路由组件，请求解析，模板渲染，请求参数绑定等基础功能。
如果之前是做PHP，Python等解释型语言开发的话，在做Go相关的Web开发时，要明白他们之间的差异。Go是编译型语言，整个Web应用会编译成一个可执行文件，main函数就是整个应用的入口。PHP是一个请求一个进程，请求结束，进程相关的数据就会回收。而Go不同，他会监听请求，处理完请求，还会继续保持监听。

### 最基础的HTTP服务

如下是用官方库net/http开发的一个最基础的HTTP服务。首先，添加路由处理，然后监听端口。Gin是基于这个包开发的一个Web框架，底层的执行依然如此。只是他包装了路由注册，路由查找，中间件等常用组件。更加方便，规范化了。所以本文会介绍几个核心组件的原理。

{% highlight go %}
package main

import "net/http"

func hello(w http.ResponseWriter, req *http.Request) {
   w.Write([]byte("hello world"))
}

func main() {
   http.HandleFunc("/", hello)
   http.ListenAndServe(":8899", nil)
}
{% endhighlight %}

### Gin的中间件实现

中间件本质就是一个流水线处理，将一组处理方法作用于一个对象。最简单的实现就是一个数组遍历执行；复杂的就像laravel的中间件。Gin的中间件实现也是非常的简洁优雅
{% highlight go %}
package main

import "fmt"

type Handler func(c *Context)

type Context struct {
   Handlers   []Handler
   index     int
}

func (c *Context) init() {
   c.index = -1
}

// 控制中间件向后执行
func (c *Context) Next() {
   c.index++;
   s := int(len(c.Handlers))
   for ; c.index < s; c.index++ {
      c.Handlers[c.index](c)
   }
}

func ma() Handler {
   return func(c *Context) {
      fmt.Println("middleware ma before")
      c.Next()
      fmt.Println("middleware ma after")
   }
}

func mb() Handler {
   return func(c *Context) {
      fmt.Println("middleware mb before")
      c.Next()
      fmt.Println("middleware mb after")
   }
}

func mc() Handler {
   return func(c *Context) {
      fmt.Println("middleware mc before")
      c.Next()
      fmt.Println("middleware mc after")
   }
}

func hello(c *Context) {
   fmt.Println("yo, Hello Bro.")
}

func main() {
   c := &Context{}
   c.init()

   // 首先添加几个中间件
   c.Handlers = []Handler{ma(), mb(), mc()}

   // 添加最后的HTTP路由处理
   c.Handlers = append(c.Handlers, hello)

   // 启动执行
   c.Next() 
}
{% endhighlight %}

### Gin中的Context优化

HTTP服务通常会支持高并发，Gin也是强调自己的并发能力。分析一个请求，当一个HTTP请求到达Gin这里时，首先进入到serveHTTP方法里面。然后Gin会在这里初始化当前请求的Context。如果当并发特别高的时候，Context会初始化很多很多次，这样，占用的内存会很高。其次，当请求处理完以后，GC又会销毁Context对象，又会造成比较频繁的GC处理。Gin使用了sync.Pool来缓存Context对象，降低了GC压力。

{% highlight go %}
func (engine *Engine) ServeHTTP(w http.ResponseWriter, req *http.Request) {
   c := engine.pool.Get().(*Context)
   c.writermem.reset(w)
   c.Request = req
   c.reset()
   engine.handleHTTPRequest(c)
   engine.pool.Put(c)
}
{% endhighlight %}

如上所示，当处理时，首先从P取一个Context对象，这里重置一次，避免拿到其他的请求的数据。然后使用完了，再放回去，非常标准。很多其他的框架都有类似的处理。

### Gin路由

Go的框架一般都比较简单。自身处理的东西其实不是很多，对比下laravel框架，路由，中间件，日志，模板解析，定时任务，事件系统等等。可以发现，Gin只做了一个Web框架的核心的核心，把这部分做好了。在这些框架的模块之中，路由可以说是一个web框架的灵魂了。路由负责将用户指定的资源请求分发到具体的处理逻辑上。

Gin框架的路由使用的一种前缀树，又叫radix tree，基数树，压缩前缀树等。是一个更加节省空间的字典树。补充下基础知识，先学习一下Trie。
字典树，就是将关键词构造成一个树结构。可以很高效的查找给定字符串，搜索补全等。

{% highlight text %}
abc
abd
ace
abcdef
|- a  
  |- c
    |- e
  |- b 
    |- c
      |- d
        |- e
          |- f
    |- d
{% endhighlight %}

对于如上的字符串，可以构造一个字典树。当查询的时候，效率就很高。但是这样的结构有一个缺点，就是，非常占内存空间。每个字符都占用了一个节点。所以这个是典型的以空间换时间。基础的Trie实现如下

{% highlight go %}
package main

import (
   "fmt"
)

type Node struct {
   Val       rune
   Children   []*Node
   ref       int
}

type Trie struct {
   Root   *Node
}

func (node *Node) Insert(r rune) *Node {
   node.ref++
   for _, child := range node.Children {
      if child.Val == r {
         return child
      }
   }

   c := NewNode(r)
   node.Children = append(node.Children, c)
   return c
}

func NewNode(r rune) *Node {
   return &Node{Val:r}
}

func (tr *Trie) Insert(word string) {
   rs := []rune(word)
   node := tr.Root
   for _, c := range rs {
      child := node.Insert(c)
      node = child
   }
}

func (tr *Trie) Del(word string) bool {
   if !tr.Has(word) {
      return false
   }

   node := tr.Root
   rs := []rune(word)
   for _, c := range rs {
      for idx, child := range node.Children {
         if child.Val == c {
            if child.ref <= 1 {
               node.Children = append(node.Children[:idx], node.Children[idx+1:]...)
            }
            node.ref--
            node = child
            break
         }
      }
   }

   return true
}

func (tr *Trie) Has(word string) bool {
   node := tr.Root
   runeArr := []rune(word)
   for _, char := range runeArr {
      exist := false
      for _, child := range node.Children {
         if child.Val == char {
            exist = true
            node = child
            break
         }
      }
      if !exist {
         return false
      }
   }

   return true
}

func NewTrie() *Trie {
   var r rune
   return &Trie{Root:NewNode(r)}
}

// 树的遍历
func Reverse(root *Node) {
   if root == nil {
      return
   }
   var queue []*Node
   var node *Node
   queue = append(queue, root)
   for len(queue) > 0 {
      // 从头部取数据，就是层序遍历(广度优先遍历)
      node, queue = queue[0], queue[1:]
      // 从尾部取，就是深度优先遍历
      // node, queue = queue[len(queue)-1:], queue[:len(queue)-1]
      if node.Val != 0 {
         fmt.Printf("[%c-%d] ", node.Val, node.ref)
      }
      for _, child := range node.Children {
         queue = append(queue, child)
      }
   }
}
func main() {
   t := NewTrie()
   // 插入3个元素，构造一颗前缀树
   t.Insert("php")
   t.Insert("python")
   t.Insert("phoenix")
   // 遍历这颗树
   fmt.Println()
   Reverse(t.Root)
   // 再插入一个元素
   t.Insert("perl")
   fmt.Println(t.Has("perl"))
   // 遍历
   Reverse(t.Root)
   // 删除这个树
   t.Del("perl")
   // 再次遍历，检查是否删除成功了
   fmt.Println()
   Reverse(t.Root)
   t.Insert("pyh")
   fmt.Println()
   Reverse(t.Root)
   t.Del("pyh")
   fmt.Println()
   Reverse(t.Root)
}
{% endhighlight %}

对于空间占用和查询效率的问题，提出的改进就是下面要提到的压缩字典树了。他做的改进就是将，图中连续的单节点进行合并，合并之后的效果如下：

{% highlight text %}
>abc
>abd
>ace
>abcdef

|- a  
  |- ce
  |- b 
    |- cdef
    |- d
{% endhighlight %}

很好理解，如果连续的单节点。说明搜索路径是唯一的，自然可以合并成一个串，只保留一个节点。Gin框架就是采用的这个数据结构来存储路由。大致实现如下
{% highlight go %}
package main

import "fmt"

type Node struct {
   path      string
   indices    string
   children   []*Node
}

type Tree struct {
   method        string
   root      *Node
}

func min(a, b int) int {
   if a <= b {
      return a
   }
   return b
}

// 插入路由。路由必须以/开头
func (n *Node) addMyRoute(path string) {
   fullpath := path

   // 如果当前插入的节点路由为空且子节点为空，表明是树是空的
   if len(n.path) > 0 || len(n.children) > 0 {
   waw:
      for {
         i := 0
         max := min(len(n.path), len(path))

         // 找到两个路由的公共部分
         for i < max && n.path[i] == path[i] {
            i++
         }

         // 如果公共部分比当前路由要短，那么说明当前路由需要拆分
         if i < len(n.path) {
            child := &Node{
               path:     n.path[i:],
               indices:   n.indices,
               children:  n.children,
            }

            n.children = []*Node{child}
            n.indices = string([]byte{n.path[i]})
            n.path = path[:i]
         }

         if i < len(path) {
            path = path[i:]

            c := path[0]

            for i := 0; i < len(n.indices); i++ {
               if n.indices[i] == c {
                  n = n.children[i]
                  continue waw
               }
            }

            n.indices += string([]byte{c})
            child := &Node{}
            n.children = append(n.children, child)
            n = child
         }

         n.insertChild(path, fullpath)
         return
      }
   } else {
      n.insertChild(path, fullpath)
      return
   }
}

func (n *Node) addRoute(path string) {
   fullpath := path
   if len(n.path) <= 0 && len(n.children) <= 0 {
      n.insertChild(path, fullpath)
      return
   }

walk:
   for {
      i := 0
      max := min(len(n.path), len(path))

      // 找到两个路由的公共前缀部分
      for i < max && n.path[i] == path[i] {
         i++
      }

      // 如果公共部分比当前插入的路由还要短，说明当前路由需要拆分
      if i < len(n.path) {
         child := &Node{
            path:     n.path[i:],
            indices:   n.indices,
            children:  n.children,
         }

         n.children = []*Node{child}
         n.indices = string([]byte{n.path[i]})
         n.path = path[:i]
      }

      // 如果公共部分比要插入的路由短，说明要插入的路由是一个child
      if i < len(path) {
         path = path[i:]

         c := path[0]

         for i := 0; i< len(n.indices); i++ {
            if c == n.indices[i] {
               n = n.children[i]
               continue walk
            }
         }

         n.indices += string([]byte{c})
         child := &Node{}
         n.children = append(n.children, child)
         n = child
      }

      n.insertChild(path, fullpath)
      return
   }
}

func (n *Node) insertChild(path string, fullpath string) {
   n.path = path
}


// 树的遍历
func Reverse(root *Node) {
   if root == nil {
      return
   }
   var queue []*Node
   var node *Node
   queue = append(queue, root)
   for len(queue) > 0 {
      // 从头部取数据，就是层序遍历(广度优先遍历)
      node, queue = queue[0], queue[1:]

      fmt.Printf("[path: %s, indices: %s] ", node.path, node.indices)

      for _, child := range node.children {
         queue = append(queue, child)
      }
   }
}

func main() {
   t := &Tree{root:new(Node)}
   t.root.addMyRoute("/abc")
   t.root.addMyRoute("/abd")
   t.root.addMyRoute("/ae")
   t.root.addMyRoute("/abf")
   Reverse(t.root)
}
{% endhighlight %}

事实上，Gin的路由还做了一些其他的处理，例如参数路由，模式匹配等。这个可以查阅源码去了解。

### 总结Gin的处理流程

说完了如上的几个核心。基本对Gin的框架有一个整体的熟悉了，强烈建议阅读以下源码。毕竟除去测试代码，实际的代码量并不大。最后总结下Gin中请求的处理流程。

有如下一个标准的基于Gin的Web应用，看看应用启动和请求处理流程。

{% highlight go %}
package main

import "github.com/gin-gonic/gin"

func main() {
        r := gin.Default()
        r.GET("/ping", func(c *gin.Context) {
                c.JSON(200, gin.H{
                        "message": "pong",
                })
        })
        r.Run() // 监听并在 0.0.0.0:8080 上启动服务
}
{% endhighlight %}

整个请求过程如图

![图片]({{ site.url }}/assert/imgs/gin_1.png)

### 闲言碎语

最后说说其他的想法。当谈到框架优劣的时候，都喜欢比性能，说自己如何的高性能。但是看完了Gin框架的大致实现后，感觉高性能和Gin没啥关系。因为真正处理HTTP连接，调度执行的还是net/http库。所以要说高性能，本文最开始的net/http应该是性能最高的。如果说是在Web框架之间对比性能的话，感觉没啥必要，无非是谁的路由查找更快，对象初始化开销等。在现在的框架实现上，难免相互借鉴，应该不会有太大的差距。很多时候，高性能往往牺牲的是用户友好性。像laravel，太友好了可能就牺牲了性能。所以说，找一个适合自己风格，喜欢的框架即可，没必要追求那些数字。

最后还是希望能多看看别人的项目。阅读源码是一种好的学习方式，可以学习别人组织代码的方式，以及优雅的实现方式。