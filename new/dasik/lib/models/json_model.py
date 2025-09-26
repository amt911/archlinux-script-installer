from typing import Optional
from .locale_model import LocaleModel
from .timezone_model import TimezoneModel
from .network_model import NetworkModel
from pydantic import BaseModel

class JsonModel(BaseModel):
    locales : LocaleModel
    timezone : TimezoneModel
    network : NetworkModel
    hostname : str
    enable_microcode : bool = False