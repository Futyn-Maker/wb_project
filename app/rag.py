from dotenv import load_dotenv

from haystack import Pipeline
from haystack_integrations.document_stores.pgvector import PgvectorDocumentStore
from haystack.components.embedders import SentenceTransformersTextEmbedder
from haystack_integrations.components.retrievers.pgvector import PgvectorEmbeddingRetriever
from haystack.components.builders import PromptBuilder
from haystack_integrations.components.generators.llama_cpp import LlamaCppGenerator


load_dotenv()

embedding_model = "Futyn-Maker/wb_questions"

template = """<|begin_of_text|><|start_header_id|>system<|end_header_id|>

Ты — Помощник, русскоязычный автоматический ассистент. Ты работаешь в технической поддержке компании Wildberries, крупного российского маркетплейса. Ты помогаешь сотрудникам пунктов выдачи заказов (ПВЗ), отвечая на их вопросы. Ответь на вопрос сотрудника ПВЗ, используя вспомогательную информацию из базы знаний. Отвечай последовательно и по существу. Не предоставляй нерелевантную или слишком общую информацию, давай такой ответ, который прямо отвечает на поставленный вопрос, при этом следи, чтобы релевантная информация была передана полностью. Отвечай только на основе вспомогательной информации из базы знаний. Вежливо отказывайся отвечать на вопросы, которые никак не связаны с Wildberries.<|eot_id|><|start_header_id|>user<|end_header_id|>

Вспомогательная информация из базы знаний:
{% for document in documents %}
    {{ document.content }}
{% endfor %}

Вопрос: {{question}}<|eot_id|><|start_header_id|>assistant<|end_header_id|>

"""

document_store = PgvectorDocumentStore(
    embedding_dimension=1024,
    language="russian",
    vector_function="cosine_similarity",
    recreate_table=False,
    search_strategy="exact_nearest_neighbor",
)

text_embedder = SentenceTransformersTextEmbedder(
    model=embedding_model,
    prefix="Instruct: Given a question, retrieve relevant documents that best answer the question\nQuery: ",
    progress_bar=False,
    normalize_embeddings=True)
retriever = PgvectorEmbeddingRetriever(document_store=document_store)
prompt_builder = PromptBuilder(template=template)
generator = LlamaCppGenerator(
    model="saiga_llama3_8b_wildberries_4bit_gguf-unsloth.Q4_K_M.gguf",
    n_ctx=8192,
    n_batch=128,
    model_kwargs={
        "n_parts": 1,
        "verbose": True,
        "seed": 42, },
    generation_kwargs={
        "max_tokens": 1024,
        "temperature": 0.6,
        "top_k": 30,
        "top_p": 0.8,
        "repeat_penalty": 1.1,
    },
)

generator.warm_up()

rag_pipeline = Pipeline()

rag_pipeline.add_component("text_embedder", text_embedder)
rag_pipeline.add_component("retriever", retriever)
rag_pipeline.add_component("prompt_builder", prompt_builder)
rag_pipeline.add_component("llm", generator)

rag_pipeline.connect(
    "text_embedder.embedding",
    "retriever.query_embedding")
rag_pipeline.connect("retriever", "prompt_builder.documents")
rag_pipeline.connect("prompt_builder", "llm")


def get_answer(question):
    result = rag_pipeline.run(
        {"text_embedder": {"text": question}, "prompt_builder": {"question": question}})
    return result["llm"]["replies"][0].strip()
