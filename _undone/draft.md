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

`vxlan`使用`mac in udp`方式，将二层的数据封装成UDP数据包，然后在三层网络中传输。采用`4789`作为通信的端口号。这种`mac in udp`方式也并不是首创，很多隧道通信协议都采用这种方式。

和`vlan`类似，`vxlan`也有一个唯一标识来区分各个子网，叫`vxlan vni`。它有24位空间，解决了空间不足的问题。此外，`vxlan`需要利用`vtep`设备做封包和解包。`vtep`设备可以是物理交换机，也可以是虚拟的网络设备。

前面提过，`vxlan`是利用三层网络来实现逻辑二层网络。那么二层网络通信需要考虑的问题，`vxlan`必须也要能支持。例如，单播，多播和广播等。同一个`vlan`下的设备，是可以直接两两通信的。在`vxlan`下，主机在不同的子网，依赖`vtep`通信，所以必须两两通过`vtep`连接。






[VXLAN vs VLAN](https://zhuanlan.zhihu.com/p/36165475)
[虚拟网络中的Linux虚拟设备](https://developers.redhat.com/blog/2018/10/22/introduction-to-linux-interfaces-for-virtual-networking/)
[vxlan](https://support.huawei.com/enterprise/zh/doc/EDOC1100087027#ZH-CN_TOPIC_0254803605)