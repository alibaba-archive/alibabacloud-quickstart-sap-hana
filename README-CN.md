[English](README.md) | 简体中文

<h1 align="center">alibabacloud-quickstart-sap-hana</h1>

## 用途

SAP自动化部署工具sap-hana，在同一可用区内创建和配置基础云资源、SAP HANA软件、HANA系统复制（HANA System Replication）、高可用集群以及可选的RDP系统和操作审计服务。

sap-hana支持如下部署模板：

+ SAP HANA单节点模板（新建VPC、已有VPC）
+ SAP HANA双节点高可用集群模板（新建VPC、已有VPC）

详细的自动化部署最佳实践请参考阿里云官网[《SAP 自动化安装部署最佳实践》](https://www.aliyun.com/acts/best-practice/preview?id=1934811)

## 文件目录

```yaml
├── sap-hana-single-node # SAP HANA单节点
    ├── scripts # 脚本目录
    │   ├── sap_hana_single_node.sh # SAP HANA单节点安装脚本
    │   ├── sap_hana_single_node_input_parameter.cfg # SAP HANA单节点安装脚本参数文件
    ├── templates # 资源编排(ROS)模板目录
    │   ├── HANA_Single_Node.json  # HANA单节点基础模板：ECS、安全组、访问控制角色等云资源
    │   ├── New_VPC_HANA_Single_Node.json # HANA单节点新建VPC模板
    │   ├── New_VPC_HANA_Single_Node_In.json # HANA单节点新建VPC模板（国际站）
    │   ├── Existing_VPC_HANA_Single_Node.json # HANA单节点已有VPC模板
    │   ├── Existing_VPC_HANA_Single_Node_In.json # HANA单节点已有VPC模板（国际站）

├──  sap-hana-ha  # SAP HANA双节点高可用集群
    ├── scripts # 脚本目录
    │   ├── sap_hana_ha_node.sh # SAP HANA 双节点高可用安装脚本
    │   ├── corosync_configuration_template.cfg # Corosync配置文件
    │   ├── sap_hana_ha_configuration_template.cfg # 集群resource配置文件
    │   ├── sap_hana_ha_input_parameter.cfg # SAP HANA双节点高可用安装脚本参数文件
    ├── templates # 资源编排(ROS)模板目录
    │   ├── HANA_HA.json  # HANA双节点高可用基础模板：ECS、安全组、弹性网卡、访问控制角色等云资源
    │   ├── New_VPC_HANA_HA.json # HANA双节点高可用新建VPC模板
    │   ├── New_VPC_HANA_HA_In.json # HANA双节点高可用新建VPC模板（国际站）
    │   ├── Existing_VPC_HA.json # HANA双节点高可用已有VPC模板
    │   ├── Existing_VPC_HA_In.json # HANA双节点高可用已有VPC模板（国际站）
```

## 部署架构

使用SAP自动化部署工具在同一可用区内实现的SAP HANA高可用集群架构图：

![sap-hana-ha](https://img.alicdn.com/tfs/TB1vEijw8r0gK0jSZFnXXbRRXXa-1643-1246.png)
