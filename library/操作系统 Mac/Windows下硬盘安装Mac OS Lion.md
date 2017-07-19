---
"title": "Windows下硬盘安装Mac OS Lion",
"date": "2012-05-20T20:20:00+08:00",
"categories": ["MacOS"],
"tags": ["MacOS"]
---

经过一年多的尝试，建议大家安装Mac OS X 10.7原版，这个版本的Mac OS 系统对硬件的兼容性非常好，安装出现的问题也最少。建议大家驱动都自己手动安装，这样子才能更清楚自己装了哪些驱动，将来遇见诸如”五国”，”无限风火轮”的问题时才能更容易找到问题的原因。

此日志讨论的是在Windows系统下通过原版Mac OS X 10.7的dmg镜像来安装Mac OS系统的方法。

文章有点长，请耐心看完~~

* 理论上说，该方法也可以用来在Windows系统下制作U盘系统安装盘。
* 理论上说，该方法也可以用来在Windows系统下安装10.7.1,10.7.2,10.7.3,10.7.4甚至是10.8的原版镜像。

<hr/>

## 准备工作
* 系统:Windows 7，Windows XP
* Mac OS X 10.7原版dmg镜像
* dmg镜像浏览工具HFSExplorer-0.21版
* 磁盘分区工具Paragon Partition Manager 11版
* 硬盘安装助手HD Install Helper v0.3版
* Mac Driver 8版
* Windows版变色龙
* 必要的驱动和破解文件
 	* 适合自己机型的dsdt.aml
	* 修改过的适合10.7的OSInstall和OSInstall.mpkg，有需要的可以下载我准备好的传送门
	* FakeSMC.kext 破解补丁，用于破解Mac OS内核，必须
	* AppleACPIPS2Nub.kext
	* ApplePS2Controller.kext
	* NullCPUPowerManagement.kext 禁用电源管理功能，解决HPET错误

**说明:以上的文件，除了dsdt.aml是要适合自己机型的外，其他的文件都是通用的，都可以在远景论坛上找到，想吃黑苹果，趴贴的精神和毅力必须是有的~~**

## 制作安装盘
* 安装Mac Driver 8备用，安装完后需要重启。

* 留出3个分区
	* 系统盘，20G,主分区，Mac OS X系统要安装在这个分区。建议该分区尽量大一点，因为装上Mac OS后我们还要装很多软件，比如我分了42G给该分区
	* 安装盘，至少2G,主分区(或逻辑分区)，Mac OS X的安装盘要安装在这个分区。
	* 备用盘，至少3G,不创建分区，该分区的目的是为了扩充安装盘分区，因为Mac OS X的镜像写入到安装盘分区后，安装盘分区只剩下300M左右，不能进行接下来的操作，这时候需要把这3G空白分区合进安装盘分区。

![分区](http://olno3yiqc.bkt.clouddn.com/blog/img/v8TRO.png)

* 修改分区ID = AF。这一步很重要，ID = AF表示这是一个Apple HFS+分区，Mac OS只能安装在HFS+分区上。

![设置分区ID](http://olno3yiqc.bkt.clouddn.com/blog/img/yRIIO.png)

**强烈建议: 用下面的命令来修改系统盘和安装盘的分区ID，因为经过实践发现，用磁盘分区工具来修改ID失败的概率很大，通过命令行来修改通常不会出错，运行cmd打开命令行窗口后，一次执行下面的命令,看到success就ok了，这个时候在资源管理器里就看不到这个分区了。**
```
diskpart
select disk 0
list partition    #列出所有分区，找到放硬盘镜象的partition
select partition 0  #选择硬盘镜象所在的分区，这里的“0”换成你上面显示的硬盘镜象所在分区的编号
set id=af
```
* 从原dmg镜像中提取BaseSystem.dmg，mach_kernel和Packages文件夹。

	需要说明的是，直接下载的dmg镜像中提取的BaseSystem.dmg文件不能被硬盘安装助手识别，这个dmg镜像比如用HFSExplorer导出一次后才能被硬盘安装助手识别。因此这一步的操作有两个:
	* 用HFSExplor加载下载的Mac OS X Install ESD.dmg镜像。然后导出BaseSystem.dmg，mach_kernel和Packages文件夹备用
	* 用HFSExplor加载导出的BaseSystem.dmg文件，然后点击”Tools”->”Create disk image”，将BaseSystem.dmg重新导出成硬盘安装助手可以识别的dmg镜像，可以把导出的文件命名为BaseSystem_Eable.dmg。

![导出dmg镜像](http://olno3yiqc.bkt.clouddn.com/blog/img/q3mjP.png)

![导出进行中](http://olno3yiqc.bkt.clouddn.com/blog/img/pZBmF.png)

**最终有用的文件是：**

>
* BaseSystem_Eable.dmg
* mach_kernel
* Packages文件夹

* 用硬盘安装助手HD_Install_Heper_v0.3写入BaseSystem_Eable.dmg镜像到安装盘分区，几分钟后，提示”All Done, have fun!”即表示写入成功。

* 扩充安装盘。

	镜像写入后，如果安装了Mac Driver 8，你就可以在资源管理器里看到，安装盘只剩下300M左右，这点空间是不足以进行接下来的工作的。这就需要尽心安装盘分区扩展。

  	操作:打开Paragon Partition Manager磁盘分区工具，选中安装盘，右键选择”移动调整分区大小”,然后把剩下的那个空白分区合并进安装盘分区，然后点击左上角的”应用”按钮。


* 将提取的mach_kernel文件放到安装盘根目录下

* 删除/System/Installtion目录下原来的Packages链接文件，并将提取的Packages文件夹放到安装盘的/System/Installtion/目录下。

* 安装文件替换
	* 将修改过的OSInstall.mpkg文件替换掉文件

```
/System/Installtion/Packages/OSInstall.mpkg
```
	* 将修改过的OSInstall 文件替换掉文件
```
/System/Library/PrivateFrameworks/Install.framework/Frameworks/OSInstall.framework/Versions/A/OSInstall
```
* 在安装盘根目录下建立Extra文件夹在该文件夹下放入以下文件

	* dsdt.aml，该文件是用于Mac OS X系统识别主板和硬件的，一定要是适合自己机型的才有用，没有这个文件或这不适合自己机型会导致绝大多数情况的”五国”问题
	* 建立Exentsion文件夹，放入下面四个驱动
		* FakeSMC.kext 破解补丁，用于破解Mac OS内核，必须
		* AppleACPIPS2Nub.kext
		* ApplePS2Controller.kext
		* NullCPUPowerManagement.kext 禁用电源管理功能，解决HPET错误
* 安装windows版变色龙

 到这里，Mac OS X的安装盘就做好了。重启计算机，选择变色龙引导，然后选择引导刚刚做好的Mac OS X安装盘分区，稍稍等一下就可以进入安装界面了，如果提示你找不到键盘，只要插上外接的USB键盘就可以了。之后用磁盘分区工具对准备好的系统分区进行”抹盘”，然后按照提示一路下一步安装即可。

<hr/>

安装完成后，进入Windows系统，把安装盘里刚刚建立的Extra文件夹(包括里面的文件)复制到Mac OS X的系统盘，如果没有这个Extra文件夹，安装好的Mac OS系统是进不去的，会提示五国。复制完后，重启计算机，用Windows版版色龙就可以引导进入新安装好的Mac OS X系统了。
