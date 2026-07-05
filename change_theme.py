import sys

tema = sys.argv[1] if len(sys.argv) > 1 else "1"

with open(r"C:\Users\Jacques\iptv-player-app\lib\core\app_config.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re
content = re.sub(r'static const int appTheme = \d+;', f'static const int appTheme = {tema};', content)

with open(r"C:\Users\Jacques\iptv-player-app\lib\core\app_config.dart", "w", encoding="utf-8") as f:
    f.write(content)

print(f"OK! Tema alterado para {tema}.")