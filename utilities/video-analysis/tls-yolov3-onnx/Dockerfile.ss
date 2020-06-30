# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

FROM ubuntu:18.04
EXPOSE 443
# Copy the app file
RUN mkdir /app
COPY app/yolov3-app.py /app
COPY  tags.txt /app

# Install runit, python, nginx, and necessary python packages
# Download the Yolov3model
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip python3-dev && \
    cd /usr/local/bin && \
    ln -s /usr/bin/python3 python && \
    pip3 install --upgrade pip && \
    pip install numpy onnxruntime flask pillow gunicorn && \
    apt-get clean && \
    apt-get update && \
    apt-get install --no-install-recommends -y wget runit nginx && \    
    cd /app && \
    wget https://onnxzoo.blob.core.windows.net/models/opset_10/yolov3/yolov3.tar.gz && \
    tar -xzf yolov3.tar.gz && \
    rm -rf yolov3.tar.gz && \
    rm -rf test_data_set_0/* && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    apt-get purge -y --auto-remove wget

# Create a self signed SSL Certificate with openssl
# hint: customize longevity (-days) and host's IP/NAME (in -subj)
RUN mkdir /certsss && cd /certsss && \
    openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=<REPLACE-WITh-IP-OR-NAME>'

# Copy nginx config file
COPY yolov3-app-ss.conf /etc/nginx/sites-available

# Setup runit file for nginx and gunicorn
RUN mkdir /var/runit && \
    mkdir /var/runit/nginx && \
    /bin/bash -c "echo -e '"'#!/bin/bash\nexec nginx -g "daemon off;"\n'"' > /var/runit/nginx/run" && \
    chmod +x /var/runit/nginx/run && \
    ln -s /etc/nginx/sites-available/yolov3-app-ss.conf /etc/nginx/sites-enabled/ && \
    rm -rf /etc/nginx/sites-enabled/default && \
    mkdir /var/runit/gunicorn && \
    /bin/bash -c "echo -e '"'#!/bin/bash\nexec gunicorn -b 127.0.0.1:8000 --chdir /app yolov3-app:app\n'"' > /var/runit/gunicorn/run" && \
    chmod +x /var/runit/gunicorn/run

# Start runsvdir
CMD ["runsvdir","/var/runit"]
