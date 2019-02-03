FROM ubuntu:xenial
RUN apt-get update && apt-get -y install git unzip wget python3-dev python3-pip
RUN wget https://releases.hashicorp.com/packer/1.3.3/packer_1.3.3_linux_amd64.zip
RUN wget https://releases.hashicorp.com/terraform/0.11.11/terraform_0.11.11_linux_amd64.zip
RUN unzip packer_1.3.3_linux_amd64.zip
RUN unzip terraform_0.11.11_linux_amd64.zip
RUN mv packer /usr/local/bin/
RUN mv terraform /usr/local/bin/
