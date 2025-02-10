# ansible-runner-service  
This project wraps the ansible_runner interface inside a REST API enabling ansible playbooks to be executed and queried from other platforms.

The incentive for this is two-fold;
- provide Ansible integration to non-python projects
- provide a means of programmatically running playbooks where the ansible engine is running on a separate host or in a separate container

## Features
The core of this project is ansible_runner, so first of all, a quick call out to those [folks](https://github.com/ansible/ansible-runner/graphs/contributors) for such an awesome tool!
#### Security
- https support (http not supported)
  - production version:
    - uses TLS mutual authentication. (<misc/nginx> folder provides a container to be used in production)
    - Valid client and server certificates must be used to access the API (See documentation in <misc/nginx> folder)
  - test version:
    - uses self-signed if existing crt/key files are not present (<misc/docker> provides a container to be used in test systems)
    - if not present, generates self-signed on first start up
- creates or reuses ssh pub/priv keys for communication with target hosts

#### Monitoring
  - /metrics endpoint provides key metrics for monitoring the instance with [Prometheus](https://prometheus.io/)
  - a sample [Grafana](https://grafana.com/) dashboard is provided in the ```misc/dashboards``` directory to track activity


## Prerequisites
So far, testing has been mainly against Fedora (28) and the CentOS7 for the docker image. Other distros may work fine (Travis build uses Ubuntu Trusty for example!).

### Package Dependencies
- Python 3.6
- pyOpenSSL
- ansible_runner 1.1.1 or above
- OpenSuse Tumbleweed

## Installation
```
python3 ansible_runner_service.py
```
When you run from any directory outside of /usr, the script regards this as 'dev' mode. In this mode, all files and paths are relative to the path that you've
unzipped the project into.

For 'prod' mode, a setup.py is provided. Once the package is installed and
called from /usr/*/bin, the script will expect config and output files to be
found in all the normal 'production' locations (see proposed file layout below)
```
sudo python3 setup.py install --record installed_files --single-version-externally-managed
```

Once this is installed, you may start the service with
```
ansible_runner_service
```

### Manual Testing
The archive, downloaded from github, contains a simple playbook that just uses the bash sleep command - enabling you to quickly experiment with the API.

Use the steps below (test mode/test container version <misc/docker>), to quickly exercise the API
1. Get the list of available playbooks (should just be test.yml)
```curl -k -i https://localhost:5001/api/v1/playbooks  -X GET```
```json

curl -k -i https://localhost:5001/api/v1/playbooks  -X GET
HTTP/1.1 200 OK
Server: Werkzeug/3.1.3 Python/3.11.11
Date: Mon, 10 Feb 2025 10:30:53 GMT
Content-Type: application/json
Content-Length: 198
Connection: close

{
    "status": "OK",
    "msg": "3 playbook found",
    "data": {
        "playbooks": [
            "probe-disks.yml",
            "runnertest.yml",
            "test-facts.yml"
        ]
    }
}

```

2. Run the runnertest.yml playbook, passing the time_delay parameter (30 secs should be enough).
```curl -k -i -H "Content-Type: application/json" --data '{"time_delay": 30}' https://localhost:5001/api/v1/playbooks/runnertest.yml -X POST```
```json
curl -k -i -H "Content-Type: application/json" --data '{"time_delay": 30}' https://localhost:5001/api/v1/playbooks/test-facts.yml -X POST
HTTP/1.1 202 ACCEPTED
Server: Werkzeug/3.1.3 Python/3.11.11
Date: Mon, 10 Feb 2025 10:32:49 GMT
Content-Type: application/json
Content-Length: 132
Connection: close

{
    "status": "STARTED",
    "msg": "starting",
    "data": {
        "play_uuid": "605175d8-e79a-11ef-ac3e-a080697cfd99"
    }
}

```


4. The previous command will return the playbooks UUID. Use this identifier to query the state or progress of the run.
```curl -k -i https://localhost:5001/api/v1/playbooks/f39069aa-9f3d-11e8-852f-c85b7671906d -X GET```


5. Get a list of all the events in a playbook. The return list consists of all the job event ID's
```curl -k -i https://localhost:5001/api/v1/jobs/f39069aa-9f3d-11e8-852f-c85b7671906d/events  -X GET```


6. To get check options go to:
```https://localhost:5001/api/``

