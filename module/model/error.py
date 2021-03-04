from flask import json, request
import boto3
import random
import traceback
import time
import base64
import os
from flask import Flask

app = Flask(__name__)
app.config.from_object(__name__)
app.config.from_object(os.getenv('LOG_ENVIRONMENT', 'configuration.ProductionConfig'))

"""
에러 로그 to KDS
"""


class Error:
    MAX_RETRY_COUNT = 3

    kinesis_option = {
        'service': 'kinesis',
        'region': app.config['AWS_REGION'],
        'dry_run': False
    }
    kinesis_stream_name = app.config['KINESIS_DATA_STREAM_ERROR_TO_S3']

    event = "error"

    def __init__(self):
        self._client = boto3.client(self.kinesis_option['service'], self.kinesis_option['region'])

    def send_error_log_kds(self, error_msg):

        header_dict = {}
        for key in request.headers.keys():
            header_dict[key] = request.headers.get(key)

        body_dict = request.json if request.json else request.form

        result_dict = {
            "request_data": {**header_dict, **body_dict},
            "error_log": error_msg
        }
        self._send_error_log_kds(result_dict)
        return False

    def _send_error_log_kds(self, log_data):

        if isinstance(log_data, list):
            self._put_records(log_data)
        else:
            self._put_record(log_data)

        return False

    def _put_record(self, data):
        # athena json 인식을 위한 개행문 추가
        data_json = json.dumps(data, sort_keys=False, ensure_ascii=False) + "\n"

        partition_key = '{}-log-{:05}'.format(self.event, random.randint(1, 1024))

        if self.kinesis_option['dry_run']:
            print(data_json)
            return

        for _ in range(self.MAX_RETRY_COUNT):
            try:
                response = self._client.put_record(StreamName=self.kinesis_stream_name, Data=data_json,
                                                   PartitionKey=partition_key)
                break
            except Exception as ex:
                traceback.print_exc()
                time.sleep(1)

    def _put_records(self, data_list):
        kds_data_list = []
        random_int = random.randint(1, 1024)

        for data in data_list:
            # athena json 인식을 위한 개행문 추가
            partition_key = '{}-log-{:05}'.format(self.event, random_int)
            kds_data = {'Data': json.dumps(data, sort_keys=False, ensure_ascii=False) + "\n",
                        'PartitionKey': partition_key}
            kds_data_list.append(kds_data)
            random_int += 1

        if self.kinesis_option['dry_run']:
            print(record_data_list)
            return

        for _ in range(self.MAX_RETRY_COUNT):
            try:
                response = self._client.put_records(StreamName=self.kinesis_stream_name, Records=kds_data_list)
                break
            except Exception as ex:
                traceback.print_exc()
                time.sleep(1)
