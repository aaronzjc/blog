---
layout: post
title: "Docker网络学习：linux网络管理"
date:   2020-06-18 22:00:00 +0800
categories: linux
---

## 简介

最近在折腾Swarm相关的东西。自从将`Mu`拆分后，实现了一台机器上任意扩容。想起自己还有一台腾讯云的1C1G机子，于是，组了一个Swarm集群。

有了集群以后，就可以进行新的实践了。Swarm和k8s这类编排工具的出现，抹平了服务器之间的差异。只要同属于一个集群，编排工具就可以根据服务器情况将容器放置到集群任意机器。再配置上服务发现，就实现了一个高可用的服务。当外界访问到这个服务时，内部会自动将流量分发到这些容器。这种模式大大减少了传统扩容机器的工作量，这也是容器技术受欢迎的原因之一。

这里面的技术知识有很多，我对其中的网络部分很感兴趣。主要好奇，容器的通信，以及多机器之间的容器通信。

于是带着问题，学习了下Docker网络知识。之前也走马观花看过，这次比较系统的了解了这些内容。重要的对一些内容亲自实践了一番。本文针对`Swarm`集群，`k8s`可能不一样，等日后学习`k8s`时再去了解。

## 网络基础

本文会介绍Docker网络中涉及到的知识，也是自己之前不太熟悉的内容。主要包括`netns`，`iptables`，`vlan`，`vxlan`。在下一篇中，才会真正介绍Docker的网络。

### Network Namespace

`Network Namespace`是网络虚拟化的一个重要功能。它可以创建多个隔离的网络空间，每个网络空间有自己独立的网络栈。和`Network Namespace`类似，也存在其他的`Namespace`类型，将对应的资源隔离，这里就不赘述了。

Linux提供`ip`命令来操作和管理网络设备等，非常方便统一。

```shell
ip netns list # 查看所有命名空间
ip netns add NAME # 添加一个网络命名空间
ip netns set NAME NETNSID # 手动设置ID 
ip [-all] netns delete [NAME] # 删除命名空间
ip [-all] netns exec [NAME] cmd ... # 在指定命名空间中执行命令
```

接下来，动动手，实践一下。创建两个基本的命名空间

```shell
$ ip netns add ns1
$ ip netns add ns2
$ ip netns ls
ns2
ns1
```

查看两个命名空间的网卡情况

```shell
$ ip netns exec ns1 ip addr
$ ip netns exec ns2 ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
```

可以看到，两个网络空间默认都只有一个本地回环网络接口。没有网络接口，就没办法和外界通信。这时候，就需要用到`veth pair`设备了。

`veth pair`是虚拟网络设备，总是`成对`出现。可以理解它是用网线连接好了的两个接口。将两个接口放到不同的`Network Namespace`中，就可以实现两个网络空间通信了。在操作`veth pair`时，时时想着，我拿着一根网线，现在要把一头插哪，另一头插哪。闲话少说，动手试试

```shell
# 1. 创建一对veth pair
$ ip link add dev myveth1 peer name myveth2

# 2. 分别绑定到前面的两个命名空间
$ ip link set dev myveth1 netns ns1
$ ip link set dev myveth2 netns ns2

# 3. 分配IP。因为两个设备已经分配到指定命名空间，所以，是不能直接ip add的。需要在指定的ns下。
$ ip netns exec ns1 ip addr add 192.168.1.1/24 dev myveth1
$ ip netns exec ns2 ip addr add 192.168.1.2/24 dev myveth2

# 4. 测试连接
$ ip netns exec ns1 ping 192.168.1.2
$ ip netns exec ns2 ping 192.168.1.1
```

如上，就熟悉了基本的`netns`概念和操作。现实生活中，在一个局域网中的N台机器，他们之间可以通过交换机通信。如果是在N个网络命名空间中呢，怎么让它们之前互通？可以使用`bridge`，也就是网桥，类似于现实中的交换机。

接着实践下怎么利用`bridge`和`veth pair`实现不同`netns`互通。我们测试的网络结构如图

![图片](/assert/imgs/docker_net_basic1.png)

结构很简单，但是命令一大坨。开始动手

```shell
# 1. 新建2个netns
$ ip netns add ns1
$ ip netns add ns2

# 2. 新建一个网桥，并绑定一个ip
$ ip link add dev mybridge type bridge
$ ip addr add 192.168.2.1/24 brd + dev mybridge
$ ip link set mybridge up

# 3. 新建2对veth pair，并指定ip，将一端绑定到对应的netns，并启用
$ ip link add dev ns1veth0 type veth peer name ns1veth1
$ ip link set ns1veth0 netns ns1
$ ip netns exec ns1 ip addr add 192.168.2.10/24 dev ns1veth0
$ ip netns exec ns1 ip link set ns1veth0 up
$ ip link add dev ns2veth0 type veth peer name ns2veth1
$ ip link set ns2veth0 netns ns2
$ ip netns exec ns2 ip addr add 192.168.2.11/24 dev ns2veth0
$ ip netns exec ns2 ip link set ns2veth0 up

# 4. 将veth pair另一端分别绑定到网桥上，并启用
$ ip link set ns1veth1 master mybridge
$ ip link set ns1veth1 up
$ ip link set ns2veth1 master mybridge
$ ip link set ns2veth1 up

# 5. 给ns1和ns2的网卡添加一条默认的路由，指向mybridge，实现通信
$ ip netns exec ns1 ip route add default via 192.168.2.1
$ ip netns exec ns2 ip route add default via 192.168.2.1
```

如上算是完成了基本的配置，接下来测试下能否互通

```shell
$ ip netns exec ns1 ping 192.168.2.11
PING 192.168.2.11 (192.168.2.11) 56(84) bytes of data.
...
--- 192.168.2.11 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2007ms
```

很奇怪，PING不通。对`mybridge`进行抓包

```shell
$ tcpdump -i mybridge -n
...
10:30:22.592201 ARP, Request who-has 192.168.2.11 tell 192.168.2.10, length 28
10:30:22.592246 ARP, Reply 192.168.2.11 is-at 6a:c7:f9:9b:4a:80, length 28
10:30:23.588339 IP 192.168.2.10 > 192.168.2.11: ICMP echo request, id 14699, seq 8, length 64
10:30:24.588316 IP 192.168.2.10 > 192.168.2.11: ICMP echo request, id 14699, seq 9, length 64
10:30:25.588299 IP 192.168.2.10 > 192.168.2.11: ICMP echo request, id 14699, seq 10, length 64
...
```
发现arp能否解析，也就是能找到`ns2`的mac地址。发包过去了，但是没有收到回应。这是因为没有开启数据包转发，或者转发被丢弃了。继续配置

```shell
# 1. 开启linux下的ipv4数据包转发
$ sysctl -w net.ipv4.ip_forward=1

# 2. 修改iptables的转发策略为ACCPET
$ iptables -P FORWARD ACCEPT

# 3. 再次测试连通
$ ip netns exec ns1 ping -c 3 192.168.2.11
PING 192.168.2.11 (192.168.2.11) 56(84) bytes of data.
64 bytes from 192.168.2.11: icmp_seq=1 ttl=64 time=0.194 ms
64 bytes from 192.168.2.11: icmp_seq=2 ttl=64 time=0.110 ms
```

如上，就实现了两个`netns`之间通过网桥来通信。这块还没完，接下来，试试在`netns`中PING外网

```shell
$ ip netns exec ns1 ping 8.8.8.8
...no reply...
```

发现PING不同。为什么？因为数据包到了网桥，网桥转发给host的网卡发送出去，源地址是网桥的地址。外网回复时是找不到这个地址的。所以，在发送出去的时候，还需要修改下包的源地址

```shell
$ iptables -t nat -A POSTROUTING -s 192.168.2.1/24 -j MASQUERADE
```

现在再PING就没问题了。

如上，介绍了linux下使用`ip`命令管理`Network Namespace`的相关知识。并学会了搭建一个简单的网桥。实际上这个网桥结构就是Docker默认的网络方式。

在上面的实践中，提到了修改`iptables`的相关规则。`iptables`也是linux网络中一个重要的内容。它主要是管理数据包转发，过滤和NAT等。Docker中的`overlay`网络实现也依赖于它。

### iptables

#### 基本介绍

`netfilter`是linux内核提供的防火墙功能，它可以对网络数据包过滤和修改。而`iptables`，则是运行在用户空间的应用软件，是对`netfilter`的封装。`netfilter`提供了5个钩子来让其他程序针对数据包特定阶段进行处理，分别时`PREROUTING`，`INPUT`，`FORWARD`，`OUTPUT`，`POSTROUTING`。

`iptables`定义了一套自己的规则系统，主要包含`table`，`chain`，`rule`，`target`这几个概念。

其中，`table`指不同的数据处理流程，例如，用于数据过滤的`filter`表，用于`NAT`功能的`nat`表，以及用于修改数据包的`mangle`表等。每张`table`又包含多个`chain`，`chain`是一系列`rule`的合集，从上往下依次匹配。当匹配到指定的`rule`，执行对应的`target`。通常，每个`chain`有一个默认`policy`。当`chain`中所有`rule`执行完毕没有跳走，则执行默认的`policy`。

`iptables`包含如下4个表，表中包含了几个默认链

>
> + filter表：默认表，用于包过滤
>   + INPUT链：输入链，发往本机数据包通过此链
>   + OUTPUT链：输出链，从本机输出时调用
>   + FORWARD链：转发链，上面介绍过。本机转发的数据包通过此链
> + nat表：用户`NAT`，网络地址转换
>   + PREROUTING：路由前链，处理路由规则前调用。通常用于`DNAT`目的地址转换
>   + POSTROUTING：路由后链，完成路由后调用。通常用于`SNAT`源地址转换
>   + OUTPUT：输出链，类似于PREROUTING，但是处理本机发出的数据
> + mangle表：用于处理数据包，侧重于单个数据包
>   + ALL：基本包含了上述所有的流程
> + raw表：处理异常
>   + PREROUTING
>   + OUTPUT
>

每个表虽然包含的链名字相同，但是彼此没有关联。唯一的相同点，就是之前提到的`netfilter`中的特定阶段。数据包在`netfilter`中的流转如图

![图片](/assert/imgs/iptables_flow.png)


#### 流程图说明

怎么理解上面的这个流转图呢？分两种情况，一种是外部进来；另一种是本地进程发出。

1、外部进来

首先，看左上角的注释，分为`Network Level`和`Bridge Level`。前面简单提过`bridge`的概念，用于在linux主机模拟二层交换机。linux为了实现网络虚拟化，实现了一系列模拟硬件设备，例如，`bridge`，`veth`等。

如果没有`bridge`的话，网络包的处理比较单一，从网卡进来后，进入网络层。引入`bridge`后，就需要在二层判断是否是发送给`bridge`的，然后，经由`bridge`转发。

从左往右梳理，当一个数据包从物理网卡进入，经过检查，发现它属于网桥接口。则数据包不会走`T`往上进入网络层，而是继续在网桥处理。从图可以看到，依次经过`iptables`中的`nat-prerouting`，`raw-prerouting`。之后，进入一个特殊的流程`conntrack`。

`conntrack`是什么？这么理解，通常，我们的主机对外只会暴露极少量几个端口。外部访问主机时，非指定端口的数据都会被抛弃。但是，当主机的进程与外部进行连接通信时，它会随机选择一个端口进行连接。这时候，返回的数据如果按照之前的逻辑，则会被抛弃，无法通信。`conntrack`提供了一种能力，可以根据连接状态进行数据包处理。

再然后，数据包来到了`mangle-prerouting`和`nat-prerouting`链。接着，又是一个`bridge decision`。这个时候的处理，就类似于交换机的处理过程了，`bridge`会判断数据包的mac地址

+ 如果是发往某个设备的，则查mac地址，进行转发。有mac记录，则直接转发，否则arp查找，转发。
+ 如果是发给网桥自身，或者目的地址不是网桥，则交给上层协议处理。

后面的流程，就是按照图中的步骤依次处理，就不介绍了。

2、进程发出

从进程发出的数据包，直接看最上面的`local process`即可。首先经过各个表中的`OUTPUT`链，接着路由，然后就是`POSTROUTING`链，最后发出。

3、SNAT和DNAT

在`POSTROUTING`中，有一个有意思的地方，就是`SNAT`。当容器内访问外网时，需要经过一次源IP转换。因为，接收方根据源IP回复时，没办法路由到内网IP。所以需要将源IP转换成出口IP。这里，又有一个情况，如果出口IP不是固定的呢，这样转换就有些棘手了。在`SNAT`中，有一个特殊动作叫`MASQUERADE`，就是动态设置源IP为出口IP。

有对源IP转换，就有对目的IP进行转换。当容器请求外部，因为发出的包经由SNAT修改为网卡IP了。现在回复的数据包到了网卡，还需要还原，才能正确发送给容器。

参考资料

+ [netfilter介绍](https://opengers.github.io/openstack/openstack-base-virtual-network-devices-bridge-and-vlan/#bridge%E4%B8%8Enetfilter)

### vlan和vxlan

下面，介绍`vlan`和`vxlan`相关的知识。从总体来理解，`vlan`和`vxlan`都是二层相关技术。

#### vlan

我们知道，`LAN`是由几台机器组成的网络。例如，在一个公司，多个部门之间的机器通过交换机就组成了一个`LAN`。但是，二层交换机只构成单一广播域。对于如下的拓扑结构

![图片](/assert/imgs/docker_net_basic4.png)

当主机`a`想要和`c`通信时，会发送数据包给交换机`B`。`B`如果没有记录`c`的地址，则会发送arp请求给所有的端口查询`c`的mac地址，包括`A`。`A`同样会转发到`B`去查询。如果一个局域网下的机器非常多的化，这样就会造成泛洪，导致网络充斥着这些数据包。所以提出了`vlan`，进一步划分子网。`vlan`的作用

+ 广播控制
+ 带宽利用
+ 降低延迟
+ 安全(非设计作用，因为隔离机制附加)

`vlan`并不依赖特定的物理设备来实现，你可以在一个交换机上划分出多个`vlan`。但是，不同的`vlan`之间是无法通信的，即使是在同一个交换机之上划分。不同的`vlan`之间想要通信，需要使用三层设备，可以是路由器或者三层交换机。

`vlan`原理和实现方式

+ 物理层。直接根据交换机的端口来作为划分`vlan`。显然，这种情况适合较小规模的组织。
+ 数据链路层。根据每台主机的MAC地址来划分。这种情况，需要有一个数据库来存储MAC地址和VLAN ID的映射关系。配置相对复杂。
+ 网络层。根据每台设备的IP地址来划分，以子网作为划分的依据。

目前最常用的vlan技术是`8021.Q VLAN`，具体的细节可以看[这个技术文档](https://project-homedo.oss-cn-shanghai.aliyuncs.com/product_attachment/100237945_IEEE%20802.1Q%20VLAN%E6%8A%80%E6%9C%AF%E7%99%BD%E7%9A%AE%E4%B9%A61.0.1.pdf)。

大致是在标准的以太网帧源MAC地址和目的MAC地址后插入了4字节的`vlan tag`作为标识。其中，作为唯一标识的`vlan ID`只有12位，取值在1～4094。可以看出，其实`vlan`的范围也不太大。当二层接收到以太网帧时，会去解析是否包含`vlan tag`，如果包含，则会发送给指定的`vlan`。

#### vxlan



参考资料

+ [图文并茂VLAN](https://cloud.tencent.com/developer/article/1412795)
+ [vxlan介绍](https://forum.huawei.com/enterprise/zh/thread-334207.html)
+ [Linux实现vxlan网络](https://cizixs.com/2017/09/28/linux-vxlan/)