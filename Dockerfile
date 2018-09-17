FROM debian:buster

RUN apt-get update --fix-missing
RUN apt-get install -y build-essential bc wget gdb libssl-dev git vim bison flex qemu-system-x86 libelf-dev python

ADD scripts /scripts
RUN mkdir /data

WORKDIR /data/
