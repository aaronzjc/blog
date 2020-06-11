---
layout: post
title: "PHP new self和new static区别"
date:   2016-02-18 18:00:00 +0800
categories: web
---

开发中，有时候看到`new self`的写法，这个很好理解，就是实例化当前类。但偶然又看到`new static`这种写法来实例化。很诡异，于是研究了一下。

一句话总结，PHP自5.3起，增加了一个后期静态绑定的功能，用于在继承范围内引用静态调用的类。什么意思？
```php
<?php
class A{
    public static function testSelf() {
        return new self();
    }
    public static function testStatic() {
        return new static();
    }
}
class B extends A{}
echo get_class(B::testSelf());  /* A */
echo get_class(B::testStatic());  /* B  */
```

### new self

self取决于当前方法定义的类。如上的例子中，testSelf是在A中定义的，B通过继承得到。因此，`new self`指的是定义的类，即A。然后，如果在B中
重新覆盖了父类中的这个方法呢？看下面
```php
<?php
class A{
    public static function testSelf() {
        return new self();
    }
}
class B extends A{
    public static function testSelf() {
        return new self();
    }
}
echo get_class(B::testSelf());  /* B */
```
就是这么一回事。然后，出现一种情况就是，用户期望在使用静态调用的时候得到调用的类。这就是静态绑定。也就是有一个关键字来获取最终调用时的类，PHP官方最终使用static关键字来干这么一件事。

### new static

经过上面的解释，现在理解，static即是获取最终调用时的类。看下面
```php
<?php
class A{
    public static function testStatic() {
        return new static();
    }
}
class B extends A{}
echo get_class(B::testStatic());  /* B */
```
我测试了一下，似乎不仅仅是通过静态方式，使用实例化访问时，表现一致。看下面
```php
<?php
class A{
    public function testSelf() {
        return new self();
    }
    public function testStatic() {
        return new static();
    }
}
class B extends A{
    /* test2
    public function testSelf() {
        return new self();
    }
    */
}
echo get_class((new A())->testSelf());
echo get_class((new A())->testStatic());
echo get_class((new B())->testSelf());
echo get_class((new B())->testStatic());
/* AAAB */
/* AABB */
```

### 最后

完。

参考资料

* [PHP后期静态绑定](http://php.net/manual/zh/language.oop5.late-static-bindings.php)
