## callback receiver - a stub interface to receive callbacks ##

The mrstub is intended for function tests to simulate a message router.
The mrstub exposes the read and write urls, used by the agent, as configured in consul.
In addition, request messages can be fed to the mrstub and the response messages can be read by polling.


### Control interface ###

The control interface can be used by any test script.
The following REST operations are available:

>Send a message to MR<br>
This method puts a request message in the queue for the agent to pick up. The returned correlationId (auto generated by the mrstub) is used when polling for the reposone message of this particular request.<br>
```URI and parameter, (GET): /get-event/<id>```<br><br>
```response: message + 200 or 204```

>Receive a message response for MR for the included correlation id<br>
The method is for polling of messages, returns immediately containing the received response (if any) for the supplied correlationId.<br>
```URI and payload, (PUT or POST): /callbacks/<id> <json array of response messages>```<br><br>
```response: OK 200 or 500 for other errors```

>Metrics - counters<br>
There are a number of counters that can be read to monitor the message processing. Do a http GET on any of the current counters and an integer value will be returned with http response code 200.
```/counter/received_callbacks``` - The total number of received callbacks<br>
```/counter/fetched_callbacks``` - The total number of fetched callbacks<br>
```/counter/current_messages``` - The current number of callback messages waiting to be fetched<br>


### Build and start ###

>Build image<br>
```docker build -t callback-receiver .```

>Start the image<br>
```docker run -it -p 8090:8090 callback-receiver```

The script ```crstub-build-start.sh``` do the above two steps in one go. This starts the callback-receiver container in stand-alone mode for basic test.<br>If the callback-receiver should be executed manually with the agent, replace docker run with this command to connect to the docker network with the correct service name (--name shall be aligned with the other components, i.e. the host named given in all callback urls).
```docker run -it -p 8090:8090 --network nonrtric-docker-net --name callback-receiver callback-receiver```


### Basic test ###

Basic test is made with the script ```basic_test.sh``` which tests all the available urls with a subset of the possible operations. Use the script ```cr-build-start.sh``` to start the callback-receiver in a container first.