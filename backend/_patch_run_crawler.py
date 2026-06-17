from pathlib import Path

path = Path('backend/features/market_insights/services/market_service.py')
text = path.read_text('utf-8')

def replace_nth(s, old, new, n):
    idx = -1
    for _ in range(n):
        idx = s.find(old, idx + 1)
        if idx == -1:
            return s, False
    return s[:idx] + new + s[idx + len(old):], True

replacements = [
    (
        'all_rows = []\n\n        for job in job_list:\n\n',
        'all_rows = []\n\n        self.logger.info(f"Running job batch: {job_list}")\n\n        for job in job_list:\n\n',
        2
    ),
    (
        'print(f"📦 Loaded {len(seen_urls)} URLs + {len(seen_ids)} IDs from Supabase")',
        'self.logger.info(f"Loaded {len(seen_urls)} URLs + {len(seen_ids)} IDs from Supabase")',
        2
    ),
    (
        'print("✅ WUZZUF saved to Supabase")',
        'self.logger.info("✅ WUZZUF saved to Supabase")',
        2
    ),
    (
        'print("✅ ADZUNA saved to Supabase")',
        'self.logger.info("✅ ADZUNA saved to Supabase")',
        2
    ),
]

for old, new, n in replacements:
    text, ok = replace_nth(text, old, new, n)
    if not ok:
        raise SystemExit(f'Replacement failed: {old}')

path.write_text(text, 'utf-8')
print('patched second run_crawler')
