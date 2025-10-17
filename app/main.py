from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from .llm_agent import query_llm

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "LLM FastAPI App Running!"}

@app.post("/llm")
async def llm_endpoint(request: Request):
    data = await request.json()
    query = data.get("query", "")
    answer = query_llm(query)
    return JSONResponse({"answer": answer})
