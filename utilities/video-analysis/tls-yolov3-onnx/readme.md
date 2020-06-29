# Yolov3 ONNX model for encrypted through the wire I/O (TLS).

*An alternative for scenarios where the YOLO inferencing container, will run separately from IoT Edge (i.e. you have a spare beefy (hardware capable) server you'd like to use for this intensive task; given the ammount of cameras you'll be feeding LVA with, which in turn, will demand simultaneous inferencing from this container). Although possible from a technical standpoint, if the inferencing container will run under IoT Edge's umbrella, a TLS certificate won't bring any added value. In this case, our suggestion is to walk the [regular documented path](../yolov3-onnx/readme.md)*

The following instruction will enable you to build a docker container with [Yolov3](http://pjreddie.com/darknet/yolo/) [ONNX](http://onnx.ai/) model using [nginx](https://www.nginx.com/), [gunicorn](https://gunicorn.org/), [flask](https://github.com/pallets/flask), and [runit](http://smarden.org/runit/).

Note: References to third-party software in this repo are for informational and convenience purposes only. Microsoft does not endorse nor provide rights for the third-party software. For more information on third-party software please see the links provided above.

## Contributions needed

* Improved logging
* Graceful shutdown of nginx and gunicorn

## Prerequisites

1. [Install Docker](http://docs.docker.com/docker-for-windows/install/) on your machine
2. Install [curl](http://curl.haxx.se/)

## Obtain a valid TLS (a.k.a. SSL) certificate

### Involving the IT team in the process
It's really important to involve the right areas here. The organization you're working for, might have it's own policies in place to deal with SSL certificates related issues, such as: naming, providers, TTL (time to live), among other not/technical ones.

### Droping certificate files for docker container to pick them up

First, create a `certs` directory where you'll copy the certificate files to. This directory will be mounted to the container, where the nginx config file expects it (more on this right after).

On the Host computer, run: `sudo mkdir /certs`

In the newly created directory, copy the public/private key pair files (our sample expects `.pem` files. You'r reality might defer. In that case, use what you have)

Reading material:

* https://nginx.org/en/docs/http/configuring_https_servers.html#chains
* https://serverfault.com/a/9717

### Updating Nginx server config file

Set the right names for the certificate files, to match what you've copied to the `/certs` folder at Host computer level. The file youi need to update is [yolov3-app.conf](yolov3-app.conf)

### Building the docker container
After getting a certificate, copying its pieces and updating the nginx configuration file, now comes the time to put the container to work.

`sudo docker run -d -p 443:443 --name secureyolov3 --mount type=bind,source=/certs,target=/certs myregistry.azurecr.io/secureyolov3:1`

Let's decompose it a bit:

* `-p 443:443`: it's up to you where you'd like to map the containers 443 port. You can pick whatever port fits your needs.
* `--mount`: here's where the Host directory where we dropped the certificate files earlier, is binded into the container, so it's able to consume them.
* `registry/image:tag`: replace this with the corresponding location/image:tag where you've pushed the image built fro `Dockerfile`

### Updating references into Topologies, to target the HTTPS inferencing container address

Build the container image (should take some minutes) by running the following docker command from a command window in that directory

```bash
    docker build . -t yolov3-onnx:latest
```

## Running and testing

Run the container using the following docker command

```bash
    docker run  --name my_yolo_container -p 80:80 -d  -i yolov3-onnx:latest
```

Test the container using the following commands

### /score

To get a list of detected objected using the following command

```bash
   curl -X POST http://127.0.0.1/score -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
```

If successful, you will see JSON printed on your screen that looks something like this

```JSON
{
    "inferences": [
        {
            "entity": {
                "box": {
                    "h": 0.3498992351271351,
                    "l": 0.027884870008988812,
                    "t": 0.6497463818662655,
                    "w": 0.212033897746693
                },
                "tag": {
                    "confidence": 0.9857677221298218,
                    "value": "person"
                }
            },
            "type": "entity"
        },
        {
            "entity": {
                "box": {
                    "h": 0.3593513820482337,
                    "l": 0.6868949751420454,
                    "t": 0.6334065123374417,
                    "w": 0.26539528586647726
                },
                "tag": {
                    "confidence": 0.9851594567298889,
                    "value": "person"
                }
            },
            "type": "entity"
        }
    ]
}
```

Terminate the container using the following docker commands

```bash
docker stop my_yolo_container
docker rm my_yolo_container
```

### /annotate

To see the bounding boxes overlaid on the image run the following command

```bash
   curl -X POST http://127.0.0.1/annotate -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg> --output out.jpeg
```

If successful, you will see a file out.jpeg with bounding boxes overlaid on the input image.

### /score-debug

To get the list of detected objects and also generate an annotated image run the following command

```bash
   curl -X POST http://127.0.0.1/score-debug -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
```

If successful, you will see a list of detected objected in JSON. The annotated image will be genereated in the /app/images directory inside the container. You can copy the images out to your host machine by using the following command

```bash
   docker cp my_yolo_container:/app/images ./
```

The entire /images folder will be copied to ./images on your host machine. Image files have the following format dd_mm_yyyy_HH_MM_SS.jpeg

## Upload docker image to Azure container registry

Follow instruction in [Push and Pull Docker images  - Azure Container Registry](http://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli) to save your image for later use on another machine.

## Deploy as an Azure IoT Edge module

Follow instruction in [Deploy module from Azure portal](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-deploy-modules-portal) to deploy the container image as an IoT Edge module (use the IoT Edge module option).
