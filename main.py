from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from passlib.context import CryptContext
from datetime import datetime, timedelta
import uvicorn
import firebase_admin
from firebase_admin import credentials, firestore
import logging
import pytz
# from openai import OpenAI
from langchain_openai import ChatOpenAI
from langchain.memory import ConversationBufferMemory
from langchain.chains import ConversationChain
from answer_string_mock import answer_mock
import os
import csv
from fastapi.responses import StreamingResponse
from io import StringIO
import tiktoken  # Importar a biblioteca de tokenização

# Inicializa o tokenizador compatível com GPT-4o
enc = tiktoken.encoding_for_model("gpt-4o")

def count_tokens(text: str) -> int:
    """Função para contar a quantidade de tokens em um texto usando o tokenizador GPT-4o"""
    return len(enc.encode(text))


# Inicializar Firebase
cred = credentials.Certificate('code-wise-ai-firebase-adminsdk-fbsvc-c775c40222.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

app = FastAPI()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permitir todas as origens (ou especifique as corretas)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MAX_LIVES = 10
RECOVERY_TIME_MINUTES = 5
PERIODOS_PERMITIDOS = range(6, 9)  # 6º, 7º ou 8º período


logging.basicConfig(level=logging.INFO)

# Configure a chave da API da OpenAI

api_key = ''  # Substitua 'YOUR_OPENAI_API_KEY' pela sua chave de API
# client = OpenAI(api_key=api_key)
os.environ['OPENAI_API_KEY'] = api_key

buffer_memory = ConversationBufferMemory()

chat = ChatOpenAI(
                  model="gpt-4o",
                    temperature=0.7,
                    max_tokens=1000,
                    timeout=None,
                    max_retries=2) 

# class CustomConversationChain(ConversationChain):
#     def __init__(self, **kwargs):
#         super().__init__(**kwargs)
    
#     # Override the predict method to capture token usage
#     def predict(self, input: str):
#         response = super().predict(input=input)
        
#         # Assuming response contains metadata about tokens in some form.
#         token_usage = response['usage'] if 'usage' in response else None
        
#         if token_usage:
#             prompt_tokens = token_usage.get('prompt_tokens', 0)
#             completion_tokens = token_usage.get('completion_tokens', 0)
#             total_tokens = token_usage.get('total_tokens', 0)
            
#             # Log or store the token usage in Firestore or elsewhere
#             print(f"Prompt Tokens: {prompt_tokens}, Completion Tokens: {completion_tokens}, Total Tokens: {total_tokens}")
        
#         return response

conversation = ConversationChain(
    llm=chat,
    memory=ConversationBufferMemory()
)

MATRICULAS_PERMITIDAS = [
    '20189035495', '20229020161', '20239017929', '20229041199', '20229037481', '20229046088', 
    '20219015687', '20229048091', '20229035718', '20229054400', '20229037490', '20209038347',
    '20229038470', '20209050486', '20229037472', '20229046275', '20229053378', '20239006550',
    '20229048430', '20229037919'
]

class MockResponse:
    def __init__(self, content, prompt_tokens, completion_tokens, total_tokens):
        self.content = content
        self.response_metadata = {
            'token_usage': {
                'prompt_tokens': prompt_tokens,
                'completion_tokens': completion_tokens,
                'total_tokens': total_tokens
            }
        }

class User(BaseModel):
    email: str
    password: str
    expertise_level: str
    enrollment: str

class Prompt(BaseModel):
    user_id: str
    conversation_id: str
    prompt: str
    liked_interaction: bool = False  # Define False como padrão
    disliked_interaction: bool = False  # Define False como padrão

class Conversation(BaseModel):
    user_id: str
    theme: str  
    system_prompt: str 

class LoginData(BaseModel):
    email: str
    password: str

def get_student_period(matricula: str) -> int:
    # Extrair os primeiros 4 dígitos da matrícula (ano de ingresso)
    ano_ingresso = int(matricula[:4])
    ano_atual = datetime.now().year
    # Calcula quantos anos se passaram desde o ingresso
    anos_passados = ano_atual - ano_ingresso
    # Cada ano tem 2 períodos (considerando semestres)
    periodos_completados = anos_passados * 2
    return periodos_completados


def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def get_brasilia_time():
    return datetime.now(pytz.timezone('America/Sao_Paulo'))

def calculate_lives(last_prompt_time, current_lives):
    if last_prompt_time is None:
        return MAX_LIVES

    now = get_brasilia_time()
    time_diff = now - last_prompt_time
    minutes_passed = time_diff.total_seconds() // 60

    recovered_lives = minutes_passed // RECOVERY_TIME_MINUTES
    new_lives = min(MAX_LIVES, current_lives + recovered_lives)

    return new_lives

@app.post("/register/")
async def register(user: User):
    # Extrair os primeiros 11 dígitos da matrícula
    matricula = user.enrollment

    # Verificar se a matrícula está na lista de matrículas permitidas
    if matricula not in MATRICULAS_PERMITIDAS:
        raise HTTPException(status_code=400, detail="Matrícula não permitida.")

    # Verificar se a matrícula já está registrada no banco de dados
    user_ref = db.collection('users').where('enrollment', '==', matricula).get()
    if user_ref:
        raise HTTPException(status_code=400, detail="Matrícula já registrada.")

    # Verificar se o email já está registrado
    email_ref = db.collection('users').where('email', '==', user.email).get()
    if email_ref:
        raise HTTPException(status_code=400, detail="Email já registrado.")

    # Criação do usuário
    user_id = db.collection('users').document().id
    user_data = {
        'email': user.email,
        'password_hash': get_password_hash(user.password),
        'expertise_level': user.expertise_level,
        'enrollment': user.enrollment,
        'lives': MAX_LIVES,
        'last_prompt_time': None,
    }
    db.collection('users').document(user_id).set(user_data)

    return {"message": "Usuário registrado com sucesso", "user_id": user_id}


@app.post("/login/")
async def login(data: LoginData):
    email = data.email
    password = data.password
    user_ref = db.collection('users').where('email', '==', email).get()
    if not user_ref:
        raise HTTPException(status_code=400, detail="Email ou senha inválido")
    user = user_ref[0].to_dict()
    if not verify_password(password, user['password_hash']):
        raise HTTPException(status_code=400, detail="Email ou senha inválido")

    # Recalculate lives based on the time since last prompt
    current_lives = user['lives']
    last_prompt_time = user['last_prompt_time']
    if last_prompt_time:
        last_prompt_time = last_prompt_time.replace(tzinfo=pytz.UTC).astimezone(pytz.timezone('America/Sao_Paulo'))

    new_lives = calculate_lives(last_prompt_time, current_lives)
    db.collection('users').document(user_ref[0].id).update({'lives': new_lives})
    return {"message": "Login successful", "user_id": user_ref[0].id, "lives": new_lives}

@app.post("/create-conversation/")
async def create_conversation(conversation: Conversation):
    # Contar quantas conversas o usuário já tem
    user_conversations_ref = db.collection('conversations').where('user_id', '==', conversation.user_id).stream()
    conversation_count = len([c for c in user_conversations_ref])  # Contagem de conversas do usuário
    
    conversation_id = db.collection('conversations').document().id
    conversation_data = {
        'user_id': conversation.user_id,
        'theme': conversation.theme,
        'system_prompt': conversation.system_prompt,
        'timestamp': get_brasilia_time(),
        'conversation_number': conversation_count + 1  # Atribui o número da conversa
    }
    
    buffer_memory.chat_memory.add_user_message(conversation.system_prompt)

    db.collection('conversations').document(conversation_id).set(conversation_data)
    return {"message": "Conversa criada com sucesso!", "conversation_id": conversation_id}

async def summarize_conversation(prompts: list[str], system_prompt: str) -> str:
    """
    Gera um resumo da conversa até o momento.
    """
    # Cria uma mensagem contendo todos os prompts da conversa até agora
    context = "\n".join(prompts)
    
    # Define uma mensagem para o GPT-4 criar um resumo
    summary_prompt = f"Resuma a seguinte conversa mantendo os pontos mais importantes: {context}"

    # Envia o prompt para o modelo GPT
    response = await handle_prompt_with_openai(summary_prompt, system_prompt)
    
    return response.content


@app.post("/send-prompt/")
async def send_prompt(prompt: Prompt):
    # Obter o usuário
    user_ref = db.collection('users').document(prompt.user_id)
    user = user_ref.get()

    if not user.exists:
        raise HTTPException(status_code=404, detail="User not found")

    data = user.to_dict()
    current_lives = data['lives']
    last_prompt_time = data['last_prompt_time']
    
    if last_prompt_time:
        last_prompt_time = last_prompt_time.replace(tzinfo=pytz.UTC).astimezone(pytz.timezone('America/Sao_Paulo'))
    print('teste 1')
    # Calcular novas vidas com base no tempo do último prompt
    new_lives = calculate_lives(last_prompt_time, current_lives)
    print('teste 2')
    if new_lives <= 0:
        raise HTTPException(status_code=403, detail="Sem vidas no momento")

    # Atualizar o tempo do último prompt e diminuir uma vida
    new_lives -= 1
    last_prompt_time = get_brasilia_time()

    # Atualizar o documento do usuário
    user_ref.update({'lives': new_lives, 'last_prompt_time': last_prompt_time})

    # Buscar os prompts da conversa
    conversation_prompts_ref = db.collection('prompts').where('conversation_id', '==', prompt.conversation_id).order_by('timestamp', direction=firestore.Query.DESCENDING).stream()

    # Lista de prompts e variáveis para verificar o número de prompts
    prompts_list = [p.to_dict()['prompt'] for p in conversation_prompts_ref]

    # Carregar o contexto anterior da conversa (se houver)
    for p in conversation_prompts_ref:
        buffer_memory.chat_memory.add_user_message(p.to_dict()['prompt'])
        buffer_memory.chat_memory.add_ai_message(p.to_dict()['response'])

    # Adicionar o novo prompt ao contexto
    response = conversation.predict(input=prompt.prompt)

    # Simula a resposta (ou você pode usar a integração real do LangChain para gerar)
    # response = await handle_prompt_with_openai(context, conversation_data.get('system_prompt'))

    # response = MockResponse(
    #     content=response,  # Usando a resposta gerada pelo ConversationChain
    #     prompt_tokens=10,  # Valor fictício para os tokens de prompt
    #     completion_tokens=20,  # Valor fictício para os tokens de resposta
    #     total_tokens=30  # Total de tokens (prompt + resposta)
    # )

    # prompt_tokens = response.response_metadata['token_usage']['prompt_tokens']
    # answer_tokens = response.response_metadata['token_usage']['completion_tokens']
    # total_tokens = response.response_metadata['token_usage']['total_tokens']

    # Criar um novo documento de prompt no Firestore
    prompt_id = db.collection('prompts').document().id
    db.collection('prompts').document(prompt_id).set({
        'user_id': prompt.user_id,
        'conversation_id': prompt.conversation_id,
        'prompt': prompt.prompt,
        'response': response,
        'timestamp': last_prompt_time,
        # 'prompt_tokens': prompt_tokens,
        # 'answer_tokens': answer_tokens,
        # 'total_tokens': total_tokens,
        'prompt_number': len(prompts_list) + 1,
        'liked_interaction': prompt.liked_interaction,  # Usa o valor do Pydantic, que já garante False por padrão
        'disliked_interaction': prompt.disliked_interaction  # Usa o valor do Pydantic, que já garante False por padrão
    })

    logging.info(f"Prompt sent by user {prompt.user_id}. Lives left: {new_lives}")

    return {"response": response}


@app.post("/like-prompt/{prompt_id}")
async def like_prompt(prompt_id: str):
    prompt_ref = db.collection('prompts').document(prompt_id)
    prompt = prompt_ref.get()

    if not prompt.exists:
        raise HTTPException(status_code=404, detail="Prompt not found")

    prompt_data = prompt.to_dict()

    # Garantir que os campos existam
    liked_interaction = prompt_data.get('liked_interaction', False)
    disliked_interaction = prompt_data.get('disliked_interaction', False)

    # Se o prompt já está curtido, descurtir. Se não está, curtir e remover descurtida
    if liked_interaction:
        prompt_ref.update({
            'liked_interaction': False,
        })
    else:
        prompt_ref.update({
            'liked_interaction': True,
            'disliked_interaction': False  # Remover descurtida se for curtido
        })

    return {
        "message": "Prompt liked successfully" if not liked_interaction else "Prompt unliked successfully",
        "prompt_id": prompt_id,
        "liked_interaction": not liked_interaction,
        "disliked_interaction": False if not liked_interaction else disliked_interaction
    }


@app.post("/dislike-prompt/{prompt_id}")
async def dislike_prompt(prompt_id: str):
    prompt_ref = db.collection('prompts').document(prompt_id)
    prompt = prompt_ref.get()

    if not prompt.exists:
        raise HTTPException(status_code=404, detail="Prompt not found")

    prompt_data = prompt.to_dict()

    # Garantir que os campos existam
    liked_interaction = prompt_data.get('liked_interaction', False)
    disliked_interaction = prompt_data.get('disliked_interaction', False)

    # Se o prompt já está descurtido, remover descurtida. Se não está, descurtir e remover curtida
    if disliked_interaction:
        prompt_ref.update({
            'disliked_interaction': False,
        })
    else:
        prompt_ref.update({
            'disliked_interaction': True,
            'liked_interaction': False  # Remover curtida se for descurtido
        })

    return {
        "message": "Prompt disliked successfully" if not disliked_interaction else "Prompt undisliked successfully",
        "prompt_id": prompt_id,
        "liked_interaction": False if not disliked_interaction else liked_interaction,
        "disliked_interaction": not disliked_interaction
    }

@app.get("/user-status/{user_id}")
async def user_status(user_id: str):
    user_ref = db.collection('users').document(user_id)
    user = user_ref.get()
    if not user.exists:
        raise HTTPException(status_code=404, detail="User not found")
    data = user.to_dict()

    current_lives = data['lives']
    last_prompt_time = data['last_prompt_time']
    if last_prompt_time:
        last_prompt_time = last_prompt_time.replace(tzinfo=pytz.UTC).astimezone(pytz.timezone('America/Sao_Paulo'))

    new_lives = calculate_lives(last_prompt_time, current_lives)
    recovery_time = None
    if new_lives < MAX_LIVES and last_prompt_time:
        next_recovery_time = last_prompt_time + timedelta(minutes=RECOVERY_TIME_MINUTES * (MAX_LIVES - new_lives))
        now = get_brasilia_time()
        if next_recovery_time > now:
            recovery_time = (next_recovery_time - now).total_seconds()
        else:
            recovery_time = 0

    return {"lives": new_lives, "recovery_time": recovery_time}

@app.get("/user-conversations/{user_id}")
async def user_conversations(user_id: str):
    conversations_ref = db.collection('conversations').where('user_id', '==', user_id).stream()
    conversations = []
    for conversation in conversations_ref:
        conversation_data = conversation.to_dict()
        conversations.append({
            'conversation_id': conversation.id,
            'theme': conversation_data['theme'],
            'timestamp': conversation_data['timestamp'],
            'conversation_number': conversation_data['conversation_number']  # Inclui o número da conversa
        })

    # Ordena as conversas pelo número
    conversations = sorted(conversations, key=lambda c: c['conversation_number'])
    
    return {"user_id": user_id, "conversations": conversations}

@app.get("/conversation-prompts/{conversation_id}")
async def conversation_prompts(conversation_id: str):
    prompts_ref = db.collection('prompts').where('conversation_id', '==', conversation_id).stream()
    prompts = []
    for prompt in prompts_ref:
        prompt_data = prompt.to_dict()
        prompts.append({
            'promptId': prompt.id,
            'prompt': prompt_data['prompt'],
            'response': prompt_data['response'],
            'timestamp': prompt_data['timestamp'],
            'liked_interaction': prompt_data.get('liked_interaction', False),  # Garante que o campo seja retornado
            'disliked_interaction': prompt_data.get('disliked_interaction', False),  # Garante que o campo seja retornado
            'prompt_number': prompt_data['prompt_number']  # Inclui o número do prompt
        })

    # Ordena os prompts pelo número
    prompts = sorted(prompts, key=lambda p: p['prompt_number'])
    
    return {"conversation_id": conversation_id, "prompts": prompts}



@app.get("/user-prompts/{user_id}")
async def user_prompts(user_id: str):
    prompts_ref = db.collection('prompts').where('user_id', '==', user_id).stream()
    prompts = []
    for prompt in prompts_ref:
        prompt_data = prompt.to_dict()
        prompts.append({
            'conversation_id': prompt_data['conversation_id'],
            'prompt': prompt_data['prompt'],
            'response': prompt_data['response'],
            'timestamp': prompt_data['timestamp']
        })
    return {"user_id": user_id, "prompts": prompts}

async def handle_prompt_with_openai(prompt: str, system: str):
    try:
        # Defina a mensagem do sistema e a do usuário
        messages = [
            (
                "system",
                system),
            ("human", prompt),
        ]
        ai_msg = chat.invoke(messages)
        # print(ai_msg.content)
        return ai_msg
        # response = client.chat.completions.create(
        #     model="text-davinci-003",
        #     messages=[
        #     {
        #         "role": "user",
        #         "content": [
        #             {
        #             "type": "text",
        #             "text": "Faça os requisitos de um sistema de gerenciamento de uma biblioteca."
        #             }
        #         ]
        #     }
        #     ],
        #     temperature=1,
        #     max_tokens=150
        # )
        # return {"response": response.choices[0].text.strip()}
        # return {"response": answer_mock}
    except Exception as e:
        logging.error(f"Error communicating with OpenAI API: {e}")
        raise HTTPException(status_code=500, detail="Error communicating with OpenAI API")


@app.get("/export-prompts-csv/")
async def export_prompts_csv():
    # Obter todos os prompts
    prompts_ref = db.collection('prompts').stream()

    # Prepara a lista para armazenar os dados
    csv_data = []
    # Inclui os novos campos 'prompt_tokens' e 'response_tokens' no cabeçalho do CSV
    csv_data.append([
        'enrollment', 'expertise_level', 'conversation_id', 'theme', 'liked_interaction', 
        'disliked_interaction', 'prompt', 'response', 'prompt_tokens', 'response_tokens'
    ])

    # Iterar sobre os prompts
    for prompt in prompts_ref:
        prompt_data = prompt.to_dict()

        # Verificar se o prompt contém o campo conversation_id
        conversation_id = prompt_data.get('conversation_id', None)
        if not conversation_id:
            continue  # Ignorar prompts sem conversation_id

        # Obter a conversa correspondente
        conversation_ref = db.collection('conversations').document(conversation_id).get()
        conversation_data = conversation_ref.to_dict() if conversation_ref.exists else {}

        # Obter o usuário correspondente
        user_ref = db.collection('users').document(prompt_data['user_id']).get()
        user_data = user_ref.to_dict() if user_ref.exists else {}

        # Obter o prompt e a resposta
        prompt_text = prompt_data.get('prompt', '')
        response_text = prompt_data.get('response', '')

        # Contar os tokens do prompt e da resposta
        prompt_tokens = count_tokens(prompt_text)
        response_tokens = count_tokens(response_text)

        # Montar os dados no formato solicitado
        csv_row = [
            user_data.get('enrollment', ''),  # Matrícula
            user_data.get('expertise_level', ''),  # Expertise level
            conversation_id,  # ID da conversa
            conversation_data.get('theme', ''),  # Tema da conversa
            prompt_data.get('liked_interaction', False),  # Interação curtida
            prompt_data.get('disliked_interaction', False),  # Interação descurtida
            prompt_text,  # Prompt
            response_text,  # Resposta
            prompt_tokens,  # Quantidade de tokens do prompt
            response_tokens  # Quantidade de tokens da resposta
        ]
        csv_data.append(csv_row)

    # Criar o CSV usando StringIO
    csv_file = StringIO()
    writer = csv.writer(csv_file)
    writer.writerows(csv_data)
    csv_file.seek(0)

    # Retornar o CSV como resposta
    return StreamingResponse(csv_file, media_type="text/csv", headers={"Content-Disposition": "attachment; filename=prompts.csv"})


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)