#!/bin/bash

# API 端点和 API 密钥
API_URL="https://pengu.gaia.domains/v1/chat/completions"
API_KEY="gaia-NTkzZWNkNGYtNGRhMi00MjcyLTgxOTYtMzhkYTRiMTcxOWMw-ic0CfDcN01zjN1p6"  # 替换为你的实际 API 密钥

# 问题文件路径（每行一个问题）
QUESTIONS_FILE="questions.txt"

# 检查问题文件是否存在
if [[ ! -f "$QUESTIONS_FILE" ]]; then
  echo "问题文件 $QUESTIONS_FILE 不存在！"
  exit 1
fi

# 读取问题文件并逐行提问
question_count=0
while IFS= read -r question && [[ $question_count -lt 50 ]]; do
  # 构造请求体
  request_body=$(jq -n \
    --arg role1 "system" \
    --arg content1 "You are a helpful assistant." \
    --arg role2 "user" \
    --arg content2 "$question" \
    '{
      messages: [
        { role: $role1, content: $content1 },
        { role: $role2, content: $content2 }
      ]
    }')

  echo "正在提问: $question"

  # 发送 API 请求（带重试机制）
  max_retries=3
  retry_count=0
  while [[ $retry_count -lt $max_retries ]]; do
    response=$(curl --max-time 30 -i -s -X POST "$API_URL" \
      -H "Authorization: Bearer $API_KEY" \
      -H "accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$request_body")

    # 检查是否成功
    if [[ $? -eq 0 ]] && [[ $(echo "$response" | grep -o "HTTP/2 200") == "HTTP/2 200" ]]; then
      break
    fi

    retry_count=$((retry_count + 1))
    echo "请求失败，正在重试 ($retry_count/$max_retries)..."
    sleep 2  # 等待 2 秒后重试
  done

  # 检查最终响应状态
  if [[ $(echo "$response" | grep -o "HTTP/2 200") != "HTTP/2 200" ]]; then
    echo "请求失败，服务器返回错误："
    echo "$response"
    echo "-------------------------"
    continue  # 跳过当前问题，继续下一个
  fi

  # 提取 JSON 部分（去掉 HTTP 头）
  json_response=$(echo "$response" | awk 'NR>1 {print}')

  # 解析并打印回答
  answer=$(echo "$json_response" | jq -r '.choices[0].message.content' 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "解析 JSON 失败，跳过当前问题。"
    echo "-------------------------"
    continue  # 跳过当前问题，继续下一个
  fi

  echo "回答: $answer"
  echo "-------------------------"

  # 增加问题计数
  question_count=$((question_count + 1))
done < "$QUESTIONS_FILE"

echo "已完成 50 个问题的提问！"