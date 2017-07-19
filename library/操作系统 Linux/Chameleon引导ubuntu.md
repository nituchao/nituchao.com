---
"title": "Chameleon引导ubuntu",
"date": "2012-06-03T18:18:18+08:00",
"categories": ["MacOS"],
"tags": ["MacOS"]

---

现在，我的笔记本上同时运行着3个系统，Windows 7，Mac OS 10.7和Ubuntu 10.10。Ubuntu 10.10主要是用来编译调试我的Egg Boiler系统。

Ubuntu的grub2不能引导Mac OS X系统，所以用chameleon来引导三个系统是非常好的选择，同时chameleon是完全的图形化引导，非常漂亮。

我的做法非常简单，首先要安装好三个系统，特别要注意的是安装Ubuntu时，要选择把gurb2安装到Ubuntu的/分区，而不能将boot loader安在整个硬盘上，否则变色龙不能识别Ubuntu。

![grub2安装](http://olno3yiqc.bkt.clouddn.com/blog/img/chameleon-disk-part.png)

然后在Mac OS下安装Mac版变色龙到Mac OS系统分区。

![安装变色龙](http://olno3yiqc.bkt.clouddn.com/blog/img/chameleon-install.png)

最后，用Ubuntu的live-cd中的Gparted分区工具把Mac OS X所在分区的标记更改为”boot”，也就是开机从Mac OS X所在分区引导。

![设置boot标志](http://olno3yiqc.bkt.clouddn.com/blog/img/chameleon-boot.png)

最后附一个变色龙主题:[传送门](http://dl.dbank.com/c08nqxu7af)

![lion主题](http://olno3yiqc.bkt.clouddn.com/blog/img/chameleon-lion.png)
