import pandas as pd
from dotenv import load_dotenv

from haystack import Document
from haystack import Pipeline
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack.components.embedders import SentenceTransformersDocumentEmbedder
from haystack.components.writers import DocumentWriter


load_dotenv()

embedding_model = "Futyn-Maker/wb_questions"

# Load data
kb_chunks = pd.read_csv("data/kb_chunks_combined.csv")

documents = [Document(content=row["chunk"])
             for index, row in kb_chunks.iterrows()]

# Initialize the DocumentStore
document_store = PgvectorDocumentStore(
    embedding_dimension=1024,
    language="russian",
    vector_function="cosine_similarity",
    recreate_table=True,
    search_strategy="exact_nearest_neighbor",
)

# Create indexing pipeline
indexing_pipeline = Pipeline()
indexing_pipeline.add_component(
    instance=SentenceTransformersDocumentEmbedder(
        model=embedding_model,
        normalize_embeddings=True),
    name="embedder")
indexing_pipeline.add_component(
    instance=DocumentWriter(
        document_store=document_store),
    name="writer")
indexing_pipeline.connect("embedder.documents", "writer.documents")

indexing_pipeline.run({"documents": documents})
