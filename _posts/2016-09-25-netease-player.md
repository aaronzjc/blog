---
layout: post
title: "Jekyll博客加上Mp3播放器"
date:   2016-09-25 10:00:00 +0800
categories: jekyll
---

{::nomarkdown}
<iframe frameborder="no" border="0" marginwidth="0" marginheight="0" width=330 height=86 src="https://music.163.com/outchain/player?type=2&id=27759604&auto=0&height=66">
</iframe>
{:/nomarkdown}

关于如何在Jekyll博客中，添加Mp3播放器，就像这篇文章那样。

首先，找到自己想要添加的歌曲，生成外链播放器

![播放器](/assert/imgs/netease.png)


查看外链播放器，发现是一个iframe标签。所以，只用在文章中嵌入iframe标签即可。这里可以设置播放器自动播放还有尺寸大小。

Jekyll使用的markdown解析器是`kradown`解析器。按照[文档](https://kramdown.gettalong.org/syntax.html)，在文章内容中，加上如下的标签，解析器就不会处理而原样输出HTML标签了。

```text
{::nomarkdown}
<iframe></iframe>
{:/nomarkdown}
```

最后，就嵌入了一个漂亮的音乐播放器了。

```text

《The Roving Gambler》

这首歌是电影《醉乡民谣》中的一个插曲，节奏听着很古老。确实很老的一首歌了。

我是喜欢《500 Miles》，然后听到这首歌，觉得很有趣。

有一种淡淡的忧伤的情绪。歌手用很随意轻快，玩世不恭的语调诉说自己是个赌徒，逢赌必输。偶然遇到自己喜欢的女孩，女孩深爱自己。

后面就是女孩和奶奶的台词，用女孩的角度来诉说她们之间的对话。

挺有意思的一首民谣。
```
