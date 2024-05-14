import re
import pandas as pd


# Load data
knowledge_base = pd.read_excel("data/knowledge_base.xlsx", sheet_name=None)
kb_chunks = knowledge_base["Knowledge_base"]
kb_sources = knowledge_base["Sources"]
qa_pairs = pd.read_excel("data/QA_pairs.xlsx")

# Duplicate search
duplicate_questions = qa_pairs[qa_pairs.duplicated("question", keep=False)]
grouped = duplicate_questions.groupby("question").filter(
    lambda x: len(x["answer"].unique()) > 1)

# Keep only later occurrences and remove complete duplicates
grouped_sorted = grouped.sort_values("id", ascending=True)
cleaned_qa_pairs = grouped_sorted.drop_duplicates(
    subset=["question"], keep="last")

qa_pairs = qa_pairs.drop_duplicates(subset=["question"], keep=False)

qa_pairs = pd.concat([qa_pairs, cleaned_qa_pairs])

qa_pairs = qa_pairs.sort_values("id", ascending=True)

# Remove duplicate chunks
kb_chunks = kb_chunks.drop_duplicates(
    subset=["chunk"], keep="first").sort_values("id")

# Fill in the missing part_id
kb_chunks["part_id"] = kb_chunks["part_id"].fillna(0)

# Clear chunks
pattern = re.compile("<[^>]+>", re.UNICODE)

kb_chunks["chunk"] = kb_chunks["chunk"].replace(
    to_replace="/n", value="\n", regex=False)
kb_chunks["chunk"] = kb_chunks["chunk"].replace(
    to_replace=pattern, value="\n", regex=True)

# Save data
qa_pairs.to_csv("data/qa_pairs_cleaned.csv", index=False)
kb_chunks.to_csv("data/kb_chunks_cleaned.csv", index=False)
