FROM ubuntu:18.04

COPY config.ini ~/
COPY oe-configs ~/
COPY scripts ~/

ENV CUSTOM_BUILD_PATH=~/build
ENV CUSTOM_TOOLS_PATH=~/tools

RUN ~/job_build.sh am64xx-evm processor-sdk-08.02.00-nightly-config.txt nightly 08.02.00 false 
