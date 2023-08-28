SSH-Proxy Using Amazon EC2 Virtual Machines
===========================================

Connecting to remote machines via SSH becomes increasingly complicated, when these machines 
are hidden behind residential routers or corporate firewalls. In these situations, a 
high-bandwidth SSH proxy is useful that can be reached from anywhere.

This project provides such a proxy using Amazon EC2 virtual machines. It targets macOS 
machines and can be used to replace Apple’s discontinued Back To My Mac service for remote 
management using an SSH command line. Linux support should also work, but is less tested.

The system consists of four pieces:
* some initial setup at Amazon,
* a web service you need to host on a PHP-enabled web server,
* a launch daemon for the Macs you want to connect to, and
* an SSH proxy command for the machine that establishes the connection.

Each of these pieces is described below in its own section.

AWS Setup
---------

In order to set everything up at Amazon Web Services, you need to perform the following 
steps:

1. Create an SSH key pair and upload the public key to EC2 with the name `ssh-proxy`. Store 
   the keys in a files `proxy` and `proxy.pub` in your `~/.ssh` directory.
2. Create an AWS stack from 
   [`aws.json`](https://raw.githubusercontent.com/mroi/aws-ssh-proxy/main/aws.json) using 
   [CloudFormation](https://aws.amazon.com/cloudformation/), either from the 
   [AWS Console](https://console.aws.amazon.com/cloudformation) or the 
   [command line](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/). Use the 
   name `ssh-proxy` for the stack.
3. Retain the credentials of the created IAM user `ssh-proxy`.

PHP Web Service
---------------

To install the web service, you need PHP-enabled web space. Follow these steps:

1. Put [`index.php`](https://github.com/mroi/aws-ssh-proxy/blob/main/index.php) and 
   [`.htaccess`](https://github.com/mroi/aws-ssh-proxy/blob/main/.htaccess) on your web 
   server.
2. Obtain the latest `aws.phar` from the 
   [AWS SDK releases](https://github.com/aws/aws-sdk-php/releases) and put it next to 
   `index.php`.
3. Make sure your web server also has the credentials of the `ssh-proxy` IAM account stored 
   in its `~/.aws/credentials` file or wherever you keep your AWS credentials. Use a profile 
   name of `ssh-proxy`.
4. The web service uses a pre-shared secret to authenticate its API requests. Store this 
   API key and optionally any other configuration in `config.php`.

An authentication token is formed by first generating a 10-byte random nonce. Then, a 
SHA256-HMAC is calculated over the string `<nonce><command>?<identifier>`. The result is 
Base64-encoded and appended to the request URL.

The web service understands three commands, all of which use an identifier for the proxied 
endpoint as their query string:

**`/launch?<identifier>&<token>`**  
Starts a new SSH proxy for the given endpoint, waits until the proxy is running and returns 
its IP address. When a proxy is already running, only the IP address is returned.

**`/status?<identifier>&<token>`**  
Returns the public IP address of the SSH proxy when such a proxy has been started for the 
given endpoint. An authentication token similar to the one used for requests is generated to 
verify the IP address. The same nonce is used to prevent replay attacks.

**`/terminate?<identifier>&<token>`**  
Terminates the running SSH proxy.

Launch Daemon for Endpoint Machines
-----------------------------------

All the machines that you want to SSH into must run a launch daemon. This daemon regularly 
queries the status of the EC2 VMs using the PHP service. A running VM signifies a connection 
request and the daemon will forward its local SSH port to the VM.

1. You install the launch daemon by invoking `make` in the 
   [`proxy`](https://github.com/mroi/aws-ssh-proxy/blob/main/proxy/) directory. You can 
   override variables (`DESTDIR`, `SIGNING_NAME`, …) to configure the installation.
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

**`--id`**  
Specifies the name of the endpoint to connect to. Usage of `%h` in you SSH config is 
practical.

**`--api-url`**  
The API URL where the PHP web service can be reached.

**`--api-key`**  
The pre-shared API key to authenticate web service requests.

A useful SSH config file, which establishes a local connection when possible and connects 
via proxy when necessary looks like this:

```
Match host <hostnames> exec "route get %h.local &> /dev/null"
HostName %h.local

Match host <hostnames>
ProxyCommand /path/to/SSHProxy.bundle/Contents/MacOS/ssh-connect --id %h --api-url <server> --api-key <secret>
```

You can also read the secret from a file using shell command substitution (`` `cat 
<keyfile>` ``). Be aware that the secret is still exposed to all users on the machine 
through the list of all running processes and their arguments.

___
This work is licensed under the [WTFPL](http://www.wtfpl.net/), so you can do anything you 
want with it.
