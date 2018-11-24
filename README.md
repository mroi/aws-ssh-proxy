SSH-Proxy Using Amazon EC2 Virtual Machines
===========================================

Connecting to remote machines via SSH becomes increasingly complicated, when these machines 
are hidden behind residential routers or corporate firewalls. In these situations, a 
high-bandwidth SSH proxy is useful that can be reached from anywhere.

This project provides such a proxy using Amazon EC2 virtual machines. It specifically 
targets macOS machines and can be used to replace Apple’s discontinued Back To My Mac 
service for remote management using an SSH command line.

The system consists of four pieces:
* some initial setup at Amazon,
* a web service you need to host on a PHP-enabled web server,
* a launchd daemon for the Macs you want to connect to, and
* an SSH proxy script for the machine that establishes the connection.

Each of these pieces is described below in its own section.

AWS Setup
---------

In order to set everything up at Amazon Web Services, you need to perform the following 
steps:
1. Create an SSH key pair and upload the public key to EC2 with the name `ssh-proxy`.
2. Create an IAM user (recommended name is `ssh-proxy`) and remember its credentials.
3. Create an EC2 security group from 
   [`security-group.json`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/security-group.json) 
   and its ingress permissions from 
   [`security-group-ingress.json`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/security-group-ingress.json).
4. Create an EC2 launch template from 
   [`launch-template.json`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/launch-template.json).
5. Finally, configure 
   [`iam-policy.json`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/iam-policy.json) 
   as the IAM user’s inline permission policy. Replace the launch template ID with the one 
   you created above.

PHP Web Service
---------------

You need to obtain the latest `aws.phar` from the [AWS SDK 
releases](https://github.com/aws/aws-sdk-php/releases). Then put it next to the 
[`index.php`](https://github.com/mroi/aws-ssh-proxy/blob/master/index.php) on your web 
server.

Make sure your web server also has the credentials of the `ssh-proxy` IAM account stored in 
its `~/.aws/credentials` file or wherever you keep your AWS credentials. Use a profile name 
of `ssh-proxy`.

The web service uses a pre-shared secret for request authentication. A SHA256-HMAC is 
calculated over the string `<command>?<client>` and appended to the request URL. Therefore, 
you need to create a random secret that is shared amongst all clients. Store this secret and 
optionally any other configuration in `config.php`.

The web service understands three commands, all of which use a client machine identifier as 
their query string:

**`/status?<client>&<hmac>`**  
Reveals the public IP address of the SSH proxy when such a proxy has been started for the 
given client.
