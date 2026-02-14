# 使用 Ubuntu 24.04 作为基础镜像
FROM ubuntu:24.04

# 更新包列表
RUN apt-get update

# 安装运行 JPro 应用所需的 Xorg 和 GTK3
RUN apt-get install -y xorg libgtk-3-0

# 安装下载工具 wget、unzip 和添加 PPA 所需的 software-properties-common
RUN apt-get install -y wget software-properties-common unzip

# 添加 Adoptium (Eclipse Temurin) 的 APT 仓库并导入 GPG 密钥
RUN wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - && \
    add-apt-repository --yes https://packages.adoptium.net/artifactory/deb/

# 安装 Temurin 21 JDK (包含 JavaFX 运行所需)
RUN apt-get update && \
    apt-get install -y temurin-21-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- 新增：下载并配置 JavaFX 25.0.2 ARM64 SDK ---
# 使用您指定的新链接下载适用于 Linux ARM64 的 JavaFX 25.0.2 SDK
RUN wget https://download2.gluonhq.com/openjfx/25.0.2/openjfx-25.0.2_linux-aarch64_bin-sdk.zip && \
    # 解压到 /opt 目录
    unzip openjfx-25.0.2_linux-aarch64_bin-sdk.zip -d /opt/ && \
    # 清理下载的 zip 文件
    rm openjfx-25.0.2_linux-aarch64_bin-sdk.zip && \
    # 重命名为更通用的目录名 /opt/javafx，方便引用
    mv /opt/javafx-sdk-25.0.2 /opt/javafx

# 设置 JavaFX 环境变量，便于后续命令使用
ENV JAVAFX_HOME=/opt/javafx
ENV JAVAFX_MODULES="--module-path=$JAVAFX_HOME/lib --add-modules=javafx.controls,javafx.fxml,javafx.web,javafx.media"

# 设置工作目录为 /jproserver
WORKDIR /jproserver

# 将当前目录下的所有文件（即您的 JPro 应用）复制到镜像的 /jproserver 目录
# 注意：此步骤假设您的 Dockerfile 位于 JPro 项目的根目录，并且 .dockerignore 文件已正确配置以避免复制不必要的文件
ADD . /jproserver/

# --- 优化：修改 JPro 的启动脚本以包含 JavaFX 模块路径 ---
# 使用 sed 命令在 restart.sh 脚本中，将所有 "java " 命令替换为包含 JavaFX 模块参数的完整命令
# 这样做可以确保通过脚本启动时能正确找到 JavaFX 模块
RUN sed -i 's|java |java $JAVAFX_MODULES |g' /jproserver/bin/restart.sh && \
    # 确保脚本有执行权限
    chmod +x /jproserver/bin/restart.sh

# --- 可选：尝试自动配置 JPro 的配置文件 ---
# 如果 JPro 使用配置文件（例如 application.conf），可以尝试在其中添加 JavaFX 配置
# 但请注意，不同 JPro 版本配置方式可能不同，此方法可能不总是有效
RUN if [ -f /jproserver/conf/application.conf ]; then \
    echo "\n# JavaFX ARM64 Configuration for Java 25.0.2" >> /jproserver/conf/application.conf && \
    echo "javafx.module-path=/opt/javafx/lib" >> /jproserver/conf/application.conf && \
    echo "javafx.modules=javafx.controls,javafx.fxml,javafx.web,javafx.media" >> /jproserver/conf/application.conf; \
    fi

# 容器启动时执行的默认命令
# 进入 /jproserver 目录并执行重启脚本
CMD (cd /jproserver/ && ./bin/restart.sh)
