from sqlalchemy import func
from sqlalchemy.orm import Session

from .models import QAPair, AnsweredQuestion


def add_qa_pair(db: Session, question: str, answer: str):
    qa_pair = QAPair(question=question, answer=answer)
    db.add(qa_pair)
    db.commit()
    db.refresh(qa_pair)
    return qa_pair


def add_answered_question(db: Session, question: str, answer: str):
    answered_question = AnsweredQuestion(question=question, answer=answer)
    db.add(answered_question)
    db.commit()
    db.refresh(answered_question)
    return answered_question


def get_answer_from_qa_pairs(db: Session, question: str):
    question_lower = question.lower()
    result = db.query(QAPair).filter(func.lower(
        QAPair.question) == question_lower).first()
    if result:
        return result.answer
    return None
