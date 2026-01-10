#!/bin/bash

# 发布脚本：自动更新版本号并创建 tag

set -e

if [ -z "$1" ]; then
    echo "用法: ./scripts/release.sh <版本号>"
    echo "示例: ./scripts/release.sh 1.8"
    exit 1
fi

VERSION=$1

# 获取脚本所在目录的上级目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "📦 发布 v$VERSION"

# 更新版本号
echo "📝 更新版本号..."
sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION;/" KeyStats.xcodeproj/project.pbxproj

# 提交更改
echo "💾 提交更改..."
git add KeyStats.xcodeproj/project.pbxproj
git commit -m "chore: bump version to $VERSION"

# 创建 tag
echo "🏷️  创建 tag..."
git tag "v$VERSION"

# 推送
echo "🚀 推送到远程..."
git push origin main
git push origin "v$VERSION"

echo ""
echo "✅ 发布完成！"
echo "   GitHub Actions 将自动构建并发布 v$VERSION"
