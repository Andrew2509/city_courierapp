import os
import re

root_dir = r'f:\Flutter\city_courierapp\lib\screens\courier\ci_word'

patterns = [
    (r"import '\.\./\.\./\.\./core/config/app_colors\.dart';", "import 'package:city_courierapp/core/config/app_colors.dart';"),
    (r"import '\.\./\.\./\.\./core/config/app_typography\.dart';", "import 'package:city_courierapp/core/config/app_typography.dart';"),
    (r"import '\.\./\.\./\.\./\.\./core/config/app_colors\.dart';", "import 'package:city_courierapp/core/config/app_colors.dart';"),
    (r"import '\.\./\.\./\.\./\.\./core/config/app_typography\.dart';", "import 'package:city_courierapp/core/config/app_typography.dart';"),
    (r"\.withOpacity\((.*?)\)", r".withValues(alpha: \1)"),
    (r"AppTypography\.(\w+)\?", r"AppTypography.\1"),
]

def fix_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content
    for pattern, replacement in patterns:
        new_content = re.sub(pattern, replacement, new_content)
    
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed: {file_path}")

for root, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))
