import os
import requests
import polib
import json

LANGUAGES = {
    'ko_KR': 'ko',
    'ja_JP': 'ja', 
    'zh_CN': 'zh-Hans',
    'ru_RU': 'ru',
    'fr_FR': 'fr',
    'de_DE': 'de',
    'es_ES': 'es',
    'it_IT': 'it',
    'pt_BR': 'pt',
    'ar_EG': 'ar',
    'hi_IN': 'hi',
    'hu_HU': 'hu',
    'id_ID': 'id',
    'tr_TR': 'tr',
    'th_TH': 'th'
}

def translate_with_azure(text, target_lang):
    key = os.environ.get('AZURE_TRANSLATOR_KEY')
    region = os.environ.get('AZURE_TRANSLATOR_REGION', 'eastus')
    
    if not key:
        print("Azure Translator key not found, skipping translation")
        return text
        
    endpoint = "https://api.cognitive.microsofttranslator.com/translate"
    
    headers = {
        'Ocp-Apim-Subscription-Key': key,
        'Ocp-Apim-Subscription-Region': region,
        'Content-type': 'application/json'
    }
    
    params = {
        'api-version': '3.0',
        'from': 'en',
        'to': target_lang
    }
    
    body = [{'text': text}]
    
    try:
        response = requests.post(endpoint, params=params, headers=headers, json=body)
        result = response.json()
        return result[0]['translations'][0]['text']
    except Exception as e:
        print(f"Azure translation error: {e}")
        return text

# 나머지 코드는 위와 동일...
