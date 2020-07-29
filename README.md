# Android Emulator and Appium Service on Docker  
## Build image  
`$ docker build --tag <image name>:<version> .` 
```
e.g. $ docker build --tag vtgautotest:1.1 .
```

## Run Container  
`$ docker run --name <container name> --privileged -d -p <hostPort:containerPort> -v <local android sdk path>:/opt/android-sdk <image name:version>`
```
e.g.
$ docker run --name bird-container-1 --privileged -d -p 5901:5901 -p 2222:22 -p 4723:4723 -v /android/sdk:/opt/android-sdk vtgautotest:1.1
$ docker run --name bird-container-2 --privileged -d -p 5902:5901 -p 2223:22 -p 4724:4723 -v /android/sdk:/opt/android-sdk vtgautotest:1.1
```
*About the container default ports*
- Port <5901>:    VNC Server
- Port <22>:      ssh services
- port <4723>:    Appium services 

## Launch appium services and AVD  
*By default, Run 'startup.sh' in container to launch appium services and AVD*
```
$ docker exec -it `docker ps -aqf "name=<container name>"` bash -c '/scripts/startup.sh'
e.g.
$ docker exec -it `docker ps -aqf "name=bird-container-1"` bash -c '/scripts/startup.sh'
```

*Customize the launch content*
```
$ docker exec -it `docker ps -aqf "name=<container name>"` bash -c '/scripts/startup.sh --<options> <arg> ... '
e.g.
$ docker exec -it `docker ps -aqf "name=<container name>"` bash -c '/scripts/startup.sh --avd myTestAVD --port 4723'   
```
*Get the useage of startup.sh*  
```
    $ ./startup.sh --help
    Usage: startup.sh  [-options arg...]
    [-d|--avd]:            Name of the AVD to launch
    [-l|--level]:          Specified the Android SDK API Level to be created
    [-s|--skin]:           The AVD skin
    [-p|--port]:           The Appium service port
    [-o|--log]:            The Appium log path
    [-v|--version]:        Version
    [-h|--help]:           Help
    [-i|install]:          App path for pre-install
```


## SSH Settings  
- The default authorized_keys is for 'nlsbic', you can use ssh client to connect to container if you have nlsbic's private key   
- if wants to add another user authorized key, run following steps  
    1. Create a local `authorized_keys` file, which contains the content from your `id_rsa.pub`  
    2. Copy the local authorized_keys file you just created to the container  
    ```
    $ docker cp <Yout locale authorized_keys> `docker ps -aqf "name=<Your container name>"`:/root/.ssh/authorized_keys
    e.g.  
    $ docker cp $(pwd)/authorized/authorized_keys `docker ps -aqf "name=bird-container-1"`:/root/.ssh/authorized_keys`
    ```
    3. Set the proper owner and group for authorized_keys file  
    ```
    $ docker exec -it `docker ps -aqf "name=<Your container name>"` bash -c 'chown root:root /root/.ssh/authorized_keys'
    e.g. 
    $ docker exec -it `docker ps -aqf "name=bird-container-1"` bash -c 'chown root:root /root/.ssh/authorized_keys' 
    ```
## VNC Settings
Remote access to the container's desktop might be helpful if you plan to run emulator inside the container.

When the container is up and running, use your favorite VNC client to connect to it:
- VNC Connect by <container_ip_address>:<ExposePortForVNC>, E.g. 172.27.19.86:5901
- Password (with control): android
- Password (view only): docker


## Tips:
1. Get container IP on host:  
    ```
	$ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container id or name>
	```

2. Get image/container ID by name on host:  
    ```
	$ docker inspect --format="{{.Id}}" <imageName or containerName>
	```

3. Get container ip in container:  
    ```
	$ ip a | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | grep 172.17
	```

4. Run docker command Without 'sudo'  
	- Create the docker group.  
		`$ sudo groupadd docker`
	- Add your user to the docker group
		`$ sudo usermod -aG docker ${USER}`
	- chomd  
	    ```
		$ ls -lrth docker.sock
		$ sudo chmod 666 /var/run/docker.sock
		$ ls -lrth docker.sock
		```
5. Kill Appium services if it's running  
    ```
	appiumPID=lsof -it tcp:4723
	kill -s 9 $appiumPID
	```
    
