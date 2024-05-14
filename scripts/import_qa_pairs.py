import os
import pandas as pd
from dotenv import load_dotenv

from db.crud import add_qa_pair
from db.database import get_db


load_dotenv()


def import_qa_pairs(csv_file_path: str):
    db = next(get_db())
    df = pd.read_csv(csv_file_path)
    for _, row in df.iterrows():
        question = row["question"].strip()
        answer = row["answer"].strip()
        add_qa_pair(db, question, answer)
    db.close()


if __name__ == "__main__":
    csv_path = os.path.join(
        os.path.dirname(
            os.path.dirname(
                os.path.abspath(__file__))),
        'data',
        'qa_pairs_cleaned.csv')
    import_qa_pairs(csv_path)
