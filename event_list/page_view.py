from module.error.standard import BadRequestError

def page_view(data):
    """
    page_view 이벤트

    event: string (necessary)
    data: dict

    """
    valid_page_name = [
        'test_page',
    ]

    valid_type = ['page', 'popup']

    event_name = data['event']
    event_info = data['data']

    # 유효성 확인
    if not event_info.get('page_name') in valid_page_name:
        raise BadRequestError(detail='Invalid page_name. {}'.format(event_info.get('page_name')))

    page_name = event_info['page_name']

    type = event_info.get('type') if event_info.get('type') in valid_type else 'page'

    return {
        'event': event_name,
        'page_name': page_name,
        'type': type
    }
