# Use an Ubuntu-based image with Java 8 and Maven installed
FROM maven:3.8.6-openjdk-8

# Set the working directory inside the container
WORKDIR /app

# Install necessary build tools and dependencies for Protobuf, Python, and other required packages
RUN apt-get update && \
    apt-get install -y autoconf automake libtool curl make g++ unzip python3 python3-pip && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

# Install Python packages: beautifulsoup4 and lxml for XML parsing
RUN pip3 install beautifulsoup4 lxml

# Download, extract, build, and install Protobuf 2.5.0
# RUN wget https://github.com/protocolbuffers/protobuf/releases/download/v2.5.0/protobuf-2.5.0.tar.gz && \
#    tar -xzf protobuf-2.5.0.tar.gz && \
#    cd protobuf-2.5.0 && \
#   ./configure && \
#    make && \
#    make install && \
#    ldconfig && \
#    cd .. && \
#    rm -rf protobuf-2.5.0 protobuf-2.5.0.tar.gz

# Set Maven to use the mounted .m2 directory for dependencies
ENV MAVEN_OPTS="-Dmaven.repo.local=/root/.m2/repository"

# Set default values for parameters, which can be overridden
ENV MODULE=""
ENV DIR_TO_PYTHON_SCRIPT=""
ENV FULL_TEST_NAME=""
# Set default value for iterations, can be overridden
ENV ITERATIONS="5"

# Set the default command to execute the statistics generator script with environment variables as arguments
CMD ["/bin/bash", "-c", "cd /app/source && chmod +x statistics_generator.sh && ./statistics_generator.sh \"$MODULE\" \"$DIR_TO_PYTHON_SCRIPT\" \"$FULL_TEST_NAME\" \"$ITERATIONS\""]
