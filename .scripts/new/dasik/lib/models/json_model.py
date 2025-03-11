from .locale_model import LocaleModel
from .timezone_model import TimezoneModel
from pydantic import BaseModel

class JsonModel(BaseModel):
    locales : LocaleModel
    timezone : TimezoneModel