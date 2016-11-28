# aliyun-ddns-Shell_Script

阿里云DDNS解析Shell Script
版本

准备条件：阿里云必须先买个域名（目前.win最便宜）

运行环境：
curl、openssl、jq（解析JSON数据）

配置参数：aliddns.sh中

#主机名数组
RRs=("home @ www")
#阿里云域名
DomainName="必须设置.win"
#Access Key Id
AccessKeyId="必须设置"
#Access Key Secret
AccessKeySecret="必须设置"