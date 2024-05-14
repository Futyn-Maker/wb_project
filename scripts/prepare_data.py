import pandas as pd

# Load data
kb_chunks = pd.read_csv("data/kb_chunks_cleaned.csv")
qa_pairs = pd.read_csv("data/qa_pairs_cleaned.csv")

# Combine questions with answers
qa_pairs["combined"] = "Query: " + qa_pairs["question"] + \
    "\n\nAnswer: " + qa_pairs["answer"]

# Add question-answers to the knowledge base
qa_combined = qa_pairs["combined"].tolist()

new_rows = [{"id": 2000 + i, "chunk": text, "document_id": 14, "part_id": 0}
            for i, text in enumerate(qa_combined)]

kb_chunks = pd.concat([kb_chunks, pd.DataFrame(new_rows)], ignore_index=True)

# Save data
kb_chunks.to_csv("data/kb_chunks_combined.csv", index=False)
