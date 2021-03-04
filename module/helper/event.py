from datetime import datetime
from module.error.standard import BadRequestError
import event_list as el

class Event:
    event_key_list = ['event', 'data']

    event_list = el.valid_event_list

    def __init__(self, id, body_data):
        self.id = id
        self.body_data = body_data
        self._create_event_data()

    def _create_event_data(self):
        # 유효성 검사
        self._check_event_valid()

        if not self.body_data['event'] in self.event_list:
            raise BadRequestError(detail='Invalid event. {}'.format(self.body_data['event']))

        # 이벤트 함수 불러오기
        event_func = getattr(el, self.body_data['event'])

        log_head = {
            'id': self.id,
            'timestamp': datetime.utcnow().timestamp(),
        }

        # 데이터 생성
        new_log_data = event_func(self.body_data)

        log_data = {**log_head, **new_log_data}

        return log_data

    def _check_event_valid(self):
        for key in self.body_data.keys():
            if not key in self.event_key_list:
                raise BadRequestError(detail='Invalid json data. {}'.format(key))

