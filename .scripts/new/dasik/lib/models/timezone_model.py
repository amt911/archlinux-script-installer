from pydantic import BaseModel

class TimezoneModel(BaseModel):
    region : str
    city : str