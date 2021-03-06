---
"date": "2017-02-15T10:12:41+08:00",
"title": "分布式算法之2PC",
"tags": ["2pc", "xa"],
"categories": ["Xa"]

---

2PC，是Two-Phase Commit的缩写，即二阶段提交，是计算机网络尤其是在数据库领域内，为了使基于分布式系统架构下的所有节点在进行事务处理的过程中能够保持原子性和一致性而设计的一种算法。通常，二阶段提交协议也被认为是一种一致性协议，用来保证分布式系统数据的一致性。目前，绝大部分的关系型数据库都是采用二阶段提交协议来完成分布式事务处理的，利用该协议能够非常方便地完成所有分布式事务参与者的协调，统一决定事务的提交或回滚，从而能够有效地保证分布式数据一致性，因此二阶段提交协议被广泛地应用在许多分布式系统中。

## 协议说明
顾名思义，二阶段提交协议是将事务的提交过程分成了两个阶段来进行处理，其执行流程如下：

### 阶段一：提交事务请求
1，事务询问

协调者向所有的参与者发送事务内容，询问是否可以执行事务提交操作，并开始等待各参与者的响应。

2，执行事务

各参与者节点执行事务操作，并将Undo和Redo信息记入事务日志中。

3，各参与者向协调者反馈事务询问的响应。

如果参与者成功执行了事务操作，那么就反馈给协调者Yes响应，表示事务可以执行；如果参与者没有成功执行事务，那么就反馈给协调者No响应，表示事务不可以执行。

由于上面讲述的内容在形式上近似是协调者组织各参与者对一次事务操作的投标表态过程，因此二阶段提交协议的阶段一也被称为"投票阶段"，即各参与者投票表明是否要继续执行接下去的事务操作。

### 阶段二：执行事务提交
在阶段二，协调者会根据各参与者的反馈情况来决定最终是否可以进行事务提交操作，正常情况下，包含以下两种可能。

**执行事务提交**

加入协调者从所有的参与者获得的反馈都是Yes响应，那么就会执行事务提交。

1，发送提交请求。

协调者向所有参与者节点发出Commit请求。

2，事务提交。

参与者接收到Commit请求后，会正式执行事务提交操作，并在完成提交之后释放在整个事务执行期间占用的事务资源。

3，反馈事务提交结果。

参与者在完成事务提交之后，向协调者发送Ack消息。

4，完成事务。

协调者收到所有参与者反馈的Ack消息后，完成事务。

**中断事务**

假如任何一个参与者向协调者反馈了No响应，或者在等待超时之后，协调者尚无法接收到所有参与者的反馈响应，那么就会中断事务。

1，发送回滚请求

协调者向所有参与者节点发出Rollback请求。

2，事务回滚

参与者接收到Rollback请求后，会利用其在阶段一中记录的Undo信息来执行事务回滚操作，并在完成回滚后释放在整个事务执行期间占用的资源。

3，反馈事务回滚结果。

参与者在完成事务回滚之后，向协调者发送Ack消息。

4，中断事务

协调者接收到所有参与者反馈的Ack消息后，完成事务中断。

以上就是二阶段提交过程，前后两个阶段分别进行的处理逻辑。简单地讲，二阶段提交讲一个事务的处理过程分为了投票和执行两个阶段，其核心是对每个事务都采用先尝试后提交的处理方式，因此也可以将二阶段提交看做一个强一致性的算法。

### 优缺点
二阶段提交协议的优点：原理简单，实现方便。

二阶段提交协议的缺点：同步阻塞，单点问题，脑裂，太过保守。

**同步阻塞**

二阶段提交协议的最明显也是最大的一个问题就是同步阻塞，这会极大地限制分布式系统的性能。在二阶段提交的执行过程中，所有参与该事务操作的逻辑都处于阻塞状态，也就是说，各个参与者在等待其他参与者相应的额过程中，将无法进行其他任何操作。

**单点问题**

在上面的讲解过程中，相信读者可以看出，协调者的角色在整个二阶段提交协议中起到了非常重要的作用。一旦协调者出现问题，那么整个二阶段提交流程将无法运转，更为严重的是，如果协调者是在阶段二中出现问题的话，那么其他参与者将会一直处于锁定事务资源的状态中，而无法继续完成事务操作。

**数据不一致**

在二阶段提交协议的阶段二，即执行事务提交的时候，当协调者向所有的参与者发送Commit请求之后，发生了局部网络异常或者是协调者在尚未发送完Commit请求之前自身发生了崩溃，导致最终只有部分参与者收到了Commit请求。于是，这部分收到了Commit请求的参与者就会进行事务的提交，而其他没有收到Commit请求的参与者则无法进行事务提交，于是整个分布式系统便出现了数据不一致的现象。

**太过保守**

如果协调者指示参与者进行事务提交询问的过程中，参与者出现故障而导致协调者始终无法获取到所有参与者的相应信息的话，这时协调者只能依靠其自身的超时机制来判断是否需要中断事务，这样的策略显得比较保守。换句话说，二阶段提交协议咩有设计较为完善的容错机制，任意一个节点的失败都会导致整个事务的失败。
