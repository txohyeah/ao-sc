从指定的Process中抓取所有的合约记录。

在 fetch_sc_record.py 中修改你需要抓取合约代码的Process id
确定合约代码的大致时间点，修改start_time和end_time。

运行fetch_sc_record.py，会生成一个msg_eval.json文件，里面包含了所有在Process上运行的代码。

可以从中简单的找出合约代码。

一般是在一条message中的data字段。


python version 3.12

依赖everpay python sdk

本程序调用了用python写的与ao交互的sdk，地址如下 https://github.com/xiaojay/ao.py 