---
"title": "MySQL数据类型之实数",
"date": "2014-09-12T10:30:00+08:00",
"categories": ["MySQL"],
"tags": ["MySQL"]
---


Mysql使用浮点数类型和定点数类型来表示小数。浮点数类型包括单精度浮点数(FLOAT类型)和双精度浮点数(DOUBLE类型)。定点数类型就是DECIMAL型。

实数有分数部分。然而，它们并不仅仅是分数。可以使用DECIMAL保存比BIGINT还大的整数。MySQL同时支持精确与非精确类型。

FLOAT和DOUBLE类型支持使用标准的浮点运算进行近似计算。如果想知道浮点运算到底如何进行，则要研究平台浮点数的具体实现。

DECIMAL类型用于保存精确的小数。在MySQL5.0及以上版本，DECIMAL类型支持精确的数学运算。MySQL4.1和早期版本对DECIMAL值执行浮点运算，它会因为丢失精度而导致奇怪的结果。在这些MySQL版本中，DECIMAL仅仅是“存储类型”。

在MySQL5.0及以上版本中，服务器进行了DECIMAL运算，因为CPU并不支持对它进行直接计算。浮点运算会快一点，因为计算直接在CUP上进行。

可以定义浮点类型和DECIMAL类型的精度。对于DECIMAL列，可以定义小数点之前和之后的最大位数，这影响了所需的存储空间。MySQL5.0和以上版本把数字保存到了一个二进制字符串中(每个4字节保存9个数字)。例如，DECIMAL(18,9)将会在小数点前后都保存9位数字，总共使用9个字节: 小数点前4个字节，小数点占一个字节，小数点后4个字节。

MySQL5.0及以上版本中的DECIMAL类型最多允许65个数字。在较早的版本中，DECIMAL最多可以有254个数字，并且保存为未压缩的字符串(一个数字占一个字节)。然而，这些版本的MySQL根本不能在计算中使用如此大的数字，因为DECIMAL只是一种存储格式。DECIMAL在计算时会被转换为DOUBLE类型。

可以用多重方式定义浮点数列的精度，它会导致MySQL悄悄采用不同的数据类型，或者在保存的时候进行圆整。这些精度定义符不是标准的，因此我们建议定义需要的类型，而不是精度。

比起DECIMAL类型，浮点类型保存同样大小的值使用的空间通常更少。FLOAT占用4个字节。DOUBLE 占用8个字节，而且精度更高，范围更大。和整数一样，你选择的仅仅是存储类型。MySQL在内部对浮点类型使用DOUBLE进行计算。

由于需要额外的空间和计算开销，只有在需要对小数进行精确计算的时候才使用DECIMAL，比如保存金融数据。
