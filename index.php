<?php
include('config.php');
require('aws.phar');

// extract request details
$command = explode('?', $_SERVER['REQUEST_URI'])[0];
$command = trim($command, '/');
$client = $_SERVER['QUERY_STRING'];
$client = preg_replace('/[^A-Za-z0-9]/', '', $client);

// you can override these variables in config.php
$region = isset($region) ? $region : getenv('AWS_DEFAULT_REGION');

try {
	$ec2 = new Aws\Ec2\Ec2Client([
		'profile' => 'ssh-proxy',
		'region' => $region,
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
