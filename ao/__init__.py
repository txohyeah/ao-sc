import requests
import arseeding
import time
from datetime import datetime, timedelta

SDK = 'ao.py'
MU = 'https://mu.ao-testnet.xyz'
CU = 'https://cu.ao-testnet.xyz'
SU = 'https://su-router.ao-testnet.xyz'
SCHEDULER = '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA'

def send_message(singer, pid, anchor, tags, data='', mu=MU, timeout=5):
    default_tags = {
        'Data-Protocol': 'ao',
        'Variant': 'ao.TN.1',
        'Type': 'Message',
        'SDK': SDK,
    }
    default_tags.update(tags)
    b = arseeding.BundleItem(singer, pid, anchor, default_tags, data)
    return b.id, requests.post(mu, data=b.binary, headers={'Content-Type': 'application/octet-stream'}, timeout=timeout).json()


def dry_run(signer, pid, anchor, tags, data='', cu=CU, timeout=60):
    default_tags = {
        'Data-Protocol': 'ao',
        'Variant': 'ao.TN.1',
        'Type': 'Message',
        'SDK': SDK,
    }
    default_tags.update(tags)

    tags = [{'name':k, 'value':v} for k,v in tags.items()]
    url = '%s/dry-run?process-id=%s' % (cu, pid)
    payload = {
        'Target': pid,
        'Owner': signer.address,
        'Anchor': anchor,
        'Data': data,
        'Tags': tags,
    }
    return requests.post(url, json=payload, timeout=timeout).json()
    
def spawn_process(singer, module, anchor, tags, data='', mu=MU, scheduler=SCHEDULER):
    default_tags = {
        'Data-Protocol': 'ao',
        'Variant': 'ao.TN.1',
        'Type': 'Process',
        'Scheduler':scheduler,
        'Module':module,
        'SDK': SDK,
    }
    default_tags.update(tags)
    b = arseeding.BundleItem(singer, '', anchor, default_tags, data)
    return b.id, requests.post(mu, data=b.binary, headers={'Content-Type': 'application/octet-stream'}).json()

def get_result(pid, message_id, timeout=60, cu=CU):
    return requests.get(f'{cu}/result/{message_id}?process-id={pid}', timeout=timeout).json()

def send_and_get(singer, pid, anchor, tags, data='', timeout=60, mu=MU, cu=CU):
    mid, _ = send_message(singer, pid, anchor, tags, data, mu)
    return mid, get_result(pid, mid, timeout=timeout, cu=cu)

def get_latest_messages(pid, time_offset, timeout = 60, su=SU):
    now = datetime.now()
    past_time = now - timedelta(seconds=time_offset)
    past_timestamp = int(time.mktime(past_time.timetuple())) * 1000
    return get_messages(pid, from_timestamp = past_timestamp, timeout = timeout, su=su)

def get_messages_via_date(pid, start_time, end_time, timeout = 60, su=SU):
    start_timestamp = int(time.mktime(start_time.timetuple())) * 1000
    end_timestamp = int(time.mktime(end_time.timetuple())) * 1000
    return get_messages(pid, from_timestamp = start_timestamp, to_timestamp = end_timestamp, timeout = timeout, su=su)

def get_messages(pid, from_timestamp = None, to_timestamp = None, timeout = 60, su=SU):
    url = f"{su}/{pid}"
    param = ""
    if from_timestamp is not None:
        param = param + f"?from={from_timestamp}"
    
    if to_timestamp is not None:
        param = param + f"&to={to_timestamp}"

    if param != "":
        url = url + param
    print(url)
    return requests.get(url, timeout=timeout).json()

def get_message(pid, mid, timeout = 60, su=SU):
    return requests.get(f"{su}/{mid}?process-id={pid}", timeout=timeout).json()