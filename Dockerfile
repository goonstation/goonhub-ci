FROM node:20

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y sqlite3 nano git curl zip rsync moreutils gcc-multilib lib32stdc++6 zlib1g-dev:i386 libssl-dev:i386 pkg-config:i386 libstdc++6 libstdc++6:i386

RUN npm install -g pm2 && \
    npm install -g gulp-cli && \
    npm install -g n && \
    n 20

RUN usermod -d /home/ss13 -l ss13 node && \
    mkdir /home/ss13 && \
    chown ss13 /home/ss13

USER ss13

RUN cd /home/ss13 && \
    curl https://sh.rustup.rs -sSfo rustup-init.sh && \
    chmod +x rustup-init.sh && \
    ./rustup-init.sh -y

RUN echo "shopt -s extglob" >> /home/ss13/.bashrc && \
    mkdir /home/ss13/cdn-build
