English | [简体中文](README-CN.md)

<h1 align="center">alibabacloud-quickstart-sap-hana</h1>

## Purpose

SAP automated tool "sap-hana" creates and configures basic cloud resources, SAP HANA software, HSR(HANA System Replication), high-availability cluster, optional RDP system and audit services in the same availability zone.

sap-hana supports the following templates:

+ SAP HANA single node template (new VPC, existing VPC)
+ SAP HANA high availability template (new VPC, existing VPC)

View deployment guide please refer to the official website of Alibaba Cloud [《SAP 自动化安装部署最佳实践》](https://www.aliyun.com/acts/best-practice/preview?id=1934811)

## Directory Structure

```yaml
├── sap-hana-single-node # SAP HANA single node
    ├── scripts # Scripts directory
    │   ├── sap_hana_single_node.sh # SAP HANA single node installation
    │   ├── sap_hana_single_node_input_parameter.cfg # SAP HANA single node parameter file
    ├── templates # ROS template directory
    │   ├── HANA_Single_Node.json  # HANA single node basic template:Create ECS,security groups,RAM,etc cloud resources
    │   ├── New_VPC_HANA_Single_Node.json # HANA single node new VPC template
    │   ├── New_VPC_HANA_Single_Node_In.json # HANA single node new VPC template(English version)
    │   ├── Existing_VPC_HANA_Single_Node.json # HANA single node existing VPC template
    │   ├── Existing_VPC_HANA_Single_Node_In.json # HANA single node existing VPC template(English version)

├──  sap-hana-ha  # SAP HANA HA cluster
    ├── scripts # Scripts directory
    │   ├── sap_hana_ha_node.sh # SAP HANA HA installation script
    │   ├── corosync_configuration_template.cfg # Corosync configuration file
    │   ├── sap_hana_ha_configuration_template.cfg # cluster resource configuration file
    │   ├── sap_hana_ha_input_parameter.cfg # SAP HANA HA installation parameter file
    ├── templates # ROS template directory
    │   ├── HANA_HA.json  # HANA HA basic template:Create ECS,security groups,ENI,RAM,etc cloud resources
    │   ├── New_VPC_HANA_HA.json # HANA HA new VPC template
    │   ├── New_VPC_HANA_HA_In.json # HANA HA new VPC template(English version)
    │   ├── Existing_VPC_HA.json # HANA HA existing VPC template
    │   ├── Existing_VPC_HA_In.json # HANA HA existing VPC template(English version)
```

## Deployment architecture

Using SAP automated tool can deploy SAP HANA high-availability cluster as below architecture in the same availability zone:

![sap-hana-ha](https://img.alicdn.com/tfs/TB1vEijw8r0gK0jSZFnXXbRRXXa-1643-1246.png)
