# Copyright (c) 2021-2022 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

FROM ubuntu:jammy-20240405 AS velocitydrivesp_support
ENV TZ=Europe/Copenhagen

# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
        build-essential \
        ca-certificates \
        curl \
        file \
        gnupg \
        gpg \
        jq \
        libpcap-dev \
        libssl-dev \
        libxml2-dev \
        locales \
        lsb-release \
        ruby-full \
        ruby-ox \
        ruby-parslet \
        util-linux \
        wget \
        xxd

# Generate en_US.UTF-8 locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 LANGUAGE=en
ENV LANG='en_US.UTF-8' LC_ALL='en_US.UTF-8' LANGUAGE='en_US.UTF-8'

# Install Ruby gems
RUN gem install nokogiri cbor-diag bit-struct packetfu tar json_schemer serialport

# Install Rust utilities
ENV CARGO_HOME='/usr/cargo'
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y \
    && /usr/cargo/bin/cargo install --root /usr cargo-trim \
    && /usr/cargo/bin/cargo install --root /usr --version 0.1.7 cbor-diag-cli \
    && /usr/cargo/bin/cargo trim registry -a

# Create default user for Jenkins compatibility
RUN adduser --no-create-home --disabled-password --home /mapped_home --uid 1000 --gecos "Bob the Builder" jenkins > /dev/null

# Install Python 3 and pip
RUN apt-get install -y python3 python3-pip python3-lxml \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 100

# Install Python dependencies via requirements.txt
COPY requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Install FastAPI and related Python packages (fallback)
# RUN pip3 install --no-cache-dir fastapi uvicorn pyyaml python-multipart

# Copy entrypoint for environment setup and command routing
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory for the FastAPI app
WORKDIR /app

# Copy FastAPI server code
COPY main.py /app/

# Remove dedicated HTML/static copy: inline HTML in main.py

# Expose FastAPI port
EXPOSE 8000

# Entrypoint and default command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
