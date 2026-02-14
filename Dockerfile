FROM ubuntu:24.04

RUN apt-get update

# Install xorg and libgtk-3-0 needed to run JPro applications
RUN apt-get install -y xorg libgtk-3-0

# Install wget and software-properties-common need to add Adoptium APT repository
RUN apt-get install -y wget software-properties-common unzip

# Add the Adoptium (Eclipse Temurin) APT repository and import the GPG key
RUN wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - && \
    add-apt-repository --yes https://packages.adoptium.net/artifactory/deb/

# Install Temurin 21 JDK
RUN apt-get update && \
    apt-get install -y temurin-21-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 下载 JavaFX 25.0.2 ARM64 SDK 到镜像中
RUN wget https://download2.gluonhq.com/openjfx/25.0.2/openjfx-25.0.2_linux-aarch64_bin-sdk.zip && \
    unzip openjfx-25.0.2_linux-aarch64_bin-sdk.zip -d /opt/ && \
    rm openjfx-25.0.2_linux-aarch64_bin-sdk.zip

# 创建 JavaFX 符号链接，方便引用
RUN ln -s /opt/javafx-sdk-25.0.2 /opt/javafx

# 设置 JavaFX 环境变量
ENV JAVAFX_HOME=/opt/javafx
ENV JAVAFX_MODULES="--module-path=$JAVAFX_HOME/lib --add-modules=javafx.controls,javafx.fxml,javafx.web,javafx.media"

# 创建一个包装脚本，它会在容器启动时运行
RUN echo '#!/bin/bash\n\
echo "=========================================="\n\
echo "JPro ARM64 Docker Container Started"\n\
echo "=========================================="\n\
echo "Java version:"\n\
java -version\n\
echo ""\n\
echo "JavaFX ARM64 libraries available at: /opt/javafx/lib"\n\
ls -la /opt/javafx/lib/ | head -10\n\
echo ""\n\
echo "Looking for JPro application at /jproserver..."\n\
\n\
# 检查 JPro 应用是否已挂载\n\
if [ -d "/jproserver" ]; then\n\
    echo "JPro directory found."\n\
    \n\
    # 检查是否有 jfx 目录，如果没有则创建符号链接\n\
    if [ ! -d "/jproserver/jfx/linux-aarch64" ]; then\n\
        echo "Creating JavaFX symlink for JPro application..."\n\
        mkdir -p /jproserver/jfx\n\
        ln -sf /opt/javafx/lib /jproserver/jfx/linux-aarch64\n\
    fi\n\
    \n\
    # 查找启动脚本\n\
    if [ -f "/jproserver/bin/restart.sh" ]; then\n\
        echo "Found restart.sh, executing..."\n\
        cd /jproserver\n\
        exec /jproserver/bin/restart.sh\n\
    elif [ -f "/jproserver/bin/start.sh" ]; then\n\
        echo "Found start.sh, executing..."\n\
        cd /jproserver\n\
        exec /jproserver/bin/start.sh\n\
    else\n\
        echo "No startup script found in /jproserver/bin/"\n\
        echo "Contents of /jproserver:"\n\
        ls -la /jproserver\n\
        echo "Contents of /jproserver/bin (if exists):"\n\
        ls -la /jproserver/bin 2>/dev/null || echo "bin directory not found"\n\
    fi\n\
else\n\
    echo "JPro directory /jproserver not found!"\n\
    echo "Please mount your JPro application to /jproserver"\n\
    echo "Example: docker run -v /path/to/your/jproserver:/jproserver ..."\n\
fi\n\
\n\
# 保持容器运行（便于调试）\n\
echo ""\n\
echo "Container will stay alive for debugging. Press Ctrl+C to exit."\n\
tail -f /dev/null\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

# 设置工作目录
WORKDIR /

# 使用 entrypoint 脚本
ENTRYPOINT ["/entrypoint.sh"]
