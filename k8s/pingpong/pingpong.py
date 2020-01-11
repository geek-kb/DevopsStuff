from flask import Flask
import redis
import datetime
import logging
from flask_caching import Cache
import json
import os


redis_server_env_var = 'REDIS_MASTER_SERVICE_HOST'
redis_port_env_var = 'REDIS_MASTER_SERVICE_PORT_REDIS'
redis_password = 'CtIBHGLv3Z'

for k, v in os.environ.items():
    if redis_server_env_var in k:
        redis_server_addr = v
    if redis_port_env_var in k:
        redis_server_port = v

app = Flask(__name__)
cache = Cache(app, config={'CACHE_TYPE': 'redis', 'CACHE_REDIS_HOST': redis_server_addr,'CACHE_REDIS_PORT': redis_server_port,'CACHE_REDIS_DB': 0, 'CACHE_REDIS_PASSWORD': redis_password })
nowTime = datetime.datetime.now()
r = redis.Redis(host=redis_server_addr, port=redis_server_port, db=1, password=redis_password)

logging.basicConfig(level=logging.DEBUG,format='%(asctime)s %(levelname)s %(threadName)s : %(message)s')

@app.route("/ping")
#@cache.cached(timeout=10)
def ping():
    nt = nowTime.time()
    data = json.dumps(
        { "json_object": [
            {
                "pong": "True"
            },
            {
                "time": str(nt)
            }
        ]})
    r.set(str(nowTime),data)
    return 'pong\n{}'.format(data)

@app.route("/")
#@cache.cached(timeout=20)
def home():
    nt = nowTime.time()
    data = json.dumps(
        { "json_object": [
            {
                "pong": "False"
            },
            {
                "time": str(nt)
            }
        ]})
    r.set(str(nowTime),data)
    return 'pong\n{}'.format(data)

if __name__ == "__main__":
    app.run(debug=True,host='0.0.0.0')
