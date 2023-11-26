# -*- coding: UTF-8 -*-

from flask import Flask, request, send_file, session, make_response
from flask_session import Session
from flask_cors import CORS
import logging, os, uuid, time
from tutorial_api_key import client

PORT = 5005

secret_key = os.urandom(24)

app = Flask(__name__)
app.config["SECRET_KEY"] = secret_key
app.config["SESSION_TYPE"] = "filesystem"  # 可以选择其他存储方式
Session(app)

CORS(app, origins=[f"http://localhost:{PORT}", "https://chat.openai.com"])

# 配置日志记录
logging.basicConfig(filename='app.log', level=logging.DEBUG)

# user_threads = {}

def callback_json(code, data, message):
    return {
        "code": code,
        "data": data,
        "message": message
    }
    
# Private

def generate_session_id():
    return str(uuid.uuid4())

def gpt_chat(user_content, session_id):
    
    context_history = session.get(session_id, [])
    
    messages = [
        {"role": "system", "content": "你叫亚当，是'主任'的私人助理，当我向你打招呼时请介绍一下你自己。请一定使用中文和我对话，并且每次对话都先称呼'老板'"},
    ] + context_history + [{"role": "user", "content": user_content}]
    
    response = client.chat.completions.create(
        model="gpt-3.5-turbo-1106",
        messages=messages
    )
    if not response:
        return {
            "success": -1,
            "message": "openAI not response"
        }
    reply = response.choices[0].message.content 
    
    # 更新会话上下文历史
    context_history.append({"role": "user", "content": user_content})
    context_history.append({"role": "assistant", "content": reply})
    session[session_id] = context_history
    
    return reply

def gpt_stt(file):
    directory = 'input_voices'
    if not os.path.exists(directory):
        os.makedirs(directory)
    mp3_file_path = os.path.join(directory, file.filename)            
    if file: file.save(mp3_file_path)  
    
    print(f'当前语音路径:{mp3_file_path}')       
                
    audio_file= open(mp3_file_path, "rb")
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
    print(f'正在请求openai.tts...')
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
    session_id = request.cookies.get('session_id', generate_session_id())
    user_content = request.json['content'] 
    reply = gpt_chat(user_content)
    response = make_response({ 
            "success": 0, 
            "message": reply
            })
    response.set_cookie('session_id', session_id, max_age=31536000)
    return response

@app.route('/voiceChat', methods=['POST'])
def api_gpt_voice_chat():
    
    session_id = request.cookies.get('session_id', generate_session_id())
    
    # judge file exist
    if 'file' not in request.files:
        return callback_json(code=-1, data=None, message="no file upload!")    
    file = request.files['file']    
    if file.filename == '':
        return callback_json(code=-1, data=None, message="no file upload!")
    
    # 语音转文字 STT
    user_content = gpt_stt(file)
        
    # Chat开始聊天
    reply = gpt_chat(user_content, session_id)
    
    # 文字转语音 TTS
    speech_file_path = gpt_tts(reply)    
            
    response = send_file(speech_file_path, as_attachment=True) # as_attachment=True
    response.set_cookie('session_id', session_id, max_age=31536000)
    return response
    
    
    
if __name__ == '__main__':    
    app.run(debug=True, host='0.0.0.0', port=PORT)
