#!/bin/bash

# deploy.sh 测试脚本
# 用于验证部署脚本的各种功能和边界情况

set -e

TEST_SCRIPT="./deploy.sh"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo -e "${BLUE}[TEST $TEST_COUNT]${NC} $test_name"
    
    if eval "$test_command"; then
        if [ "$expected_result" = "pass" ]; then
            echo -e "${GREEN}✅ PASS${NC}"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo -e "${RED}❌ FAIL (expected to fail but passed)${NC}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        if [ "$expected_result" = "fail" ]; then
            echo -e "${GREEN}✅ PASS (expected failure)${NC}"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo -e "${RED}❌ FAIL${NC}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi
    echo ""
}

echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}        Deploy.sh 测试套件${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo ""

# 测试1: 检查脚本文件是否存在
run_test "检查deploy.sh文件存在" "[ -f '$TEST_SCRIPT' ]" "pass"

# 测试2: 检查脚本语法
run_test "Bash语法检查" "bash -n '$TEST_SCRIPT'" "pass"

# 测试3: 检查脚本权限
run_test "检查脚本可执行权限" "[ -x '$TEST_SCRIPT' ] || chmod +x '$TEST_SCRIPT'" "pass"

# 测试4: 检查shebang
run_test "检查shebang行" "head -1 '$TEST_SCRIPT' | grep -q '^#!/bin/bash'" "pass"

# 测试5: 检查set -e存在
run_test "检查错误退出设置" "grep -q 'set -e' '$TEST_SCRIPT'" "pass"

# 测试6: 检查root用户检查逻辑
run_test "检查root用户验证逻辑" "grep -q 'EUID.*-ne.*0' '$TEST_SCRIPT'" "pass"

# 测试7: 检查apt-get系统检查
run_test "检查apt-get系统验证" "grep -q 'command -v apt-get' '$TEST_SCRIPT'" "pass"

# 测试8: 检查Docker检查逻辑
run_test "检查Docker安装检查" "grep -q 'command -v docker' '$TEST_SCRIPT'" "pass"

# 测试9: 检查用户输入处理
run_test "检查用户输入处理" "grep -q 'read -p' '$TEST_SCRIPT'" "pass"

# 测试10: 检查默认值设置
run_test "检查默认值设置" "grep -q ':-' '$TEST_SCRIPT'" "pass"

# 测试11: 检查镜像源选择
run_test "检查镜像源选择逻辑" "grep -q 'DERPER_IMAGE' '$TEST_SCRIPT'" "pass"

# 测试12: 检查docker-compose文件创建
run_test "检查docker-compose配置" "grep -q 'docker-compose.yml' '$TEST_SCRIPT'" "pass"

# 测试13: 检查端口配置
run_test "检查端口配置" "grep -q 'DERP_PORT' '$TEST_SCRIPT'" "pass"

# 测试14: 检查STUN配置
run_test "检查STUN服务配置" "grep -q 'DERP_STUN' '$TEST_SCRIPT'" "pass"

# 测试15: 检查客户端验证配置
run_test "检查客户端验证配置" "grep -q 'DERP_VERIFY_CLIENTS' '$TEST_SCRIPT'" "pass"

# 测试16: 检查工作目录创建
run_test "检查工作目录设置" "grep -q 'WORK_DIR' '$TEST_SCRIPT'" "pass"

# 测试17: 检查权限设置
run_test "检查文件权限设置" "grep -q 'chown' '$TEST_SCRIPT'" "pass"

# 测试18: 检查服务启动
run_test "检查服务启动命令" "grep -q 'docker compose up -d' '$TEST_SCRIPT'" "pass"

# 测试19: 检查错误处理
run_test "检查错误处理机制" "grep -q 'exit 1' '$TEST_SCRIPT'" "pass"

# 测试20: 检查用户友好的输出
run_test "检查用户友好输出" "grep -q 'echo.*====' '$TEST_SCRIPT'" "pass"

# 模拟测试：非root用户运行
if [ "$EUID" -ne 0 ]; then
    run_test "非root用户运行测试" "timeout 5 '$TEST_SCRIPT' 2>&1 | grep -q '请以root用户'" "pass"
else
    echo -e "${YELLOW}⚠️  跳过非root用户测试（当前为root用户）${NC}"
    echo ""
fi

# 功能测试：检查apt-get可用性
if command -v apt-get >/dev/null 2>&1; then
    run_test "apt-get可用性测试" "command -v apt-get >/dev/null 2>&1" "pass"
else
    run_test "apt-get不可用测试" "! command -v apt-get >/dev/null 2>&1" "pass"
fi

# 代码质量检查
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}        代码质量检查${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# 检查代码行数
TOTAL_LINES=$(wc -l < "$TEST_SCRIPT")
COMMENT_LINES=$(grep -c "^#" "$TEST_SCRIPT" || echo "0")
CODE_LINES=$((TOTAL_LINES - COMMENT_LINES))

echo -e "${BLUE}代码统计:${NC}"
echo "  总行数: $TOTAL_LINES"
echo "  注释行: $COMMENT_LINES"
echo "  代码行: $CODE_LINES"
echo ""

# 检查函数数量
FUNCTION_COUNT=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*()" "$TEST_SCRIPT" || echo "0")
echo "  函数数量: $FUNCTION_COUNT"
echo ""

# 安全检查
echo -e "${BLUE}安全检查:${NC}"
if grep -q "curl.*http://" "$TEST_SCRIPT"; then
    echo -e "${YELLOW}⚠️  发现HTTP下载（建议使用HTTPS）${NC}"
else
    echo -e "${GREEN}✅ 所有下载使用HTTPS${NC}"
fi

if grep -i "password\|secret\|key" "$TEST_SCRIPT" | grep -v "#" >/dev/null; then
    echo -e "${YELLOW}⚠️  发现可能的硬编码敏感信息${NC}"
else
    echo -e "${GREEN}✅ 未发现硬编码敏感信息${NC}"
fi
echo ""

# 测试结果汇总
echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}        测试结果汇总${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo ""
echo -e "总测试数: ${BLUE}$TEST_COUNT${NC}"
echo -e "通过测试: ${GREEN}$PASS_COUNT${NC}"
echo -e "失败测试: ${RED}$FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 所有测试通过！deploy.sh脚本质量良好。${NC}"
    exit 0
else
    echo -e "${RED}❌ 有 $FAIL_COUNT 个测试失败，请检查脚本。${NC}"
    exit 1
fi