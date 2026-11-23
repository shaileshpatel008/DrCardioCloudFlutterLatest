"""raw.json (export_fixtures.py) -> cloud_panel/assets/demo/demo_data.json"""
import json, sys
w = json.load(open(sys.argv[1]))

def fix_record(d):
    i = d['id']
    d['ecg_pdf_url'] = f'demo://ecg/{i}'
    if d.get('report_pdf_url'): d['report_pdf_url'] = f'demo://report/{i}'
    if d.get('cardiologist_report_pdf_url'): d['cardiologist_report_pdf_url'] = f'demo://report/{i}'
    if d.get('csv_url'): d['csv_url'] = f'demo://csv/{i}'
    d.pop('actions', None)
    return d

records = {k: fix_record(v) for k, v in w['records'].items()}
roles = {}
for k, r in w['roles'].items():
    r['dashboard']['recent_ids'] = [x['id'] for x in r['dashboard'].pop('recent')]
    r.pop('login_message', None)
    roles[k] = r
s = json.dumps({'captured_at': w['captured_at'], 'records': records, 'staff_details': w['staff_details'], 'roles': roles}, separators=(',', ':'))
assert '127.0.0.1' not in s and 'test.local' not in s
open(sys.argv[2], 'w').write(s)
print(len(s) // 1024, 'KB,', len(records), 'records')
