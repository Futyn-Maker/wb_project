import os
from dotenv import load_dotenv

from sqlalchemy import create_engine

from db.models import Base


load_dotenv()


def initialize_database():
    engine = create_engine(os.getenv("PG_CONN_STR"), echo=True)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)


if __name__ == "__main__":
    initialize_database()
