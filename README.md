*This project is derived from the [SSH-Proxy](https://github.com/mroi/aws-ssh-proxy) by way 
of a branch that I am rebasing forward. I will not provide a linear progression of commits 
on this branch.*


Unison File Sync to Amazon EFS Storage
======================================

This project allows to sync machines via the [Unison](https://github.com/bcpierce00/unison) 
file synchronizer to a central file system stored in the cloud. An Amazon EC2 virtual 
machine is launched on demand to access an Amazon EFS storage backend.

The system consists of four pieces:
* some initial setup at Amazon,
* a web service you need to host on a PHP-enabled web server, and
* an SSH proxy command to establish the connection.

Each of these pieces is described below in its own section.

AWS Setup
---------

In order to set everything up at Amazon Web Services, you need to perform the following 
steps:

1. Create an SSH key pair and upload the public key to EC2 with the name `unison-sync`. Store 
   the keys in a files `sync` and `sync.pub` in your `~/.ssh` directory.
2. Create an AWS stack from 
   [`aws.json`](https://raw.githubusercontent.com/mroi/aws-ssh-proxy/unison-sync/aws.json) using 
   [CloudFormation](https://aws.amazon.com/cloudformation/), either from the 
   [AWS Console](https://console.aws.amazon.com/cloudformation) or the 
   [command line](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/). Use the 
   name `unison-sync` for the stack.
3. Retain the credentials of the created IAM user `unison-sync`.

PHP Web Service
---------------

To install the web service, you need PHP-enabled web space. Follow these steps:

1. Put [`index.php`](https://github.com/mroi/aws-ssh-proxy/blob/unison-sync/index.php) and 
   [`.htaccess`](https://github.com/mroi/aws-ssh-proxy/blob/unison-sync/.htaccess) on your web 
   server.
2. Obtain the latest `aws.phar` from the 
   [AWS SDK releases](https://github.com/aws/aws-sdk-php/releases) and put it next to 
   `index.php`.
3. Make sure your web server also has the credentials of the `unison-sync` IAM account stored 
   in its `~/.aws/credentials` file or wherever you keep your AWS credentials. Use a profile 
   name of `unison-sync`.
4. The web service uses a pre-shared secret to authenticate its API requests. Store this 
   API key and optionally any other configuration in `config.php`.

An authentication token is formed by first generating a 10-byte random nonce. Then, a 
SHA256-HMAC is calculated over the string `<nonce><command>`. The result is Base64-encoded 
and appended to the request URL.

The web service understands three commands:

**`/launch?<token>`**  
Starts a new Unison backend, waits until the it is running and returns its IP address. When 
a backend is already running, only the IP address is returned.

**`/status?<token>`**  
Returns the public IP address of the Unison backend when such a backend has been started. An 
authentication token similar to the one used for requests is generated to verify the IP 
address. The same nonce is used to prevent replay attacks.

**`/terminate?<token>`**  
Terminates the running Unison backend.

SSH Proxy Command
-----------------

Connecting to a backend requires launching and later tearing down the respective EC2 VM. 
This can be automated and integrated into SSH by way of a proxy command. The binary 
`unison-connect` is installed in the `UnisonSync.bundle/Contents/MacOS` directory. You can 
use it in your SSH configuration by way of the `ProxyCommand` directive. It understands 
these command line options:

**`--api-url`**  
The API URL where the PHP web service can be reached.

**`--api-key`**  
The pre-shared API key to authenticate web service requests.

A useful SSH config file, which connects to the Unison sync backend looks like this:

```
Host unison
ProxyCommand /path/to/UnisonSync.bundle/Contents/MacOS/unison-connect --api-url <server> --api-key <secret>
ProxyUseFdpass yes
User unison-sync
IdentityFile ~/.ssh/unison-sync
```

You can also read the secret from a file using shell command substitution (`` `cat 
<keyfile>` ``). Be aware that the secret is still exposed to all users on the machine 
through the list of all running processes and their arguments.

___
This work is licensed under the [WTFPL](http://www.wtfpl.net/), so you can do anything you 
want with it.
