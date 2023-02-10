#!/usr/bin/env python
# ***********************************************************************
# $ Copyright (c) 2023
# =======================================================================
# author    date       purpose
# ========  ========   ==================================================
# btoranto  02/07/2023 Send messages to Google Chat
# **************************************************************
from json import dumps
from httplib2 import Http

v_BotText = r'Insert your message here '

def p_ChatBot(v_BotText):
    url = 'https://chat.googleapis.com/v1/spaces/AAAAeWpCAuw/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=Vvzmbyeh387EGykdOPzW1QvIQDdv5JXet843Kiu8OE0%3D'
    bot_message = {
        'text' : v_BotText}
    message_headers = {'Content-Type': 'application/json; charset=UTF-8'}
    http_obj = Http()
    response = http_obj.request(
        uri=url,
        method='POST',
        headers=message_headers,
        body=dumps(bot_message),
    )

if __name__ == '__main__':
    p_ChatBot(v_BotText)