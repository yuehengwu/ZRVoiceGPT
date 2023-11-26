# -*- coding: UTF-8 -*-

from flask import Flask, request, send_file, make_response
from flask_cors import CORS
import logging, os, time
from tutorial_api_key import client

PORT = 5005

app = Flask(__name__)

CORS(app, origins=[f"http://localhost:{PORT}", "https://chat.openai.com"])

# 配置日志记录
logging.basicConfig(filename='app.log', level=logging.DEBUG)

# global thread map: { userId -> Thread }
user_threads = {}


# knowladge
global_file = client.files.create(
  file=open("input_name_list.txt", "rb"),
  purpose='assistants'
)

# global assistant 
global_assistant = client.beta.assistants.create(
        name="Math Tutor",
        instructions="你叫亚当，是'主任'的私人助理，当我向你打招呼时请介绍一下你自己。请一定使用中文和我对话，并且每次对话都先称呼'老板'",
        tools=[{"type": "code_interpreter"}, {"type": "retrieval"}],
        model="gpt-4-1106-preview", #"gpt-3.5-turbo-1106" "gpt-4-1106-preview"
        file_ids=[global_file.id]
    )

def callback_json(code, data, message):
    return {
        "code": code,
        "data": data,
        "message": message
    }
    
# Private

def gpt_get_thread_id(user_id=''):            
    if user_id not in user_threads:
        thread = client.beta.threads.create() # 创建线程
        user_threads[user_id] = thread.id  
    thread_id = user_threads[user_id]
    return thread_id

def gpt_chat(user_content, user_id):
    print(f'正在请求openai聊天')
    thread_id = gpt_get_thread_id(user_id)
        
        
    client.beta.threads.messages.create(
        thread_id=thread_id,
        role="user",
        content=user_content
        # file_ids=[global_file.id]
    )
    
    run = client.beta.threads.runs.create(
        thread_id=thread_id,
        assistant_id=global_assistant.id
        # instructions="请称呼用户为Michael"
    )
    
    # 轮询查找运行状态
    while True:
        run_status = client.beta.threads.runs.retrieve(
            thread_id=thread_id,
            run_id=run.id
        )
        if run_status.status == "completed":
            break
        time.sleep(1)  # 暂停一秒再次检查
    
    # 检索消息
    messages = client.beta.threads.messages.list(
        thread_id=thread_id
    )
    
    reply = messages.data[0].content[0].text.value
    print(f'openai.reply:{reply}')
    return reply

def gpt_stt(file):
    directory = 'input_voices'
    if not os.path.exists(directory):
        os.makedirs(directory)
    mp3_file_path = os.path.join(directory, file.filename)            
    if file: file.save(mp3_file_path)  
    
    # print(f'当前语音路径:{mp3_file_path}')       
                
    audio_file= open(mp3_file_path, "rb")
    print(f'正在请求openai.stt（语音转文字）')
    transcript = client.audio.transcriptions.create(
        model="whisper-1", 
        file=audio_file
    )      
    user_content = transcript.text
    print(f'openai.stt:{user_content}')
    return user_content

def gpt_tts(content):    
    directory = 'output_voices'
    if not os.path.exists(directory):
        os.makedirs(directory)    
    speech_file_path = os.path.join(directory, 'speech.mp3') 
    if os.path.exists(speech_file_path):
        os.remove(speech_file_path)
    print(f'正在请求openai.tts（文字转语音）')
    response = client.audio.speech.create(
        model="tts-1-hd",
        voice="onyx", # alloy, echo, fable, onyx, nova, and shimmer
        input=content
    )
    response.stream_to_file(speech_file_path)
    print(f'openai.tts:{speech_file_path}')
    return speech_file_path

# API

@app.route('/', methods=['GET'])
def api_hello_world():    
    return 'Hello, World! This is a GET request.'

@app.route('/chat', methods=['POST'])
def api_gpt_chat():            
    user_content = request.json['content'] 
    user_id = request.headers['userId']
    reply = gpt_chat(user_content, user_id)
    response = make_response({ 
            "success": 0, 
            "message": reply
            })
    return response

@app.route('/voiceChat', methods=['POST'])
def api_gpt_voice_chat():        
    
    user_id = request.headers['userId']
    
    # judge file exist
    if 'file' not in request.files:
        return callback_json(code=-1, data=None, message="no file upload!")    
    file = request.files['file']    
    if file.filename == '':
        return callback_json(code=-1, data=None, message="no file upload!")
    
    # 语音转文字 STT
    user_content = gpt_stt(file)
        
    # Chat开始聊天
    reply = gpt_chat(user_content, user_id)
    
    # 文字转语音 TTS
    speech_file_path = gpt_tts(reply)    
            
    response = send_file(speech_file_path, as_attachment=True) # as_attachment=True
    return response
    
    
if __name__ == '__main__':    
    app.run(debug=True, host='0.0.0.0', port=PORT)
