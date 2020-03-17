---
layout: post
title: "MurmurHash 2.0"
date:   2020-03-17 11:00:00 +0800
categories: deep-in
---

## Murmurhash 2.0

[`MurmurHash 2.0`](https://github.com/aappleby/smhasher/wiki/SMHasher)算法是由`Austin Appleby`设计的一个hash方法。应用广泛。Redis中就是用的此方法来对字典key做hash计算。

2.0版本可以生成32位的hash值。其大致思路是，将串的比特位，按照4字节分组。将每个分组进行一系列计算，最终计算一个hash值。如果输入串长度不是4的倍数，则针对剩余串再做一些处理。生成最终的hash值。

如下是按照Redis中原始c实现，写了个Go版本

{% highlight golang %}
var (
	m uint32 = 0x5bd1e995
	r uint32 = 24
)

func MurmurHash2(data []byte, seed uint32) uint32 {
	h := seed ^ uint32(len(data))

	for len(data) >= 4 {
		k := *(*uint32)(unsafe.Pointer(&data[0]))

		k *= m
		k ^= k >> r
		k *= m

		h *= m
		h ^= k

		data = data[4:]
	}

	switch len(data) {
	case 3:
		h ^= uint32(data[2]) << 16
	case 2:
		h ^= uint32(data[1]) << 8
	case 1:
		h ^= uint32(data[0])
		h *= m
	}

	h ^= h >> 13
	h *= m
	h ^= h >> 15

	return h
}
{% endhighlight %}

实话实说，看到这个方法，有点懵。知道每一个步骤是啥，但是连在一起就看不懂了。不知道这一通乘，移位，异或运算的根据在哪里。后续再深入了解吧。

## Hash攻击

按照作者所言，此版本的hash方法是有[缺陷](https://github.com/aappleby/smhasher/wiki/MurmurHash2Flaw)的。

假设有一个32位的串x，有这么一个输入串xx。针对循环中的hash计算如下

{% highlight text %}
# 因为x相同，所以这一段的内容不变
x *= m
x ^= x >> r
x *= m

# 因为读取了两段x，所以这里只是执行了两次这个过程
h *= m
h ^= x
h *= m
h ^= x
{% endhighlight %}

现在，假设m = 1，上面的这段计算就变成了

{% highlight text %}
x ^= x >> r

# 两次异或等于本身
# h ^= x
# h ^= x
{% endhighlight %}

即，最终的hash值和输入的串没有任何关系。最终都是一个值。不过，实际中，m的值不可能是1。那是不是m不等于1就没有问题了呢？作者经过测试，给出了答案。就算m不等于1，也还是会有一些hash值有问题。

## 最后

因为这个问题。作者升级了3.0版本，采用了另一个计算方式。

此外作者也做了一个额外的工作，开发了一个hash检测工具，来测量一个hash方法。感兴趣可以查看项目主页了解。