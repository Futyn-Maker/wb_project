from sqlalchemy import Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base


Base = declarative_base()


class QAPair(Base):
    __tablename__ = "qa_pairs"
    id = Column(Integer, primary_key=True, autoincrement=True)
    question = Column(String)
    answer = Column(String)


class AnsweredQuestion(Base):
    __tablename__ = "answered_questions"
    id = Column(Integer, primary_key=True, autoincrement=True)
    question = Column(String)
    answer = Column(String)
