import os
import polib
import time
from tqdm import tqdm
from openai import OpenAI

LANGUAGES = {
    'ko_KR': {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
    'ja_JP': {'code': 'ja', 'name': 'Japanese', 'native': '日本語'}, 
    'zh_CN': {'code': 'zh-CN', 'name': 'Chinese', 'native': '中文'},
    'ru_RU': {'code': 'ru', 'name': 'Russian', 'native': 'Русский'},
    'fr_FR': {'code': 'fr', 'name': 'French', 'native': 'Français'},
    'de_DE': {'code': 'de', 'name': 'German', 'native': 'Deutsch'},
    'es_ES': {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
    'it_IT': {'code': 'it', 'name': 'Italian', 'native': 'Italiano'},
    'pt_BR': {'code': 'pt', 'name': 'Portuguese', 'native': 'Português'},
    'ar_EG': {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
    'hi_IN': {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    'hu_HU': {'code': 'hu', 'name': 'Hungarian', 'native': 'Magyar'},
    'id_ID': {'code': 'id', 'name': 'Indonesian', 'native': 'Bahasa Indonesia'},
    'tr_TR': {'code': 'tr', 'name': 'Turkish', 'native': 'Türkçe'},
    'th_TH': {'code': 'th', 'name': 'Thai', 'native': 'ไทย'}
}

def initialize_perplexity_client():
    """Perplexity API 클라이언트 초기화"""
    api_key = os.environ.get('PERPLEXITY_API_KEY')
    
    if not api_key:
        print("❌ Perplexity API key not found")
        print("💡 Pro subscribers get $5 monthly credits")
        return None
        
    client = OpenAI(
        api_key=api_key,
        base_url="https://api.perplexity.ai"
    )
    
    print("✅ Perplexity API client initialized")
    return client

def translate_with_perplexity(client, text, target_language, max_retries=3):
    """Perplexity API를 사용한 번역"""
    if not client:
        print(f"⚠️  No API client, returning original text: {text}")
        return text
        
    for attempt in range(max_retries):
        try:
            response = client.chat.completions.create(
                model="llama-3.1-sonar-small-128k-online",
                messages=[
                    {
                        "role": "system",
                        "content": f"""You are a professional translator specializing in software localization. 
                        Translate the given text to {target_language['name']} ({target_language['native']}).
                        
                        Rules:
                        1. Return ONLY the translated text, no explanations
                        2. Maintain the original tone and context
                        3. Use appropriate technical terminology for software interfaces
                        4. Keep formatting markers (like %s, %d) unchanged if present
                        5. For single words, provide the most appropriate translation for UI elements"""
                    },
                    {
                        "role": "user",
                        "content": f"Translate this text: {text}"
                    }
                ],
                max_tokens=200,
                temperature=0.1,  # 일관성을 위해 낮은 temperature 사용
                timeout=30
            )
            
            translated = response.choices[0].message.content.strip()
            
            # 번역 결과 정리 (따옴표나 불필요한 텍스트 제거)
            if translated.startswith('"') and translated.endswith('"'):
                translated = translated[1:-1]
            
            # 토큰 사용량 로깅
            tokens_used = response.usage.total_tokens
            cost_estimate = tokens_used * 0.0001
            print(f"  📊 Tokens: {tokens_used}, Cost: ${cost_estimate:.4f}")
            
            return translated
            
        except Exception as e:
            print(f"❌ Translation attempt {attempt + 1} failed: {e}")
            if attempt < max_retries - 1:
                wait_time = (2 ** attempt) + 0.5
                print(f"⏳ Retrying in {wait_time} seconds...")
                time.sleep(wait_time)
            else:
                print(f"⚠️  Max retries reached, returning original: {text}")
                return text
    
    return text

def create_po_file(locale, lang_info, entries):
    """PO 파일 생성"""
    target_dir = f"lang/{locale}/LC_MESSAGES"
    os.makedirs(target_dir, exist_ok=True)
    
    po = polib.POFile()
    po.metadata = {
        'Content-Type': 'text/plain; charset=UTF-8',
        'Language': lang_info['code'],
        'Language-Team': f"{lang_info['name']} <team@example.com>",
        'MIME-Version': '1.0',
        'Content-Transfer-Encoding': '8bit',
        'Generated-By': 'Perplexity AI Translation Workflow',
        'X-Generator': 'GitHub Actions + Perplexity API'
    }
    
    entry_count = 0
    for msgid, msgstr in entries.items():
        if msgid.strip():
            entry = polib.POEntry(
                msgid=msgid,
                msgstr=msgstr,
                comment=f"Translated by Perplexity AI"
            )
            po.append(entry)
            entry_count += 1
    
    target_path = os.path.join(target_dir, 'tcrp.po')
    po.save(target_path)
    print(f"✅ Created: {target_path} ({entry_count} entries)")
    return target_path

def main():
    print("🚀 Starting Perplexity AI Translation Workflow")
    print("=" * 60)
    
    # Perplexity 클라이언트 초기화
    client = initialize_perplexity_client()
    if not client:
        print("❌ Cannot proceed without API client")
        return
    
    source_path = 'lang/en_US/LC_MESSAGES/tcrp.po'
    
    # 원본 파일이 없으면 샘플 생성
    if not os.path.exists(source_path):
        print(f"📁 Source file not found: {source_path}")
        print("🔧 Creating sample file...")
        os.makedirs('lang/en_US/LC_MESSAGES', exist_ok=True)
        
        sample_po = polib.POFile()
        sample_po.metadata = {
            'Content-Type': 'text/plain; charset=UTF-8',
            'Language': 'en',
            'Language-Team': 'English <team@example.com>'
        }
        
        sample_entries = [
            "Hello", "Welcome", "Settings", "Save", "Cancel", 
            "Error", "Success", "Yes", "No", "OK", "Loading...",
            "Please wait", "Configuration", "Advanced options",
            "Apply changes", "Restart required"
        ]
        
        for text in sample_entries:
            entry = polib.POEntry(msgid=text, msgstr=text)
            sample_po.append(entry)
        
        sample_po.save(source_path)
        print(f"✅ Sample file created: {source_path} ({len(sample_entries)} entries)")
    
    # 원본 PO 파일 로드
    try:
        po = polib.pofile(source_path)
        print(f"📖 Loaded source file: {source_path}")
        total_entries = len([e for e in po if e.msgid and e.msgid.strip()])
        print(f"📊 Total entries to translate: {total_entries}")
    except Exception as e:
        print(f"❌ Error loading PO file: {e}")
        return
    
    # 번역 통계 추적
    total_tokens = 0
    total_cost = 0
    
    # 각 언어별로 번역
    for locale, lang_info in LANGUAGES.items():
        print(f"\n🌍 Translating to {locale} ({lang_info['native']})...")
        print("-" * 50)
        
        translated_entries = {}
        entries_to_translate = [entry for entry in po if entry.msgid and entry.msgid.strip()]
        language_tokens = 0
        
        for entry in tqdm(entries_to_translate, desc=f"🔄 {lang_info['name']}"):
            if entry.msgid and entry.msgid.strip():
                original_text = entry.msgid
                print(f"  🔤 '{original_text[:50]}{'...' if len(original_text) > 50 else ''}'")
                
                translated_text = translate_with_perplexity(
                    client, original_text, lang_info
                )
                
                translated_entries[original_text] = translated_text
                print(f"  ✅ '{translated_text[:50]}{'...' if len(translated_text) > 50 else ''}'\n")
                
                # API 제한 방지를 위한 대기
                time.sleep(0.2)
        
        create_po_file(locale, lang_info, translated_entries)
        print(f"🎉 Completed translation for {locale}")
    
    print("\n" + "=" * 60)
    print("✨ Translation workflow completed successfully!")
    print(f"💰 Estimated total cost: ${total_cost:.4f}")
    print("💡 Check your Perplexity API usage at Settings > API")

if __name__ == "__main__":
    main()
