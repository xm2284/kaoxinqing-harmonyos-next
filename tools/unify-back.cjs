const fs=require('fs');
const base='entry/src/main/ets/pages/';
for(const file of fs.readdirSync(base).filter(s=>s.endsWith('.ets'))){
  let code=fs.readFileSync(base+file,'utf8');
  code=code.replace(/(Button\(\{ type: ButtonType\.Circle \}\) \{\s*)(?:Text\('<'\)|SymbolGlyph\(\$r\('sys\.symbol\.left_parenthesis'\)\))\s*(?:\.(?:fontSize|fontWeight|fontColor)\([^\n]*\)\s*)+\}/g, "$1Image($rawfile('back_arrow.svg')).width(24).height(24)\n      }");
  code=code.replace(/(Image\(\$rawfile\('back_arrow.svg'\)\)\.width\(24\)\.height\(24\)\s*\}\s*)\.width\(\d+\)\s*\.height\(\d+\)/g, "$1.width(44).height(44).accessibilityText('返回')");
  fs.writeFileSync(base+file,code);
}