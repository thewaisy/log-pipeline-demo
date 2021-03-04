from module.error.standard import BadRequestError


def click(data):
    """
    click 이벤트

    event: string (necessary)
    data: dict

    """
    valid_type = ['button', 'image', 'icon', 'banner', 'etc']

    valid_page_name = [
        'test_page',
    ]

    valid_cta = [
        'test_click',
    ]

    event = data['event']
    event_info = data['data']

    # 유효성 확인
    if not event_info.get('page_name') in valid_page_name:
        raise BadRequestError(detail='Invalid page_name. {}'.format(event_info.get('page_name')))

    page_name = event_info['page_name']

    type = event_info.get('type') if event_info.get('type') in valid_type else 'button'

    if not event_info.get('name') in valid_cta:
        raise BadRequestError(detail='Invalid cta. {}'.format(event_info.get('cta')))

    cta = event_info.get('cta')

    return {
        'event': event,
        'page_name': page_name,
        'type': type,
        'cta': cta
    }
