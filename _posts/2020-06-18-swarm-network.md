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

本文会介绍，Docker网络涉及到的知识。主要包括`netns`，`iptables`，`vlan`，`vxlan`。

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

`iptables`是运行在用户空间的应用软件，对linux内核`netfilter`模块的封装。主要用于网络数据包管理和转发，可以实现对数据包过滤，转发，修改，以及`NAT`等功能。

它主要包含`table-表`，`chain-链`，`rule-规则`，`target-动作`这几个概念。

其中，表指不同的数据处理流程，例如，用于数据过滤的`filter`表，用于`NAT`的`nat`表，以及用于修改数据包的`mangle`表。每张表又包含多个链，链是一系列规则的合集，从上往下依次匹配。当匹配到指定的规则，执行对应的动作。通常，每个链有一个默认策略。当链中所有规则执行完毕没有跳走，则执行默认的策略。

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

每个表虽然包含的链名字相同，但是彼此没有关联。唯一的相同点，就是在数据包流动中的特定步骤。各个链对应的数据包处理步骤如图

![图片](/assert/imgs/iptables_flow.png)

接下来会分析一个实际例子，理解它的处理逻辑；然后，再根据实际需求，自己去建一个规则。

看下Docker的默认`iptables`配置

```shell
# 执行iptables-save打印所有的表
$ iptables-save
...
*filter
:INPUT ACCEPT [668:52089]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [431:46901]
:DOCKER - [0:0]
:DOCKER-ISOLATION-STAGE-1 - [0:0]
:DOCKER-ISOLATION-STAGE-2 - [0:0]
:DOCKER-USER - [0:0]
-A FORWARD -j DOCKER-USER
-A FORWARD -j DOCKER-ISOLATION-STAGE-1
-A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -o docker0 -j DOCKER
-A FORWARD -i docker0 ! -o docker0 -j ACCEPT
-A FORWARD -i docker0 -o docker0 -j ACCEPT
-A DOCKER-ISOLATION-STAGE-1 -i docker0 ! -o docker0 -j DOCKER-ISOLATION-STAGE-2
-A DOCKER-ISOLATION-STAGE-1 -j RETURN
-A DOCKER-ISOLATION-STAGE-2 -o docker0 -j DROP
-A DOCKER-ISOLATION-STAGE-2 -j RETURN
-A DOCKER-USER -j RETURN
COMMIT
*nat
:PREROUTING ACCEPT [1:60]
:INPUT ACCEPT [1:60]
:OUTPUT ACCEPT [124:8795]
:POSTROUTING ACCEPT [124:8795]
:DOCKER - [0:0]
-A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
-A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
-A DOCKER -i docker0 -j RETURN
COMMIT
```

### vlan和vxlan

## Docker容器网络

### Host

![图片](/assert/imgs/docker_net_host2.png)

#### 实践

```shell
host#docker run -d --name demo --net host busybox sleep 3600 
host#ip link
1: lo: ...
2: eth0: ...
3: docker0: ...
host#docker exec -it demo ip link
1: lo: ...
2: eth0: ...
3: docker0: ...
```

### Bridge

![图片](/assert/imgs/docker_net_bridge1.png)

#### 实践
```shell
# 查看Docker默认的网桥
host#ip addr | grep docker0
5: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0

# 启动两个容器
host#docker run -d --name C0 busybox sleep 3600
host#docker run -d --name C1 busybox sleep 3600

# 查看此时宿主机的网络设备
host#ip addr show
5: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:19:92:73:ba brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
7: vethc00ed59@if6: ... 
9: vetheab08d9@if8: ... 

# 查看容器C0和C1的网卡信息
C0#ip addr show
6: eth0@if7: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
C1#ip addr show
8: eth0@if9: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:ac:11:00:03 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.3/16 brd 172.17.255.255 scope global eth0
```

#### 自定义Bridge

```shell
# 创建一个自定义的网桥
host#docker netowork create -d bridge --subnet 192.168.0.0/24 mybridge
host#docker network ls
NETWORK ID          NAME                DRIVER
84dcfa90bc26        bridge              bridge
504fe4ba30e7        mybridge            bridge
...

# 启动两个容器，并连接到自定义的网桥
host#docker run -d --name D0 --net mybridge busybox sleep 3600
host#docker run -d --name D1 --net mybridge busybox sleep 3600

# 查看下网络命名空间
host#ip netns ls
752b54bc8316 (id: 3)
bcda1ab21d9d (id: 2)
d1fb83738e70 (id: 1)
0b11f8681598 (id: 0)
default

# 查看新启动的容器网络信息
host#docker exec -it D0 ip addr 
12: eth0@if13: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:c0:a0:00:02 brd ff:ff:ff:ff:ff:ff
    inet 192.160.0.2/24 brd 192.160.0.255 scope global eth0
host#docker exec -it D1 ip addr 
12: eth0@if13: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:c0:a0:00:02 brd ff:ff:ff:ff:ff:ff
    inet 192.160.0.3/24 brd 192.160.0.255 scope global eth0

# 查看路由信息
host#ip route
default via 10.0.3.1 dev enp0s8 proto static metric 101 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 
192.160.0.0/24 dev br-504fe4ba30e7 proto kernel scope link src 192.160.0.1
...

# 查看iptables
host#iptables -t nat -L
...
Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
MASQUERADE  all  --  192.160.0.0/24       anywhere            
MASQUERADE  all  --  172.17.0.0/16        anywhere
...
```

### overlay