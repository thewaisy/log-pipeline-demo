class Config(object):
    DEBUG = True
    # AWS 설정
    AWS_REGION = "ap-northeast-2"

    # 키네시스 스트림
    KINESIS_DATA_STREAM_TO_S3 = "kinesis-stream-to-s3"
    KINESIS_DATA_STREAM_TO_ES = "kinesis-stream-to-es"
    KINESIS_DATA_STREAM_ERROR_TO_S3 = "error-kinesis-stream-to-s3"

class development(Config):
    # 엘라스틱 서치 설정
    # docker elasticsearch로 대체
    ES_EVENT_LOG_HOST = "http://elasticsearch:9200" # aws elasticsearch service domain

