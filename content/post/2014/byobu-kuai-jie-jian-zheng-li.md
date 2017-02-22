---
title: "Linux终端Session管理工具整理"
date: "2014-06-24T15:19:00+08:00"
categories: ["Linux"]
tags: ["Linux", "Tool"]
draft: false
---

## Tmux
**2017年2月22日更新**

最近一直在用Tmux作为默认的终端Session管理工具。Tmux可以轻松的完成窗口创建，屏幕切分，文本模式，命令行模式等功能。

最让我满意的是多屏幕的同步操作功能。每次需要ssh到服务器查看日志时，我会将屏幕切割成四块，分别登陆到4个服务器上，然后开启sync模式，这样输入的命令将同时在4台服务器上一起执行，大大提高了操作效率。

Tmux的Session支持后台运行，可以通过attache随时进入Tmux，并立即恢复工作状态。

### 同步操作

<img src="http://olno3yiqc.bkt.clouddn.com/blog/img/tmux-session.png" width=780px height=500px alt="tmux同步操作" />


## Byoby

byoby是Ubuntu团队开发的screen的替代产品，支持session管理，屏幕切分，SSH管理。配置和使用也非常简单，一直是我非常喜欢的系统Terminal的替代产品，大赞。

### 帮助菜单

![byobu帮助](http://hanquan.qiniudn.com/byobuhelp.png)
