FROM ubuntu:14.04

RUN apt-get update
RUN apt-get install -y build-essential bc wget gdb libssl-dev git vim bison flex

ADD scripts /scripts
RUN mkdir /data

WORKDIR /data/
