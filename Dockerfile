FROM ubuntu:18.04

# Install basic packages required for running scripts
ARG DEBIAN_FRONTEND=noninteractive
Run apt-get update && apt-get install -y git wget vim sudo

ADD . /home/root/
COPY .git /home/root/.git

ENV CUSTOM_BUILD_PATH=/home/root/sdk/build
ENV CUSTOM_TOOLS_PATH=/home/root/sdk/tools
ENV TZ="America/New_York"

# Install all the packages required for build in separate step of it's own
RUN cd /home/root; . scripts/setup-tasks.sh; install_host_packages


RUN cd /home/root; ./scripts/job_build.sh am64xx-evm processor-sdk-08.02.00-nightly-config.txt nightly 08.02.00 false 
