import os
from flask import Flask, request

app = Flask(__name__)
app.config.from_object(__name__)
app.config.from_object(os.getenv('ENV', 'configuration.development'))

from module.helper.response import res
from module.error.standard import BadRequestError, InternalServerError
from module.helper.kinesis import Kinesis
from module.helper.event import Event

kds = Kinesis()

@app.route('/', methods=['POST'])
def event():
    # device_timestamp 값 확인
    valid_header = ['id']
    for key in valid_header:
        if not key in request.headers:
            raise BadRequestError(detail='No {}.'.format(key))

    # 데이터 확인 확인
    body_data = request.json

    if not body_data:
        raise BadRequestError(detail='No Data, No Entries.')

    id = request.headers.get('id')
    if not id:
        raise BadRequestError(detail='No id.')

    log_data = Event(id, body_data)

    # KDS 데이터 전송
    # kds.send_event_log_kds('event', log_data)

    return res()

if __name__ == '__main__':
    app.run(debug=False, port=80, host='0.0.0.0')
