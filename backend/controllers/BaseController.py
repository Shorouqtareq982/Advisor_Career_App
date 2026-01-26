from helpers.config import get_settings, Settings
import os
import random
import string

class BaseController:
    
    def __init__(self):

        self.app_settings = get_settings()