"""End-to-end smoke test for the panel API v2 (129 checks, all four roles).

!! Run ONLY against a local / staging copy seeded with test data !!
It signs in with *@test.local accounts and creates, updates and deletes
clients, staff, devices, cardiologists, OEM users and ECG records.

    BASE=http://127.0.0.1:8000/api/v2 python3 api_v2_smoke_test.py
"""
import os
import json, sys, urllib.request, urllib.error

BASE = os.environ.get('BASE', 'http://127.0.0.1:8000/api/v2')
results = []

def call(method, path, token=None, body=None, raw=False, query=None):
    url = BASE + path
    if query:
        from urllib.parse import urlencode
        url += '?' + urlencode({k: v for k, v in query.items() if v is not None})
    data = None
    headers = {'Accept': 'application/json'}
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            content = r.read()
            ctype = r.headers.get('Content-Type', '')
            return r.status, (content if raw or 'json' not in ctype else json.loads(content)), ctype
    except urllib.error.HTTPError as e:
        content = e.read()
        try:
            return e.code, json.loads(content), e.headers.get('Content-Type', '')
        except Exception:
            return e.code, content[:300], e.headers.get('Content-Type', '')

def check(name, cond, detail=''):
    results.append((name, bool(cond), detail))
    print(('PASS ' if cond else 'FAIL ') + name + ('' if cond else f'  -> {detail}'))

def login(email, pw):
    s, b, _ = call('POST', '/auth/login', body={'email': email, 'password': pw})
    check(f'login {email}', s == 200 and b.get('data', {}).get('token'), (s, b))
    return b['data']['token'], b['data']['user']

# ---------------------------------------------------------------- auth
s, b, _ = call('POST', '/auth/login', body={'email': 'admin@test.local', 'password': 'wrong'})
check('login wrong password -> 422', s == 422, (s, b))
s, b, _ = call('POST', '/auth/login', body={'email': 'rahul.verma@test.local', 'password': 'Staff@123'})
check('staff cannot sign in to panel -> 403', s == 403, (s, b))
s, b, _ = call('GET', '/dashboard')
check('no token -> 401 JSON', s == 401 and isinstance(b, dict), (s, b))

admin, admin_u = login('admin@test.local', 'Admin@123')
oem, oem_u = login('oem@test.local', 'Oem@1234')
client, client_u = login('client@test.local', 'Client@123')
multi, multi_u = login('citycare@test.local', 'Client@123')
cardio, cardio_u = login('cardio@test.local', 'Cardio@123')

check('menus: admin', admin_u['menu'] == ['dashboard','oem_users','clients','admin_staffs','cardiologists','devices','ecg_records','download_ecg','profile'], admin_u['menu'])
check('menus: oem', oem_u['menu'] == ['dashboard','clients','cardiologists','devices','ecg_records','download_ecg','profile'], oem_u['menu'])
check('menus: client (no multi)', client_u['menu'] == ['dashboard','client_staffs','ecg_records','download_ecg','profile'], client_u['menu'])
check('menus: client (multi)', 'cardiologists' in multi_u['menu'], multi_u['menu'])
check('menus: cardiologist', cardio_u['menu'] == ['dashboard','ecg_records','export_ecg_counts','notifications','profile'], cardio_u['menu'])

s, b, _ = call('GET', '/auth/me', admin)
check('me', s == 200 and b['data']['role'] == 'admin', (s, b))

# ---------------------------------------------------------------- dashboard
for name, tok in [('admin', admin), ('oem', oem), ('client', client), ('cardio', cardio)]:
    s, b, _ = call('GET', '/dashboard', tok)
    ok = s == 200 and 'counts' in b['data'] and len(b['data']['insights']['daily']) == 14
    check(f'dashboard {name}', ok, (s, b if s != 200 else b['data']['counts']))
    if ok:
        print('   counts', name, b['data']['counts'], 'recent', len(b['data']['recent']), 'avgTAT', b['data']['insights']['avg_tat_minutes'])

# ---------------------------------------------------------------- ecg lists & scoping
s, b, _ = call('GET', '/ecg-records', admin, query={'per_page': 100})
admin_total = b['meta']['total']; check('ecg list admin', s == 200 and admin_total == 40, b['meta'])
s, b, _ = call('GET', '/ecg-records', oem, query={'per_page': 100})
check('ecg list oem only own clients (20)', s == 200 and b['meta']['total'] == 20 and all(r['hospital_name'] == 'Medilab Diagnostic Centre' for r in b['data']), b['meta'])
oem_ecg_ids = [r['id'] for r in b['data']]
s, b, _ = call('GET', '/ecg-records', client, query={'per_page': 100})
check('ecg list client only own (20)', s == 200 and b['meta']['total'] == 20 and all(r['hospital_name'] == 'Sunrise Diagnostics' for r in b['data']), b['meta'])
s, b, _ = call('GET', '/ecg-records', cardio, query={'per_page': 100})
check('ecg list cardiologist only assigned', s == 200 and all(r['cardiologist_id'] == cardio_u['id'] for r in b['data']), b['meta'])
cardio_rows = b['data']
s, b, _ = call('GET', '/ecg-records', admin, query={'status': 'reported', 'ecg_status': 'abnormal', 'date_filter': '7'})
check('ecg filters status+ecg+date', s == 200 and all(r['status'] == 'reported' and r['ecg_status'] == 'abnormal' for r in b['data']), b.get('meta'))
s, b, _ = call('GET', '/ecg-records', admin, query={'date_filter': 'custom', 'from_date': '2020-01-01', 'to_date': '2030-01-01', 'search': 'Ramesh'})
check('ecg custom date + search', s == 200 and b['meta']['total'] >= 1 and all('Ramesh' in r['file_name'] for r in b['data']), b.get('meta'))
s, b, _ = call('GET', '/ecg-records', admin, query={'sort': 'hospital', 'dir': 'asc', 'page': 2, 'per_page': 10})
check('ecg sort+page 2', s == 200 and b['meta']['page'] == 2 and len(b['data']) == 10, b.get('meta'))
s, b, _ = call('GET', '/ecg-records/summary', admin)
check('ecg summary', s == 200 and b['data']['all'] == admin_total, b)
s, b, _ = call('GET', f'/ecg-records/{oem_ecg_ids[0]}', client)
check('client cannot open OEM ecg -> 404', s == 404, (s, b))
s, b, _ = call('GET', f'/ecg-records/{oem_ecg_ids[0]}', oem)
check('ecg detail', s == 200 and b['data']['ecg_pdf_url'].startswith('http') and 'measurements' in b['data'], (s, b))

# PDF files reachable
s, body, ctype = call('GET', '/ecg-records', admin, query={'status': 'reported', 'per_page': 1})
rep = body['data'][0]
for key in ['ecg_pdf_url', 'report_pdf_url']:
    try:
        with urllib.request.urlopen(rep[key]) as r:
            check(f'{key} downloadable', r.status == 200 and r.read(4) == b'%PDF', rep[key])
    except Exception as e:
        check(f'{key} downloadable', False, str(e))

# ---------------------------------------------------------------- lookups
s, b, _ = call('GET', '/lookups/hospitals', admin); check('lookup hospitals admin (2 admin-owned)', s == 200 and len(b['data']) == 2, b)
hosp = b['data'][0]
s, b, _ = call('GET', '/lookups/hospitals', oem); check('lookup hospitals oem (1)', s == 200 and len(b['data']) == 1, b)
oem_hosp = b['data'][0]
s, b, _ = call('GET', '/lookups/staffs', admin, query={'hospital_id': hosp['id']}); check('lookup staffs', s == 200 and len(b['data']) == 2, b)
s, b, _ = call('GET', '/lookups/devices', admin, query={'hospital_id': hosp['id']}); check('lookup devices', s == 200 and len(b['data']) == 2, b)
s, b, _ = call('GET', '/lookups/staffs', oem, query={'hospital_id': hosp['id']}); check('oem cannot list other hospital staff', s == 200 and len(b['data']) == 0, b)
s, b, _ = call('GET', '/lookups/cardiologists', admin); check('lookup cardiologists admin', s == 200 and len(b['data']) == 2, b)
cardio_ids = [c['id'] for c in b['data']]
s, b, _ = call('GET', '/lookups/cardiologists', oem); check('lookup cardiologists oem (1)', s == 200 and len(b['data']) == 1, b)
s, b, _ = call('GET', '/lookups/cardiologists', client); check('lookup cardiologists client (linked)', s == 200 and len(b['data']) == 1, b)
s, b, _ = call('GET', '/lookups/hospitals', cardio); check('lookup hospitals cardiologist', s == 200 and len(b['data']) == 1, b)

# ---------------------------------------------------------------- role gates
for path, tok, name in [('/clients', client, 'client'), ('/devices', cardio, 'cardio'), ('/oem-users', oem, 'oem'), ('/admin-staffs', oem, 'oem'), ('/cardiologists', client, 'client w/o multi')]:
    s, b, _ = call('GET', path, tok)
    check(f'{name} blocked from {path} -> 403', s == 403, (s, b))
s, b, _ = call('GET', '/cardiologists', multi); check('client with multi-hospital sees cardiologists', s == 200, (s, b))

# ---------------------------------------------------------------- clients CRUD (admin)
s, b, _ = call('GET', '/clients', admin); check('clients list admin (2)', s == 200 and b['meta']['total'] == 2, b.get('meta'))
s, b, _ = call('GET', '/clients', oem); check('clients list oem (1)', s == 200 and b['meta']['total'] == 1, b.get('meta'))
s, b, _ = call('GET', '/clients', admin, query={'cardiologist_id': cardio_u['id']}); check('clients filter by cardiologist', s == 200 and b['meta']['total'] == 1, b.get('meta'))
new_client = {
    'name': 'Lotus Heart Clinic', 'email': 'lotus@test.local', 'password': 'Lotus@123', 'password_confirmation': 'Lotus@123',
    'hospital_name': 'Lotus Heart Clinic', 'address': 'Pune', 'doctor_name': 'Dr. Ravi Menon', 'phone_number': '9822012345',
    'cardiologist': cardio_u['id'], 'report_limit_enabled': True, 'report_limit': 50, 'multi_hospital_access': False,
    'create_default_staff': True, 'devices': ['Dr.Cardio/999-AAAA', 'Dr.Cardio/999-BBBB', ''], 'webhook_url': 'https://x.example/hook',
    'get_patient_api_enabled': True, 'get_patient_url': 'https://x.example/patient',
}
s, b, _ = call('POST', '/clients', admin, new_client); check('create client', s == 200, (s, b))
s, b, _ = call('POST', '/clients', admin, new_client); check('create client duplicate email -> 422', s == 422 and 'email' in b.get('errors', {}), (s, b))
s, b, _ = call('GET', '/clients', admin, query={'search': 'Lotus'})
lotus = b['data'][0]
check('new client in list w/ cardiologist + balance', lotus['cardiologist_id'] == cardio_u['id'] and lotus['ecg_balance'] == 50, lotus)
s, b, _ = call('GET', f"/clients/{lotus['id']}", admin)
check('client detail devices+staff', s == 200 and len(b['data']['devices']) == 2 and b['data']['staff_count'] == 1 and b['data']['get_patient_api_enabled'], b)
upd = dict(new_client); upd.update({'doctor_name': 'Dr. Ravi M', 'password': '', 'password_confirmation': '', 'report_limit_enabled': False, 'get_patient_api_enabled': False})
s, b, _ = call('PUT', f"/clients/{lotus['id']}", admin, upd); check('update client', s == 200, (s, b))
s, b, _ = call('GET', f"/clients/{lotus['id']}", admin)
check('update persisted', b['data']['doctor_name'] == 'Dr. Ravi M' and not b['data']['report_limit_enabled'] and not b['data']['get_patient_api_enabled'], b['data'])
s, b, _ = call('POST', '/auth/login', body={'email': 'lotus@test.local', 'password': 'Lotus@123'})
check('blank password on update kept old password', s == 200, (s, b))
s, b, _ = call('GET', f"/clients/{lotus['id']}", oem); check('oem cannot open admin client -> 404', s == 404, (s, b))
s, b, _ = call('PUT', f"/clients/{lotus['id']}", oem, upd); check('oem cannot update admin client -> 404', s == 404, (s, b))

# ---------------------------------------------------------------- staff
s, b, _ = call('GET', f"/clients/{lotus['id']}/staff", admin); check('client staff list (default staff)', s == 200 and b['meta']['total'] == 1 and b['data'][0]['email'] == 'lotus-staff@test.local', b)
s, b, _ = call('POST', '/staff', admin, {'client_id': lotus['client_id'], 'name': 'Neha Desai', 'email': 'neha@test.local', 'password': 'Neha@123', 'password_confirmation': 'Neha@123', 'phone_number': '9000000001'})
check('admin add staff', s == 200, (s, b))
s, b, _ = call('POST', '/staff', admin, {'client_id': lotus['client_id'], 'name': '', 'email': 'bad', 'password': '1', 'password_confirmation': '2', 'phone_number': ''})
check('add staff validation -> 422 with fields', s == 422 and 'email' in b.get('errors', {}), (s, b))
s, b, _ = call('GET', f"/clients/{lotus['id']}/staff", admin, query={'search': 'Neha'}); neha = b['data'][0]
s, b, _ = call('GET', f"/staff/{neha['id']}", admin); check('staff detail', s == 200 and b['data']['email'] == 'neha@test.local', b)
s, b, _ = call('PUT', f"/staff/{neha['id']}", admin, {'name': 'Neha D', 'email': 'neha@test.local', 'phone_number': '9000000002'}); check('update staff', s == 200, (s, b))
s, b, _ = call('GET', f"/staff/{neha['id']}", oem); check('oem cannot open admin staff -> 404', s == 404, (s, b))
s, b, _ = call('DELETE', f"/staff/{neha['id']}", admin); check('delete staff', s == 200, (s, b))
s, b, _ = call('GET', '/admin-staffs', admin); check('admin staffs list', s == 200 and b['meta']['total'] >= 7 and b['data'][0]['client_name'], b.get('meta'))
s, b, _ = call('GET', '/staffs', client); check('client own staff', s == 200 and b['meta']['total'] == 2, b.get('meta'))
s, b, _ = call('POST', '/staff', client, {'name': 'Amit Joshi', 'email': 'amit@test.local', 'password': 'Amit@123', 'password_confirmation': 'Amit@123', 'phone_number': '9000000003', 'cardiologist_id': cardio_u['id']})
check('client add staff (with cardiologist)', s == 200, (s, b))
s, b, _ = call('GET', '/staffs', client, query={'search': 'Amit'})
check('client staff has cardiologist', b['data'][0]['cardiologist_id'] == cardio_u['id'], b['data'])
amit = b['data'][0]
s, b, _ = call('PUT', f"/staff/{amit['id']}", oem, {'name': 'x', 'email': 'amit@test.local', 'phone_number': '1'}); check('oem cannot edit client staff', s == 404, (s, b))

# ---------------------------------------------------------------- cardiologists
s, b, _ = call('GET', '/cardiologists', admin); check('cardiologists admin (2)', s == 200 and b['meta']['total'] == 2, b.get('meta'))
s, b, _ = call('GET', '/cardiologists', oem); check('cardiologists oem (1)', s == 200 and b['meta']['total'] == 1, b.get('meta'))
s, b, _ = call('POST', '/cardiologists', oem, {'name': 'Dr. Meera Iyer', 'email': 'meera@test.local', 'password': 'Meera@123', 'password_confirmation': 'Meera@123', 'address': 'Chennai', 'phone_number': '9444000000'})
check('oem create cardiologist', s == 200, (s, b))
s, b, _ = call('GET', '/cardiologists', oem, query={'search': 'Meera'}); meera = b['data'][0]
check('oem cardiologist owned by oem', b['meta']['total'] == 1, b)
s, b, _ = call('GET', f"/cardiologists/{meera['id']}", admin); check('admin can view any cardiologist', s == 200, (s, b))
s, b, _ = call('GET', f"/cardiologists/{cardio_u['id']}", oem); check('oem cannot view admin cardiologist -> 404', s == 404, (s, b))
s, b, _ = call('PUT', f"/cardiologists/{meera['id']}", oem, {'name': 'Dr. Meera I', 'email': 'meera@test.local', 'address': 'Chennai, TN', 'phone_number': '9444000001'}); check('update cardiologist', s == 200, (s, b))
s, b, _ = call('DELETE', f"/cardiologists/{meera['id']}", oem); check('delete cardiologist', s == 200, (s, b))

# ---------------------------------------------------------------- devices
s, b, _ = call('GET', '/devices', admin); check('devices admin', s == 200 and b['meta']['total'] >= 6, b.get('meta'))
s, b, _ = call('GET', '/devices', admin, query={'hospital_id': hosp['id']}); check('devices hospital filter', s == 200 and b['meta']['total'] == 2, b.get('meta'))
s, b, _ = call('POST', '/devices', oem, {'hospital_id': hosp['id'], 'intrument_id': 'Dr.Cardio/X-1'}); check('oem cannot add device to admin hospital -> 422', s == 422, (s, b))
s, b, _ = call('POST', '/devices', oem, {'hospital_id': oem_hosp['id'], 'intrument_id': 'Dr.Cardio/OEM-0001'}); check('oem add device', s == 200, (s, b))
s, b, _ = call('POST', '/devices', oem, {'hospital_id': oem_hosp['id'], 'intrument_id': 'Dr.Cardio/OEM-0001'}); check('duplicate device -> 422', s == 422 and 'intrument_id' in b.get('errors', {}), (s, b))
s, b, _ = call('GET', '/devices', oem, query={'search': 'OEM-0001'}); dev = b['data'][0]
s, b, _ = call('PUT', f"/devices/{dev['id']}", oem, {'hospital_id': oem_hosp['id'], 'intrument_id': 'Dr.Cardio/OEM-0002'}); check('update device', s == 200, (s, b))
s, b, _ = call('DELETE', f"/devices/{dev['id']}", oem); check('delete device', s == 200, (s, b))

# ---------------------------------------------------------------- oem users
s, b, _ = call('GET', '/oem-users', admin); check('oem users list', s == 200 and b['meta']['total'] == 1, b.get('meta'))
s, b, _ = call('POST', '/oem-users', admin, {'name': 'Pulse Medtech', 'email': 'pulse@test.local', 'password': 'Pulse@123', 'password_confirmation': 'Pulse@123', 'phone_number': '9833021456'}); check('create oem', s == 200, (s, b))
s, b, _ = call('GET', '/oem-users', admin, query={'search': 'Pulse'}); pulse = b['data'][0]
s, b, _ = call('GET', f"/oem-users/{pulse['id']}", admin); check('oem detail', s == 200 and 'password' not in b['data'], b)
s, b, _ = call('PUT', f"/oem-users/{pulse['id']}", admin, {'name': 'Pulse Medtech Pvt', 'email': 'pulse@test.local', 'phone_number': '9833021456'}); check('update oem', s == 200, (s, b))
s, b, _ = call('POST', '/auth/login', body={'email': 'pulse@test.local', 'password': 'Pulse@123'}); check('new oem can sign in', s == 200 and b['data']['user']['role'] == 'sub_admin', (s, b))
s, b, _ = call('DELETE', f"/oem-users/{pulse['id']}", admin); check('delete oem (fixed endpoint)', s == 200, (s, b))

# ---------------------------------------------------------------- ecg actions
s, b, _ = call('GET', '/ecg-records', admin, query={'status': 'requested', 'per_page': 100})
reassignable = [r for r in b['data'] if r['actions']['reassign']]
check('requested ecgs offer reassign', len(reassignable) > 0, b['meta'])
target = reassignable[0]
other = [c for c in cardio_ids if c != target['cardiologist_id']][0]
s, b, _ = call('POST', f"/ecg-records/{target['id']}/reassign", admin, {'cardiologist_id': other}); check('reassign', s == 200, (s, b))
s, b, _ = call('GET', f"/ecg-records/{target['id']}", admin); check('reassign persisted', b['data']['cardiologist_id'] == other and b['data']['is_reassigned'], b['data'])
s, b, _ = call('GET', '/ecg-records', admin, query={'status': 'no_credit', 'per_page': 100})
assignable = [r for r in b['data'] if r['actions']['assign']]
if assignable:
    s, b2, _ = call('POST', f"/ecg-records/{assignable[0]['id']}/assign", admin); check('assign no-credit ecg', s == 200, (s, b2))
    s, b2, _ = call('GET', f"/ecg-records/{assignable[0]['id']}", admin); check('assign persisted -> requested', b2['data']['status'] == 'requested', b2['data'])
s, b, _ = call('POST', f"/ecg-records/{target['id']}/reassign", client, {'cardiologist_id': other}); check('client cannot reassign -> 403', s == 403, (s, b))

# ---------------------------------------------------------------- cardiologist diagnose flow
s, b, _ = call('GET', '/ecg-records', cardio, query={'status': 'requested', 'per_page': 100})
req = [r for r in b['data'] if r['actions']['diagnose']]
check('cardiologist has requested ECGs to diagnose', len(req) > 0, b['meta'])
ecg = req[0]
s, b, _ = call('GET', f"/ecg-records/{ecg['id']}/diagnose", cardio); check('diagnose form + templates', s == 200 and len(b['data']['templates']) == 2, (s, b))
s, b, _ = call('POST', f"/ecg-records/{ecg['id']}/diagnose", cardio, {'action': 'publish', 'cardiologist_report': '<p>x</p>'}); check('publish without ecg status -> 422', s == 422, (s, b))
s, b, _ = call('POST', f"/ecg-records/{ecg['id']}/diagnose", cardio, {'action': 'draft', 'ecg_status': 'abnormal', 'cardiologist_report': '<p>Draft advice</p>', 'hr': '88', 'qt': '380', 'qtc': '420'})
check('save draft', s == 200 and b['data']['status'] == 'requested' and b['data']['measurements']['qt_by_qtc'] == '0.90', (s, b))
s, b, _ = call('POST', f"/ecg-records/{ecg['id']}/diagnose", cardio, {'action': 'publish', 'ecg_status': 'abnormal', 'cardiologist_report': '<p>Sinus tachycardia.</p><ul><li>Follow up</li></ul>', 'hr': '104', 'pr': '150', 'qrs': '90', 'qt': '360', 'qtc': '430', 'r': '1.2', 'rr': '580'})
check('publish report (PDF generate + merge)', s == 200 and b['data']['status'] == 'reported' and b['data']['report_pdf_url'], (s, b if s != 200 else b['data']['report_pdf_url']))
if s == 200:
    try:
        with urllib.request.urlopen(b['data']['report_pdf_url']) as r:
            check('merged report PDF exists', r.status == 200 and r.read(4) == b'%PDF')
    except Exception as e:
        check('merged report PDF exists', False, str(e))
s, b, _ = call('GET', f"/ecg-records/{oem_ecg_ids[0]}/diagnose", cardio); check('cardiologist cannot diagnose others ECG -> 404', s == 404, (s, b))
s, b, _ = call('GET', '/ecg-records', client, query={'status': 'reported', 'per_page': 1})
check('client sees report link', s == 200 and b['data'][0]['report_pdf_url'], b['data'][:1])

# ---------------------------------------------------------------- notifications
s, b, _ = call('GET', '/notifications', cardio); check('notifications', s == 200 and b['unread_total'] >= 1, (s, b))
if b.get('data'):
    nid = b['data'][0]['id']
    before = b['unread_total']
    s, b, _ = call('POST', f'/notifications/{nid}/read', cardio); check('read one', s == 200, (s, b))
    s, b, _ = call('GET', '/notifications', cardio); check('unread decreased', b['unread_total'] == before - 1, b['unread_total'])
s, b, _ = call('POST', '/notifications/read-all', cardio); check('read all', s == 200, (s, b))
s, b, _ = call('GET', '/notifications', cardio); check('unread zero', b['unread_total'] == 0, b['unread_total'])

# ---------------------------------------------------------------- exports
s, b, _ = call('GET', '/exports/ecg/count', admin, query={'hospital_id': hosp['id']}); check('export count', s == 200 and b['data']['total'] > 0, (s, b))
s, b, _ = call('GET', '/exports/ecg/count', oem); check('oem export "all" scoped to own (20)', s == 200 and b['data']['total'] == 20, (s, b))
s, b, _ = call('GET', '/exports/ecg/count', client); check('client export "all" scoped to own (20)', s == 200 and b['data']['total'] == 20, (s, b))
s, body, ctype = call('POST', '/exports/ecg', client, {'type': 'pdf', 'date_filter': '30'}, raw=True)
check('export pdf zip', s == 200 and 'zip' in ctype and body[:2] == b'PK', (s, ctype, body[:80]))
s, body, ctype = call('POST', '/exports/ecg', admin, {'type': 'csv', 'hospital_id': hosp['id']}, raw=True)
check('export csv zip', s == 200 and body[:2] == b'PK', (s, ctype))
s, b, _ = call('POST', '/exports/ecg', admin, {'type': 'pdf', 'date_filter': 'custom', 'from_date': '2001-01-01', 'to_date': '2001-01-02'}); check('export empty -> 404 message', s == 404 and 'No ECG' in b.get('message', ''), (s, b))
from datetime import date
s, body, ctype = call('POST', '/exports/ecg-counts', cardio, {'month': date.today().strftime('%m'), 'year': date.today().strftime('%Y')}, raw=True)
check('ecg counts csv', s == 200 and body.startswith(b'"Hospital Name"') or body.startswith(b'Hospital Name'), (s, ctype, body[:120]))
s, b, _ = call('POST', '/exports/ecg-counts', admin, {'month': '01', 'year': '2026'}); check('ecg counts admin allowed (admin passes all)', s == 200 or s == 422, s)
s, b, _ = call('POST', '/exports/ecg', cardio, {'type': 'pdf'}); check('cardiologist blocked from download ECG -> 403', s == 403, (s, b))

# ---------------------------------------------------------------- profile
s, b, _ = call('GET', '/profile', client); check('profile client', s == 200 and b['data']['editable']['hospital_name'] == 'Sunrise Diagnostics', b)
s, b, _ = call('POST', '/profile', client, {'name': 'Sunrise Diagnostics', 'hospital_name': 'Sunrise Diagnostics', 'doctor_name': 'Dr. N Shah', 'address': 'Ahmedabad'}); check('update profile client', s == 200 and b['data']['editable']['doctor_name'] == 'Dr. N Shah', (s, b))
s, b, _ = call('POST', '/profile', client, {'name': 'X', 'hospital_name': 'Sunrise Diagnostics', 'password': 'abc12345', 'password_confirmation': 'nope'}); check('profile password mismatch -> 422', s == 422, (s, b))
s, b, _ = call('POST', '/profile', cardio, {'name': 'Dr. Ananya Rao', 'address': 'Bengaluru', 'footer': 'MD, DM Cardiology'}); check('update profile cardiologist', s == 200 and b['data']['editable']['footer'] == 'MD, DM Cardiology', (s, b))
s, b, _ = call('DELETE', '/profile/logo', cardio); check('delete cardiologist logo', s == 200, (s, b))

# ---------------------------------------------------------------- delete client + ecg, forgot, logout
s, b, _ = call('DELETE', f"/ecg-records/{oem_ecg_ids[-1]}", oem); check('oem delete own ecg', s == 200, (s, b))
s, b, _ = call('DELETE', f"/ecg-records/{oem_ecg_ids[-2]}", cardio); check('cardiologist cannot delete ecg -> 403', s == 403, (s, b))
s, b, _ = call('DELETE', f"/clients/{lotus['id']}", admin); check('delete client', s == 200, (s, b))
s, b, _ = call('POST', '/auth/forgot-password', body={'email': 'client@test.local'}); check('forgot password', s == 200, (s, b))
s, b, _ = call('POST', '/auth/logout', admin); check('logout', s == 200, (s, b))
s, b, _ = call('GET', '/auth/me', admin); check('token revoked after logout -> 401', s == 401, (s, b))

failed = [r for r in results if not r[1]]
print(f"\n{len(results) - len(failed)}/{len(results)} passed")
sys.exit(1 if failed else 0)
