"""Captures every GET the Flutter panel makes, for each demo role, from the
local test backend (fictional seed data) into one JSON file for demo mode."""
import json, sys, urllib.request, urllib.error, urllib.parse, datetime

BASE = 'http://127.0.0.1:8000/api/v2'
OUT = sys.argv[1]
ROLES = {
    'admin': ('admin@example.com', 'Demo@123'),
    'oem': ('oem@example.com', 'Demo@123'),
    'client': ('client@example.com', 'Demo@123'),
    'citycare': ('citycare@example.com', 'Demo@123'),
    'cardio': ('cardio@example.com', 'Demo@123'),
}


def call(method, path, token=None, body=None, query=None):
    url = BASE + path
    if query:
        url += '?' + urllib.parse.urlencode(query)
    headers = {'Accept': 'application/json'}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read())
        except Exception:
            return e.code, None


def get(token, path, **query):
    code, body = call('GET', path, token, query=query or None)
    return body if code == 200 else None


def full_list(token, path, **query):
    out, page = [], 1
    while True:
        body = get(token, path, per_page=100, page=page, **query)
        if body is None:
            return None
        out += body.get('data', [])
        meta = body.get('meta') or {}
        if page >= int(meta.get('last_page') or 1):
            return out
        page += 1


world = {'captured_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'roles': {}, 'records': {}, 'staff_details': {}}

for key, (email, pw) in ROLES.items():
    code, body = call('POST', '/auth/login', body={'email': email, 'password': pw, 'device_name': 'export'})
    assert code == 200, (key, code, body)
    token = body['data']['token']
    user = body['data']['user']
    r = {'email': email, 'user': user, 'login_message': body.get('message')}
    r['dashboard'] = get(token, '/dashboard')['data']
    r['profile'] = get(token, '/profile')['data']
    n = get(token, '/notifications')
    r['notifications'] = {'items': n['data'], 'unread_total': n.get('unread_total', 0)}

    recs = full_list(token, '/ecg-records') or []
    r['record_ids'] = [x['id'] for x in recs]
    for x in recs:
        d = get(token, f"/ecg-records/{x['id']}")['data']
        world['records'][str(x['id'])] = d
    form = None
    for x in recs:
        f = get(token, f"/ecg-records/{x['id']}/diagnose")
        if f:
            form = f['data']['templates']
            break
    r['templates'] = form or []

    lists = {}
    for name, path in [('clients', '/clients'), ('admin_staffs', '/admin-staffs'), ('staffs', '/staffs'),
                       ('cardiologists', '/cardiologists'), ('devices', '/devices'), ('oem_users', '/oem-users')]:
        lists[name] = full_list(token, path)
    r['lists'] = lists

    if lists['clients'] is not None:
        r['client_details'] = {str(c['id']): get(token, f"/clients/{c['id']}")['data'] for c in lists['clients']}
        r['client_staff'] = {str(c['id']): full_list(token, f"/clients/{c['id']}/staff") for c in lists['clients']}
    if lists['cardiologists'] is not None:
        r['cardiologist_details'] = {str(c['id']): get(token, f"/cardiologists/{c['id']}")['data'] for c in lists['cardiologists']}
    if lists['oem_users'] is not None:
        r['oem_user_details'] = {str(c['id']): get(token, f"/oem-users/{c['id']}")['data'] for c in lists['oem_users']}
    for s in (lists['staffs'] or []) + (lists['admin_staffs'] or []):
        d = get(token, f"/staff/{s['id']}")
        if d:
            world['staff_details'][str(s['id'])] = d['data']

    hosp = (get(token, '/lookups/hospitals') or {}).get('data', [])
    r['lookups'] = {
        'hospitals': hosp,
        'cardiologists': (get(token, '/lookups/cardiologists') or {}).get('data', []),
        'staffs': {str(h['id']): (get(token, '/lookups/staffs', hospital_id=h['id']) or {}).get('data', []) for h in hosp},
        'devices': {str(h['id']): (get(token, '/lookups/devices', hospital_id=h['id']) or {}).get('data', []) for h in hosp},
    }
    world['roles'][key] = r
    call('POST', '/auth/logout', token)
    print(key, 'records', len(recs), {k: (None if v is None else len(v)) for k, v in lists.items()})

json.dump(world, open(OUT, 'w'), indent=1)
print('wrote', OUT)
