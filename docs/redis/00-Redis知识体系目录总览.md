# 00-Redis知识体系目录总览 📚

📌 目录总览

| 模块  | 文件                                                         | 备注                                        |
| ----- | ------------------------------------------------------------ | ------------------------------------------- |
| Redis | [01-Redis基础入门.md](docs/redis/01-Redis基础入门.md)             | 介绍、安装部署、配置与基本命令              |
| Redis | [02-五大基础数据结构&底层原理.md](docs/redis/02-五大基础数据结构&底层原理.md) | String/List/Hash/Set/ZSet 底层实现          |
| Redis | [03-高级数据结构&特殊类型.md](docs/redis/03-高级数据结构&特殊类型.md) | Bitmap、HyperLogLog、Geo、Stream 等         |
| Redis | [04-Redis持久化机制.md](docs/redis/04-Redis持久化机制.md)         | RDB、AOF、混合持久化原理与选型              |
| Redis | [05-高可用：主从+哨兵+集群.md](docs/redis/05-高可用：主从+哨兵+集群.md) | 主从复制、哨兵、Cluster 分片与扩缩容        |
| Redis | [06-缓存核心问题&解决方案.md](docs/redis/06-缓存核心问题&解决方案.md) | 缓存穿透/击穿/雪崩、一致性、热点/大Key      |
| Redis | [07-Redis事务&锁机制.md](docs/redis/07-Redis事务&锁机制.md)       | 事务、Lua 脚本、分布式锁与 Redisson         |
| Redis | [08-内存管理&性能优化.md](docs/redis/08-内存管理&性能优化.md)     | 内存淘汰、过期删除、碎片、慢查询优化        |
| Redis | [09-运维监控&生产最佳实践.md](docs/redis/09-运维监控&生产最佳实践.md) | 部署规范、监控指标、备份恢复与事故复盘      |
| Redis | [10-Java客户端与实战.md](docs/redis/10-Java客户端与实战.md)       | Jedis/Lettuce/SpringDataRedis、常见场景代码 |
| Redis | [11-Redis核心源码浅析.md](docs/redis/11-Redis核心源码浅析.md)     | 事件模型、IO多路复用、关键实现解析          |
| Redis | [12-Redis6.0+新特性.md](docs/redis/12-Redis6.0+新特性.md)         | 多线程、ACL、客户端缓存、模块扩展           |
| Redis | [13-常见面试场景题.md](docs/redis/13-常见面试场景题.md)           | 高频问答、场景设计题、面试答题模板          |