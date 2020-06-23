`vxlan`是一个比较复杂的玩意。我也只是初略的学习了下，以下内容也是基于自己学习的深度。如果对这个技术感兴趣，建议阅读完后寻找其他更加深入的材料进行学习。

#### vxlan介绍

`vxlan`是什么？

`vxlan`全称`virtual extensible local area network`，是对`vlan`技术的一种扩展，属于网络虚拟化技术的一种。网络虚拟化，指的是在物理网络上构建一套虚拟的逻辑网络。通常，物理世界的网络叫`underlay network`，基于此构建的逻辑网络也叫`overlay network`。因此，使用`vxlan`技术构建的网络，也是一种`overlay network`。

为什么会有`vxlan`技术？

`vxlan`技术的发展和云计算息息相关。在大规模云计算数据中心下，`vlan`技术渐渐显得力不从心。主要有如下一些问题

+ `vlan ID`只有12位，只支持最多4096个子网。
+ `vlan`技术使用常规的二层网络通信，交换机需要记录每个设备的MAC地址，在云计算时代，每个物理机有好多个虚拟机，每个数据中心又有很多物理机。MAC地址急剧膨胀，很容易导致交换机的MAC地址耗尽。
+ 需要支持虚拟机的灵活迁移。可能一个物理机宕机了，在之上的虚拟机会很快迁移到另一个机器，这两个机器很可能不在一个子网内，但是迁移时又不希望改变它的网络配置。而通常`vlan`下的机器都属于一个子网，这样就限制了虚拟机的迁移。
+ `STP`收敛慢的问题。其实，我自己的理解，`vxlan`并没有主要去解决这个问题。而是它选择基于三层网络传输，自然就没有这个问题了。

`vxlan`怎么工作？

`vxlan`使用`mac in udp`方式，将二层的数据封装成UDP数据包，通过`4789`端口，在三层网络中传输。这种`mac in udp`方式也并不是首创，很多隧道通信协议都采用这种方式。它具体的封装结构如图(来自：[https://support.huawei.com/enterprise/en/doc/EDOC1100004365/f95c6e68/vxlan-packet-format](https://support.huawei.com/enterprise/en/doc/EDOC1100004365/f95c6e68/vxlan-packet-format))

![img](/assert/imgs/docker_net_basic5.png)

类似`vlan`，`vxlan`通过24位的`vni`来标识子网，解决了空间不足的问题。相同`vni`构成的一个虚拟大二层网络叫`Bridge-Domain`。`vxlan`需要`vtep`设备做封包和解包。`vtep`设备可以是物理交换机，也可以是虚拟的网络设备。因为`vxlan`是利用三层网络来实现逻辑二层网络。那么`vxlan`也具备`vlan`的一些特征。例如，支持单播，多播和广播等；不同的`vni`之间不能直接通信，需要借助其他的方式来实现。

熟悉了`vxlan`的基本概念，接下来实际操作。实现一个`vxlan`，让两个虚拟机中的Docker容器能够通过`vxlan`通信。大致结构如图


[虚拟网络中的Linux虚拟设备](https://developers.redhat.com/blog/2018/10/22/introduction-to-linux-interfaces-for-virtual-networking/)
[什么是vxlan](https://support.huawei.com/enterprise/zh/doc/EDOC1100087027#ZH-CN_TOPIC_0254803605)