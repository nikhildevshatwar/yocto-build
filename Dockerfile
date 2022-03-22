# Author: Nikhil Devshatwar
# some pieces taken from https://embeddeduse.com/2019/02/11/using-docker-containers-for-yocto-builds/

FROM ubuntu:18.04

# Install basic packages required for running scripts
ARG DEBIAN_FRONTEND=noninteractive
Run apt-get update && apt-get install -y git wget vim locales locales-all sudo

ADD . /home/root/
COPY .git /home/root/.git

ENV CUSTOM_BUILD_PATH=/home/root/sdk/build
ENV CUSTOM_TOOLS_PATH=/home/root/sdk/tools
ENV TZ="America/New_York"
ENV USER_NAME github_job
ENV PROJECT ti-processor-sdk-am64xx-evm

# Install all the packages required for build in separate step of it's own
RUN cd /home/root; . scripts/setup-tasks.sh; install_host_packages

# create a new user and switch to it
RUN groupadd -g 1001 $USER_NAME && useradd -g 1001 -m -s /bin/bash -u 1001 $USER_NAME
USER $USER_NAME

RUN cd /home/root; ./scripts/job_build.sh am64xx-evm processor-sdk-08.02.00-nightly-config.txt nightly 08.02.00 false 
