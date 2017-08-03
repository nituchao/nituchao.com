---
"categories": ["MySQL"],
"tags": ["MySQL"],
"date": "2017-08-03T13:32:00+08:00",
"title": "InnoDB新特性"

---

1. 在线修改InnoDB buffer的大小


2. 提高 crash 恢复能力


3. 提高 read-only的可扩展性


4. 提高read-write事务的可扩展性


5. 几种优化高性能临时表


6. 扩展varchar大小只要求meta-data的改变


7. alter table rename index 只要求meta-data的改变


8. alter table的速度提高


9. 多page_cleaner 线程


10. 分析buffer pool刷新


11. 新加innodb_log_checksum_algorithm 操作


12. 提高对ＭＵＭＡ的支持


13. 全表空间的支持


14. 透明页的压缩


15. innodb_log_write_ahead_size 介绍地址potential  'read-on-write' 用于redo logs


16. 全文索引支持解析器


17. 支持ngram and MeCab 全文索引解析器的插件


18. 全文索引搜索的分析


19. 支持’innodb_buffer_pool_dump_pct‘


20. 两次写 buffer是禁用在文件系统并且支持原子写


21. page的填充因素现在是可以配置的


22. 支持32K和64K页


23. 在线 undo log 清空


24. update time 可以被更改的


25. truncate table是原子操作


26. memcached api 的性能提高


27. 自适应hash可伸缩性提高


28. InnoDB 实现了information_schema.files


29. 遗留的Innodb monitor表已经移除或者被全局配置文件替代


30. Innodb默认是row格式


31. Innodb 现在删除表在后台线程


32. Innodb 临时目录是可以立即配置的


33. InnoDB MERGE_THRESHOLD  可以在线配置


34. 默认配置的改变：innodb_file_format=Barracuda，innodb_large_prefix=1，innodb_page_cleaners=4， innodb_purge_threads=4，innodb_buffer_pool_dump_at_shutdown=1，innodb_buffer_pool_load_at_startup=1，innodb_buffer_pool_dump_pct=25，innodb_strict_mode=1，innodb_checksum_algorithm=crc32，innodb_default_row_format=DYNAMIC