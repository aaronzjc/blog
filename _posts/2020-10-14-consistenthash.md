---
layout: post
title: "一致性Hash"
date:   2020-10-13 22:00:00 +0800
categories: deep-in
---
## 介绍

一致性hash是一种特殊的hash算法。传统的hash算法在改变槽的数量后，一般需要重新映射，元素变动很大。采用一致性hash算法，在改变槽的数量时，平均只需要对k/n(k是元素个数，n是槽的数量)个元素进行重新映射。

举个例子，将10w个元素存入一个水平划分的4个Redis服务器集群。在选择集群的时候，按照最简单的取模的方式来确定服务器。这时候，每个服务器的元素数量约1/4。如果这时候有两个Redis服务器被下线了。沿用之前取模的方式，则可能导致找不到对应的元素，最后重新映射这10w个元素。

一致性hash算法就是解决类似如上的这种场景。当增减服务器时，尽可能的保证原有的元素位置不变，只有少量的元素需要重新映射。

## 一致性hash算法

此算法的核心思想是，将hash槽看做一个环。每个槽就是环上的一个节点。在计算元素所属的节点时，不是直接返回节点的位置。而是先算出这个元素的hash，返回距离它最近的那个节点。

如图

![img](/assert/imgs/consisthash_1.png)

有3个节点A-100，B-200，C-300。按照它们的hash值从小打到排列，在图位置如上。我们规定，一致性hash算法，返回大于元素的hash值的第一个元素。那么，对于图中元素1，应该返回节点B；对于元素2，应该返回节点C；对于元素3呢？找不到比它更大的节点，此时返回节点A。

按照这个规则的话，如果节点B突然挂了。此时，受影响的也只有A-B之间的元素。这部分元素需要重新映射到节点C。相比传统的hash算法，稳定性更好。

但是这个算法有一个问题。当节点比较少的时候，节点在环上的位置很容易分布不均。这时候，很容易导致3个节点的元素数量差别很大。这也不符合一个好的hash算法。

解决方法是，在环上增加对应的虚拟节点。例如，原先有3个节点，可以增加3个副本，即9个虚拟节点。如下所示

![img](/assert/imgs/consisthash_2.png)

相同节点用相同颜色表示。环上的节点多了，自然分布也会更加均匀。需要注意的是，这里的分布均匀并不是严格的均匀。因为我们分割这个环依赖的是hash算法计算出来的值。因为hash算法的随机性，所以还是会出现一类节点挨在一起的情况。

## 一个实现

这里，我们参考一个简单的实现，`go-redis`包中引用到的。

```golang
package consistenthash

import (
	"hash/crc32"
	"sort"
	"strconv"
)

type Hash func(data []byte) uint32

type Map struct {
	hash     Hash
	replicas int
	keys     []int // 所有节点的hash值
	hashMap  map[int]string
}

func New(replicas int, fn Hash) *Map {
	m := &Map{
		replicas: replicas, // 生成多少个节点副本
		hash:     fn, // 底层使用的hash算法
		hashMap:  make(map[int]string),
    }
    // 默认的hash算法
	if m.hash == nil {
		m.hash = crc32.ChecksumIEEE
	}
	return m
}

// 判断是否为空
func (m *Map) IsEmpty() bool {
	return len(m.keys) == 0
}

// 生成各个节点的hash，也就是生成一个“环”。
func (m *Map) Add(keys ...string) {
	for _, key := range keys {
        // 根据副本数量，添加节点，即节点+虚拟节点
		for i := 0; i < m.replicas; i++ {
			hash := int(m.hash([]byte(strconv.Itoa(i) + key)))
			m.keys = append(m.keys, hash)
			m.hashMap[hash] = key
		}
    }
    // 排序，加速查找
	sort.Ints(m.keys)
}

// 获取随机字符串对应的节点
func (m *Map) Get(key string) string {
	if m.IsEmpty() {
		return ""
	}

	hash := int(m.hash([]byte(key)))

	// 查找所有hash节点中，大于给定元素hash的第一个节点
	idx := sort.Search(len(m.keys), func(i int) bool { return m.keys[i] >= hash })

	// 没找到，表明到了环的最后一节，取第一个节点。
	if idx == len(m.keys) {
		idx = 0
	}

	return m.hashMap[m.keys[idx]]
}
```

看吧，也没有很复杂。