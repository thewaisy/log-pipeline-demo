from flask import Response, json


def res(result=None, code=200, headers=None):
    if not result:
        result = {
            'status': code
        }
    return Response(
        json.dumps(result),
        status=code,
        headers=headers,
        mimetype='application/json'
    )

