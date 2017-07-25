---
"categories": ["Linux"],
"tags": ["Linux"],
"date": "2014-06-22T13:32:00+08:00",
"title": "Unix多路复用函数"
---

### 函数select和pselect

在所有POSIX兼容的平台上，select函数使我们可以执行I/O多路转接。传给select的参数告诉内核：

- 我们所关心的描述符。
- 对于每个描述符我们所关心的条件（是否想从一个给定的描述符读，是否想写一个给定的描述符，是否关心一个给定描述符的异常条件）；
- 愿意等待所长时间（可以永远等待、等待一个固定的时间或者根本不等待）。


从select返回时，内核告诉我们：

- 已经准备好的描述符的总数量。
- 对于读、写或异常这三个条件中的每一个，哪些描述符已经准备好。

使用这种返回信息，就可调用响应的I/O函数（一般是read或write），并且确知该函数不会阻塞。


```c
#include <sys/select.h>

int select(intmaxfdpl, 
		   fd_set*restrict readfds, 
		   fd_set*resttrict writefds, 
		   fd_set*restrict exceptfds, 
	       structtimeval *restrict tvptr);
```


select函数的特点：

- select传给内核三个集合，readfds,     writefds, exceptfds。
- 内核遍历并标记这些fd的状态，返回给进程，返回值是已经准备好的文件描述符df的总数，如果某个文件描述符fd有多个事件（如读、写、异常）都准备好，则总数计算多次。
- 进程遍历这些fd，对于准备好I/O的fd，进行阻塞式I/O。


```c
include <sys/select.h>
int pselect(intmaxfdpl, 
			fd_set *restrict readfds,
            fd_set *restrict writefds, 
            fd_set *restrict exceptfds,  
            const  struct timespec *restrict tsptr,
            const  sigset_t *restrict sigmask);
```

 

除了以下几点外，pselect与select相同。

- select的超时值用timeval结构指定，但pselect使用timespec结构。timespec结构以秒和纳秒表示超时值，而非秒和微秒。如果平台支持这样的时间精度，那么timespec就能提供更精准的超时时间。
- pselect的超时值被声明为const，这保证了调用pselect不会改变此值。
- pselect可使用可选信号屏蔽字。若sigmask为null，那么在与信号有关的方面，pselect的运行状况和select相同。否则，sigmask指向一信号屏蔽字，在调用pselect时，以原子操作的方式安装该信号屏幕字。在返回时，恢复以前的信号屏蔽字。



### 函数poll

```c
include <poll.h>
int poll(structpollfd fdarray[], nfds_t nfds, int timeout);
struct pollfd {
    int fd;          /* file descriptior to check, or < 0 to ignore*/
    short events;    /* events of interest on fd */
    short revents;   /* events that occurred on fd */

};   
```

poll函数可用于任何类型的文件描述符。与select不同，poll不是为每个条件（可读性，可写性和异常条件）构造一个描述符集，而是构造一个pollfd结构的数组，每个元素指定一个描述符编号以及我们对该描述符感兴趣的条件。

 应将每个数组元素的events成员设置为图14-17中所示值的一个或几个，通过这些值告诉内核我们关心的是每个描述符的哪些事件。返回时，revents成员由内核设置，用于说明每个描述符发生了哪些事件。

### 函数epoll

直到Linux2.6才出现了由内核直接支持的实现方法，那就是epoll，它几乎具备了之前所说的一切优点，被公认为Linux2.6下性能最好的多路I/O就绪通知方法。

epoll可以同时支持水平触发和边缘触发（EdgeTriggered，只告诉进程哪些文件描述符刚刚变为就绪状态，它只说一遍，如果我们没有采取行动，那么它将不会再次告知，这种方式称为边缘触发），理论上边缘触发的性能要更高一些，但是代码实现相当复杂。

epoll同样只告知那些就绪的文件描述符，而且当我们调用epoll_wait()获得就绪文件描述符时，返回的不是实际的描述符，而是一个代表就绪描述符数量的值，你只需要去epoll指定的一个数组中依次取得相应数量的文件描述符即可，这里也使用了内存映射（mmap）技术，这样便彻底省掉了这些文件描述符在系统调用时复制的开销。

另一个本质的改进在于epoll采用基于事件的就绪通知方式。在select/poll中，进程只有在调用一定的方法后，内核才对所有监视的文件描述符进行扫描，而epoll事先通过epoll_ctl()来注册一个文件描述符，一旦基于某个文件描述符就绪时，内核会采用类似callback的回调机制，迅速激活这个文件描述符，当进程调用epoll_wait()时便得到通知。

```c
#include<sys/epoll.h>
intepoll_create(int size);
intepoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
intepoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout);
```

 