<?php
include('config.php');
require('aws.phar');

// extract request details
$command = explode('?', $_SERVER['REQUEST_URI'])[0];
$command = trim($command, '/');
$id = explode('&', $_SERVER['QUERY_STRING'])[0];
$id = preg_replace('/[^A-Za-z0-9-]/', '', $id);
$auth = explode('&', $_SERVER['QUERY_STRING'])[1] ?? '';
$auth = base64_decode($auth);
$nonce = substr($auth, 0, 10);
$hmac = substr($auth, 10);

// you can override these variables in config.php
$region = isset($region) ? $region : getenv('AWS_DEFAULT_REGION');
$apiKey = isset($apiKey) ? $apiKey : exit();
$accept = isset($accept) ? $accept : array();

header('Content-Type: text/plain');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

// check request authentication
if (!hash_equals($hmac, hash_hmac('sha256', $nonce . $command . '?' . $id, $apiKey, true))) {
	header($_SERVER['SERVER_PROTOCOL'] . ' 401 Unauthorized');
	exit();
}
if (!empty($accept) && !in_array($id, $accept)) {
	header($_SERVER['SERVER_PROTOCOL'] . ' 403 Forbidden');
	exit();
}

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
				'Values' => [$id]
			]
		]
	]);

	switch ($command) {

	case 'launch':
		// prevent race between check and action by file locking
		$file = fopen(__FILE__, 'r+');
		flock($file, LOCK_EX);
		if (empty($result->search("Reservations[].Instances[?State.Name=='pending'][]")) &&
		    empty($result->search("Reservations[].Instances[?State.Name=='running'][]"))) {
			// search latest version of Amazon Linux image
			$result = $ec2->describeImages([
				'Filters' => [
					[
						'Name' => 'name',
						'Values' => ['al2023-ami-minimal-*-arm64']
					],
					[
						'Name' => 'owner-id',
						'Values' => ['137112412989']
					],
					[
						'Name' => 'state',
						'Values' => ['available']
					]
				]
			]);
			$image = $result->search("Images | sort_by(@, &CreationDate) | [-1].ImageId");
			// launch a new instance
			$result = $ec2->runInstances([
				'ImageId' => $image,
				'LaunchTemplate' => [
					'LaunchTemplateName' => 'ssh-proxy'
				],
				'MaxCount' => 1,
				'MinCount' => 1,
				'TagSpecifications' => [
					[
						'ResourceType' => 'instance',
						'Tags' => [
							[
								'Key' => 'ssh-proxy',
								'Value' => $id
							]
						]
					]
				]
			]);
			$id = $result->search("Instances[0].InstanceId");
		} else {
			$id = $result->search("Reservations[].Instances[?State.Name=='pending'][].InstanceId | [0]");
		}
		flock($file, LOCK_UN);
		fclose($file);

		// wait until the instance is running
		while ($id) {
			sleep(5);
			$result = $ec2->describeInstances([
				'InstanceIds' => [$id]
			]);
			if (!empty($result->search("Reservations[].Instances[?State.Name=='running'][]"))) break;
		}
		// fallthrough intended

	case 'status':
		// print public IPs of running VMs
		$ip = $result->search("Reservations[].Instances[?State.Name=='running'][].PublicIpAddress | [0]");
		if ($ip) {
			$auth = base64_encode($nonce . hash_hmac('sha256', $nonce . $ip, $apiKey, true));
			print("${ip} ${auth}\n");
		}
		break;

	case 'terminate':
		$ec2->terminateInstances([
			'InstanceIds' => $result->search("Reservations[].Instances[].InstanceId")
		]);
		break;

	default:
		header($_SERVER['SERVER_PROTOCOL'] . ' 400 Bad Request');
	}
} catch (Exception $e) {
	header($_SERVER['SERVER_PROTOCOL'] . ' 503 Service Unavailable');
}
