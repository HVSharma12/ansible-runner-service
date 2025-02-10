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

## API Endpoints

Once the service is running, you can point your browser at  ```https://localhost:5001/api``` to show which endpoints are available. Each endpoint is described along with a curl example showing invocation and output.

![API endpoints](./screenshots/runner-service-api.gif)

You may click on any row to expand the description of the API route and show the curl example. The app uses a self-signed certificate, so all examples use the -k parameter (insecure mode).

**Note**: *It is not the intent of this API to validate the parameters passed to it. It is assumed that parameter selection and validation happen prior to the API call.*

Here's a quick 'cheat sheet' of the API endpoints.

| API Route | Description |
|-----------|-------------|
|/api | Show available API endpoints (this page)|
|/api/v1/groups| List all the defined groups in the inventory|
|/api/v1/groups/<group_name>| Manage groups within the inventory|
|/api/v1/groupvars/<group_name>| Manage group variables|
|/api/v1/hosts| Return a list of hosts from the inventory|
|/api/v1/hosts/<host_name>| Show group membership for a given host|
|/api/v1/hosts/<host_name>/groups/<group_name>| Manage ansible control of a given host|
|/api/v1/hostvars/<host_name>/groups/<group_name>| Manage host variables for a specific group within the inventory|
|/api/v1/jobs/<play_uuid>/events| Return a list of events within a given playbook run (job)|
|/api/v1/jobs/<play_uuid>/events/<event_uuid>| Return the output of a specific task within a playbook|
|/api/v1/playbooks| Return the names of all available playbooks|
|/api/v1/playbooks/<play_uuid>| Query the state or cancel a playbook run (by uuid)|
|/api/v1/playbooks/<playbook_name>| Start a playbook by name, returning the play's uuid|
|/api/v1/playbooks/<playbook_name>/tags/<tags>| Start a playbook using tags to control which tasks run|
|/metrics| Provide prometheus compatible statistics which describe playbook [activity](./misc/dashboards/README.md) |

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
curl -k -i -H "Content-Type: application/json" --data '{"time_delay": 30}' https://localhost:5001/api/v1/playbooks/runnertest.yml -X POST
HTTP/1.1 202 ACCEPTED
Server: Werkzeug/3.1.3 Python/3.11.11
Date: Mon, 10 Feb 2025 10:46:24 GMT
Content-Type: application/json
Content-Length: 132
Connection: close

{
    "status": "STARTED",
    "msg": "starting",
    "data": {
        "play_uuid": "45bebfe4-e79c-11ef-a664-a080697cfd99"
    }
}

```


4. The previous command will return the playbooks UUID. Use this identifier to query the state or progress of the run.
```curl -k -i https://localhost:5001/api/v1/playbooks/f39069aa-9f3d-11e8-852f-c85b7671906d -X GET```
```json
curl -k -i https://localhost:5001/api/v1/playbooks/45bebfe4-e79c-11ef-a664-a080697cfd99 -X GET
HTTP/1.1 200 OK
Server: Werkzeug/3.1.3 Python/3.11.11
Date: Mon, 10 Feb 2025 10:47:11 GMT
Content-Type: application/json
Content-Length: 1014
Connection: close

{
    "status": "OK",
    "msg": "running",
    "data": {
        "task": "Step 2",
        "task_metadata": {
            "playbook": "runnertest.yml",
            "playbook_uuid": "33fd772f-a3a3-4338-9b79-708334ec6632",
            "play": "test Playbook",
            "play_uuid": "a080697c-fd99-c63c-4af0-000000000002",
            "play_pattern": "all",
            "task": "Step 2",
            "task_uuid": "a080697c-fd99-c63c-4af0-000000000005",
            "task_action": "command",
            "resolved_action": "ansible.builtin.command",
            "task_args": "",
            "task_path": "/home/spectro/ansible-runner-service/samples/project/runnertest.yml:12",
            "name": "Step 2",
            "is_conditional": false,
            "uuid": "a080697c-fd99-c63c-4af0-000000000005",
            "created": "2025-02-10T10:46:54.954241+00:00"
        },
        "role": "",
        "last_task_num": 12,
        "skipped": 0,
        "failed": 0,
        "ok": 1,
        "failures": {}
    }
}

```

5. Get a list of all the events in a playbook. The return list consists of all the job event ID's
```curl -k -i https://localhost:5001/api/v1/jobs/f39069aa-9f3d-11e8-852f-c85b7671906d/events  -X GET```
```json
curl -k -i https://localhost:5001/api/v1/jobs/45bebfe4-e79c-11ef-a664-a080697cfd99/events  -X GET
HTTP/1.1 200 OK
Server: Werkzeug/3.1.3 Python/3.11.11
Date: Mon, 10 Feb 2025 10:48:09 GMT
Content-Type: application/json
Content-Length: 1620
Connection: close

{
    "status": "OK",
    "msg": "",
    "data": {
        "events": {
            "1-33fd772f-a3a3-4338-9b79-708334ec6632": {
                "event": "playbook_on_start"
            },
            "2-a080697c-fd99-c63c-4af0-000000000002": {
                "event": "playbook_on_play_start"
            },
            "3-a080697c-fd99-c63c-4af0-000000000004": {
                "event": "playbook_on_task_start",
                "task": "Step 1"
            },
            "4-0b9d5ef4-60dc-4aee-98b6-b0ef88ff45de": {
                "event": "runner_on_start",
                "host": "26sles15",
                "task": "Step 1"
            },
            "9-b6ffebe2-2c12-4542-8691-9be38d1bc380": {
                "event": "verbose"
            },
            "10-8694a8c9-43a8-47f1-ad74-835f8bcffac2": {
                "event": "runner_on_ok",
                "host": "26sles15",
                "task": "Step 1"
            },
            "11-a080697c-fd99-c63c-4af0-000000000005": {
                "event": "playbook_on_task_start",
                "task": "Step 2"
            },
            "12-dba44434-80d2-41d2-a93c-8ea264ad1137": {
                "event": "runner_on_start",
                "host": "26sles15",
                "task": "Step 2"
            },
            "13-20aba243-395c-4536-a5e5-5a5ca8f0d0a3": {
                "event": "runner_on_ok",
                "host": "26sles15",
                "task": "Step 2"
            },
            "14-f86c6499-2988-4515-87d3-304efddec9cb": {
                "event": "playbook_on_stats"
            }
        },
        "total_events": 10
    }
}

```
