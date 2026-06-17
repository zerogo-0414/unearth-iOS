#!/bin/bash

# Unearth App 打包脚本
# 版本号固定 1.0.0，构建版本从1开始递增
# 奇数为测试版(TestFlight)，偶数为正式版(App Store)

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目配置
PROJECT_NAME="Unearth"
WORKSPACE="${PROJECT_NAME}.xcworkspace"
SCHEME="${PROJECT_NAME}"
CONFIGURATION="Release"
VERSION="1.0.0"

# 路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ARCHIVE_DIR="${PROJECT_DIR}/build/archives"
EXPORT_DIR="${PROJECT_DIR}/build/export"
BUILD_NUMBER_FILE="${PROJECT_DIR}/build_number.txt"

# App Store Connect API
API_KEY="JZ27BY6YH7"
API_ISSUER="afc5a658-4baf-42ad-87e9-65c8609a2a2b"

# 打印函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 获取当前构建版本号
get_build_number() {
    if [ -f "$BUILD_NUMBER_FILE" ]; then
        cat "$BUILD_NUMBER_FILE" | tr -d '[:space:]'
    else
        echo "0"
    fi
}

# 递增构建版本号
increment_build_number() {
    local current=$(get_build_number)
    local next=$((current + 1))
    echo "$next" > "$BUILD_NUMBER_FILE"
    echo "$next"
}

# 更新 Xcode 项目版本号
update_project_version() {
    local build_number=$1
    print_info "版本号: ${VERSION} | 构建号: ${build_number}"

    cd "$PROJECT_DIR"
    xcrun agvtool new-marketing-version "$VERSION"
    xcrun agvtool new-version -all "$build_number"
}

# 构建并上传
build_and_upload() {
    local build_number=$1
    local export_method=$2
    local should_upload=$3
    local archive_name="${PROJECT_NAME}_v${VERSION}_b${build_number}"

    print_info "=========================================="
    print_info "构建: ${archive_name}"
    print_info "=========================================="

    mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR"

    # 清理
    print_info "清理..."
    xcodebuild clean -workspace "$WORKSPACE" -scheme "$SCHEME" -quiet

    # 构建 Archive
    print_info "构建 Archive..."
    xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "${ARCHIVE_DIR}/${archive_name}.xcarchive" \
        -destination "generic/platform=iOS" \
        -quiet

    if [ $? -ne 0 ]; then
        print_error "构建失败"
        return 1
    fi
    print_success "Archive 构建成功"

    # 导出 IPA
    print_info "导出 IPA..."
    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_DIR}/${archive_name}.xcarchive" \
        -exportPath "${EXPORT_DIR}/${archive_name}" \
        -exportOptionsPlist "${SCRIPT_DIR}/ExportOptions_${export_method}.plist" \
        -quiet

    if [ $? -ne 0 ]; then
        print_error "导出失败"
        return 1
    fi
    print_success "IPA 导出成功"

    # 上传
    if [ "$should_upload" = "true" ]; then
        local ipa_path="${EXPORT_DIR}/${archive_name}/${PROJECT_NAME}.ipa"
        if [ -f "$ipa_path" ]; then
            print_info "上传到 App Store Connect..."
            xcrun altool --upload-app \
                --type ios \
                --file "$ipa_path" \
                --apiKey "$API_KEY" \
                --apiIssuer "$API_ISSUER"
            if [ $? -eq 0 ]; then
                print_success "上传成功！"
            else
                print_error "上传失败"
                return 1
            fi
        fi
    fi

    return 0
}

# 主流程
main() {
    print_info "=========================================="
    print_info "Unearth App 打包"
    print_info "版本: ${VERSION}"
    print_info "当前构建号: $(get_build_number)"
    print_info "=========================================="

    echo ""
    echo "  1) 构建测试版 (本地)"
    echo "  2) 构建测试版并上传到 TestFlight"
    echo "  3) 构建正式版 (本地)"
    echo "  4) 构建正式版并上传到 App Store"
    echo "  0) 退出"
    echo ""
    read -p "请输入选项: " choice

    case $choice in
        1)
            local build_number=$(increment_build_number)
            update_project_version "$build_number"
            build_and_upload "$build_number" "testflight" "false"
            ;;
        2)
            local build_number=$(increment_build_number)
            update_project_version "$build_number"
            build_and_upload "$build_number" "testflight" "true"
            ;;
        3)
            local build_number=$(increment_build_number)
            update_project_version "$build_number"
            build_and_upload "$build_number" "appstore" "false"
            ;;
        4)
            local build_number=$(increment_build_number)
            update_project_version "$build_number"
            build_and_upload "$build_number" "appstore" "true"
            ;;
        0)
            exit 0
            ;;
        *)
            print_error "无效选项"
            exit 1
            ;;
    esac

    echo ""
    print_success "=========================================="
    print_success "完成！构建版本: $build_number"
    print_success "=========================================="
}

main "$@"
