# -*- coding: UTF-8 -*-

from flask import Flask, request, make_response
from flask_cors import CORS
import time
from tutorial_api_key import client

PORT = 5010

app = Flask(__name__)

CORS(app, origins=[f"http://localhost:{PORT}", "https://chat.openai.com"])


def callback_json(code, data, message):
    return {
        "code": code,
        "data": data,
        "message": message
    }

# global assistant 
global_assistant = client.beta.assistants.create(
        name="Math Tutor",
        instructions="你叫我的私人助理，请使用我提供的function来回答问题。",
        tools=[
                {
                    "type": "function",
                    "function": {
                        "name": "getAnswer",
                        "description": "Get the correct answer",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "question": {"type": "string", "description": "the anser"},                            
                            },
                            "required": ["question"]
                        }
                    }
                }
            ],
        model="gpt-4-1106-preview",  # "gpt-3.5-turbo-1106" "gpt-4-1106-preview"
    )

thread = client.beta.threads.create()  # 创建线程

# 查找gpt当前的状态
def gpt_check_status(run_id, input_status):
    # 轮询查找运行状态
    while True:
        run_status = client.beta.threads.runs.retrieve(
            thread_id=thread.id,
            run_id=run_id
        )
        print(f'openai进入{run_status.status}')
        if run_status.status == 'cancelled' or run_status.status == 'failed' or run_status.status == 'expired' or run_status.status == 'completed': 
            return run_status
        if run_status.status == input_status: 
            return run_status            
        time.sleep(1)  # 暂停一秒再次检查


def getAnswer(question):    
    # 处理外部方法
    anwser = '神秘代码是：520helloworld'
    return anwser
    


# 聊天
def gpt_chat(question):
    print(f'正在请求openai聊天')                
                
    client.beta.threads.messages.create(
        thread_id=thread.id,
        role="user",
        content=question
        # file_ids=[global_file.id]
    )        
    
    run = client.beta.threads.runs.create(
        thread_id=thread.id,
        assistant_id=global_assistant.id
        # instructions="请称呼用户为Michael"
    )
    
    # 轮询查找运行状态
    run_status = gpt_check_status(run.id, 'requires_action')
                
    # tool_outputs = run_status.required_action.submit_tool_outputs.tool_calls
    # print(tool_outputs)
    call_id = run_status.required_action.submit_tool_outputs.tool_calls[0].id
    
    run = client.beta.threads.runs.submit_tool_outputs(
        thread_id=thread.id,
        run_id=run.id,
        tool_outputs=[
            {
                "tool_call_id": call_id,
                "output": getAnswer(question)                
            }
        ]
    )
    
    run_status = gpt_check_status(run.id, 'completed')
                
    # 检索消息
    messages = client.beta.threads.messages.list(
        thread_id=thread.id
    )
    
    reply = messages.data[0].content[0].text.value
    print(f'openai.reply:{reply}')
    return callback_json(code=0, data=reply, message='请求成功')

# http://43.128.104.107:5010/testFunc?question=请问神秘代码是多少？
@app.route('/testFunc', methods=['GET'])
def api_gpt_voice_chat(): 
    
    question = request.args["question"]
    
    return gpt_chat(question)
    
    
if __name__ == '__main__': 
    app.run(debug=True, host='0.0.0.0', port=PORT)
