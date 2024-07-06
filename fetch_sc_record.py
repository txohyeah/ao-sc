import sys
import pathlib

# 获取当前文件的绝对路径
current_dir = pathlib.Path(__file__).resolve().parent
# 获取上一层目录的路径
parent_dir = current_dir.parent
# 将上一层目录添加到模块搜索路径
sys.path.insert(0, str(parent_dir))

import ao
import ao.su_messages
from datetime import datetime
import json


start_time = datetime(2024, 6, 13, 0, 0, 0)
end_time = datetime(2024, 6, 13, 1, 0, 0)
proccess = "m3PaWzK4PTG9lAaqYQPaPdOcXdO8hYqi5Fe9NWqXd0w"


def start():
    resp_dict = ao.get_messages_via_date(proccess, start_time, end_time)
    su_msg = ao.su_messages.parse(resp_dict)

    edges = su_msg.get_edges_via_tags("Action", "Eval")
    # convert edges to array with dict elements
    edges_array = [edge.to_dict() for edge in edges]

    with open("./data/msg_eval.json", "w") as f:
        f.write(json.dumps(edges_array, indent=4))


if __name__ == '__main__':
    start()