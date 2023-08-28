<?php
include('config.php');
require('aws.phar');

// extract request details
$command = explode('?', $_SERVER['REQUEST_URI'])[0];
$command = trim($command, '/');
$auth = $_SERVER['QUERY_STRING'];
$auth = base64_decode($auth);
$nonce = substr($auth, 0, 10);
$hmac = substr($auth, 10);

// you can override these variables in config.php
$region = isset($region) ? $region : getenv('AWS_DEFAULT_REGION');
$apiKey = isset($apiKey) ? $apiKey : exit();

header('Content-Type: text/plain');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

// check request authentication
if (!hash_equals($hmac, hash_hmac('sha256', $nonce . $command, $apiKey, true))) {
	header($_SERVER['SERVER_PROTOCOL'] . ' 401 Unauthorized');
	exit();
}

try {
	$ec2 = new Aws\Ec2\Ec2Client([
		'profile' => 'unison-sync',
		'region' => $region,
		'version' => 'latest'
	]);

	$result = $ec2->describeInstances([
		'Filters' => [
			[
				'Name' => 'tag-key',
				'Values' => ['unison-sync']
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
					'LaunchTemplateName' => 'unison-sync'
				],
				'MaxCount' => 1,
				'MinCount' => 1,
				'TagSpecifications' => [
					[
						'ResourceType' => 'instance',
						'Tags' => [
							[
								'Key' => 'unison-sync',
								'Value' => ''
							]
						]
					]
				]
			]);
			$instance = $result->search("Instances[0].InstanceId");
		} else {
			$instance = $result->search("Reservations[].Instances[?State.Name=='pending'][].InstanceId | [0]");
		}
		flock($file, LOCK_UN);
		fclose($file);

		// wait until the instance is running
		while ($instance) {
			$result = $ec2->describeInstances([
				'InstanceIds' => [$instance]
			]);
			if (!empty($result->search("Reservations[].Instances[?State.Name=='running'][]"))) break;
		}
		// fallthrough intended

	case 'status':
		// fetch public IPs of running VMs
		$ip = $result->search("Reservations[].Instances[?State.Name=='running'][].PublicIpAddress | [0]");

		if ($ip) {
			// wait for SSH port to be ready
			for ($i = 0; $i < 10; $i++) {
				$socket = @fsockopen($ip, 22);
				if (is_resource($socket)) {
					fclose($socket);
					break;
				}
				sleep(5);
			}

			// authenticate and send response
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
