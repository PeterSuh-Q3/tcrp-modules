import os
import requests
import polib
import json
import time
from tqdm import tqdm

LANGUAGES = {
    'ko_KR': 'ko',
    'ja_JP': 'ja', 
    'zh_CN': 'zh-CN',
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

def translate_with_google(text, target_lang, max_retries=3):
    api_key = os.environ.get('GOOGLE_TRANSLATE_API_KEY')
    
    if not api_key:
        print("Google Translate API key not found, skipping translation")
        return text
        
    url = "https://translation.googleapis.com/language/translate/v2"
    
    params = {
        'key': api_key,
        'q': text,
        'source': 'en',
        'target': target_lang,
        'format': 'text'
    }
    
    for attempt in range(max_retries):
        try:
            response = requests.post(url, params=params, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                return result['data']['translations'][0]['translatedText']
            elif response.status_code == 429:
                print(f"Rate limit exceeded, waiting {2 ** attempt} seconds...")
                time.sleep(2 ** attempt)
                continue
            else:
                print(f"API error: {response.status_code} - {response.text}")
                return text
                
        except Exception as e:
            print(f"Google Translate error (attempt {attempt + 1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
            else:
                return text
    
    return text

def create_po_file(locale, lang_code, entries):
    target_dir = f"lang/{locale}/LC_MESSAGES"
    os.makedirs(target_dir, exist_ok=True)
    
    po = polib.POFile()
    po.metadata = {
        'Content-Type': 'text/plain; charset=UTF-8',
        'Language': lang_code,
        'MIME-Version': '1.0',
        'Content-Transfer-Encoding': '8bit',
    }
    
    for msgid, msgstr in entries.items():
        if msgid.strip():
            entry = polib.POEntry(
                msgid=msgid,
                msgstr=msgstr
            )
            po.append(entry)
    
    target_path = os.path.join(target_dir, 'tcrp.po')
    po.save(target_path)
    print(f"Created: {target_path}")
    return target_path

def main():
    source_path = 'lang/en_US/LC_MESSAGES/tcrp.po'
    
    # 원본 파일이 없으면 샘플 생성
    if not os.path.exists(source_path):
        print(f"Source file not found: {source_path}")
        print("Creating sample file...")
        os.makedirs('lang/en_US/LC_MESSAGES', exist_ok=True)
        
        sample_po = polib.POFile()
        sample_po.metadata = {
            'Content-Type': 'text/plain; charset=UTF-8',
            'Language': 'en',
        }
        
        sample_entries = [
            "Hello", "Welcome", "Settings", "Save", "Cancel", 
            "Error", "Success", "Yes", "No", "OK"
        ]
        
        for text in sample_entries:
            entry = polib.POEntry(msgid=text, msgstr=text)
            sample_po.append(entry)
        
        sample_po.save(source_path)
        print(f"Sample file created: {source_path}")
    
    # 원본 PO 파일 로드
    try:
        po = polib.pofile(source_path)
        print(f"Loaded source file: {source_path}")
    except Exception as e:
        print(f"Error loading PO file: {e}")
        return
    
    # 각 언어별로 번역
    for locale, lang_code in LANGUAGES.items():
        print(f"\nTranslating to {locale} ({lang_code})...")
        
        translated_entries = {}
        entries_to_translate = [entry for entry in po if entry.msgid and entry.msgid.strip()]
        
        for entry in tqdm(entries_to_translate, desc=f"Translating {locale}"):
            if entry.msgid and entry.msgid.strip():
                translated_text = translate_with_google(entry.msgid, lang_code)
                translated_entries[entry.msgid] = translated_text
                time.sleep(0.1)  # API 제한 방지
        
        create_po_file(locale, lang_code, translated_entries)
        print(f"Completed translation for {locale}")

if __name__ == "__main__":
    main()
