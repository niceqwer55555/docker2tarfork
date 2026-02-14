FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    xorg \
    libgtk-3-0 \
    wget \
    software-properties-common \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 添加 Adoptium 仓库
RUN wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - && \
    add-apt-repository --yes https://packages.adoptium.net/artifactory/deb/

# 安装 Temurin 21 JDK
RUN apt-get update && \
    apt-get install -y temurin-21-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /jproserver

# 复制应用文件
ADD . /jproserver/

# 下载 JavaFX 25.0.2 ARM64 SDK 并解压到应用期望的位置
RUN wget https://download2.gluonhq.com/openjfx/25.0.2/openjfx-25.0.2_linux-aarch64_bin-sdk.zip && \
    unzip openjfx-25.0.2_linux-aarch64_bin-sdk.zip && \
    # 创建应用期望的目录结构
    mkdir -p /jproserver/jfx/linux-aarch64 && \
    # 复制所有 JAR 文件到正确位置
    cp javafx-sdk-25.0.2/lib/*.jar /jproserver/jfx/linux-aarch64/ && \
    # 清理
    rm -rf javafx-sdk-25.0.2.zip javafx-sdk-25.0.2

# 确保脚本有执行权限
RUN chmod +x /jproserver/bin/*.sh

# 设置环境变量（可选）
ENV JPRO_WORKING_DIR=/jproserver

# 使用 restart.sh 启动应用
CMD ["/jproserver/bin/restart.sh"]
