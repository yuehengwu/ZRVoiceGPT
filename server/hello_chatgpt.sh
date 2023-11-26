OPENAI_API_KEY=your-chatgpt-key
HOST=https://api.openai.com
# HOST=https://api.openai-proxy.com # 这个是国内的对于openai的反向代理


curl "$HOST/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
     "model": "gpt-3.5-turbo",
     "messages": [{"role": "user", "content": "Say this is a test!"}],
     "temperature": 0.7
   }'