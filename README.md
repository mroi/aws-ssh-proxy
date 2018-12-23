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
* a launch daemon for the Macs you want to connect to, and
* an SSH proxy command for the machine that establishes the connection.

Each of these pieces is described below in its own section.

AWS Setup
---------

In order to set everything up at Amazon Web Services, you need to perform the following 
steps. You will find everything you need for this setup in the 
[`aws`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/) directory.

1. Create an SSH key pair and upload the public key to EC2 with the name `ssh-proxy`. Store 
   the keys in a files `proxy` and `proxy.pub` in your `~/.ssh` directory.
2. Create an IAM user (recommended name is `ssh-proxy`) and keep its credentials.
3. Create an EC2 security group from 
   [`security-group.json`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/security-group.json) 
   and its ingress permissions from 
   [`security-group-ingress.json`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/security-group-ingress.json).
4. Create a VPC subnet under the default VPC or any other.
5. Create an EC2 launch template from
   [`launch-template.json`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/launch-template.json). 
   Replace the security group and subnet IDs with the ones created above.
6. Finally, configure 
   [`iam-policy.json`](https://github.com/mroi/aws-ssh-proxy/blob/master/aws/iam-policy.json) 
   as the IAM user’s inline permission policy. Replace the launch template ID with the one 
   you created above.

PHP Web Service
---------------

To install the web service, you need PHP-enabled web space. Follow these steps:

1. Put [`index.php`](https://github.com/mroi/aws-ssh-proxy/blob/master/index.php) and 
   [`.htaccess`](https://github.com/mroi/aws-ssh-proxy/blob/master/.htaccess) on your web 
   server.
2. Obtain the latest `aws.phar` from the [AWS SDK 
   releases](https://github.com/aws/aws-sdk-php/releases) and put it next to `index.php`.
3. Make sure your web server also has the credentials of the `ssh-proxy` IAM account stored 
   in its `~/.aws/credentials` file or wherever you keep your AWS credentials. Use a profile 
   name of `ssh-proxy`.
4. The web service uses a pre-shared secret for request authentication. Store this secret 
   and optionally any other configuration in `config.php`.

An authentication token is formed by first generating a 10-byte random nonce. Then, a 
SHA256-HMAC is calculated over the string `<nonce><command>?<endpoint>`. The result is 
Base64-encoded and appended to the request URL.

The web service understands three commands, all of which use an endpoint identifier as their 
query string:

**`/launch?<endpoint>&<token>`**  
Starts a new SSH proxy for the given endpoint, waits until the proxy is running and returns 
its IP address. When a proxy is already running, only the IP address is returned.

**`/status?<endpoint>&<token>`**  
Returns the public IP address of the SSH proxy when such a proxy has been started for the 
given endpoint. An authentication token similar to the one used for requests is generated to 
verify the IP address. The same nonce is used to prevent replay attacks.

**`/terminate?<endpoint>&<token>`**  
Terminates the running SSH proxy.

Launch Daemon for Endpoint Machines
-----------------------------------

All the machines that you want to SSH into must run a launch daemon. This daemon regularly 
queries the status of the EC2 VMs using the PHP service. A running VM signifies a connection 
request and the daemon will forward its local SSH port to the VM.

1. You install the launch daemon by invoking `make` in the 
   [`proxy`](https://github.com/mroi/aws-ssh-proxy/blob/master/proxy/) directory. You can 
   override variables (`DESTDIR`, `SIGNING_ID`, …) to configure the installation.
2. Register the daemon with launchd by copying the included plist file from 
   `SSHProxy.bundle/Contents/Resources` to `/Library/LaunchDaemons/`. You may want to 
   customize the file if the defaults don’t suit your needs.

SSH Proxy Command
-----------------

Connecting to an endpoint requires launching and later tearing down the respective EC2 VM. 
This can be automated and integrated into SSH by way of a proxy command. The binary 
`ssh-connect` is installed alongside the daemon in the `SSHProxy.bundle/Contents/MacOS` 
directory. You can use it in your SSH configuration by way of the `ProxyCommand` directive. 
It understands the same command line options as the daemon:

**`--endpoint`**  
Specifies the name of the endpoint to connect to. Usage of `%h` in you SSH config is 
practical.

**`--key`**  
The pre-shared secret to authenticate the connection.

**`--url`**  
The URL where the PHP web service can be reached.

A useful SSH config file, which establishes a local connection when possible and connects 
via proxy when necessary looks like this:

```
Match host <hostnames> exec "route get %h.local"
HostName %h.local

Match host <hostnames>
ProxyCommand /path/to/SSHProxy.bundle/Contents/MacOS/ssh-connect --endpoint %h --key <secret> --url <url>
```

This work is licensed under the [WTFPL](http://www.wtfpl.net/), so you can do anything you 
want with it.
