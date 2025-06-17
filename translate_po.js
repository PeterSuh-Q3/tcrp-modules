const fs = require('fs');
const path = require('path');

// 언어 코드 매핑
const languages = {
  'ko_KR': 'ko',
  'ja_JP': 'ja', 
  'zh_CN': 'zh',
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
  'am_ET': 'am',
  'th_TH': 'th'
};

async function translateText(text, targetLang) {
  // GitHub Copilot API 또는 다른 번역 서비스 사용
  // 여기서는 간단한 예시로 fetch API 사용
  try {
    const response = await fetch('https://api.mymemory.translated.net/get', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
      params: new URLSearchParams({
        q: text,
        langpair: `en|${targetLang}`
      })
    });
    const data = await response.json();
    return data.responseData.translatedText || text;
  } catch (error) {
    console.error(`Translation error for ${targetLang}:`, error);
    return text; // 번역 실패시 원문 반환
  }
}

function parsePOFile(content) {
  const entries = [];
  const lines = content.split('\n');
  let currentEntry = {};
  
  for (const line of lines) {
    if (line.startsWith('msgid')) {
      if (currentEntry.msgid !== undefined) {
        entries.push(currentEntry);
        currentEntry = {};
      }
      currentEntry.msgid = line.match(/msgid\s+"(.*)"/)?.[1] || '';
    } else if (line.startsWith('msgstr')) {
      currentEntry.msgstr = line.match(/msgstr\s+"(.*)"/)?.[1] || '';
    } else if (line.startsWith('#:')) {
      currentEntry.comment = line;
    }
  }
  
  if (currentEntry.msgid !== undefined) {
    entries.push(currentEntry);
  }
  
  return entries;
}

async function main() {
  const sourcePath = 'lang/en_US/LC_MESSAGES/tcrp.po';
  
  if (!fs.existsSync(sourcePath)) {
    console.error('Source PO file not found:', sourcePath);
    return;
  }
  
  const sourceContent = fs.readFileSync(sourcePath, 'utf8');
  const entries = parsePOFile(sourceContent);
  
  // 각 언어별로 번역 생성
  for (const [locale, langCode] of Object.entries(languages)) {
    const targetDir = `lang/${locale}/LC_MESSAGES`;
    
    // 디렉토리 생성
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }
    
    console.log(`Translating to ${locale}...`);
    
    let translatedContent = `# Translation for ${locale}\n`;
    translatedContent += `msgid ""\n`;
    translatedContent += `msgstr ""\n`;
    translatedContent += `"Content-Type: text/plain; charset=UTF-8\\n"\n`;
    translatedContent += `"Language: ${langCode}\\n"\n\n`;
    
    for (const entry of entries) {
      if (entry.msgid && entry.msgid !== '') {
        const translatedText = await translateText(entry.msgid, langCode);
        
        if (entry.comment) {
          translatedContent += `${entry.comment}\n`;
        }
        translatedContent += `msgid "${entry.msgid}"\n`;
        translatedContent += `msgstr "${translatedText}"\n\n`;
      }
    }
    
    const targetPath = path.join(targetDir, 'tcrp.po');
    fs.writeFileSync(targetPath, translatedContent);
    console.log(`Created: ${targetPath}`);
  }
}

main().catch(console.error);
