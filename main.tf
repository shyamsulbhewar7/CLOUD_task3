provider "aws"{ 
    region     = "ap-south-1"
  }




//creating vpc  
resource "aws_vpc" "shyamvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "Vpc"
  }
}




//creating subnet
resource "aws_subnet" "public_subnet" {
depends_on = [aws_vpc.shyamvpc]
  vpc_id     = aws_vpc.shyamvpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone_id = "aps1-az1"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public_Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
depends_on = [aws_vpc.shyamvpc]
  vpc_id     = aws_vpc.shyamvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone_id = "aps1-az3"
  tags = {
    Name = "Private_Subnet"
  }
}




//creating internet getway
resource "aws_internet_gateway" "internet_getway" {
depends_on = [aws_vpc.shyamvpc]
  vpc_id = aws_vpc.shyamvpc.id
  tags = {
    Name = "Internet_Getway"
  }
}




//updating default routing table
resource "aws_default_route_table" "routing_table" {
depends_on  = [aws_internet_gateway.internet_getway,aws_vpc.shyamvpc]
  default_route_table_id = aws_vpc.shyamvpc.default_route_table_id
   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_getway.id
  }
  tags = {
    Name = "Route_table"
  }
}




//routing association with subnet1 making it public
resource "aws_route_table_association" "routing_table_asson" {
depends_on  = [aws_default_route_table.routing_table,aws_subnet.public_subnet]
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_vpc.shyamvpc.default_route_table_id
}




//creating security grp for bostion host 
resource "aws_security_group" "bostion_host_security_grp"{
depends_on = [aws_vpc.shyamvpc]
    name        = "bostion_host_security_grp"
    vpc_id      = aws_vpc.shyamvpc.id
    ingress{
           description = "For login to bostion host from anywhere"
           from_port   = 22
           to_port     = 22
           protocol    = "TCP"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks  = ["::/0"]
      }
    egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
      }

    tags ={
           Name = "Security_Group_Bostion_host"
      }
}




//creating security grp for WordPress 
resource "aws_security_group" "wordpress_security_grp"{
depends_on = [aws_vpc.shyamvpc,aws_security_group.bostion_host_security_grp]
    name        = "wordpress_security_grp"
    vpc_id      = aws_vpc.shyamvpc.id
    ingress{
           description = "For connecting to WordPress from outside world"
           from_port   = 80
           to_port     = 80
           protocol    = "TCP"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks  = ["::/0"]
      }
    ingress{
           description = "Only bostion host can connect to WordPress using ssh"
           from_port   = 22
           to_port     = 22
           protocol    = "TCP"
           security_groups=[aws_security_group.bostion_host_security_grp.id]
           ipv6_cidr_blocks  = ["::/0"]
      }
    ingress{
           description = "icmp from VPC"
           from_port   = -1
           to_port     = -1
           protocol    = "icmp"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks =  ["::/0"]
      }
    egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks =  ["::/0"]
  }

    tags ={
           Name = "Security_Group_WordPress"
      }
}




//creating security grp for MySql 
resource "aws_security_group" "mysql_security_grp"{
depends_on = [aws_vpc.shyamvpc,aws_security_group.wordpress_security_grp]
    name        = "mysqlsecuritygrp"
    vpc_id      = aws_vpc.shyamvpc.id
    ingress{
           description = "WordPress can connect to MySql"
           from_port   = 3306
           to_port     = 3306
           protocol    = "TCP"
           security_groups=[aws_security_group.wordpress_security_grp.id]
      }

    ingress{
           description = "Only web ping sql from public subnet"
           from_port   = -1
           to_port     = -1
           protocol    = "icmp"
           security_groups=[aws_security_group.wordpress_security_grp.id]
           ipv6_cidr_blocks=["::/0"]
      }
    ingress{
           description = "Only bostion host can connect to MySql using ssh"
           from_port   = 22
           to_port     = 22
           protocol    = "TCP"
           security_groups=[aws_security_group.bostion_host_security_grp.id]
           ipv6_cidr_blocks  = ["::/0"]
      }
     egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks =  ["::/0"]
  }

    tags ={
           Name = "Security_Group_MySql"
      }
}




//creating WordPress OS
resource "aws_instance" "wordpress_instance"{
depends_on = [aws_security_group.wordpress_security_grp]
    ami     = "ami-0e9c43b5bc2603d9d" //enter ami/os image id if you want another os(now it is amazon linux)
    instance_type   ="t2.micro"
    vpc_security_group_ids =[aws_security_group.wordpress_security_grp.id]
    key_name    ="EFS_task"                //enter key_pair name you created at aws console
    subnet_id = aws_subnet.public_subnet.id
    tags ={
        Name = "WordPress_instance"
      }
}




//creating MySql OS
resource "aws_instance" "mysql_instance"{
depends_on = [aws_security_group.mysql_security_grp]
    ami     = "ami-0eb6467b60a881234" //enter ami/os image id if you want another os(now it is amazon linux)
    instance_type   ="t2.micro"
    vpc_security_group_ids =[aws_security_group.mysql_security_grp.id]
    key_name    ="EFS_task"                //enter key_pair name you created at aws console
    subnet_id = aws_subnet.private_subnet.id
    tags ={
        Name = "MySql_instance"
      }
}




//creating bostion host OS
resource "aws_instance" "bostion_host_instance"{
depends_on = [aws_security_group.bostion_host_security_grp]
    ami     = "ami-08706cb5f68222d09" //enter ami/os image id if you want another os(now it is amazon linux)
    instance_type   ="t2.micro"
    vpc_security_group_ids =[aws_security_group.bostion_host_security_grp.id]
    key_name    ="EFS_task"                //enter key_pair name you created at aws console
    subnet_id = aws_subnet.public_subnet.id
    tags ={
        Name = "Bositon_Host_instance"
      }
}




//downloading required IPs of all three OS
resource "null_resource" "writing_ip_to_local_file"{

    depends_on = [
    aws_instance.wordpress_instance,
    aws_instance.mysql_instance,
    aws_instance.bostion_host_instance,
    ]
    provisioner "local-exec"{
          command = "echo WORDPRESS_Public_IP:${aws_instance.wordpress_instance.public_ip}=======WORDPRESS_Private_IP:${aws_instance.wordpress_instance.private_ip}======Bostion_OS_Public_IP:${aws_instance.bostion_host_instance.public_ip}======MySql_Private_IP:${aws_instance.mysql_instance.private_ip} >  ip_address_of_instances.txt "  
      } 
      }




//Uploading the Key pair (file_name.pem) to the bostion host
resource "null_resource" "Putting_key_in_bostion_os"{
    depends_on = [
    aws_instance.wordpress_instance,
    aws_instance.mysql_instance,
    aws_instance.bostion_host_instance,
    ]
    provisioner "local-exec"{
          command = "scp -i C:/Users/DELL/Downloads/EFS_task.pem C:/Users/DELL/Downloads/EFS_task.pem  ec2-user@${aws_instance.bostion_host_instance.public_ip}:~/"      
      }
  }




  