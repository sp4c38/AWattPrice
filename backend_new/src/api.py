from fastapi import FastAPI

app = FastAPI()

@app.get("/data/{region}")
def get_data(region: str):
    pass
