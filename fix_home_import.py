with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = "import 'activation_screen.dart';"
NEW = "import 'activation_screen_v3.dart';"

count = content.count(OLD)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! home_screen_v2.dart corrigido.")