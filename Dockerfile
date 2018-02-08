FROM ubuntu:rolling

RUN apt-get update
RUN apt-get install -y unzip python-virtualenv software-properties-common
RUN add-apt-repository -y ppa:ethereum/ethereum-dev
RUN add-apt-repository -y ppa:ethereum/ethereum
RUN apt-get update && apt-get install -y build-essential make \
    python3 python3-pip pkg-config golang-go libssl-dev \
    curl zlib1g-dev libreadline-dev npm \
    libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev \
    zlib1g-dev libffi-dev autoconf libtool wget \
    libcurl4-openssl-dev python-software-properties nodejs && \
    apt-get clean

RUN mkdir /analyzer
WORKDIR /analyzer

COPY requirements.txt ./
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.6 2
RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 2

RUN wget https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.6.6-10a45cb5.tar.gz && \
	tar -xvf geth-alltools-linux-amd64-1.6.6-10a45cb5.tar.gz && mv geth-alltools-linux-amd64-1.6.6-10a45cb5/* /usr/local/bin/

RUN wget https://github.com/ethereum/solidity/releases/download/v0.4.18/solc-static-linux && \
	chmod +x solc-static-linux && mv solc-static-linux /usr/local/bin/solc

RUN mkdir -p /deps/z3/ &&  wget https://github.com/Z3Prover/z3/archive/z3-4.5.0.zip -O /deps/z3/z3.zip && \
        cd /deps/z3/ && unzip /deps/z3/z3.zip && \
        ls /deps/z3 && mv /deps/z3/z3-z3-4.5.0/* /deps/z3/ &&  rm /deps/z3/z3.zip && \
        python scripts/mk_make.py --python && cd build && make && make install

RUN pip install -r requirements.txt
COPY ./oyente/ /oyente/

COPY . .
CMD [ "make", "run" ]