import json
import boto3
import random
import traceback
import time
import base64
from module.error.standard import InternalServerError
from app import app

# json_dict 넘어옴
class Kinesis:
    MAX_RETRY_COUNT = 3

    kinesis_option = {
        'service': 'kinesis',
        'region': app.config['AWS_REGION'],
        'dry_run': app.config['DEBUG']
    }
    kinesis_stream_name = {
        'event': app.config['KINESIS_DATA_STREAM_TO_S3'],
        'purchased': app.config['KINESIS_DATA_STREAM_TO_ES']
    }

    def __init__(self):
        self._client = boto3.client(self.kinesis_option['service'], self.kinesis_option['region'])
        self.event = ''

    # 이벤트 로그 to KDS
    def send_event_log_kds(self, event, log_data):
        self.event = event

        if isinstance(log_data, list):
            self._put_records(log_data)
        else:
            self._put_record(log_data)

        return False


    def _put_record(self, data):
        # athena json 인식을 위한 개행문 추가
        data_json = json.dumps(data, sort_keys=False, ensure_ascii=False)+"\n"
        partition_key = '{}-log-{:05}'.format(self.event, random.randint(1, 1024))

        if self.kinesis_option['dry_run']:
            print(data_json)
            return

        for _ in range(self.MAX_RETRY_COUNT):
            try:
                response = self._client.put_record(StreamName=self.kinesis_stream_name[self.event], Data=data_json,
                                                   PartitionKey=partition_key)
                break
            except Exception as ex:
                traceback.print_exc()
                time.sleep(1)
        else:
            raise InternalServerError(
                detail='[ERROR] Failed to put_records into stream: {}'.format(self.kinesis_stream_name[self.event]))

    def _put_records(self, data_list):
        kds_data_list = []
        random_int = random.randint(1, 1024)

        for data in data_list:
            # athena json 인식을 위한 개행문 추가
            partition_key = '{}-log-{:05}'.format(self.event, random_int)
            kds_data = {'Data': json.dumps(data, sort_keys=False, ensure_ascii=False)+"\n", 'PartitionKey': partition_key}
            kds_data_list.append(kds_data)
            random_int += 1

        if self.kinesis_option['dry_run']:
            print(record_data_list)
            return

        for _ in range(self.MAX_RETRY_COUNT):
            try:
                response = self._client.put_records(StreamName=self.kinesis_stream_name[self.event], Records=kds_data_list)
                break
            except Exception as ex:
                traceback.print_exc()
                time.sleep(1)
        else:
            raise InternalServerError(
                detail='[ERROR] Failed to put_records into stream: {}'.format(self.kinesis_stream_name[self.event]))