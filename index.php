<?php
require('aws.phar');

$command = explode('?', $_SERVER['REQUEST_URI'])[0];
$command = trim($command, '/');
$client = $_SERVER['QUERY_STRING'];
$client = preg_replace('/[^A-Za-z0-9]/', '', $client);

try {
	$ec2 = new Aws\Ec2\Ec2Client([
		'profile' => 'ssh-proxy',
		'version' => 'latest'
	]);

	$result = $ec2->describeInstances([
		'Filters' => [
			[
				'Name' => 'tag:ssh-proxy',
				'Values' => [$client]
			]
		]
	]);

	switch ($command) {
	case 'status':
		// obtain public IPs of running VMs
		print($result->search("Reservations[].Instances[?State.Name=='running'][].PublicIpAddress | [0]"));
		break;
	}
}
catch (Exception $e) {
	header($_SERVER['SERVER_PROTOCOL'] . ' 503 Service Unavailable');
}
