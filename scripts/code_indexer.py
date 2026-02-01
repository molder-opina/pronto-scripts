#!/usr/bin/env python3
"""
Code Indexer using Ollama embeddings and ChromaDB vector store.

This script indexes the codebase for semantic search using Retrieval-Augmented Generation (RAG).
"""

import os
from typing import Any

import chromadb
import requests


class OllamaEmbedder:
    """Embedder using Ollama API."""

    def __init__(
        self, model: str = "mxbai-embed-large:latest", base_url: str = "http://localhost:11434"
    ):
        self.model = model
        self.base_url = base_url

    def embed(self, text: str) -> list[float]:
        """Generate embedding for text using Ollama."""
        url = f"{self.base_url}/api/embeddings"
        payload = {"model": self.model, "prompt": text}
        response = requests.post(url, json=payload)
        response.raise_for_status()
        data = response.json()
        return data["embedding"]


class CodeChunker:
    """Chunker for code files using recursive character splitting."""

    def __init__(self, chunk_size: int = 1000, chunk_overlap: int = 200):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def chunk_text(self, text: str, file_path: str) -> list[dict[str, Any]]:
        """Chunk text into overlapping segments with metadata."""
        chunks = []
        start = 0
        lines = text.split("\n")
        total_chars = len(text)

        while start < total_chars:
            end = min(start + self.chunk_size, total_chars)
            chunk_text = text[start:end]

            # Find line numbers
            start_line = sum(1 for c in text[:start] if c == "\n") + 1
            end_line = sum(1 for c in text[:end] if c == "\n") + 1

            chunks.append(
                {
                    "text": chunk_text,
                    "file_path": file_path,
                    "start_line": start_line,
                    "end_line": end_line,
                }
            )

            # Move start position with overlap
            start = end - self.chunk_overlap
            if start >= total_chars:
                break

        return chunks


class CodeIndexer:
    """Main indexer class."""

    def __init__(
        self, embedder: OllamaEmbedder, chunker: CodeChunker, db_path: str = "./chroma_db"
    ):
        self.embedder = embedder
        self.chunker = chunker
        self.client = chromadb.PersistentClient(path=db_path)
        self.collection = self.client.get_or_create_collection("code_index")

    def load_files(self, root_dir: str, extensions: list[str] = None) -> list[str]:
        """Load file paths to index."""
        if extensions is None:
            extensions = [".py", ".js", ".ts", ".html", ".css", ".sql"]

        files = []
        for dirpath, dirnames, filenames in os.walk(root_dir):
            # Skip certain directories
            dirnames[:] = [
                d
                for d in dirnames
                if not d.startswith(".") and d not in ["node_modules", "__pycache__", ".venv"]
            ]
            for filename in filenames:
                if any(filename.endswith(ext) for ext in extensions):
                    files.append(os.path.join(dirpath, filename))
        return files

    def index_file(self, file_path: str) -> None:
        """Index a single file."""
        try:
            with open(file_path, encoding="utf-8", errors="ignore") as f:
                content = f.read()
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return

        chunks = self.chunker.chunk_text(content, file_path)

        for i, chunk in enumerate(chunks):
            embedding = self.embedder.embed(chunk["text"])
            doc_id = f"{file_path}:{chunk['start_line']}-{chunk['end_line']}"

            self.collection.add(
                ids=[doc_id],
                embeddings=[embedding],
                documents=[chunk["text"]],
                metadatas=[
                    {
                        "file_path": chunk["file_path"],
                        "start_line": chunk["start_line"],
                        "end_line": chunk["end_line"],
                    }
                ],
            )

    def index_all(self, root_dir: str) -> None:
        """Index all files in directory."""
        files = self.load_files(root_dir)
        print(f"Found {len(files)} files to index")

        for file_path in files:
            print(f"Indexing {file_path}")
            self.index_file(file_path)

        print("Indexing complete")

    def search(self, query: str, n_results: int = 5) -> dict[str, Any]:
        """Search the index."""
        query_embedding = self.embedder.embed(query)
        results = self.collection.query(query_embeddings=[query_embedding], n_results=n_results)
        return results


def main():
    """Main function."""
    embedder = OllamaEmbedder(model="glm-4.7-flash:latest")
    chunker = CodeChunker(chunk_size=1000, chunk_overlap=200)
    indexer = CodeIndexer(embedder, chunker)

    # Index the current directory
    indexer.index_all(".")

    # Example search
    results = indexer.search("function to handle orders")
    print("Search results:")
    for i, doc in enumerate(results["documents"][0]):
        metadata = results["metadatas"][0][i]
        print(
            f"File: {metadata['file_path']}, Lines: {metadata['start_line']}-{metadata['end_line']}"
        )
        print(f"Text: {doc[:200]}...")
        print("---")


if __name__ == "__main__":
    main()
