import os

from event_list.page_view import page_view
from event_list.click import click

path = "./event_list/"
file_list = os.listdir(path)
valid_event_list = [file.replace(".py", "") for file in file_list if file.endswith(".py") and not file.startswith("__")]
