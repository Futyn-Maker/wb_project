from fastapi import FastAPI, HTTPException, Depends
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

from db.crud import get_answer_from_qa_pairs, add_answered_question
from db.database import get_db
from app.rag import get_answer


app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/get_answer/")
async def return_answer(question: str, db: Session = Depends(get_db)):
    answer = get_answer_from_qa_pairs(db, question)
    if answer is None:
        try:
            answer = get_answer(question)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

        try:
            add_answered_question(db, question, answer)
        except Exception:
            raise HTTPException(
                status_code=500,
                detail="Failed to add answered question to the database")

    return {"question": question, "answer": answer}
