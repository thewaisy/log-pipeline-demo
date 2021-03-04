from module.helper.response import res
from werkzeug.exceptions import HTTPException


class BasicHTTPError(HTTPException):
    def __init__(self, description=None, response=None):
        self.response = response
        if not self.response:
            self.response = res(
                {
                    'type': 'Internal Server Error',
                    'status': 500,
                }
            )
        HTTPException.__init__(self, description, self.response)

class BadRequestError(BasicHTTPError):
    def __init__(self, description=None, detail=''):
        res_data = {
            'type': 'BadRequest Error',
            'status': 400,
            'errors': {
                "message": detail
            }
        }
        self.response = res(res_data)
        BasicHTTPError.__init__(self, description, self.response)

class InternalServerError(BasicHTTPError):
    def __init__(self, description=None, detail=''):
        self.response = res(
            {
                'type': 'Internal Server Error',
                'status': 500,
                'errors': {
                    "message": detail
                }
            }
        )
        BasicHTTPError.__init__(self, description, self.response)
