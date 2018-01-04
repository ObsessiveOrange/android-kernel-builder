FROM ubuntu:14.04

RUN mkdir /data

RUN apt-get update
RUN apt-get install -y build-essential bc wget gdb libssl-dev

WORKDIR /data/kernel
