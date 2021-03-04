import math

"""
  millisecond timestamp to double
  13자리 millisecond timestamp 10.3f 소수변환
"""
def convert_millisecond_int_to_float(timestamp):
    # 자릿수 확인
    timestamp = float(timestamp)
    square_root = int(math.log10(timestamp))-9
    # double 변환
    double_timestamp = timestamp/(10 ** square_root)
    return float("{:.3f}".format(double_timestamp))
