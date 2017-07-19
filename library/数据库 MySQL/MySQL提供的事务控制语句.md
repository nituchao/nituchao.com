---
"date": "2017-02-14T14:09:01+08:00",
"title": "MySQL提供的事务控制语句",
"tags": ["MySQL", "Transaction"],
"categories": ["MySQL"]

---

在MySQL命令行的默认设置下，事务都是自动提交的，即执行SQL语句后就会马上执行`COMMIT`操作。因此要显式地开启一个事务需要使用命令`BEGIN`, `START TRANSACTION`, 或者执行命令`SET AUTOCOMMIT=0`, 禁用当前会话的自动提交。

每个数据库厂商自动提交的设置都会不相同，每个DBA或开发人员需要非常明白这一点，这对之后的SQL编程会有非凡的意义，因此用户不能以之前的经验来判断MySQL数据库的运行方式。

MySQL为开发者提供了三种类型的事务，分别是扁平化事务，带保存点的事务，链式事务。通过带保存点的事务还可以模拟实现嵌套事务。

### START TRANSACTION | BEGIN
显式地开启一个事务。

### COMMIT
要想使用这个语句的最简形式，只需要发出`COMMIT`。也可以更详细一点，写为`COMMIT WORK`, 不过这两者几乎是等价的。`COMMIT`会提交事务，并使得已对数据库做的修改称为永久性的。

### ROLLBACK
要想使用这个语句的最简形式，只需要发出`ROLLBACK`。同样地，也可以写为`ROLLBACK WORK`，但两者几乎是等价的。回滚会结束用户的事务，并撤销正在进行的所有未提交的修改。

### SAVEPOINT identity
`SAVEPOINT`允许在事务中创建一个保存点，一个事务中可以有多个`SAVEPOINT`。

### RELEASE SAVEPOINT identity
删除一个事务的保存点，当没有一个保存点执行这语句时，会抛出一个异常。

### ROLLBACK TO [SAVEPOINT] identity
这个语句与`SAVEPOINT`命令一起使用。可以把事务回滚到标记点，而不回滚在此标记点之前的任何工作。

例如，可以发出两调`UPDATE`语句，后面跟一个`SAVEPOINT`, 然后又是两条`DELETE`语句。如果执行`DELETE`语句期间出现了某种异常情况，并且捕获到这个异常，同时发出了`ROLLBACK TO SAVEPOINT`命令，事务就会回滚到指定的SAVEPOINT，撤销`DELETE`完成的所有工作，而`UPDATE`语句完成的工作不受影响。

### SET TRANSACTION
这个语句用来设置事务的隔离级别。

InnoDB存储引擎提供的事务隔离级别有：

* READ UNCOMMITED
* READ COMMITTED
* REPEATABLE READ
* SERIALIZABLE

`START TRANSACTION`, `BEGIN`语句都可以在MySQL命令行下显示地开启一个事务。但是在存储过程中，MySQL数据库的分析器会自动将BEGIN识别为BEGIN...END, 因此在存储过程中只能使用`START TRANSACTION`语句来开启一个事务。

`COMMIT`和`COMMIT WORK`语句基本是一致的，都是用来提交事务。不同之处在于`COMMIT WORK`用来控制事务结束后的行为是`CHAIN`还是`RELEASE`的。如果是`CHAIN`方式，那么事务就变成了链事务。

用户可以通过参数`completion_type`来进行控制，该参数默认为0，表示没有任何操作。

当参数`completion_type`的值为1时，`COMMIT WORK`等同于`COMMIT AND CHAIN`, 表示马上自动开启一个相同隔离级别的事务。

当参数`completion_type`的值为2时，`COMMIT WORK`等同于`COMMIT AND RELEASE`, 在事务提交后会自动断开与服务器的连接。
